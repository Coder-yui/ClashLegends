"""Inspect native Godot 4 PCK directory entries, not ResourceLoader remaps.
Format reference: Godot 4.7 core/io/file_access_pack.cpp PackedSourcePCK.
Only plain standalone v2/v3/v4 packs are accepted by this local release gate.
"""
import hashlib
import json
from pathlib import Path
import struct


def entries(path):
    total = path.stat().st_size
    with path.open('rb') as file:
        def read(size):
            data = file.read(size)
            if len(data) != size: raise ValueError('Truncated PCK')
            return data
        def u32(): return struct.unpack('<I', read(4))[0]
        def u64(): return struct.unpack('<Q', read(8))[0]
        if read(4) != b'GDPC': raise ValueError('Not a standalone native PCK')
        version = u32()
        if version not in (2, 3, 4): raise ValueError('Unsupported PCK version')
        read(12)
        flags = u32()
        if flags & ~2: raise ValueError('Encrypted/sparse/unknown PCK flags unsupported')
        base = u64()
        if version >= 3:
            directory = u64()
            if not 40 <= directory <= total - 4: raise ValueError('Invalid PCK directory offset')
            file.seek(directory)
        else: read(64)
        count = u32()
        if count > 1000000: raise ValueError('PCK file count limit')
        result = {}
        for _ in range(count):
            length = u32()
            if not 1 <= length <= 4096: raise ValueError('PCK path size limit')
            name = read(length).rstrip(b'\0').decode('utf-8').removeprefix('res://')
            offset, size = u64() + base, u64()
            md5 = read(16)
            file_flags = u32()
            if file_flags: raise ValueError('Encrypted/removal/delta entry unsupported')
            if name in result or name.startswith('/') or '..' in name.split('/') or offset + size > total:
                raise ValueError('Invalid PCK entry')
            result[name] = dict(offset=offset, bytes=size, md5=md5.hex())
        return result


def audit(pack, root, index):
    native = entries(pack)
    required = {p.removeprefix('res://') for p in index['runtime_raw']}
    missing = sorted(required - native.keys())
    forbidden = sorted(p for p in native if p.startswith(('tools/source_assets/', 'tools/generated/')) or p.endswith('.dependencies.json') or p == 'assets/effects/void_summoning/sampled.json')
    if missing or forbidden: raise ValueError(f'PCK native raw closure mismatch: missing={missing}, forbidden={forbidden}')
    # Compare actual bytes in pack, rather than assuming directory inclusion.
    with pack.open('rb') as stream:
        for name in sorted(required):
            stream.seek(native[name]['offset'])
            left = native[name]['bytes']; sha = hashlib.sha256()
            while left:
                chunk = stream.read(min(left, 1024 * 1024))
                if not chunk: raise ValueError('Truncated raw payload: ' + name)
                sha.update(chunk); left -= len(chunk)
            with (root / name).open('rb') as original:
                if sha.hexdigest() != hashlib.file_digest(original, 'sha256').hexdigest():
                    raise ValueError('PCK raw bytes differ: ' + name)
    return dict(native_entries=len(native), required_raw=len(required), missing=missing, forbidden=forbidden, passed=True)
