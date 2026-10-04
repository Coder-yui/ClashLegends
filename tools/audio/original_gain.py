"""Fail closed on wwiser preview gain and never reuse an unverified WAV cache."""
import hashlib
import re
import subprocess
import tempfile
from pathlib import Path


def validate_txtp(path):
    text = Path(path).read_text()
    if re.search(r'master volume:\s*auto', text, re.I):
        raise ValueError(f'{path}: auto master gain; regenerate from banks with -gv=0dB')
    for value in re.findall(r'master volume:\s*([-+\d.]+)dB', text, re.I):
        if float(value) != 0:
            raise ValueError(f'{path}: nonzero master gain {value} dB')
    return hashlib.sha256(text.encode()).hexdigest()


def render_fresh(txtp, destination, decoder='vgmstream-cli'):
    """Decode every time: changed banks, TXTP or decoder cannot reuse stale previews.

    Validate before touching output; atomically replace only after successful decode.
    Event node gains remain intact. No normalization or master compensation is added.
    """
    validate_txtp(txtp)
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=destination.parent) as temporary:
        rendered = Path(temporary)/'render.wav'
        subprocess.run([decoder, '-i', '-o', str(rendered), str(Path(txtp).resolve())],
                       check=True, capture_output=True)
        if not rendered.is_file() or rendered.stat().st_size < 44:
            raise ValueError(f'{txtp}: decoder produced no WAV')
        rendered.replace(destination)
