"""Editable Blender approximation of the runtime materials, using intact PNGs.
The Godot wrapper remains the exact shader implementation. No atlas is repainted.
Call configure_materials(arena_directory) on the unbatched source scene.
"""
from pathlib import Path
import bpy


def configure_materials(directory):
    directory=Path(directory)
    images={}
    def image(name):
        if name not in images:
            images[name]=bpy.data.images.load(str(directory/'textures'/name),check_existing=True)
            images[name].pack()
        return images[name]
    for material in bpy.data.materials:
        name=material.name
        if not name.startswith('Rift'):continue
        material.use_nodes=True
        nodes=material.node_tree.nodes;links=material.node_tree.links
        nodes.clear()
        output=nodes.new('ShaderNodeOutputMaterial')
        bsdf=nodes.new('ShaderNodeBsdfPrincipled')
        bsdf.inputs['Roughness'].default_value=1
        bsdf.inputs['Specular IOR Level'].default_value=0
        links.new(bsdf.outputs['BSDF'],output.inputs['Surface'])
        bsdf.inputs['Base Color'].default_value=material.diffuse_color
        def math_node(op,a,b=None):
            n=nodes.new('ShaderNodeMath');n.operation=op
            if hasattr(a,'node'):links.new(a,n.inputs[0])
            else:n.inputs[0].default_value=a
            if b is not None:
                if hasattr(b,'node'):links.new(b,n.inputs[1])
                else:n.inputs[1].default_value=b
            return n.outputs[0]
        def coords(output_name='Generated'):
            c=nodes.new('ShaderNodeTexCoord')
            sep=nodes.new('ShaderNodeSeparateXYZ');links.new(c.outputs[output_name],sep.inputs[0])
            return sep.outputs
        def sample(texture,u,v,region=(0,0,1,1),repeat=False):
            # Region is measured from PNG top-left; Blender UV V is bottom-up.
            x,y,w,h=region
            u=math_node('MULTIPLY_ADD',u,w)
            u.node.inputs[2].default_value=x
            v=math_node('MULTIPLY_ADD',v,h)
            v.node.inputs[2].default_value=1-y-h
            xy=nodes.new('ShaderNodeCombineXYZ');links.new(u,xy.inputs[0]);links.new(v,xy.inputs[1])
            tex=nodes.new('ShaderNodeTexImage');tex.image=image(texture)
            tex.extension='REPEAT' if repeat else 'EXTEND'
            links.new(xy.outputs[0],tex.inputs['Vector'])
            return tex
        if name=='RiftGround':
            pos=coords('Object')
            # Empty object coordinates are local mesh coordinates; terrain mesh
            # vertices were authored directly in world coordinates at origin.
            u=math_node('MULTIPLY',pos['X'],.15)
            v=math_node('MULTIPLY',pos['Y'],.15/2**.5)
            grass=sample('sunlit_grass.png',u,v,repeat=True)
            terrain=sample('grass_primary.png',math_node('PINGPONG',u,1),math_node('PINGPONG',v,1),(.613,.455,.037,.07))
            row=math_node('SUBTRACT',16,math_node('DIVIDE',pos['Y'],2**.5))
            spread=math_node('MINIMUM',math_node('DIVIDE',math_node('SUBTRACT',row,3),3.5),
                             math_node('DIVIDE',math_node('SUBTRACT',29,row),3.5))
            spread=math_node('MULTIPLY',math_node('MINIMUM',math_node('MAXIMUM',spread,0),1),5.5)
            distance=math_node('ABSOLUTE',math_node('SUBTRACT',math_node('ABSOLUTE',pos['X']),spread))
            factor=math_node('MULTIPLY',math_node('MINIMUM',math_node('MAXIMUM',math_node('DIVIDE',math_node('SUBTRACT',1.48,distance),1.08),0),1),.76)
            mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MIX'
            links.new(factor,mix.inputs[0]);links.new(grass.outputs['Color'],mix.inputs[1]);links.new(terrain.outputs['Color'],mix.inputs[2])
            links.new(mix.outputs[0],bsdf.inputs['Base Color'])
        elif name.startswith('RiftPine'):
            uv=nodes.new('ShaderNodeTexCoord');tex=nodes.new('ShaderNodeTexImage');tex.image=image('canopy_foliage.png')
            links.new(uv.outputs['UV'],tex.inputs['Vector']);links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
            alpha=math_node('GREATER_THAN',tex.outputs['Alpha'],.5);links.new(alpha,bsdf.inputs['Alpha'])
            material.surface_render_method='DITHERED';material.use_backface_culling=False
        elif name.startswith(('RiftRock','RiftStone','RiftCrown','RiftBark','RiftSoil')):
            texture='rock_cliff.png';region=(.15,.07,.35,.18)
            if name.startswith('RiftStone'):region=(.15,.033,.25,.065)
            elif name.startswith('RiftCrown'):
                texture='canopy_foliage.png';region=(.19,.08,.19,.15)
            elif name.startswith(('RiftBark','RiftSoil')):region=(.57,.125,.1,.12)
            p=coords()
            tex=sample(texture,p['X'],p['Z'] if name.startswith('RiftBark') else p['Y'],region)
            links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
        elif name=='RiftWater':
            bsdf.inputs['Base Color'].default_value=(.035,.24,.27,1)
            bsdf.inputs['Roughness'].default_value=.65
        if name in ('RiftOrder','RiftChaos'):
            bsdf.inputs['Emission Color'].default_value=material.diffuse_color
            bsdf.inputs['Emission Strength'].default_value=.12
    scene=bpy.context.scene
    scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.36,.43,.48,1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.6
    scene.view_settings.view_transform='Standard'
    scene.view_settings.look='Medium High Contrast'
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL'
            area.spaces.active.region_3d.view_perspective='CAMERA'
