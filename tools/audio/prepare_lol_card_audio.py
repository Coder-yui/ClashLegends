"""Prepare an external base-skin TXTP library without changing original LoL WADs.
Requires existing wadtools, ritobin-tools, wwiser and a matching shared init.bnk.
Produces inspectable names, banks, TXTP and logs; does not import any game assets.
"""
import argparse
import os
import re
import struct
import subprocess
from pathlib import Path


def run(command, log, cwd):
    subprocess.run(list(map(str, command)), stdout=log, stderr=log, cwd=cwd, check=True)


def unpack_wpk(path, destination):
    blob = path.read_bytes()
    magic, version, count = struct.unpack_from('<4sII', blob)
    assert magic == b'r3d2' and version == 1 and 12+count*4 <= len(blob)
    for index in range(count):
        entry = struct.unpack_from('<I', blob, 12+index*4)[0]
        offset, size, length = struct.unpack_from('<III', blob, entry)
        assert entry+12+length*2 <= len(blob) and offset+size <= len(blob)
        name = blob[entry+12:entry+12+length*2].decode('utf-16-le')
        assert Path(name).name == name and name.endswith('.wem')
        (destination/name).write_bytes(blob[offset:offset+size])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wads', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--init', type=Path, required=True)
    parser.add_argument('--champions', nargs='+', required=True)
    parser.add_argument('--voices', action='store_true', help='Also prepare verified Death3D from zh_CN')
    args = parser.parse_args()
    args.wads, args.output, args.init = args.wads.resolve(), args.output.resolve(), args.init.resolve()
    library = Path(__file__).resolve().parents[2] / 'ClashLegends-开发素材库'
    if not args.output.is_relative_to(library):
        parser.error('--output must be inside ClashLegends-开发素材库')
    assert args.init.is_file()
    for champion in args.champions:
        output = (args.output/champion.lower()).resolve()
        output.mkdir(parents=True, exist_ok=True)
        with (output/'prepare.log').open('w') as log:
            run(['wadtools','extract','-i',args.wads/(champion+'.wad.client'),'-o',output,'-x',r'skins/(base/.*sfx.*|skin0.bin)$'],log,output)
            # A champion WAD can contain pets/forms with their own skin0.bin.
            texts = []
            for source in output.rglob('skin0.bin'):
                text = source.with_suffix('.ritobin')
                run(['ritobin-tools','convert',source,'-o',text],log,output)
                texts.append(text.read_text())
            names = sorted(set(re.findall(r'"((?:Play|Stop)_[^"]+)"','\n'.join(texts))))
            (output/'wwnames.txt').write_text('\n'.join(names)+'\n')
            banks = sorted(output.rglob('*.bnk'))
            run(['wwiser',args.init,*banks,'-nl',output/'wwnames.txt','-g','-gra','-gd','-go',output/'txtp','-gw',banks[0].parent,'-d','none'],log,output)
        if args.voices:
            voice = output.with_name(output.name+'_vo')
            voice.mkdir(exist_ok=True)
            with (voice/'prepare.log').open('w') as log:
                run(['wadtools','extract','-i',args.wads/(champion+'.zh_CN.wad.client'),'-o',voice,'-x',r'skins/base/.*vo.*'],log,voice)
                wem = voice/'wem'
                wem.mkdir(exist_ok=True)
                for source in voice.rglob('*.wpk'):
                    unpack_wpk(source,wem)
                deaths = [n for n in names if n.startswith('Play_vo_') and n.endswith('_Death3D')]
                (voice/'wwnames.txt').write_text('\n'.join(deaths)+'\n')
                if deaths:
                    run(['wwiser',args.init,*sorted(voice.rglob('*.bnk')),'-nl',voice/'wwnames.txt','-g','-gra','-gd','-go',voice/'txtp','-gw',wem,'-d','none','-gf',*deaths],log,voice)
        for folder in [output, output.with_name(output.name+'_vo')]:
            for txtp in (folder/'txtp').glob('*.txtp'):
                # vgmstream's TXTP reader needs paths relative to the TXTP directory.
                text = re.sub(r'(?m)^(\s*)(/[^\n]+?)(?= #|\n)',lambda m:m[1]+os.path.relpath(m[2],txtp.parent),txtp.read_text())
                txtp.write_text(text)
        print(champion, 'prepared; inspect prepare.log before importing')


if __name__ == '__main__':
    main()
