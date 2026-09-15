#!/usr/bin/env python3
"""Create an isolated, disposable integration preview from the current working tree."""
import argparse
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
                        ignore=shutil.ignore_patterns('__pycache__', '.DS_Store', '*.import'))
    for name in ['project.godot', 'default_bus_layout.tres', 'godot-version.txt', 'README.md', 'AGENTS.md']:
        shutil.copy2(PROJECT / name, output / name)
    if arena and not (output / "assets/arena/rift_arena/rift_arena.tscn").exists():
        source = LIBRARY / '03-制作中/3D地图'
        shutil.copytree(source, output / 'assets/arena/rift_arena',
                        ignore=shutil.ignore_patterns('.godot', '.DS_Store', '*.import'))
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--arena', action='store_true', help='Include the in-development 3D arena')
    parser.add_argument('--open', action='store_true', help='Import and open the existing arena preview or game')
    args = parser.parse_args()
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
