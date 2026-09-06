"""Rebuild the editable Rift arena and its runtime GLB with Blender (no add-ons).
Blender --background --python tools/arena/build_rift_arena.py
Coordinates are authored in authoritative tile space; only presentation uses sqrt(2)
foreshortening compensation for the game's existing 45-degree orthographic camera.
"""
import bpy
import math
import random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/arena/rift_arena'
random.seed(71239)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for col in list(bpy.data.collections):
    if col.name != 'Collection':
        bpy.data.collections.remove(col)
base = bpy.data.collections.get('Collection')
base.name = 'Rift Arena'
COLS = {}
for name in ['Terrain', 'Ancient paving', 'Bridges', 'River banks', 'Forest cliffs', 'Pines', 'Ground foliage', 'Runic monuments', 'RiverSurface']:
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    COLS[name] = col


def mat(name, color, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = .88
    if emission:
        p.inputs['Emission Color'].default_value = (*color, 1)
        p.inputs['Emission Strength'].default_value = emission
    return m

stone = [mat('Slate %02d' % i, c) for i, c in enumerate([
    (.22,.29,.28), (.29,.36,.32), (.35,.40,.34), (.26,.32,.30), (.39,.43,.36)])]
cliff = [mat('Basalt %02d' % i, c) for i, c in enumerate([
    (.095,.16,.17), (.14,.21,.21), (.19,.26,.25), (.24,.30,.26)])]
paving = [mat('Weathered limestone %02d' % i,c) for i,c in enumerate([
    (.23,.29,.25),(.28,.33,.28),(.20,.265,.23),(.32,.35,.28),(.26,.31,.27)])]
leaves = [mat('Pine needles %02d' % i,c) for i,c in enumerate([
    (.025,.115,.09),(.035,.18,.12),(.055,.25,.15),(.095,.31,.18)])]
moss = [mat('Undergrowth %02d' % i,c) for i,c in enumerate([
    (.12,.26,.075),(.20,.34,.09),(.28,.39,.10),(.075,.23,.13)])]
bark = mat('Old cedar bark', (.15,.16,.105))
gold = mat('Tarnished brass', (.44,.34,.14))
blue = mat('Order runes', (.03,.43,.68), .35)
red = mat('Chaos runes', (.65,.055,.12), .3)
water = mat('River water - replaced by Godot shader', (.025,.27,.28))
soil = mat('Earth strata',(.12,.19,.12))
terrain_mat = mat('Living moss vertex colors',(.2,.3,.1))
nodes = terrain_mat.node_tree.nodes
attr = nodes.new('ShaderNodeVertexColor'); attr.layer_name = 'Color'
terrain_mat.node_tree.links.new(attr.outputs['Color'], nodes.get('Principled BSDF').inputs['Base Color'])


def pt(x, row, h=0):
    return (x-9, (16-row)*math.sqrt(2), h)


def move(obj, group, material):
    for col in list(obj.users_collection): col.objects.unlink(obj)
    COLS[group].objects.link(obj)
    obj.data.materials.append(material)
    return obj


def box(name, x, row, h, sx, sy, sz, material, group, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pt(x,row,h))
    o=bpy.context.object; o.name=name; o.scale=(sx,sy*math.sqrt(2),sz)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod=o.modifiers.new('Worn edges','BEVEL'); mod.width=bevel; mod.segments=1
        bpy.context.view_layer.objects.active=o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return move(o,group,material)


def rock(name,x,row,h,sx,sy,sz,material,group='Forest cliffs'):
    if group == 'Forest cliffs':
        bpy.ops.mesh.primitive_cube_add(size=2,location=pt(x,row,h))
        o=bpy.context.object
        for v in o.data.vertices:
            v.co.x += random.uniform(-.18,.18)
            v.co.y += random.uniform(-.12,.12)
            v.co.z += random.uniform(-.12,.12)
        o.scale=(sx,sy*math.sqrt(2),sz)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        mod=o.modifiers.new('Chiseled rock corners','BEVEL');mod.width=.13;mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    else:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=pt(x,row,h))
        o=bpy.context.object; o.scale=(sx,sy*math.sqrt(2),sz)
    o.name=name
    o.rotation_euler=(random.uniform(-.12,.12),random.uniform(-.12,.12),random.uniform(-.4,.4))
    return move(o,group,material)


def mesh(name, vertices, faces, material, group):
    m=bpy.data.meshes.new(name); m.from_pydata(vertices,[],faces); m.update()
    o=bpy.data.objects.new(name,m); COLS[group].objects.link(o); m.materials.append(material)
    return o


def ring(name,x,row,radius,width,material,h=.018,segments=48):
    vs=[]; fs=[]
    for i in range(segments):
        a=i*math.tau/segments
        for r in [radius-width,radius]: vs.append(pt(x+math.cos(a)*r,row+math.sin(a)*r,h))
    for i in range(segments):
        j=(i+1)%segments; fs.append((i*2,j*2,j*2+1,i*2+1))
    return mesh(name,vs,fs,material,'Ancient paving')


def road_fragment(x, row):
    # A chipped six/eight-sided slab rather than a perfect square paving tile.
    sx=random.uniform(1.06,1.18); sy=random.uniform(.72,.83)
    corners=[(-.5,-.32),(-.30,-.5),(.36,-.5),(.5,-.24),(.5,.36),(.25,.5),(-.40,.5),(-.5,.19)]
    vs=[]
    for h in [-.065,.006]:
        for a,b in corners:
            vs.append(pt(x+a*sx+random.uniform(-.018,.018),row+b*sy,h))
    # The tile-space Y direction is inverted in Blender, so reverse the top face.
    fs=[tuple(reversed(range(8,16)))]
    for i in range(8):fs.append((i,(i+1)%8,(i+1)%8+8,i+8))
    return mesh('Chipped ancient paving',vs,fs,random.choice(paving),'Ancient paving')


def path_distance(x,row):
    # Main lanes connect the bridge axes to each tower. Base approaches branch inward.
    d=min(abs(x-3.5),abs(x-14.5))
    t=max(0,min(1,(row-3)/3.5)) if row<16 else max(0,min(1,(29-row)/3.5))
    if row<6.5 or row>25.5:
        d=min(abs(x-(9-5.5*t)),abs(x-(9+5.5*t)))
    return d

# Flat authoritative ground: all relief stays beneath it or outside the walking area.
for a,b in [(-3,15),(17,36)]:
    verts=[]; faces=[]; colors=[]; step=.4; nx=60; ny=round((b-a)/step)
    for j in range(ny+1):
        row=a+(b-a)*j/ny
        for i in range(nx+1):
            x=-3+i*step
            verts.append(pt(x,row,-.018))
            n=math.sin(x*1.7+math.sin(row*1.2))*math.cos(row*.82+x*.41)*.5+.5
            fine=random.random()
            edge=min(max(x,0),max(18-x,0))
            grass=(.13+.05*n,.235+.065*n,.065+.027*n)
            path=max(0,1-path_distance(x,row)/1.65)**1.4
            dirt=(.265,.29,.135)
            mix=min(.82,path*.84)
            shade=.82+fine*.20 if edge>.7 else .68+fine*.17
            colors.append(tuple((grass[k]*(1-mix)+dirt[k]*mix)*shade for k in range(3))+(1,))
    for j in range(ny):
        for i in range(nx):
            k=j*(nx+1)+i
            faces.extend([(k,k+nx+1,k+1),(k+1,k+nx+1,k+nx+2)])
    o=mesh('Moss bank %s'%a,verts,faces,terrain_mat,'Terrain')
    ca=o.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
    for i,c in enumerate(colors):ca.data[i].color=c
    box('Earth bank',9,(a+b)/2,-.65,24,b-a,1.2,soil,'Terrain')

# River is recessed; no collision mesh is ever exported.
box('River bed',9,16,-.67,24,2.1,.25,cliff[0],'Terrain')
mesh('RiverSurface',[pt(-3,15,-.23),pt(21,15,-.23),pt(21,17,-.23),pt(-3,17,-.23)],[(0,3,2,1)],water,'RiverSurface')

# Broad fractured stone islands set into warm earth, as in Rift lane paving.
# Layout remains two clear routes, with broad base courtyards at each end.
for row_i in range(2,37):
    row=row_i*.85
    if 14.7<row<17.3:continue
    for lane in [3.5,14.5]:
        if row<6.5:lane=9+(lane-9)*max(0,(row-3)/3.5)
        if row>25.5:lane=9+(lane-9)*max(0,(29-row)/3.5)
        for side in [-.57,.57]:
            if random.random()<.13:continue
            road_fragment(lane+side+random.uniform(-.07,.07),row+random.uniform(-.035,.035))
for start,end in [(0,5),(27,32)]:
    for j in range(6):
        row=start+(j+.5)*(end-start)/6
        for i in range(8):
            x=9+(i-3.5)*1.1
            if random.random()<.12:continue
            road_fragment(x,row)

# Ground-level foundations: model feet remain exactly on Y=0 in Godot.
for team,row,kingrow in [(1,6.5,3),(0,25.5,29)]:
    accent=red if team else blue
    for x,r,rad in [(3.5,row,1.62),(14.5,row,1.62),(9,kingrow,2.15)]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=rad,depth=.12,location=pt(x,r,-.065))
        o=bpy.context.object;o.name='Tower foundation';o.scale.y=math.sqrt(2);move(o,'Ancient paving',stone[1])
        ring('Foundation outer rim',x,r,rad,.09,paving[1],.005)
        ring('Foundation team inlay',x,r,rad-.19,.027,accent,.008)
        for i in range(12):
            a=i*math.tau/12
            o=box('Radial foundation joint',x+math.cos(a)*(rad-.07),r+math.sin(a)*(rad-.07),.012,.025,.13,.009,stone[0],'Ancient paving')
            o.rotation_euler.z=-a
# Bridges: exact 3-tile walking surface, X=[2,5]/[13,16], river rows 15..17.
for x in [3.5,14.5]:
    box('Bridge foundation',x,16,-.29,3,2.35,.54,stone[0],'Bridges',.06)
    for j in range(6):
        for i in range(4):
            box('Bridge dressed stone',x-1.5+(i+.5)*.75,15+(j+.5)/3,-.045,
                .733,.318,.085,paving[(i+j)%len(paving)],'Bridges',.028)
    # Curbs and pillars sit beyond the navigable width.
    for side in [-1,1]:
        for j in range(4):
            box('Low bridge parapet',x+side*1.62,15.22+j*.52,.13,.22,.49,.35,stone[(j+2)%5],'Bridges',.045)
        for row in [14.83,17.17]:
            box('Gate pier',x+side*1.66,row,.27,.40,.40,.57,stone[2],'Bridges',.055)
            box('Gate capital',x+side*1.66,row,.58,.46,.46,.09,paving[1],'Bridges',.035)
            box('Gate brass inset',x+side*1.66,row,.64,.23,.23,.035,gold,'Bridges',.02)

# Banks stay within the blocked river, preserving the exact shoreline at rows 15 and 17.
for row in [15.18,16.82]:
    for i in range(43):
        x=-1+i*.48
        if min(abs(x-3.5),abs(x-14.5))<1.86:continue
        rock('Wet river stone',x,row,-.19,.30,random.uniform(.11,.16),random.uniform(.17,.25),random.choice(stone),'River banks')
        if i%3==0:
            rock('Bank moss',x,row,-.005,.24,.09,.08,random.choice(moss),'River banks')

# Small reed beds and flowers at protected bank pockets, as in the Rift river.
for x in [.55, 6.0, 11.8, 17.45]:
    for row in [15.12,16.88]:
        for i in range(16):
            xx=x+random.uniform(-.25,.25);rr=row+random.uniform(-.055,.055)
            vs=[];fs=[]
            for j in range(4):
                a=random.uniform(0,math.tau);h=random.uniform(.13,.34);k=len(vs)
                vs.extend([pt(xx-.018,rr,-.02),pt(xx+.018,rr,-.02),pt(xx+math.cos(a)*.08,rr+math.sin(a)*.04,h)])
                fs.append((k,k+1,k+2))
            mesh('River reeds',vs,fs,moss[1],'Ground foliage')

# Framing cliffs, mature cedars and fragments of abandoned architecture.
for side in [-1,1]:
    edge=0 if side<0 else 18
    for j in range(18):
        row=-1+j*2
        if 14<row<18:continue
        x=edge+side*random.uniform(-.12,.15)
        rock('Cliff lower ledge',x,row,.10,.78,random.uniform(.62,.95),random.uniform(.6,.95),random.choice(cliff))
        rock('Cliff fractured crown',x+side*.38,row-.10,.78,.65,.66,random.uniform(.65,1.25),random.choice(cliff))
        rock('Moss cap',x,row-.15,.64,.55,.6,.14,random.choice(moss),'Ground foliage')
    for j in range(17):
        row=-1+j*2.1+random.uniform(-.5,.5)
        if 14.2<row<18:continue
        x=edge+side*random.uniform(.05,.30)
        h=random.uniform(1.9,3.4)
        box('Cedar trunk',x,row,h*.37,.18,.17,h*.76,bark,'Pines')
        # Four irregular, flattened whorls with drooping branch tips.
        for tier in range(5):
            radius=(1-tier*.16)*random.uniform(1.05,1.40)
            z=.48+tier*h*.16
            vs=[pt(x,row,z+h*.43)];fs=[];n=15
            for k in range(n):
                a=k*math.tau/n + tier*.32
                rr=radius*random.uniform(.83,1.13)
                vs.append(pt(x+math.cos(a)*rr,row+math.sin(a)*rr*.72,z+random.uniform(-.10,.08)))
            vs.append(pt(x,row,z-.12))
            for k in range(n):fs.extend([(0,k+1,(k+1)%n+1),(n+1,(k+1)%n+1,k+1)])
            mesh('Cedar whorl',vs,fs,leaves[min(tier,3)],'Pines')
    for row in [3,10,22,29]:
        x=edge+side*.04
        accent=red if row<16 else blue
        box('Runestone plinth',x,row,.18,.73,.71,.4,cliff[1],'Runic monuments',.09)
        o=box('Runestone obelisk',x,row,.88,.43,.40,1.2,stone[0],'Runic monuments',.09)
        o.rotation_euler.y=side*.1
        rock('Runestone crystal',x,row,1.67,.18,.15,.43,accent,'Runic monuments')
        box('Relic collar',x,row,1.40,.50,.47,.08,gold,'Runic monuments',.02)

# Low foliage clusters on perimeter and at river corners; never a tall obstacle on lanes.
for i in range(260):
    row=random.uniform(-1,33); x=random.choice([random.uniform(-.5,.65),random.uniform(17.35,18.5)])
    if 14.8<row<17.2:continue
    rock('Fern cushion',x,row,.055,random.uniform(.12,.28),random.uniform(.12,.24),random.uniform(.08,.20),random.choice(moss),'Ground foliage')
    if i%3==0:
        vs=[];fs=[]
        for j in range(5):
            a=j*math.tau/5;length=random.uniform(.19,.38);k=len(vs)
            vs.extend([pt(x,row,.04),pt(x+math.cos(a+.3)*length*.6,row+math.sin(a+.3)*length*.6,.10),pt(x+math.cos(a)*length,row+math.sin(a)*length,.25)])
            fs.append((k,k+1,k+2))
        mesh('Fern fronds',vs,fs,moss[2],'Ground foliage')

# Ancient gate fragments on either side of each base form an end-cap composition.
for row in [.35, 33.0]:
    for x in [1.2, 3.0, 5.1, 12.9, 15.0, 16.8]:
        rock('Gate shoulder',x,row,.30,.58,.5,.57,cliff[1])
        rock('Gate ivy',x,row-.20,.68,.50,.40,.13,moss[0],'Ground foliage')
        if x in [3.0,15.0]:
            box('Ruined gate pillar',x,row,.8,.60,.5,1.3,stone[0],'Runic monuments',.10)
            box('Ruined gate cap',x,row,1.48,.76,.64,.14,stone[1],'Runic monuments',.05)
    for x in [1.5,16.5]:
        for tier in range(3):
            rock('End canopy',x,row-.25,.65+tier*.42,.85-tier*.16,.62-tier*.1,.4,leaves[tier+1],'Pines')

# A backdrop beyond the end rows, screened by the match UI and field bounds.
for row in [-1.0,33.4]:
    for x in range(-1,20):
        rock('End boundary rock',x,row,.30,.62,.5,.65,cliff[1])
        if x%2==0:rock('End ivy',x,row-.3,.58,.65,.45,.20,moss[0],'Ground foliage')

# Keep the .blend component-level editable. Export batches by category/material to
# limit runtime draw calls; the editable source is saved before any joins.
scene=bpy.context.scene
scene.world.color=(.15,.19,.22)
bpy.ops.object.camera_add(location=(0,-24,24))
cam=bpy.context.object;cam.name='Game camera reference';cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO';cam.data.ortho_scale=32;scene.camera=cam
scene.render.resolution_x=720;scene.render.resolution_y=1280;scene.render.resolution_percentage=100
bpy.ops.object.light_add(type='SUN',location=(5,-8,20));sun=bpy.context.object;sun.name='Warm canopy light';sun.rotation_euler=(.45,-.5,-.4);sun.data.energy=2
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_perspective='CAMERA'
        area.spaces.active.shading.type='MATERIAL'
scene['authoritative_grid']='18 x 32, tile 40 px. River rows 15..17. Bridge axes 3.5 / 14.5, width 3.'
scene['ground_mapping']='Blender (tile_x-9, (16-tile_row)*sqrt(2), height). Godot (x, height, -Blender_y).'
OUT.mkdir(parents=True,exist_ok=True)
# Embed the paint atlas in the editable source for a useful material preview.
# Runtime uses the same external atlas with Godot world-space projection/blending.
atlas_path=OUT/'rift_surface_atlas.png'
preview_links=[]
if atlas_path.exists():
    atlas=bpy.data.images.load(str(atlas_path));atlas.pack()
    for m in bpy.data.materials:
        if not m.use_nodes:continue
        offset=None
        if m.name.startswith(('Slate','Basalt','Weathered')):offset=(.503,.503,0)
        elif m.name.startswith('Pine needles'):offset=(.503,.003,0)
        elif m.name.startswith('Living moss'):offset=(.003,.503,0)
        elif m.name.startswith('Earth strata'):offset=(.003,.003,0)
        if offset is None:continue
        n=m.node_tree.nodes;p=n.get('Principled BSDF')
        previous=[(link.from_socket,link.to_socket) for link in m.node_tree.links if link.to_socket==p.inputs['Base Color']]
        tex=n.new('ShaderNodeTexImage');tex.image=atlas;tex.extension='EXTEND';tex.label='Hand-painted Rift surface atlas'
        coord=n.new('ShaderNodeTexCoord');scale=n.new('ShaderNodeVectorMath');scale.operation='MULTIPLY';scale.inputs[1].default_value=(.494,.494,.494)
        add=n.new('ShaderNodeVectorMath');add.operation='ADD';add.inputs[1].default_value=offset
        m.node_tree.links.new(coord.outputs['Generated'],scale.inputs[0]);m.node_tree.links.new(scale.outputs[0],add.inputs[0]);m.node_tree.links.new(add.outputs[0],tex.inputs['Vector'])
        m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
        preview_links.append((m,tex,previous))
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/rift_arena.blend'))
# Leave GLB materials as named tint swatches; shaders sample the single external
# atlas at runtime, avoiding duplicated embedded textures and requiring no UV seams.
for m,tex,previous in preview_links:
    m.node_tree.nodes.remove(tex)
    for from_socket,to_socket in previous:m.node_tree.links.new(from_socket,to_socket)
for group,col in COLS.items():
    by_mat={}
    for o in list(col.objects):
        if o.type=='MESH':by_mat.setdefault(o.data.materials[0].name,[]).append(o)
    for material,objects in by_mat.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join()
        objects[0].name=group.replace(' ','_')+'__'+material.replace(' ','_')
bpy.ops.object.select_all(action='DESELECT')
for col in COLS.values():
    for o in col.objects:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'rift_arena.glb'),export_format='GLB',use_selection=True,export_apply=True,export_cameras=False,export_lights=False,export_yup=True)
print('RIFT_ARENA_BUILD_OK',OUT)
