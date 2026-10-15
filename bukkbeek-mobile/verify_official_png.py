#!/usr/bin/env python3
"""Verify original hand-approved touchscreen PNGs. No generated fallback art."""
from pathlib import Path
import struct
import sys

FILES = (
    "move.png", "fire.png", "ads.png", "adsfire.png",
    "reload.png", "interact.png", "jump.png", "sprint.png",
    "crouch.png", "knife.png", "switch.png", "pause.png",
)
BANNED = (
    "touch_idle.png", "touch_pressed.png", "touch_small_idle.png",
    "touch_fire_idle.png", "touch_fire_pressed.png",
    "touch_ads_idle.png", "touch_ads_pressed.png",
    "touch_adsfire_idle.png", "touch_adsfire_pressed.png",
    "joystick_ring.png", "joystick_knob.png", "joystick_knob_active.png",
)

def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("bukkbeek-mobile/official_png")
    if not root.is_dir():
        print(f"ASSET GATE RED: official PNG directory missing: {root}", file=sys.stderr)
        print("No fallback: old circles and auto-generated buttons are forbidden.", file=sys.stderr)
        return 2
    found = {p.name for p in root.glob("*.png")}
    absent = sorted(set(FILES) - found)
    extra = sorted(found - set(FILES))
    banned = sorted(found.intersection(BANNED))
    if absent or extra or banned:
        print(f"ASSET GATE RED: missing={absent} extra={extra} old={banned}", file=sys.stderr)
        return 3
    for name in FILES:
        data = (root / name).read_bytes()
        if len(data) < 70 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
            print(f"ASSET GATE RED: invalid PNG: {name}", file=sys.stderr)
            return 4
        width, height, bit_depth, color_type = struct.unpack_from(">IIBB", data, 16)
        if not (32 <= width <= 4096 and 32 <= height <= 4096):
            print(f"ASSET GATE RED: wrong dimensions {name}: {width}x{height}", file=sys.stderr)
            return 5
        if color_type not in (4, 6) and b"tRNS" not in data:
            print(f"ASSET GATE RED: needs transparency: {name}", file=sys.stderr)
            return 6
    print("OFFICIAL XZIEL PNG ONLY: 12/12 available, valid transparent PNGs.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
