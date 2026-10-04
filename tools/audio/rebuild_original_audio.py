"""Render reviewed per-file recipes into a new material-library directory.

No source or assets are modified. Recipes contain clean float inputs generated with
wwiser -gv=0dB, explicit temporal filters, and zero post gain. Reject clipped output
instead of silently adding headroom or normalizing. Requires numpy and ffmpeg.
"""
import argparse
import concurrent.futures
import hashlib
import json
import subprocess
from pathlib import Path
import numpy as np
from original_gain import validate_txtp


def run_recipe(recipe, output):
    if '/freeze/' in recipe['file']:
        raise ValueError('freeze is excluded')
    if recipe['post_gain_db'] != 0 or recipe['tool_master_gain_db'] != 0:
        raise ValueError('only original event gain is allowed')
    relative = Path(recipe['file'])
    if relative.is_absolute() or '..' in relative.parts or not str(relative).startswith('assets/audio/'):
        raise ValueError('invalid audio destination')
    if len(recipe.get('input_sha256', [])) != len(recipe['inputs']):
        raise ValueError('reviewed input hashes required')
    for path, expected in zip(recipe['inputs'], recipe['input_sha256']):
        if hashlib.sha256(Path(path).read_bytes()).hexdigest() != expected:
            raise ValueError(f'{path}: input changed since recipe review')
    for event in recipe.get('clean_txtp', []):
        validate_txtp(event['file'])
        if hashlib.sha256(Path(event['file']).read_bytes()).hexdigest() != event['sha256']:
            raise ValueError('event description changed since review')
    if not recipe.get('clean_txtp') and any(Path(p).suffix != '.ogg' for p in recipe['inputs']):
        raise ValueError('clean TXTP evidence or original OGG required')
    destination = output / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    command = ['ffmpeg', '-v', 'error', '-y']
    for path in recipe['inputs']:
        command += ['-i', path]
    if recipe.get('filter_complex'):
        command += ['-filter_complex', recipe['filter_complex'], '-map', '[out]']
    elif recipe['filters']:
        command += ['-af', ','.join(recipe['filters'])]
    command += ['-ar', str(recipe['sample_rate']), '-ac', str(recipe['channels'])]
    float_result = subprocess.run(command + ['-f', 'f32le', '-'], check=True, capture_output=True)
    pcm = np.frombuffer(float_result.stdout, dtype='<f4')
    if not pcm.size or not np.isfinite(pcm).all() or not np.any(pcm):
        raise ValueError(f'{recipe["file"]}: empty/nonfinite/silent output')
    peak = float(np.max(np.abs(pcm)))
    if peak >= 1 and destination.suffix != '.ogg':
        raise ValueError(f'{recipe["file"]}: original mix exceeds PCM16, peak={peak}; review layers')
    if destination.suffix == '.ogg':
        # Retain the original compressed media; decoding/re-encoding loses fidelity.
        if recipe['filters'] or recipe.get('filter_complex'):
            raise ValueError('edited OGG requires an explicit new format')
        destination.write_bytes(Path(recipe['inputs'][0]).read_bytes())
    else:
        # Godot expects standard PCM RIFF, including the 96 kHz stereo lock-in SFX.
        import wave
        quantized = np.clip(np.rint(pcm.astype(np.float64)*32768), -32768, 32767).astype('<i2')
        with wave.open(str(destination), 'wb') as stream:
            stream.setnchannels(recipe['channels'])
            stream.setsampwidth(2)
            stream.setframerate(recipe['sample_rate'])
            stream.writeframes(quantized.tobytes())
    return dict(recipe, sha256=hashlib.sha256(destination.read_bytes()).hexdigest(),
                peak=peak, duration=pcm.size/recipe['channels']/recipe['sample_rate'],
                input_sha256=[hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in recipe['inputs']])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    library = Path(__file__).resolve().parents[2]/'ClashLegends-开发素材库'
    if not args.output.resolve().is_relative_to(library.resolve()):
        parser.error('output must be inside the development material library')
    args.output.mkdir(parents=True, exist_ok=False)
    recipes = json.loads(args.plan.read_text())
    errors, results = [], []
    def job(recipe):
        try:
            return run_recipe(recipe, args.output), None
        except Exception as error:
            return None, {'file': recipe['file'], 'error': str(error)}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for result, error in pool.map(job, recipes):
            if error: errors.append(error)
            else: results.append(result)
    (args.output/'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
    (args.output/'errors.json').write_text(json.dumps(errors, ensure_ascii=False, indent=2))
    print(f'Rendered {len(results)}; rejected {len(errors)}')
    if errors: raise SystemExit(1)


if __name__ == '__main__':
    main()
