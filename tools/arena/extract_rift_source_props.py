"""Blender extraction of six small props from the original Summoner's Rift map.

Run after prepare_rift_sources.py with Blender --background --python this_file.
Only base.mapgeo and its materials are extracted from the read-only WAD to a
temporary directory. No complete map geometry is archived in the project.
Original connected surface components retain their UVs. Tree crowns are grouped
with an original trunk, rather than importing surrounding terrain chunks.
"""

import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile

import bmesh
import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
ARENA = ROOT / "assets/arena/rift_arena"
DESTINATION = ARENA / "source_props"
SOURCE_WAD = Path("/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/Maps/Shipping/Map11.wad.client")
MAP_PATH = "data/maps/mapgeometry/map11/base.mapgeo"
MAT_PATH = "data/maps/mapgeometry/map11/base.materials.bin"
ATLAS_BY_MESH = {405: "rock_woodland", 542: "rock_cliff", 955: "forest_south"}
SPECS = [
    ("pine_tall", 955, [10, 38, 39, 47, 48, 57, 60], "tree", 2.0),
    ("pine_broad", 955, [7, 32, 44, 54], "tree", 2.0),
    ("pine_compact", 405, [5, 19, 22], "tree", 2.0),
    ("mossy_boulder", 405, [0], "span", 2.5),
    ("hollow_log", 405, [1], "span", 2.5),
    ("carved_runestone", 542, [1], "height", 1.6),
]


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True, capture_output=True)


def bounds(obj):
    vertices = [v.co for v in obj.data.vertices]
    return (Vector([min(v[i] for v in vertices) for i in range(3)]),
            Vector([max(v[i] for v in vertices) for i in range(3)]))


def material(atlas):
    name = "LoLSource_" + atlas
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = False
    mat.surface_render_method = "DITHERED"
    nodes = mat.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.inputs["Roughness"].default_value = 1.0
    shader.inputs["Specular IOR Level"].default_value = 0.0
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = bpy.data.images.load(str(ARENA / "textures" / (atlas + ".png")))
    mat.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    mat.node_tree.links.new(texture.outputs["Alpha"], shader.inputs["Alpha"])
    mat.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return mat


def components(obj):
    adjacency = [[] for _ in obj.data.vertices]
    for edge in obj.data.edges:
        a, b = edge.vertices
        adjacency[a].append(b)
        adjacency[b].append(a)
    visited = set()
    groups = []
    for index in range(len(adjacency)):
        if index in visited:
            continue
        pending, component = [index], []
        visited.add(index)
        while pending:
            vertex = pending.pop()
            component.append(vertex)
            for neighbor in adjacency[vertex]:
                if neighbor not in visited:
                    visited.add(neighbor)
                    pending.append(neighbor)
        groups.append(component)
    return sorted(groups, key=len, reverse=True)


def take_components(source, ranks, name):
    groups = components(source)
    selected = {vertex for rank in ranks for vertex in groups[rank]}
    obj = bpy.data.objects.new(name, source.data.copy())
    bpy.context.collection.objects.link(obj)
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    mesh.verts.ensure_lookup_table()
    bmesh.ops.delete(mesh, geom=[v for v in mesh.verts if v.index not in selected], context="VERTS")
    mesh.to_mesh(obj.data)
    mesh.free()
    return obj


def normalized_source(obj, matrix, atlas):
    obj.parent = None
    for vertex in obj.data.vertices:
        vertex.co = matrix @ vertex.co
    obj.matrix_world.identity()
    low, high = bounds(obj)
    offset = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    factor = 3.1 / max(high - low)
    for vertex in obj.data.vertices:
        vertex.co = (vertex.co - offset) * factor
    # Weld only coincident geometry. UV data remains on per-face loops.
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    bmesh.ops.remove_doubles(mesh, verts=list(mesh.verts), dist=0.0001)
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.materials.clear()
    obj.data.materials.append(material(atlas))


def patch_gltf_cutout(path):
    blob = path.read_bytes()
    json_length = struct.unpack_from("<I", blob, 12)[0]
    document = json.loads(blob[20:20 + json_length])
    for mat in document.get("materials", []):
        mat["alphaMode"] = "MASK"
        mat["alphaCutoff"] = 0.35
        mat["doubleSided"] = True
    data = json.dumps(document, separators=(",", ":")).encode()
    data += b" " * ((-len(data)) % 4)
    remaining = blob[20 + json_length:]
    header = struct.pack("<4sII", b"glTF", 2, 20 + len(data) + len(remaining))
    path.write_bytes(header + struct.pack("<I4s", len(data), b"JSON") + data + remaining)


def extract(geometry):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(geometry))
    sources = {index: bpy.data.objects[f"MapGeo_Instance_{index}"] for index in ATLAS_BY_MESH}
    transforms = {index: obj.matrix_world.copy() for index, obj in sources.items()}
    for index, obj in sources.items():
        normalized_source(obj, transforms[index], ATLAS_BY_MESH[index])
    for obj in list(bpy.data.objects):
        if obj not in sources.values():
            bpy.data.objects.remove(obj, do_unlink=True)
    results, manifest = [], []
    for name, index, ranks, mode, size in SPECS:
        obj = take_components(sources[index], ranks, name)
        if mode == "tree":
            # The source map stores tree trunks separately from foliage. Reuse
            # a true original trunk and align it to each selected canopy volume.
            trunk = take_components(sources[955], [1], name + "_trunk")
            low, high = bounds(obj)
            crown_span = high - low
            t_low, t_high = bounds(trunk)
            trunk_span = t_high - t_low
            trunk_height = max(crown_span.z * 0.9, max(crown_span.x, crown_span.y) * 0.45)
            base_z = low.z - trunk_height * 0.58
            center = (low + high) / 2
            scale = Vector((crown_span.x * 0.16 / trunk_span.x,
                            crown_span.y * 0.16 / trunk_span.y,
                            trunk_height / trunk_span.z))
            for vertex in trunk.data.vertices:
                p = vertex.co - Vector(((t_low.x + t_high.x) / 2, (t_low.y + t_high.y) / 2, t_low.z))
                vertex.co = Vector((p.x * scale.x + center.x,
                                    p.y * scale.y + center.y,
                                    p.z * scale.z + base_z))
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            trunk.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.join()
        low, high = bounds(obj)
        offset = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
        factor = size / ((high - low).z if mode in ("tree", "height") else max(high - low))
        for vertex in obj.data.vertices:
            vertex.co = (vertex.co - offset) * factor
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        destination = DESTINATION / (name + ".glb")
        bpy.ops.export_scene.gltf(filepath=str(destination), export_format="GLB",
                                  use_selection=True, export_yup=True, export_materials="EXPORT",
                                  export_cameras=False, export_lights=False, export_animations=False)
        patch_gltf_cutout(destination)
        low, high = bounds(obj)
        obj.data.calc_loop_triangles()
        manifest.append({
            "id": name,
            "glb": destination.relative_to(ROOT).as_posix(),
            "sha256": sha256(destination),
            "source_mesh": f"MapGeo_Instance_{index}",
            "connected_component_ranks_descending_vertex_count": ranks,
            "source_atlas": ATLAS_BY_MESH[index],
            "assembly": "Original UV mesh components; canopy aligned with original MapGeo_Instance_955 component 1 trunk"
                        if mode == "tree" else "One original connected component; no map ground retained",
            "normalization": "Horizontal center at origin, Godot foot Y=0; baked into vertices",
            "godot_size_xyz": [high.x - low.x, high.z - low.z, high.y - low.y],
            "vertices": len(obj.data.vertices),
            "triangles": len(obj.data.loop_triangles),
            "materials": [mat.name for mat in obj.data.materials],
        })
        results.append(obj)
    for obj in sources.values():
        bpy.data.objects.remove(obj, do_unlink=True)
    return results, manifest


def render_contact(objects, target):
    for index, obj in enumerate(objects):
        obj.location = ((index % 3 - 1) * 4.3, (index // 3 - 0.5) * 4.7, 0)
        text = bpy.data.curves.new("label", "FONT")
        text.body, text.align_x, text.size = obj.name, "CENTER", 0.23
        label = bpy.data.objects.new("label", text)
        bpy.context.collection.objects.link(label)
        label.location = (obj.location.x, obj.location.y - 1.5, 0.05)
    bpy.ops.object.camera_add(location=(0, -17, 25))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type, camera.data.ortho_scale = "ORTHO", 14.5
    scene = bpy.context.scene
    scene.camera = camera
    bpy.ops.object.light_add(type="AREA", location=(0, -6, 18))
    bpy.context.object.data.energy, bpy.context.object.data.size = 3300, 18
    scene.world.color = (0.55, 0.55, 0.55)
    scene.render.engine, scene.cycles.samples = "CYCLES", 24
    scene.view_settings.view_transform, scene.view_settings.exposure = "Standard", 1.0
    scene.render.resolution_x, scene.render.resolution_y = 1600, 1100
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--geometry", type=Path)
    parser.add_argument("--wad", type=Path, default=SOURCE_WAD)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    DESTINATION.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="clash_rift_props_") as staging:
        staging = Path(staging)
        geometry = args.geometry
        if geometry is None:
            run("wadtools", "-L", "warning", "extract", "-i", args.wad, "-o", staging,
                "-x", r"^data/maps/mapgeometry/map11/base\.(mapgeo|materials.bin)$", "--stats=false")
            geometry = staging / "base.glb"
            run("lol2gltf", "mapgeo2gltf", "-m", staging / MAP_PATH,
                "-b", staging / MAT_PATH, "-g", geometry, "-l", "Ignore")
        objects, props = extract(geometry)
        manifest = {
            "source_wad": str(args.wad), "source_geometry": MAP_PATH,
            "source_materials": MAT_PATH, "mapgeo_version": 14,
            "geometry_glb_sha256": sha256(geometry),
            "original_archive_policy": "Read only; only mapgeo and materials decoded into temporary staging",
            "component_recipe": "Normalize each source chunk max span to 3.1, weld coincident vertices at 0.0001; components sorted by vertex count descending",
            "texture_policy": "Unedited original PNG pixels; alpha mask at 0.35; two-sided rough materials named LoLSource_*",
            "purpose": "Small presentation-only decorations, no collision, navigation or map ground",
            "props": props,
        }
        (DESTINATION / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        render_contact(objects, ROOT / "builds/arena_preview/source_props_contact.png")
        print("SOURCE_PROPS_COMPLETE", json.dumps(props), flush=True)


if __name__ == "__main__":
    main()
