#!/usr/bin/env python3
"""Record isolated control fixtures with Godot Movie Maker; no screen or mic capture."""
import argparse
import json
from pathlib import Path
import subprocess

SHOTS = {
    "attack_stun": "01a_attack_stun",
    "attack_freeze": "01b_attack_freeze",
    "attack_stasis": "01c_attack_stasis",
    "judgment": "02_judgment_stasis",
    "projectile": "03_projectile_stasis",
    "scatter_freeze": "04a_scatter_freeze",
    "scatter_stasis": "04b_scatter_stasis",
    "transform": "05_transform_stasis",
    "tower": "06_tower_stasis",
    "mist_baseline": "07a_gwen_without_mist",
    "mist": "07b_gwen_mist_targeting",
    "knockback_baseline": "08a_sett_without_knockback",
    "knockback": "08b_sett_knockback_cast",
    "herald_enemy_stasis": "09a_herald_enemy_stasis",
    "herald_friendly_stasis": "09b_herald_friendly_stasis",
}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--shots", nargs="+", choices=SHOTS, default=list(SHOTS))
    parser.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot")
    parser.add_argument("--ffmpeg", default="/opt/homebrew/bin/ffmpeg")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    if not output.is_relative_to(repo / "ClashLegends-promo-materials"):
        parser.error("Output must be inside the project's ignored promo directory")
    for sub in ("raw", "clips", "qa", "logs"):
        (output / sub).mkdir(parents=True, exist_ok=True)
    # Preflight the whole request before starting; never overwrite an earlier take.
    for shot in args.shots:
        for path in (output / "raw" / (shot + ".avi"), output / "clips" / (SHOTS[shot] + ".mp4"), output / "qa" / (shot + "_trace.jsonl")):
            if path.exists(): parser.error(f"Existing take: {path}")
    for shot in args.shots:
        raw = output / "raw" / (shot + ".avi")
        log = output / "logs" / (shot + ".log")
        cmd = [args.godot, "--path", str(repo), "--log-file", str(log), "--fixed-fps", "60",
               "--write-movie", str(raw), "--resolution", "720x1400", "--script",
               "tools/capture/capture_control_scenes.gd", "--", "--shot=" + shot, "--out=" + str(output / "qa")]
        print("RECORD", shot, flush=True)
        with (output / "logs" / (shot + "_console.log")).open("w") as stream:
            subprocess.run(cmd, cwd=repo, stdout=stream, stderr=subprocess.STDOUT, timeout=150, check=True)
        if "SCRIPT ERROR" in log.read_text() or "ERROR:" in log.read_text():
            raise RuntimeError(f"Inspect {log}")
        trace = [json.loads(line) for line in (output / "qa" / (shot + "_trace.jsonl")).read_text().splitlines()]
        assert trace[-1]["event"] == "capture_end" and trace[-1]["ticks"] == 240, shot
        expected = {"mist_baseline": "comparison_marker", "mist": "mist_start", "knockback_baseline": "skill_start", "knockback": "knockback_after"}
        if shot.startswith("herald_"):
            assert any(row["event"] == "herald_stasis_cast" and row["accepted"] for row in trace), f"Spell did not launch: {shot}"
        elif shot in expected:
            assert any(row["event"] == expected[shot] for row in trace), f"Fixture did not trigger: {shot}"
        elif shot != "judgment":
            assert any(row["event"] == "control_after" for row in trace), f"Control did not trigger: {shot}"
        clip = output / "clips" / (SHOTS[shot] + ".mp4")
        subprocess.run([args.ffmpeg, "-hide_banner", "-loglevel", "error", "-n", "-i", str(raw),
                        "-c:v", "libx264", "-preset", "fast", "-crf", "16", "-pix_fmt", "yuv420p",
                        "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", str(clip)], check=True, timeout=150)
        print("DONE", clip, flush=True)

if __name__ == "__main__":
    main()
