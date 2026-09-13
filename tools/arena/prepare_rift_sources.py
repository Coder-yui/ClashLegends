"""Extract selected original Summoner's Rift atlases from a read-only LoL WAD.

Requires the installed wadtools and ltk-tex-utils commands, plus Pillow for the
optional contact sheet. This only decodes selected TEX files to PNG; it does not
paint, crop, recolor, or reinterpret their authored pixels. Most inputs are UV
atlases, NOT seamless textures. Select suitable UV regions in arena materials.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
ARENA = ROOT / "assets/arena/rift_arena"
DEFAULT_WAD = Path(
    "/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/Maps/Shipping/Map11.wad.client"
)
SR = "assets/maps/kitpieces/summoners_rift/textures/"
SRX = "assets/maps/kitpieces/srx/"

# Names describe intended material use, not the entirety of each source atlas.
SELECTION = [
    ("grass_primary", SRX + "base/textures/terrain_midlane_ground_a.tex",
     "Grass, warm dirt and broken gray stone of mid lane; use selected surface UVs."),
    ("grass_secondary", SR + "grnd_terrain_l.tex",
     "Jungle grass, branching paths and cool gray camp stone; selected UVs only."),
    ("stone_paving", SRX + "base/textures/terrain_base_south_ground_b.tex",
     "Order base broad cut-stone courtyard, grassy verge and warm path."),
    ("rock_cliff", SR + "_chunk_jungle_north_island_a_alpha_3dcuv_atlas_color_1bitalpha.tex",
     "Layered mossy cliff, carved ruin and column islands, with small blue plants."),
    ("rock_woodland", SR + "_chunk_jungle_north_island_d_alpha_3dcuv_atlas_color_1bitalpha.tex",
     "Different rock faces, cut trunks, low foliage and wooden details."),
    ("rock_crystal", SR + "_chunk_jungle_north_island_c_alpha_3dcuv_atlas_color_1bitalpha.tex",
     "Cool rocky outcrops and crystal faces with bark, plants and needle foliage."),
    ("canopy_foliage", SR + "base_south_foliage_1bitalpha.tex",
     "Several hand-painted needle-canopy shapes and bare branches with cutout alpha."),
    ("forest_south", SR + "_chunk_jungle_south_island_c_alpha_3dcuv_atlas_color_1bitalpha.tex",
     "Moss-covered woodland rocks, trunks and multiple separate foliage islands."),
    ("brush_grass", SRX + "textures/sru_brush.tex",
     "Broad wind-combed brush strokes; authored UV layout, not a plain grass tile."),
    ("river_waterlily", SRX + "textures/ocean_waterlily_a.tex",
     "Pink flowers, lily leaves and curled bank vegetation; cutout UV islands."),
    ("ruin_wall", SR + "_chunk_base_north_walls_b_alpha_3dcuv_atlas_color_1bitalpha.tex",
     "Distinct carved base-wall and architectural stone atlas."),
    ("base_platform", SR + "pally_platform_1bitalpha.tex",
     "Order platform stone and circular construction trim atlas."),
]


def digest(path):
    checksum = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            checksum.update(block)
    return checksum.hexdigest()


def command(*args):
    return subprocess.run([str(arg) for arg in args], check=True, text=True,
                          capture_output=True).stdout


def png_dimensions(path):
    import struct
    with path.open("rb") as handle:
        header = handle.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Invalid PNG: {path}")
    return list(struct.unpack(">II", header[16:24]))


def contact_sheet(output, textures):
    from PIL import Image, ImageDraw, ImageFont
    columns, cell_w, cell_h = 4, 360, 410
    sheet = Image.new("RGB", (columns * cell_w, 3 * cell_h), (40, 49, 48))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=18)
    for index, item in enumerate(textures):
        source = ROOT / item["png_path"]
        with Image.open(source) as image:
            image.thumbnail((348, 348), Image.Resampling.LANCZOS)
            x, y = (index % columns) * cell_w + 6, (index // columns) * cell_h + 6
            if image.mode == "RGBA":
                sheet.paste(image, (x, y), image)
            else:
                sheet.paste(image, (x, y))
        draw.text((x, y + 354), item["id"], fill=(230, 238, 235), font=font)
        draw.text((x, y + 377), "Original pixels / UV atlas", fill=(158, 180, 173), font=font)
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wad", type=Path, default=DEFAULT_WAD)
    parser.add_argument("--contact-sheet", type=Path,
                        default=ROOT / "builds/arena_preview/source_texture_contact.jpg")
    args = parser.parse_args()
    wad = args.wad.resolve(strict=True)
    wad_stat = wad.stat()
    for executable in ("wadtools", "ltk-tex-utils"):
        if not shutil.which(executable):
            raise RuntimeError(f"Required tool not found: {executable}")
    pattern = "^(?:" + "|".join(re.escape(path) for _, path, _ in SELECTION) + ")$"
    entries = json.loads(command("wadtools", "-L", "warning", "list", "-i", wad,
                                 "-x", pattern, "-F", "json"))["chunks"]
    by_path = {entry["path"]: entry for entry in entries}
    missing = [path for _, path, _ in SELECTION if path not in by_path]
    if missing:
        raise RuntimeError(f"Missing selected assets: {missing}")

    destination = ARENA / "textures"
    destination.mkdir(parents=True, exist_ok=True)
    textures = []
    with tempfile.TemporaryDirectory(prefix="clash_rift_sources_") as directory:
        staging = Path(directory)
        command("wadtools", "-L", "warning", "extract", "-i", wad,
                "-o", staging, "-x", pattern, "--stats=false")
        for asset_id, path, usage in SELECTION:
            original = staging / path
            target = destination / (asset_id + ".png")
            command("ltk-tex-utils", "decode", "-i", original, "-o", target)
            textures.append({
                "id": asset_id,
                "source_path": path,
                "wad_path_hash": by_path[path]["hash"],
                "source_tex_sha256": digest(original),
                "png_path": target.relative_to(ROOT).as_posix(),
                "png_sha256": digest(target),
                "dimensions": png_dimensions(target),
                "source_format": "Riot TEX",
                "processing": "ltk-tex-utils decode mip 0 to PNG; no image edits",
                "layout": "authored UV atlas; not seamless",
                "intended_use": usage,
            })
    if (wad.stat().st_size, wad.stat().st_mtime_ns) != (wad_stat.st_size, wad_stat.st_mtime_ns):
        raise RuntimeError("Source WAD changed during extraction")
    manifest = {
        "source": "Local League of Legends asset archive / Riot Games",
        "extracted_on": "2026-09-12",
        "source_wad": str(wad),
        "source_wad_size": wad_stat.st_size,
        "source_wad_sha256": digest(wad),
        "source_policy": "Original archive read only. Selected files decoded; no original moved or edited.",
        "usage": "Textures for individual 3D surfaces. No map image used as arena background.",
        "note": "Color and alpha remain original. Brightness and UV selection belong to arena materials.",
        "tools": {"wadtools": command("wadtools", "--version").strip(),
                  "ltk-tex-utils": command("ltk-tex-utils", "--version").strip()},
        "textures": textures,
    }
    (ARENA / "source_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    contact_sheet(args.contact_sheet, textures)
    print(f"Prepared {len(textures)} original atlases in {destination}")
    print(f"Contact sheet: {args.contact_sheet}")


if __name__ == "__main__":
    main()
