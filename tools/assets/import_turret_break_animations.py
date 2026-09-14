"""Append verified native Break clips, preserving existing meshes, materials and animations."""
import json,struct,copy,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SOURCE=Path('/Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/素材加工/turret_native_review/breaks.glb')
def read(path):
 b=path.read_bytes();size=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+size]);offset=20+size;length=struct.unpack_from('<I',b,offset)[0];return j,b[offset+8:offset+8+length]
src,raw=read(SOURCE)
for team in ['blue','red']:
 p=ROOT/f'assets/towers/princess/source/princess_tower_{team}.glb';dst,data=read(p)
 if any(a['name']=='NativeBreak1' for a in dst['animations']):continue
 data+=b'\0'*(-len(data)%4);start=len(data);view_offset=len(dst['bufferViews']);accessor_offset=len(dst['accessors']);names={n.get('name'):i for i,n in enumerate(dst['nodes'])}
 for v in src['bufferViews']:
  v=copy.deepcopy(v);v['byteOffset']=v.get('byteOffset',0)+start;v['buffer']=0;dst['bufferViews'].append(v)
 for a in src['accessors']:
  a=copy.deepcopy(a)
  if 'bufferView' in a:a['bufferView']+=view_offset
  dst['accessors'].append(a)
 for a in src['animations']:
  a=copy.deepcopy(a);a['name']='NativeBreak'+a['name'][-1]
  for s in a['samplers']:s['input']+=accessor_offset;s['output']+=accessor_offset
  for c in a['channels']:c['target']['node']=names[src['nodes'][c['target']['node']]['name']]
  dst['animations'].append(a)
 data+=raw;data+=b'\0'*(-len(data)%4);dst['buffers']=[{'byteLength':len(data)}];j=json.dumps(dst,separators=(',',':')).encode();j+=b' '*(-len(j)%4);p.write_bytes(struct.pack('<III',0x46546c67,2,28+len(j)+len(data))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(data),0x004e4942)+data)
print('Native Break1/2/3 appended to both existing model files')
