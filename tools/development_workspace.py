#!/usr/bin/env python3
"""Create an isolated, disposable integration preview from the current working tree."""
import argparse
import hashlib
import json
import os
from datetime import datetime
from pathlib import Path
import shutil
import subprocess
import sys
from lib.tool_paths import PROJECT, godot

LIBRARY = PROJECT / 'ClashLegends-开发素材库'


def stage(arena=False):
    output = LIBRARY / '04-中间产物/联调副本' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    output.mkdir(parents=True)
    for name in ['assets', 'scripts', 'scenes', 'tools', 'tests', 'docs']:
        shutil.copytree(PROJECT / name, output / name,
                        ignore=shutil.ignore_patterns('__pycache__', '.DS_Store'))
    for name in ['project.godot', 'default_bus_layout.tres', 'godot-version.txt', 'README.md', 'AGENTS.md']:
        shutil.copy2(PROJECT / name, output / name)
    if arena and not (output / "assets/arena/rift_arena/rift_arena.tscn").exists():
        source = LIBRARY / '03-制作中/3D地图'
        shutil.copytree(source, output / 'assets/arena/rift_arena',
                        ignore=shutil.ignore_patterns('.godot', '.DS_Store'))
    # Explicit arena staging previews the in-development package, never production.
    candidate = LIBRARY / '03-制作中/3D地图/runtime'
    if arena and candidate.is_dir():
        shutil.copytree(candidate, output / 'assets/arena/rift_arena', dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns('.godot', '.gdignore', '.DS_Store'))
    # A source baseline makes later differences reviewable; caches are never source evidence.
    files = {path.relative_to(output).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
             for path in output.rglob('*') if path.is_file()}
    (output / 'stage_manifest.json').write_text(json.dumps({
        'schema': 1, 'source': str(PROJECT), 'arena': arena, 'files': files,
    }, ensure_ascii=False, indent=2) + '\n')
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--arena', action='store_true', help='Include the in-development 3D arena')
    parser.add_argument('--open', action='store_true', help='Import and open the existing arena preview or game')
    parser.add_argument('--reuse', type=Path, help='Open an existing stage without copying or overwriting its files')
    args = parser.parse_args()
    if args.reuse:
        output = args.reuse.resolve()
        stage_root = (LIBRARY / '04-中间产物/联调副本').resolve()
        if output.parent != stage_root or not (output / 'project.godot').is_file():
            parser.error('--reuse must name an existing direct child of the stage directory')
        if args.arena and not (output / 'assets/arena/rift_arena/rift_arena.tscn').is_file():
            parser.error('Existing stage has no arena; create a new --arena stage first')
    else:
        output = stage(args.arena)
    print(output, flush=True)
    if args.open:
        os.environ["CLASH_SOURCE_PROJECT"] = str(PROJECT)
        subprocess.run([godot(), '--headless', '--path', str(output), '--editor', '--import', '--quit'], check=True)
        command = [godot(), '--path', str(output)]
        if args.arena: command += ['--script', 'tools/capture/capture_rift_arena_v2.gd', '--', '--hold']
        return subprocess.call(command)
    return 0

if __name__ == '__main__': raise SystemExit(main())
