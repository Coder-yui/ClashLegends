"""Bake the death-cue limit into imported PCM16 WAVs, never the source library."""
from array import array
import hashlib
import os
from pathlib import Path
import sys
import tempfile
import wave


DEATH_AUDIO_NOTE = "死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。"


def apply_death_envelope(path: Path, entry: dict) -> bool:
    """Process an explicitly selected death cue; a repeated call is a no-op."""
    path = Path(path)
    with wave.open(str(path), 'rb') as source:
        params = source.getparams()
        keep_frames = round(params.framerate * 1.5)
        if params.nframes <= keep_frames:
            return False
        if params.sampwidth != 2 or params.comptype != 'NONE':
            raise ValueError(f'{path}: expected uncompressed PCM16 death audio')
        pcm = source.readframes(keep_frames)

    source_hash = hashlib.sha256(path.read_bytes()).hexdigest()
    samples = array('h', pcm)
    if sys.byteorder != 'little':
        samples.byteswap()
    fade_start = params.framerate
    fade_span = keep_frames - fade_start - 1
    for frame in range(fade_start, keep_frames):
        gain = (keep_frames - 1 - frame) / fade_span
        for channel in range(params.nchannels):
            index = frame * params.nchannels + channel
            samples[index] = round(samples[index] * gain)
    if sys.byteorder != 'little':
        samples.byteswap()

    # Replace only after a complete WAV has been written.
    fd, temporary = tempfile.mkstemp(suffix='.wav', dir=path.parent)
    os.close(fd)
    try:
        with wave.open(temporary, 'wb') as output:
            output.setparams(params._replace(nframes=keep_frames))
            output.writeframes(samples.tobytes())
        os.chmod(temporary, path.stat().st_mode & 0o777)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)

    entry['duration'] = keep_frames / params.framerate
    entry['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    entry['death_envelope'] = {
        'source_duration': params.nframes / params.framerate,
        'source_sha256': source_hash,
        'keep_seconds': 1.5,
        'fade_start_seconds': 1.0,
        'fade_seconds': 0.5,
        'curve': 'linear_amplitude',
    }
    processing = entry.get('processing', 'source PCM gain retained')
    entry['processing'] = processing + '; death: first 1.5s, unchanged first 1s, linear amplitude fade to zero over final 0.5s'
    return True
