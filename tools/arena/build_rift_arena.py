"""Build the sunlit Rift diorama (Blender 4+, no add-ons).
Run from any directory: blender -b --python tools/arena/build_rift_arena.py
Editable source retains individual objects; the GLB batches category/material pairs.
All paths, bridge decks and foundations lie at/below the authoritative Y=0 plane.
"""
import bpy
import math
import random
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'ClashLegends-开发素材库/03-制作中/3D地图'
RNG = random.Random(20260912)
SQ = math.sqrt(2)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    bpy.data.collections.remove(c)
COLS = {}
for name in ['Terrain', 'RiverSurface', 'Cliff strata', 'Lane fragments', 'Foundations',
             'Bridges', 'River gardens', 'Woodland', 'Canopy', 'Relics', 'Accents', 'Source woodland', 'Source relics']:
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    COLS[name] = c


def mat(name, rgb, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*rgb, 1)
    p.inputs['Roughness'].default_value = 1
    if emission:
        p.inputs['Emission Color'].default_value = (*rgb, 1)
        p.inputs['Emission Strength'].default_value = emission
    return m


ground = mat('RiftGround', (.27,.42,.14))
water = mat('RiftWater', (.075,.40,.39))
rock_mats = [mat('RiftRock_%d'%i, c) for i,c in enumerate([
    (.29,.38,.35), (.35,.44,.39), (.40,.47,.39), (.25,.34,.34)])]
stone = [mat('RiftStone_%d'%i,c) for i,c in enumerate([
    (.45,.49,.37), (.53,.54,.42), (.38,.44,.37), (.58,.56,.43)])]
soil = mat('RiftSoil', (.22,.29,.21))
bark = mat('RiftBark', (.30,.25,.16))
leaf = [mat('RiftPine_%d'%i,c) for i,c in enumerate([
    (.07,.26,.20), (.11,.34,.23), (.18,.43,.27), (.25,.48,.29)])]
oak = [mat('RiftCrown_%d'%i,c) for i,c in enumerate([
    (.19,.35,.12), (.28,.45,.15), (.38,.51,.18)])]
foliage = [mat('RiftFoliage_%d'%i,c) for i,c in enumerate([
    (.25,.40,.15), (.37,.50,.18), (.20,.43,.26)])]
brass = mat('RiftBrass', (.55,.42,.20))
blue = mat('RiftOrder', (.08,.55,.70), .15)
red = mat('RiftChaos', (.72,.18,.19), .08)
petals = [mat('RiftPetal_%d'%i,c) for i,c in enumerate([
    (.48,.60,.81), (.73,.69,.42), (.43,.61,.73)])]


def pt(x,r,h=0):
    return (x-9,(16-r)*SQ,h)


def mesh(name, verts, faces, material, group):
    data=bpy.data.meshes.new(name)
    data.from_pydata(verts,[],faces)
    data.update()
    o=bpy.data.objects.new(name,data)
    COLS[group].objects.link(o)
    o.data.materials.append(material)
    return o


def relocate(o,name,material,group):
    o.name=name
    for c in list(o.users_collection):c.objects.unlink(o)
    COLS[group].objects.link(o)
    o.data.materials.append(material)
    return o


def box(name,x,r,h,sx,sy,sz,material,group,bevel=.04):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pt(x,r,h))
    o=bpy.context.object
    o.scale=(sx,sy*SQ,sz)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Hand worn corners','BEVEL');mod.width=bevel;mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return relocate(o,name,material,group)


def prism(name,x,r,radii,h0,h1,material,group,angle=0):
    n=len(radii); vs=[]
    for h in [h0,h1]:
        for i,(rx,ry) in enumerate(radii):
            a=i*math.tau/n+angle
            vs.append(pt(x+math.cos(a)*rx,r+math.sin(a)*ry,h))
    fs=[tuple(reversed(range(n,2*n))),tuple(range(n))]
    for i in range(n):
        j=(i+1)%n;fs.append((i,i+n,j+n,j))
    return mesh(name,vs,fs,material,group)


def slab(x,r,sx,sy,angle=0,name='Unearthed lane slab',group='Lane fragments',top=-.004):
    radii=[(sx*RNG.uniform(.85,1.04),sy*RNG.uniform(.83,1.05)) for _ in range(RNG.choice([5,6,7]))]
    return prism(name,x,r,radii,top-.10,top,RNG.choice(stone),group,angle)


def boulder(name,x,r,h,sx,sy,sz,material=None,group='Cliff strata',seed=0):
    # Three staggered polygon rings give a broad crown, fractured shoulder and tapered foot.
    n=RNG.choice([5,6,7]);vs=[]
    phase=RNG.uniform(0,.9)
    shape=[RNG.uniform(.8,1.15) for _ in range(n)]
    for tier,(z,scale) in enumerate([(-1,.76),(-.36,1),(.52,.88),(1,.55)]):
        for i in range(n):
            a=i*math.tau/n+phase
            vs.append(pt(x+math.cos(a)*sx*shape[i]*scale+.14*sx*tier,
                         r+math.sin(a)*sy*shape[i]*scale,h+sz*(z+RNG.uniform(-.09,.09))))
    fs=[tuple(reversed(range(3*n,4*n)))]
    for k in range(3):
        for i in range(n):
            j=(i+1)%n;fs.append((k*n+i,(k+1)*n+i,(k+1)*n+j,k*n+j))
    o=mesh(name,vs,fs,material or RNG.choice(rock_mats),group)
    return o


def tube(name,points,radii,material,group='Woodland',sides=7):
    verts=[]
    points=[Vector(pt(*p)) for p in points]
    for j,p in enumerate(points):
        tangent=points[min(j+1,len(points)-1)]-points[max(0,j-1)]
        tangent.normalize()
        normal=tangent.cross(Vector((0,1,0))).normalized()
        if normal.length<.1:normal=tangent.cross(Vector((1,0,0))).normalized()
        bit=tangent.cross(normal).normalized()
        for i in range(sides):
            a=i*math.tau/sides
            verts.append(tuple(p+radii[j]*(normal*math.cos(a)+bit*math.sin(a))))
    faces=[]
    for j in range(len(points)-1):
        for i in range(sides):
            ni=(i+1)%sides;faces.append((j*sides+i,j*sides+ni,(j+1)*sides+ni,(j+1)*sides+i))
    faces.append(tuple(range((len(points)-1)*sides,len(points)*sides)))
    return mesh(name,verts,faces,material,group)


def ring(name,x,r,radius,width,material,h=-.002,group='Foundations',start=0,end=math.tau,segments=48):
    vs=[];fs=[]
    for i in range(segments+1):
        a=start+(end-start)*i/segments
        for rr in [radius-width,radius]:vs.append(pt(x+math.cos(a)*rr,r+math.sin(a)*rr,h))
    for i in range(segments):fs.append((2*i,2*i+2,2*i+3,2*i+1))
    return mesh(name,vs,fs,material,group)


SOURCE_CACHE={}
def source_prop(asset,x,r,h=0,scale=1,yaw=0,group='Source woodland'):
    if asset not in SOURCE_CACHE:
        before=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(OUT/'source_props'/(asset+'.glb')))
        imported=[o for o in bpy.data.objects if o not in before]
        templates=[]
        for o in imported:
            if o.type!='MESH':continue
            data=o.data.copy()
            data.transform(o.matrix_world)
            templates.append(data)
        for o in imported:bpy.data.objects.remove(o,do_unlink=True)
        SOURCE_CACHE[asset]=templates
    for i,data in enumerate(SOURCE_CACHE[asset]):
        o=bpy.data.objects.new(asset+'_%d'%i,data)
        COLS[group].objects.link(o)
        o.location=pt(x,r,h)
        o.rotation_euler.z=yaw
        o.scale=(scale,scale,scale)


def pine(x,r,h,width,variant):
    # Alternate source tree silhouettes, with a few authored multi-tier trees.
    if variant % 4 != 0:
        kind=['pine_broad','pine_tall','pine_compact'][variant%3]
        source_prop(kind,x,r,0,h/2,RNG.uniform(-.8,.8))
        return
    lean=RNG.uniform(-.22,.22)
    tube('Pine %d curved trunk'%variant,[(x,r,-.1),(x+.10,r,h*.45),(x+lean,r+.08,h*.9)],
         [width*.16,width*.10,.025],bark)
    # Domed branch patches with authored atlas UVs and preserved alpha contours.
    regions=[(.004,.005,.587,.447),(.632,.014,.36,.464),(.524,.558,.46,.348)]
    for tier in range(4):
        height=h*(.28+tier*.18)
        radius=width*(1-tier*.20)
        for arm in range(3):
            angle=arm*math.tau/3+tier*.8+variant*.7
            u0,v0,us,vs=regions[(arm+variant+tier)%len(regions)]
            verts=[];uvs=[];faces=[]
            for j in range(5):
                v=j/4
                for i in range(5):
                    u=i/4
                    local_x=(u-.5)*radius*1.7
                    local_y=(v-.28)*radius*1.55
                    xx=x+math.cos(angle)*local_x-math.sin(angle)*local_y+lean*tier/4
                    rr=r+(math.sin(angle)*local_x+math.cos(angle)*local_y)*.72
                    z=height+(1-v)*h*.22+math.sin(u*math.pi)*radius*.22
                    verts.append(pt(xx,rr,z))
                    uvs.append((u0+u*us,1-(v0+v*vs)))
            for j in range(4):
                for i in range(4):
                    k=j*5+i;faces.extend([(k,k+5,k+1),(k+1,k+5,k+6)])
            o=mesh('Pine painted branch %d'%tier,verts,faces,leaf[tier],'Canopy')
            layer=o.data.uv_layers.new(name='UVMap')
            for face in o.data.polygons:
                for li in face.loop_indices:layer.data[li].uv=uvs[o.data.loops[li].vertex_index]


def crown(x,r,h,sx,sy,sz,material):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=pt(x,r,h))
    o=bpy.context.object
    for v in o.data.vertices:v.co*=RNG.uniform(.91,1.09)
    o.scale=(sx,sy*SQ,sz)
    for p in o.data.polygons:p.use_smooth=True
    return relocate(o,'Broadleaf sculpted crown',material,'Canopy')


def elder(x,r,h,width):
    tube('Elder twisted bole',[(x,r,-.15),(x-.18,r+.12,h*.33),(x+.21,r,h*.67),(x+.12,r,h*.87)],
         [.31,.26,.17,.06],bark)
    for i in range(5):
        a=i*math.tau/5+.24;dx=math.cos(a)*width;dy=math.sin(a)*width*.75
        tube('Elder reaching limb',[(x-.1,r,h*.40),(x+dx*.58,r+dy*.6,h*.61),(x+dx,r+dy,h*.78)],
             [.14,.09,.025],bark)
        crown(x+dx*.72,r+dy*.72,h*(.75+RNG.uniform(-.05,.05)),width*.7,width*.56,h*.23,oak[i%3])
        tube('Exposed elder root',[(x,r,.04),(x+dx*.65,r+dy*.65,-.03),(x+dx,r+dy,-.08)],
             [.17,.10,.005],bark)
    crown(x+.08,r,h*.92,width*.68,width*.56,h*.19,oak[2])


def fern(x,r,size,flower=False):
    for i in range(7):
        a=i*math.tau/7+RNG.random()*.2
        dx=math.cos(a);dy=math.sin(a)*.65;l=size*RNG.uniform(.75,1.15)
        # Paired leaflets follow a bent central rib.
        for k in range(3):
            f=.22+k*.23;w=l*(.25-.06*k)
            for sign in [-1,1]:
                verts=[pt(x+dx*l*f,r+dy*l*f,.025+l*.5*f),
                       pt(x+dx*l*(f+.30)-dy*w*sign,r+dy*l*(f+.30)+dx*w*sign,.03+l*.55*f),
                       pt(x+dx*l*(f+.26),r+dy*l*(f+.26),.04+l*.5*(f+.2))]
                mesh('Fern leaflet',verts,[(0,1,2)],foliage[i%3],'River gardens')
    if flower:
        for j in range(3):
            xx=x+RNG.uniform(-size*.6,size*.6);rr=r+RNG.uniform(-size*.3,size*.3)
            crown_obj=boulder('River iris',xx,rr,.10,.065,.05,.06,petals[j%3],'River gardens')


# A sculpted, finite diorama silhouette. Open playable field is perfectly flat.
for a,b in [(-1.6,15),(17,33.6)]:
    mesh('RiftGround bank', [pt(-2.2,a,-.025),pt(20.2,a,-.025),pt(20.2,b,-.025),pt(-2.2,b,-.025)],
         [(0,3,2,1)],ground,'Terrain')
    box('Earth terrace',9,(a+b)/2,-.67,22.4,b-a,1.25,soil,'Terrain',.34)
    # Lower shelves are hidden in the gameplay camera, readable in the model overview.
    box('Bedrock shelf',9,(a+b)/2,-1.36,21.8,b-a-.30,.48,rock_mats[0],'Terrain',.3)
mesh('RiverSurface', [pt(-2.25,15,-.20),pt(20.25,15,-.20),pt(20.25,17,-.20),pt(-2.25,17,-.20)],
     [(0,3,2,1)],water,'RiverSurface')
box('Recessed river bed',9,16,-.70,22.4,2,.75,rock_mats[0],'Terrain')
# Thin hanging water lips express the river cross section in the diorama view.
for x in [-2.23,20.23]:
    mesh('RiverSurface spill lip', [pt(x,15,-.2),pt(x,17,-.2),pt(x,17,-.78),pt(x,15,-.78)],
         [(0,1,2,3)],water,'RiverSurface')

# Restrained, irregular remnants of paving. Earth/grass continue between the stones.
for lane in [3.5,14.5]:
    for a,b in [(7.9,14.7),(17.3,24.1)]:
        rr=a
        while rr<b:
            slab(lane+RNG.uniform(-.24,.24),rr,RNG.uniform(.48,.75),RNG.uniform(.25,.43),RNG.uniform(-.4,.4))
            if RNG.random()<.55:
                slab(lane+RNG.choice([-1,1])*.78,rr+.21,.23,.26,RNG.random())
            rr+=RNG.uniform(.85,1.30)
# Base courtyards use radial broken wedges instead of a uniform tiled carpet.
for team,tower_r,base_r in [(1,6.5,3),(0,25.5,29)]:
    accent=red if team else blue
    for x,r,rad in [(3.5,tower_r,1.57),(14.5,tower_r,1.57),(9,base_r,2.03)]:
        prism('Flush foundation',x,r,[(rad,rad)]*40,-.17,-.016,stone[0],'Foundations')
        ring('Foundation bronze seam',x,r,rad-.07,.045,brass,-.006)
        ring('Foundation faction inlay',x,r,rad-.25,.025,accent,-.005)
        for i in range(8):
            a=i*math.tau/8
            ring('Interrupted limestone apron',x,r,rad+.24,.25,stone[(i+team)%4],-.008,
                 start=a+.022,end=a+.69,segments=5)
    for sign in [-1,1]:
        for i in range(5):
            t=(i+.5)/5;x=9+sign*5.5*t;r=base_r+(tower_r-base_r)*t
            slab(x,r,.62,.36,RNG.uniform(-.4,.4))
    for i in range(9):
        a=i*math.tau/9+RNG.uniform(-.10,.10)
        slab(9+math.cos(a)*2.65,base_r+math.sin(a)*2.40,.48,.29,a)

# Two traversable stone bridges, all raised detail outside x=[2,5]/[13,16].
for x in [3.5,14.5]:
    box('Bridge buried deck',x,16,-.19,3,2.20,.37,rock_mats[0],'Bridges',.05)
    for j in range(4):
        for i in range(3):
            box('Bridge fitted voussoir',x-1+(i),15.25+j*.5,-.052,.97,.47,.10,
                stone[(i+j)%4],'Bridges',.032)
    for side in [-1,1]:
        # Arched sidewall profile beneath the parapet.
        xx=x+side*1.60
        vs=[]
        for rr,z in [(14.93,-.45),(15.15,-.62),(15.50,-.33),(16,-.23),(16.5,-.33),(16.85,-.62),(17.07,-.45)]:
            vs.extend([pt(xx-.09,rr,z),pt(xx+.09,rr,z),pt(xx-.09,rr,.04),pt(xx+.09,rr,.04)])
        fs=[]
        for j in range(6):
            k=j*4;fs.extend([(k,k+4,k+6,k+2),(k+1,k+3,k+7,k+5),(k+2,k+6,k+7,k+3)])
        mesh('Bridge arched side masonry',vs,fs,stone[2],'Bridges')
        box('Low carved bridge coping',xx,16,.085,.23,1.95,.16,stone[1],'Bridges',.05)
        for rr in [14.91,17.09]:
            box('Bridge terminal pier',xx,rr,.18,.35,.33,.4,stone[0],'Bridges',.07)
            box('Bridge worn cap',xx,rr,.40,.45,.41,.12,stone[1],'Bridges',.04)
            ring('Bridge seal',xx,rr,.11,.035,brass,.465,'Bridges',segments=12)

# Bank outcrops are broad, spaced and non-identical, not a line of pebbles.
for x,row,sx,sy in [(-.7,15.11,1.0,.16),(.8,16.86,.6,.12),(6.0,15.10,.6,.13),
                    (7.5,16.90,.85,.12),(9.3,15.12,1.03,.16),(11.8,16.86,.64,.11),
                    (17.7,15.12,.62,.14),(19.0,16.88,1.13,.14)]:
    boulder('River weathered shelf',x,row,-.19,sx,sy,.22,stone[2],'River gardens')
    fern(x+.2,row,.34,True)
# Submerged slabs and reeds add scale without narrowing the bridge approaches.
for x,row in [(7.0,15.38),(10.6,16.62),(17.6,16.7),(.7,15.35)]:
    slab(x,row,.33,.13,.3,'Submerged stone','River gardens',-.17)
    for j in range(9):
        xx=x+RNG.uniform(-.35,.35);rr=row+RNG.uniform(-.05,.05)
        h=RNG.uniform(.12,.29)
        mesh('Reed blade',[pt(xx-.015,rr,-.12),pt(xx+.017,rr,-.12),pt(xx+.07,rr+.02,h)],[(0,1,2)],foliage[1],'River gardens')

# Four landscape compositions. Low connecting walls are intermittent; the skyline varies.
clusters=[(-1.0,1.0,2.0,1.4),(-1.35,7.6,1.4,2.0),(-1.35,11.6,1.4,1.1),
          (19.2,2.3,1.6,1.6),(19.1,9.0,1.5,2.0),(19.2,12.8,1.0,.8),
          (-1.1,20.4,1.5,1.4),(-1.4,27.3,1.8,2.2),(19.1,21.0,1.4,1.5),
          (19.2,28.4,1.5,2.1)]
for k,(x,r,sx,sy) in enumerate(clusters):
    boulder('Outcrop %02d lower mass'%k,x,r,.1,sx,sy,.71)
    boulder('Outcrop %02d offset crown'%k,x+(-.35 if x<0 else .4),r+.13,.66,sx*.74,sy*.70,.78)
    # Moss overhang differs for every ledge, leaving bare cliff faces.
    for j in range(2+(k%2)):
        crown(x+RNG.uniform(-.55,.55),r+RNG.uniform(-.7,.7),1.02,.55,.46,.22,oak[j%3])
for i,(x,r,h,w) in enumerate([(-.85,.3,3.3,1.15),(-1.15,2.1,2.7,.95),(-.7,8.2,3.3,1.1),
    (-1.2,11.7,2.7,1.0),(19.2,.1,3.7,1.1),(19.1,1.7,2.9,1.0),(19.3,8.8,3.4,1.15),
    (19.0,11.0,2.4,.84),(-1.15,20.5,3.1,1.0),(-1.2,27.8,3.7,1.1),(-.7,30.0,2.8,.9),
    (19.2,22.6,3.2,1.05),(19.0,29.8,3.4,1.1),(19.4,31.4,2.4,.8)]):
    pine(x,r,h,w,i)
elder(-.20,23.0,3.5,1.10)
elder(18.10,4.15,3.25,1.00)

# North-west: a single broken arch, its missing stones lying below the ivy.
def arch(x,r,side):
    for dx,height in [(-.76,1.8),(.76,2.20)]:
        box('Ruined arch upright',x+dx,r,height/2,.48,.57,height,stone[0],'Relics',.085)
        box('Ruined arch foot',x+dx,r,.16,.74,.8,.32,stone[2],'Relics',.09)
    for i in range(6):
        a=math.pi*(i+.5)/7
        xx=x+math.cos(a)*.79;z=1.78+math.sin(a)*.84
        o=box('Broken arch wedge',xx,r,z,.43,.57,.43,stone[i%4],'Relics',.06)
        o.rotation_euler.y=a-math.pi/2
    fern(x-.82,r-.25,.54)
arch(.10,3.55,-1)
# South-east: unequal remnants of an abandoned colonnade.
for x,r,h in [(19.0,25.9,2.05),(19.5,27.1,1.18),(18.9,28.1,.69)]:
    prism('Fluted relic column',x,r,[(.26,.23)]*8,.05,h,stone[0],'Relics',.2)
    box('Relic square capital',x,r,h,.68,.60,.20,stone[1],'Relics',.08)
    box('Relic square footing',x,r,.10,.70,.66,.23,stone[2],'Relics',.08)
# North-east: a serrated, layered ridge with a small runic standing stone.
for i in range(3):
    boulder('Dragon ridge spire',19.5+i*.25,13.1-i*.63,.7+i*.2,.52,.53,1.15+i*.24)
# South-west: a curved sunken stair and exposed roots below the broadleaf tree.
for i in range(5):
    box('Forgotten woodland step',-1.25+i*.16,22.0+i*.33,-.18+i*.10,1.2,.38,.18,stone[i%4],'Relics',.04)

# Small visible groves introduce three original silhouettes at irregular intervals.
for asset,x,r,h,angle in [('pine_broad',.15,11.8,3.1,.3),('pine_compact',.25,13.1,2.2,-.5),
    ('pine_tall',17.9,10.4,3.6,.6),('pine_broad',18.0,12.4,2.6,-.4),
    ('pine_compact',.10,20.4,2.5,.7),('pine_broad',17.85,22.9,3.1,.1),
    ('pine_tall',17.90,30.8,2.8,.9),('pine_compact',.25,29.1,2.2,-.6)]:
    source_prop(asset,x,r,0,h/2,angle)

# Distinct original Rift relics sit in the perimeter pockets, away from lanes.
source_prop('hollow_log',.12,18.8,.08,.74,.45,'Source relics')
source_prop('carved_runestone',17.7,19.3,.06,.68,-.40,'Source relics')
source_prop('mossy_boulder',.05,10.0,.03,.86,.65,'Source relics')
source_prop('mossy_boulder',17.75,8.4,.08,.73,-.8,'Source relics')

# Only two faction shrines, different silhouettes and locations.
for team,x,r in [(1,19.15,17.9),(0,-1.1,14.1)]:
    accent=red if team else blue
    box('Shrine foundation',x,r,.10,.89,.76,.24,stone[2],'Relics',.08)
    boulder('Shrine rune stone',x,r,.62,.32,.23,.65,stone[0],'Relics')
    prism('Shrine crystal',x,r,[(.12,.12)]*5,1.12,1.58,accent,'Accents',.3)
    box('Shrine gold collar',x,r,1.1,.35,.30,.10,brass,'Accents',.02)
# Broken end terraces leave central nexus silhouettes open.
for row in [-.85,33.2]:
    for x in [1.1,4.4,13.6,16.9]:
        boulder('End terrace',x,row,.04,1.35,.47,.40,rock_mats[1])
        if x in [1.1,16.9]:pine(x,row+.1,2.1,.82,int(x+row))
    for x in [6.7,11.3]:
        box('Base approach boundary',x,row,-.04,1.4,.65,.3,stone[0],'Relics',.1)

# Ground-level planting is grouped in pockets, with open stretches between them.
for i,(x,r) in enumerate([(.18,3.4),(.18,9.7),(.2,12.8),(17.85,3.5),(17.8,7.3),(17.8,12.2),
                         (.16,18.5),(.15,23.0),(.2,29.4),(17.85,18.4),(17.9,24.5),(17.8,30.8)]):
    for j in range(3):fern(x+RNG.uniform(-.2,.12),r+RNG.uniform(-.5,.5),RNG.uniform(.22,.40),j==0)
# Mossy embedded chips within the meadow are below the ground and do not suggest obstacles.
for x,r in [(7.2,9.8),(10.6,12.4),(6.8,20.5),(10.5,23),(8.8,7.8),(9.0,26.1)]:
    slab(x,r,.30,.18,RNG.random(),'Meadow buried fragment',top=-.012)

# 2026-09: layered forest margins. A separate seed preserves the original layout.
RNG = random.Random(20260923)
# Taller rear trees frame clustered mid-height saplings; avoid a uniform hedge.
for side in [0, 18]:
    outward = -1 if side == 0 else 1
    for index, row in enumerate([1.6, 5.1, 9.3, 12.7, 19.3, 23.2, 27.2, 30.7]):
        x = side + outward * RNG.uniform(.45, 1.25)
        source_prop(['pine_broad', 'pine_tall', 'pine_compact'][index % 3],
                    x, row, 0, RNG.uniform(1.25, 1.7), RNG.uniform(-2.5, 2.5))
        source_prop('pine_compact', side + outward * .05, row + .8,
                    0, RNG.uniform(.62, .9), RNG.uniform(-2.5, 2.5))
    # Low plants extend just inside the camera edge, with gaps by towers and bridges.
    for index, row in enumerate([1.3, 3.9, 8.8, 10.7, 12.9, 18.5, 20.5, 22.7, 27.9, 30.2]):
        x = side - outward * RNG.uniform(.25, .48)
        source_prop('mossy_boulder', x + outward * .35, row, -.06,
                    RNG.uniform(.34, .52), RNG.uniform(-2.5, 2.5), 'Source relics')
        for j in range(5):
            fern(x + RNG.uniform(-.24, .24), row + RNG.uniform(-.65, .65),
                 RNG.uniform(.32, .54), j % 3 == 0)
        # Roots connect stone and undergrowth rather than isolated decorative dots.
        tube('Forest margin root', [(x + outward * .3, row, .12),
             (x, row + .36, .06), (x - outward * .20, row + .62, .015)],
             [.09, .05, .008], bark, 'Woodland')
# Fallen timber and aged markers make the four perimeter pockets distinct.
for asset, x, row, scale, yaw in [
    ('hollow_log', -.20, 5.0, .64, -1.0),
    ('hollow_log', 18.25, 23.4, .67, .8),
    ('carved_runestone', -.15, 28.3, .46, .7),
    ('mossy_boulder', 18.0, 5.8, .67, -.4)]:
    source_prop(asset, x, row, .01, scale, yaw, 'Source relics')
# Richer river pockets stay clear of both bridge decks and approach lanes.
for x, row in [(.6, 14.86), (6.7, 14.86), (10.5, 17.12), (17.4, 17.14)]:
    for j in range(5):
        fern(x + RNG.uniform(-.36, .36), row + RNG.uniform(-.08, .08),
             RNG.uniform(.25, .39), j == 0)
# Low fern/stone groups on the end terraces keep the two central nexus wells open.
for row in [-.7, 32.9]:
    for x in [2.0, 4.8, 13.1, 16.2]:
        source_prop('pine_compact', x, row, -.02, .85, RNG.uniform(-2, 2))
        for j in range(4):
            fern(x + RNG.uniform(-.5, .5), row + RNG.uniform(-.25, .25), .4, j == 0)

# Useful Blender reference camera and lighting; neither is exported to the game.
scene=bpy.context.scene
scene.world.color=(.26,.32,.36)
bpy.ops.object.camera_add(location=(0,-24,24))
cam=bpy.context.object;cam.name='Game camera reference'
cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO';cam.data.ortho_scale=32;scene.camera=cam
scene.render.resolution_x=720;scene.render.resolution_y=1280;scene.render.resolution_percentage=100
bpy.ops.object.light_add(type='SUN',location=(5,-8,20))
sun=bpy.context.object;sun.name='Sunlit forest key';sun.rotation_euler=(.45,-.5,-.4);sun.data.energy=1.6
scene['authoritative_grid']='18x32; river rows 15..17; bridges x 2..5 and 13..16; all walking surfaces <= 0.'
scene['art_version']='2026-09-23 Sunlit Rift / layered woodland margins / flowing river'
scene['mapping']='Blender(tile_x-9,(16-tile_row)*sqrt(2),height) -> Godot(x,height,-Blender_y)'
scene['purpose']='Presentation-only candidate; no collision/navigation/gameplay state.'
OUT.joinpath('source').mkdir(parents=True,exist_ok=True)
bpy.context.preferences.filepaths.save_version=0
# Preserve individually editable meshes before runtime batching.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/rift_arena.blend'))
for group,col in COLS.items():
    batches={}
    for o in list(col.objects):
        if o.type=='MESH':batches.setdefault(o.data.materials[0].name,[]).append(o)
    for material,objects in batches.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join()
        objects[0].name=group.replace(' ','_')+'__'+material
bpy.ops.object.select_all(action='DESELECT')
for col in COLS.values():
    for o in col.objects:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'rift_arena.glb'),export_format='GLB',use_selection=True,
    export_apply=True,export_cameras=False,export_lights=False,export_yup=True)
print('RIFT_ARENA_V2_BUILD_OK',sum(len(o.data.polygons) for c in COLS.values() for o in c.objects if o.type=='MESH'),'faces',OUT)

# Keep the editable source useful in Blender, without exporting its node graph
# as if it were a glTF-compatible approximation of the runtime shaders.
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from rift_blender_materials import configure_materials
bpy.ops.wm.open_mainfile(filepath=str(OUT/'source/rift_arena.blend'))
configure_materials(OUT)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/rift_arena.blend'))
print('RIFT_EDITABLE_MATERIALS_OK')
