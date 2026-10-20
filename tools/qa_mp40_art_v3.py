#!/usr/bin/env python3
"""Direct GitHub CI art QA: prove 13 distinct purposeful transparent nun MP40 poses.

Creates a labeled 3-column contact sheet uploaded as an Actions artifact;
not a user-visible chat image. The in-engine captures are a separate gate.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

FRAMES = [
    "idle_hip_01", "fire_hip_01", "ads_idle", "ads_fire_01",
    "sprint_01", "reload_01", "reload_02", "reload_03", "reload_04",
    "reload_empty_01", "reload_empty_02", "reload_empty_03",
    "reload_empty_04",
]


def gate(root: Path, output: Path):
    manifest = json.loads((root / "nun_mp40_v3_manifest.json").read_text())
    assert manifest["frames"] == FRAMES
    assert manifest["resolution"] == [960, 720]
    assert manifest["hip_optical_anchor_px"] == [480, 207]
    assert manifest["ads_optical_anchor_px"] == [480, 213]
    thumbnails = []
    hashes = {}
    for name in FRAMES:
        source = root / (name + ".png")
        assert source.is_file(), f"missing rendered nun source frame {name}"
        im = Image.open(source)
        assert im.mode == "RGBA" and im.size == (960, 720), (name, im.mode, im.size)
        assert im.getpixel((0, 0))[3] == 0
        assert im.getpixel((480, 214))[3] > 40, f"broken crosshair shaft {name}"
        # A genuinely dark habit + exposed pale skin, never olive military gloves.
        colors = im.getdata()
        pale = sum(1 for r, g, b, a in colors if a > 180 and r > 160 and r > g + 13 and g > b - 10)
        dark = sum(1 for r, g, b, a in colors if a > 180 and 14 < r < 85 and abs(r-g) < 23 and abs(g-b) < 25)
        assert pale > 300 and dark > 5000, f"nun hands or sleeves missing {name}: {pale=} {dark=}"
        hashes[name] = hashlib.sha256(source.read_bytes()).hexdigest()
        thumb = im.resize((470, 353), Image.Resampling.LANCZOS)
        thumbnails.append((name, thumb))
        print("NUN_MP40_V3_ART_GATE", name, "pale=", pale, "habit=", dark, "sha256=", hashes[name])

    for lhs, rhs in [
        ("idle_hip_01", "fire_hip_01"),
        ("idle_hip_01", "ads_idle"),
        ("reload_01", "reload_02"),
        ("reload_02", "reload_03"),
        ("reload_03", "reload_04"),
        ("reload_04", "reload_empty_04"),
    ]:
        assert hashes[lhs] != hashes[rhs], f"two mechanical poses are identical: {lhs}, {rhs}"

    sheet = Image.new("RGBA", (1500, 5 * 407), (26, 22, 29, 255))
    d = ImageDraw.Draw(sheet, "RGBA")
    for i, (name, thumbnail) in enumerate(thumbnails):
        x = (i % 3) * 500 + 15
        y = (i // 3) * 407 + 42
        d.rectangle((x - 8, y - 35, x + 480, y + 357), fill=(47, 43, 53, 255))
        d.text((x + 6, y - 25), name, fill=(234, 208, 188, 255))
        sheet.alpha_composite(thumbnail, (x, y))
        sight = (x + 235, y + 176)
        d.line((sight[0] - 8, sight[1], sight[0] - 3, sight[1]), fill=(255, 255, 255, 145), width=1)
        d.line((sight[0] + 3, sight[1], sight[0] + 8, sight[1]), fill=(255, 255, 255, 145), width=1)
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(output, quality=91)
    (output.parent / "nun_mp40_v3_sha256.json").write_text(json.dumps(hashes, indent=2) + "\n")
    print("NUN_MP40_V3_VISUAL_CONTACT_SHEET_GREEN", output)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--source", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    gate(args.source, args.output)
