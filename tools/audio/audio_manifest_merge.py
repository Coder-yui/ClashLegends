"""Keep separately audited supplemental assets when rebuilding a legacy whitelist."""
import json
from pathlib import Path


def merge_audio_manifest(path: Path, generated: list) -> list:
    if not path.exists():
        return generated
    produced = {row['file'] for row in generated}
    previous = json.loads(path.read_text())
    return generated + [row for row in previous
                        if row['file'] not in produced
                        and (path.parent / row['file']).is_file()]
