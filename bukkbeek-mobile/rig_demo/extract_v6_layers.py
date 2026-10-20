#!/usr/bin/env python3
"""Isolated MP40 skeletal proof-of-concept: extract REAL V6 art, no new drawings.
Never changes shipped weapons, source PNGs, or V6/V8 animation scripts.
Flat 2D source cannot reveal unseen finger/receiver pixels; these masks are
experimental and deliberately kept outside production.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
from hashlib import sha256
import json
import sys

SRC = Path(sys.argv[1])
DEST = Path(sys.argv[2])
DEST.mkdir(parents=True, exist_ok=True)
assert SRC.is_file(), "RIG_RED original user-approved 1448x1086 source missing"
source = Image.open(SRC).convert("RGBA")
assert source.size == (1448, 1086), f"RIG_RED source size {source.size}"

def tile(idx):
    c, r = idx % 3, idx // 3
    x = round(c * 1448 / 3)
    im = source.crop((x, r * 362, round((c + 1) * 1448 / 3), r * 362 + 326))
    canvas = Image.new("RGBA", (483, 326))
    canvas.alpha_composite(im)
    return canvas

# Exactly two REAL, previously-used V6 drawings, not the flawed V8 strips.
empty_left = tile(5)   # reload_01: hand reaching at magazine well
held_mag = tile(8)     # reload_04: hand holding removed/fresh magazine
W, H = held_mag.size

def cut(image, name, vertices):
    mask = Image.new("L", (W, H))
    ImageDraw.Draw(mask).polygon(vertices, fill=255)
    output = image.copy()
    output.putalpha(ImageChops.multiply(image.getchannel("A"), mask))
    assert output.getchannel("A").getbbox() is not None, "RIG_RED empty cut: " + name
    output.save(DEST / name)
    return output

# The image is flattened: split approximate zones into movable pieces.
# Note: seams and hidden fingers have NOT been repainted. These defects are
# explicitly what this feasibility study must expose before adopting a rig.
cut(held_mag, "gun_right_arm.png",
    [(186, 0), (482, 0), (482, 325), (186, 325)])
cut(held_mag, "left_sleeve.png",
    [(0, 265), (152, 265), (153, 325), (0, 325)])
cut(held_mag, "left_mag_hand.png",
    [(0, 0), (185, 0), (185, 265), (0, 265)])
cut(empty_left, "left_bolt_hand.png", [
    (0, 155), (105, 151), (146, 151), (160, 166), (162, 182),
    (183, 194), (207, 199), (213, 211), (193, 224), (174, 230),
    (147, 246), (125, 270), (0, 270)
])
# Expose precise data for repeatable QA, not ungrounded image-quality claims.
manifest = {
    "type": "isolated_2d_bone_study_not_a_weapon",
    "source": SRC.name,
    "sha256": sha256(SRC.read_bytes()).hexdigest(),
    "original_source_images": ["reload_01", "reload_04"],
    "cutout_layers": ["gun_right_arm", "left_sleeve", "left_mag_hand", "left_bolt_hand"],
    "limitations": ["manually approximated masks", "seams can appear", "no new side angles",
                    "bolt is gesture test, not verified source mechanical animation",
                    "existing V6 artwork, not new anime-sketch look"],
}
(DEST / "rig_source_manifest.json").write_text(json.dumps(manifest, indent=2))
print("MP40_BONES_ART_GREEN exactly_two_approved_V6_source_poses=true isolated=true")
