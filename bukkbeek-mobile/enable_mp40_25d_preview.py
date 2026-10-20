#!/usr/bin/env python3
"""Stage a playable, deliberately labeled MP40 V8 ART PREVIEW alongside source MP40.

This never edits the original 3D MP40 or the nine existing weapon slots.
The current MP40Pixel test slot is upgraded only in the assembled V8 APK.
"""
from pathlib import Path
import sys
import tempfile
import zipfile
import shutil

from build_mp40_25d_from_sheets import SOURCES, assemble

source = Path(__file__).resolve().parent
root = Path(sys.argv[1]).resolve()
archive = source / "pixel_assets/mp40_25d_original_source_strips.zip"
assert archive.is_file(), "MP40_25D_V8_SOURCE_RED: 8 strips ZIP missing"
expected = {name for name, _ in SOURCES.values()}
with tempfile.TemporaryDirectory(prefix="mp40-v8-art-") as directory:
    temp = Path(directory)
    found = {}
    with zipfile.ZipFile(archive) as z:
        for entry in z.infolist():
            if entry.is_dir():
                continue
            name = Path(entry.filename.replace("\\", "/")).name
            if name not in expected:
                continue
            assert name not in found, "MP40_25D_V8_SOURCE_RED duplicated strip: " + name
            assert entry.file_size <= 16_000_000, "MP40_25D_V8_SOURCE_RED oversized strip: " + name
            with z.open(entry) as inp, (temp / name).open("wb") as out:
                shutil.copyfileobj(inp, out)
            found[name] = entry.file_size
    assert set(found) == expected, (
        "MP40_25D_V8_SOURCE_RED missing strips "
        + repr(sorted(expected - set(found)))
    )
    destination = root / "mobile/mp40_25d"
    destination.mkdir(parents=True, exist_ok=True)
    for name in ["motion_manifest.json", "timeline.gd", "sprite_deck.gd",
                 "mp40_pixel_v8_weapon.gd", "playable_probe.gd", "visual_probe.gd"]:
        shutil.copy2(source / "mobile/mp40_25d" / name, destination / name)
    assemble(temp, destination / "motion_manifest.json", destination / "frames")
    frame_paths = sorted((destination / "frames").glob("*/*.png"))
    assert len(frame_paths) == 107, f"MP40_25D_V8_FRAMES_RED {len(frame_paths)} / 107"

# Do not replace any other gun, gameplay script, ammo values, or real audio.
scene = root / "mobile/mp40_pixel.tscn"
text = scene.read_text()
needle = 'path="res://mobile/mp40_pixel_weapon.gd"'
assert text.count(needle) == 1, "MP40_25D_V8_STAGE_RED wrong MP40Pixel scene"
scene.write_text(text.replace(needle, 'path="res://mobile/mp40_25d/mp40_pixel_v8_weapon.gd"', 1))
print("MP40_25D_V8_STAGE_GREEN original_strips=8 original_frames=107 mp40_3d_untouched=true art_review=required preview_only=true")
