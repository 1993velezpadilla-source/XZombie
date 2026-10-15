#!/usr/bin/env python3
"""Exact approved XZIEL buttons validation — SHA of each ORIGINAL PNG from GitHub."""
import hashlib
from pathlib import Path
import struct
import sys

SOURCE_REPOSITORY = "1993velezpadilla-source/config-old-3"
SOURCE_COMMIT = "0119c5b0f9109c4c88dbdd4173a9a2ba523abc3d"
SOURCE_DIRECTORY = "assets/xziel/official_touch_skins_v1"
GIT_BLOB_SHA = {
    "aim.png": "e0d1d2043f85a100c6740aa806c321048f595f4b",
    "aim_fire.png": "e8d86eeb2763bd1b9c0066f885d75020b746d523",
    "crouch.png": "e6d46676896d2b54fa2dc98e27ffa71dc1c6ddbe",
    "fire.png": "2909049cd326c5b016dac41784d40fcbd6eaef86",
    "grenade.png": "897ed75623d3baeb6855a18ae9e47875a4589b7d",
    "interact.png": "31b00206f6caebd1029342a082b6943bc3ef826e",
    "knife.png": "26c2cd0ed621834656afaad9cd73db2b4d331723",
    "prone.png": "73727e569937ed189d19e6cbf46d4ee5759b6f11",
    "reload.png": "a1b87f13c3ba29f06e80afcd73fd577d00d96ff6",
    "slide.png": "bf8851a7920bf7e44def2bb6043841bd631359f8",
    "vault_jump.png": "05ddc4aed65605b0e960864c6141599df5496454",
    "weapon_swap.png": "b297eae9f3cc108d600333c3402d71987c986421",
}

def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("bukkbeek-mobile/official_png")
    existing = {p.name for p in root.glob("*.png")} if root.is_dir() else set()
    expected = set(GIT_BLOB_SHA)
    if existing != expected:
        print("XZIEL PNG GATE RED: missing =", sorted(expected-existing), "unknown =", sorted(existing-expected), file=sys.stderr)
        return 2
    for name, correct_sha in GIT_BLOB_SHA.items():
        raw = (root / name).read_bytes()
        if len(raw) < 70 or raw[:8] != b"\x89PNG\r\n\x1a\n" or raw[12:16] != b"IHDR":
            print("XZIEL PNG GATE RED: corrupt", name, file=sys.stderr)
            return 3
        width, height, depth, color = struct.unpack_from(">IIBB", raw, 16)
        if not (32 <= width <= 4096 and 32 <= height <= 4096):
            print("XZIEL PNG GATE RED: dimensions", name, file=sys.stderr)
            return 4
        if color not in (4, 6) and b"tRNS" not in raw:
            print("XZIEL PNG GATE RED: not transparent", name, file=sys.stderr)
            return 5
        actual_sha = hashlib.sha1(("blob %d\0" % len(raw)).encode("ascii")+raw).hexdigest()
        if actual_sha != correct_sha:
            print("XZIEL PNG GATE RED: not official asset", name, file=sys.stderr)
            return 6
    print("XZIEL OFFICIAL BUTTON SKINS GREEN: EXACT original 12/12, verified Git blob SHA.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
