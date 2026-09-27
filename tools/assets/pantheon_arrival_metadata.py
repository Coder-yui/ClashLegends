#!/usr/bin/env python3
"""Recover supported source fields omitted by the original one-off converter.
Requires the six original ritobin definition text files. Does not convert meshes,
textures, or apply project-specific placement fixes. Output is deterministic.
"""
import argparse
import json
import re
from pathlib import Path
num_re = r"[-+]?(?:\d+\.?\d*|\.\d+)(?:e[-+]?\d+)?"

def nums(s):return [float(x) for x in re.findall(num_re,s,re.I)]

def fields(s):
 # Strip the object's braces, then consume complete values with balanced nested braces.
 start=s.find('{');s=s[start+1:s.rfind('}')] if start>=0 else s
 result={};i=0
 pattern=re.compile(r'\s*,?\s*(\w+):\s*[^=\n]+?=\s*')
 while i<len(s):
  m=pattern.match(s,i)
  if not m:break
  a=m.end();i=a;depth=0;quoted=False
  while i<len(s):
   c=s[i]
   if c=='"' and (i==0 or s[i-1]!='\\'):quoted=not quoted
   if not quoted:
    if c=='{':depth+=1
    elif c=='}':
     depth-=1
     if depth==0:i+=1;break
    elif c=='\n' and depth==0:break
   i+=1
  result[m.group(1)]=s[a:i].strip()
 return result

def value(raw,default):
 if not raw:return {'base':default}
 f=fields(raw);base=f.get('constantValue','');v=nums(base) if base else default
 if isinstance(default,(int,float)):v=v[0] if isinstance(v,list) and v else v
 d={'base':v}
 dy=fields(f.get('dynamics',''));times=nums(dy.get('times',''));values=nums(dy.get('values',''))
 if times and values:
  n=1 if isinstance(default,(int,float)) else len(default)
  if len(values)==len(times)*n:d.update(times=times,values=values if n==1 else [values[i:i+n] for i in range(0,len(values),n)])
 tables=[]
 for m in re.finditer(r'VfxProbabilityTableData\s*\{',dy.get('probabilityTables','')):
  text=dy['probabilityTables'];start=m.start();i=m.end();depth=1
  while depth:
   if text[i]=='{':depth+=1
   elif text[i]=='}':depth-=1
   i+=1
  table=fields(text[start:i]);kt=nums(table.get('keyTimes',''));kv=nums(table.get('keyValues',''))
  tables.append({'base':1,'times':kt,'values':kv} if kt and len(kt)==len(kv) else {'base':1})
 if tables:d['probabilities']=tables
 return d


def emitters(text):
    for match in re.finditer(r'VfxEmitterDefinitionData\s*\{', text):
        at, depth, quoted = match.end(), 1, False
        while depth and at < len(text):
            char = text[at]
            if char == '"' and text[at-1] != "\\": quoted = not quoted
            if not quoted:
                if char == '{': depth += 1
                elif char == '}': depth -= 1
            at += 1
        if depth: raise ValueError('Unbalanced emitter definition')
        definition = fields(text[match.start():at])
        yield definition['emitterName'].strip('"'), definition


def enrich(data, source):
    for system, definitions in data.items():
        original = dict(emitters((source / f'Pantheon_Base_R_{system}.txt').read_text()))
        for emitter in definitions:
            definition = original[emitter['name']]
            mult = fields(definition.get('textureMult', ''))
            emitter['mult_birth_scroll'] = value(mult.get('birthUvScrollRateMult', ''), [0, 0])
            emitter['mult_birth_offset'] = value(mult.get('birthUVOffsetMult', ''), [0, 0])
            if emitter['trail']:
                trail = fields(fields(definition['primitive'])['mTrail'])
                emitter['trail_tiling'] = value(trail.get('mBirthTilingSize', ''), [1, 0, 0])
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    data = enrich(json.loads(args.input.read_text()), args.source)
    args.output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__': main()
