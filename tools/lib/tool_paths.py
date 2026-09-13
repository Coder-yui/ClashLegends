"""Shared, read-only discovery of local LoL conversion tools."""
import os
from pathlib import Path
import shutil
import subprocess

PROJECT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = Path('/Users/czh/Downloads/LOL_Asset_Source')
DEFAULT_TOOL_BIN = Path('/Users/czh/Tools/lol-asset-tools/bin')


def executable(name):
    folder = Path(os.environ.get('LOL_TOOLS_BIN', str(DEFAULT_TOOL_BIN)))
    local = folder / name
    found = str(local) if local.is_file() and os.access(local, os.X_OK) else shutil.which(name)
    if not found:
        raise ValueError(f'Missing tool: {name}. Set LOL_TOOLS_BIN or add it to PATH.')
    return found


def run(name, *args):
    result = subprocess.run([executable(name), *map(str, args)], capture_output=True, text=True)
    if result.returncode:
        raise ValueError(f'{name} failed ({result.returncode}):\n{result.stderr[-4000:]}\n{result.stdout[-4000:]}')
    return result.stdout


def godot():
    specified = os.environ.get('GODOT_BIN') or os.environ.get('GODOT')
    if specified:
        return specified
    return shutil.which('Godot') or shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot'
