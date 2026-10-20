#!/usr/bin/env python3
"""Stage approved MP40 forward-looking hip PNG into the existing Godot map.

V6 keeps original WaW MP40, ADS, sounds, source hands and other sprite frames
untouched. Replaces ONLY idle HIP and fired HIP with this approved sprite.
"""
from pathlib import Path
from hashlib import sha256
from PIL import Image
import json
import shutil
import sys

SOURCE_SHA256 = "f120ab53c5b5593392cfdb184ef98077a76d8881d7755ca4992ca8c47847394f"
SOURCE_NAME = "MP40_Pixel_Forward_HIP_482x326.png"
FRAMES = ("idle_hip_01", "fire_hip_01")


def apply(root: Path) -> None:
    source = Path(__file__).resolve().parent / "pixel_assets" / SOURCE_NAME
    assert source.is_file(), "MP40_PIXEL_V6_RED approved source PNG missing"
    data = source.read_bytes()
    assert sha256(data).hexdigest() == SOURCE_SHA256, "MP40_PIXEL_V6_RED source changed"
    with Image.open(source) as png:
        assert png.format == "PNG" and png.size == (482, 326), "MP40_PIXEL_V6_RED incorrect PNG"
        im = png.convert("RGBA")
    assert im.getpixel((0, 0))[3] == 0, "MP40_PIXEL_V6_RED opaque black backdrop"
    assert sum(v > 90 for v in im.getchannel("A").getdata()) > 25000, "MP40_PIXEL_V6_RED silhouette missing"
    assert im.getpixel((221, 105))[3] > 50, "MP40_PIXEL_V6_RED frontal sight missing"
    target = root.resolve() / "mobile" / "mp40_pixel"
    frame_dir = target / "frames"
    assert frame_dir.is_dir(), "MP40_PIXEL_V6_RED sprite directory absent"
    assert len(list(frame_dir.glob("*.png"))) == 9, "MP40_PIXEL_V6_RED sprite catalog changed"
    for name in FRAMES:
        shutil.copyfile(source, frame_dir / (name + ".png"))
        assert sha256((frame_dir / (name + ".png")).read_bytes()).hexdigest() == SOURCE_SHA256
    (target / "forward_hip_manifest.json").write_text(json.dumps({
        "release": "MP40PixelV6", "source_file": SOURCE_NAME,
        "source_sha256": SOURCE_SHA256, "source_size": [482,326],
        "forward_sight_x_px": 221.5, "replaces_only": list(FRAMES),
        "other_weapons_and_original_mp40": "untouched",
    }, indent=2) + "\n")
    print("MP40_PIXEL_V6_SOURCE_GREEN image_sha256=" + SOURCE_SHA256 +
          " idle_hip=true fire_hip=true alpha_transparent=true preserved_other_frames=7")


if __name__ == "__main__":
    assert len(sys.argv) == 2
    apply(Path(sys.argv[1]))
