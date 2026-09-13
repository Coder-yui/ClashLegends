"""Copy the selected, already rendered Miss Fortune base-skin events."""
from audio_manifest_merge import merge_audio_manifest
import json
import shutil
from pathlib import Path
from death_audio_envelope import apply_death_envelope


SOURCE = Path("/Users/czh/Tools/lol-asset-tools/verification/missfortune")
DEATH_SOURCE = Path("/Users/czh/Tools/lol-asset-tools/verification/missfortune_vo_zh")
DEST = Path(__file__).resolve().parents[2] / "assets/audio/units/missfortune"
EVENTS = [
    "Play_sfx_MissFortune_MissFortuneBasicAttack_OnCast",
    "Play_sfx_MissFortune_MissFortuneBasicAttack2_OnCast",
    "Play_sfx_MissFortune_MissFortuneBasicAttack_OnMissileLaunch",
    "Play_sfx_MissFortune_MissFortuneBasicAttack_OnHit",
    "Play_sfx_MissFortune_MissFortuneViciousStrikes_OnCast",
    "Play_sfx_MissFortune_MissFortuneViciousStrikes_OnBuffActivate",
    "Play_sfx_MissFortune_MissFortuneViciousStrikes_OnBuffDeactivate",
]
PASSIVE_CHAIN_FILES = [
    (
        "_inspect_play_sfx_missfortune_missfortunepassiveattack_oncast_r1_d.wav",
        "play_sfx_missfortune_missfortunepassiveattack_oncast_r1_d.wav",
        "Play_sfx_MissFortune_MissFortunePassiveAttack_OnCast",
        3539532735,
        [15777038, 26204524, 51337931, 130283286, 259861560, 285174077],
    ),
    (
        "_inspect_play_sfx_missfortune_missfortunepassiveattack_oncast_r2_d.wav",
        "play_sfx_missfortune_missfortunepassiveattack_oncast_r2_d.wav",
        "Play_sfx_MissFortune_MissFortunePassiveAttack_OnCast",
        3539532735,
        [15777038, 26204524, 51337931, 130283286, 259861560, 285174077],
    ),
    (
        "_inspect_play_sfx_missfortune_missfortunepassiveattack_onmissilecast_r1_d.wav",
        "play_sfx_missfortune_missfortunepassiveattack_onmissilecast_r1_d.wav",
        "Play_sfx_MissFortune_MissFortunePassiveAttack_OnMissileCast",
        1678124587,
        [18378979, 32099403, 54597363, 92661311, 158378122, 211201504],
    ),
    (
        "_inspect_play_sfx_missfortune_missfortunepassiveattack_onmissilecast_r2_d.wav",
        "play_sfx_missfortune_missfortunepassiveattack_onmissilecast_r2_d.wav",
        "Play_sfx_MissFortune_MissFortunePassiveAttack_OnMissileCast",
        1678124587,
        [18378979, 32099403, 54597363, 92661311, 158378122, 211201504],
    ),
    (
        "_inspect_play_sfx_missfortune_missfortunepassiveattack_onmissilelaunch_r1_d.wav",
        "play_sfx_missfortune_missfortunepassiveattack_onmissilelaunch_r1_d.wav",
        "Play_sfx_MissFortune_MissFortunePassiveAttack_OnMissileLaunch",
        2962715415,
        [2853485, 62316331, 83624132, 104087277, 104129671, 105856332],
    ),
    (
        "_inspect_play_sfx_missfortune_missfortunepassiveattack_onmissilelaunch_r2_d.wav",
        "play_sfx_missfortune_missfortunepassiveattack_onmissilelaunch_r2_d.wav",
        "Play_sfx_MissFortune_MissFortunePassiveAttack_OnMissileLaunch",
        2962715415,
        [2853485, 62316331, 83624132, 104087277, 104129671, 105856332],
    ),
    (
        "_inspect_play_sfx_missfortune_missfortunepassiveattack_onhit_1559186049_1153642577_r1_d.wav",
        "play_sfx_missfortune_missfortunepassiveattack_onhit_1559186049_1153642577_r1_d.wav",
        "Play_sfx_MissFortune_MissFortunePassiveAttack_OnHit",
        644705581,
        [72463933, 75463106, 86281192, 189031158, 198488072, 305334516],
    ),
    (
        "_inspect_play_sfx_missfortune_missfortunepassiveattack_onhit_1559186049_1153642577_r2_d.wav",
        "play_sfx_missfortune_missfortunepassiveattack_onhit_1559186049_1153642577_r2_d.wav",
        "Play_sfx_MissFortune_MissFortunePassiveAttack_OnHit",
        644705581,
        [72463933, 75463106, 86281192, 189031158, 198488072, 305334516],
    ),
    (
        "_inspect_play_sfx_missfortune_missfortunepassiveattack_onhitlocation_d.wav",
        "play_sfx_missfortune_missfortunepassiveattack_onhitlocation_d.wav",
        "Play_sfx_MissFortune_MissFortunePassiveAttack_OnHitLocation",
        3874678880,
        [192796325],
    ),
]


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    source_map = json.loads((SOURCE / "event_map.json").read_text())
    selected = []
    for event_name in EVENTS:
        event = next(item for item in source_map["events"] if item["name"] == event_name)
        for relative in event["event_wav"]:
            source = SOURCE / relative
            destination = DEST / source.name
            shutil.copy2(source, destination)
            selected.append(
                {
                    "file": destination.name,
                    "event": event["name"],
                    "event_id": event["id"],
                    "source_preview": relative,
                    "media_ids": event["media_ids"],
                }
            )

    for source_name, destination_name, event_name, event_id, media_ids in PASSIVE_CHAIN_FILES:
        source = SOURCE / "event_wav" / source_name
        destination = DEST / destination_name
        shutil.copy2(source, destination)
        selected.append(
            {
                "file": destination.name,
                "event": event_name,
                "event_id": event_id,
                "source_preview": f"event_wav/{source_name}",
                "media_ids": media_ids,
                "selection_note": "已验证的 PassiveAttack 完整链条自然变体；其余随机分支留在外部来源库。",
            }
        )

    death_map = json.loads((DEATH_SOURCE / "death_event_manifest.json").read_text())
    for item in death_map:
        source = DEATH_SOURCE / "event_wav" / item["file"]
        destination = DEST / source.name
        shutil.copy2(source, destination)
        selected.append(
            {
                "file": destination.name,
                "event": item["event"],
                "event_id": item["event_id"],
                "source_preview": str(source),
                "source_txtp": str((DEATH_SOURCE / item["source_preview"]).resolve()),
                "media_ids": item["media_ids"],
                "source_package": item["source_package"],
            }
        )
        apply_death_envelope(destination, selected[-1])

    selected = merge_audio_manifest(DEST / 'event_manifest.json', selected)
    (DEST / "event_manifest.json").write_text(json.dumps(selected, ensure_ascii=False, indent=2) + "\n")
    print(f"Copied {len(selected)} selected Miss Fortune event WAVs; source banks remain outside the project.")


if __name__ == "__main__":
    main()
