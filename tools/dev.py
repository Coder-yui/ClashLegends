#!/usr/bin/env python3
"""Common entry points for reusable card-development tools. Run a command with --help for options."""
import argparse
import os
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.tool_paths import PROJECT, DEFAULT_SOURCE, executable, godot

COMMANDS = {
    'stage': ('python', 'tools/development_workspace.py', '在开发素材库内建立联调副本；--arena --open 预览制作中地图'),
    'source': ('python', 'tools/assets/lol_source.py', '原始素材：找包、筛选、提取、转换'),
    'model': ('godot', 'tools/viewers/model_studio.gd', '模型动作展台与卡面摄影'),
    'audio': ('python', 'tools/audio_review/serve.py', '目录或清单驱动的声音试听台'),
    'audio-prepare': ('python', 'tools/audio/prepare_lol_card_audio.py', '准备英雄原始音频事件工作目录'),
    'audio-import': ('python', 'tools/audio/import_card_audio.py', '按选定计划导入声音（先用 --dry-run）'),
    'verify': ('python', 'tools/verify.py', '可追溯自动验证：审计、导入、机制、日志与版本'),
    'audit': ('python', 'tools/maintenance/audit_project.py', '项目资源、文档、注册审计'),
    'workbench': ('workbench', '', '完整实战与技能审查'),
}


def main():
    if len(sys.argv) == 1 or sys.argv[1] in ['-h', '--help', 'list']:
        print(__doc__)
        for name, (_, _, label) in COMMANDS.items(): print(f'  {name:16} {label}')
        print('  doctor           检查本机工具与源库，不安装、不修改')
        return 0
    command, args = sys.argv[1], sys.argv[2:]
    if command == 'doctor':
        print('Source:', DEFAULT_SOURCE, '(exists)' if DEFAULT_SOURCE.is_dir() else '(missing)')
        print('Godot:', godot())
        missing = []
        for name in ['wadtools', 'lol2gltf', 'ltk-tex-utils', 'ritobin-tools', 'wwiser', 'vgmstream-cli']:
            try: print(name + ':', executable(name))
            except ValueError as error: print(error); missing.append(name)
        return 1 if missing else 0
    if command not in COMMANDS:
        print(f'Unknown command: {command}', file=sys.stderr); return 2
    kind, target, _ = COMMANDS[command]
    if kind == 'python': cmd = [sys.executable, str(PROJECT / target), *args]
    elif kind == 'workbench': cmd = [godot(), '--path', str(PROJECT), '--', '--mode=workbench', *args]
    else: cmd = [godot(), '--path', str(PROJECT), '--script', target, '--', *args]
    try: return subprocess.call(cmd, cwd=PROJECT)
    except FileNotFoundError as error: print(error, file=sys.stderr); return 2
    except KeyboardInterrupt: return 130

if __name__ == '__main__': raise SystemExit(main())
