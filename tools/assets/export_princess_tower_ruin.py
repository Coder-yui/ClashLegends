"""Bake the final princess-tower Rubble surface into a static GLB.

Usage:
  blender -b --factory-startup --python tools/assets/export_princess_tower_ruin.py -- SOURCE.glb OUTPUT.glb
"""

import sys

import bmesh
import bpy


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1 :]
    if len(args) != 2:
        raise SystemExit("expected SOURCE.glb OUTPUT.glb")
    source_path, output_path = args

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=source_path)
    armature = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
    source_mesh = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH")
    action = bpy.data.actions.get("Destroyed")
    if action is None:
        raise RuntimeError("source tower has no Destroyed action")
    armature.animation_data_create()
    armature.animation_data.action = action
    final_frame = action.frame_range[1] - 1.5
    bpy.context.scene.frame_set(int(final_frame), subframe=final_frame % 1.0)

    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = source_mesh.evaluated_get(depsgraph)
    baked_mesh = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=depsgraph)
    baked = bpy.data.objects.new("PrincessTowerRuin", baked_mesh)
    bpy.context.scene.collection.objects.link(baked)
    baked.matrix_world = source_mesh.matrix_world

    rubble_index = next(
        index
        for index, material in enumerate(baked_mesh.materials)
        if material is not None and material.name == "Rubble"
    )
    edit_mesh = bmesh.new()
    edit_mesh.from_mesh(baked_mesh)
    bmesh.ops.delete(
        edit_mesh,
        geom=[face for face in edit_mesh.faces if face.material_index != rubble_index],
        context="FACES",
    )
    # TowerModel3D normally discards below-ground fragments in its shader. The
    # standalone ruin is baked once instead, so its wrapper needs no runtime shader.
    bmesh.ops.bisect_plane(
        edit_mesh,
        geom=list(edit_mesh.verts) + list(edit_mesh.edges) + list(edit_mesh.faces),
        plane_co=(0.0, 0.0, 0.0),
        plane_no=(0.0, 0.0, 1.0),
        clear_inner=True,
        clear_outer=False,
    )
    edit_mesh.to_mesh(baked_mesh)
    edit_mesh.free()

    rubble_material = baked_mesh.materials[rubble_index]
    baked_mesh.materials.clear()
    baked_mesh.materials.append(rubble_material)
    for polygon in baked_mesh.polygons:
        polygon.material_index = 0
    baked_mesh.update()

    bpy.ops.object.select_all(action="DESELECT")
    baked.select_set(True)
    bpy.context.view_layer.objects.active = baked
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_materials="EXPORT",
    )


if __name__ == "__main__":
    main()
