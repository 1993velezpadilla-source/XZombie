#!/usr/bin/env python3
"""V5.2 source-pixel gate: clean reload sprite-sheet bleed and open ADS aperture.

Called AFTER split + matte repair so restored alpha cannot resurrect ghosts.
Original MP40 RGB, fire/reload timing/audio, all other weapons remain untouched.
Uses only Pillow already installed in GitHub Actions.
"""
from __future__ import annotations
from collections import deque
from pathlib import Path
from PIL import Image
import json
import sys

RELOADS = ("reload_01", "reload_02", "reload_03", "reload_04")
FRAMES = ("idle_hip_01", "ads_idle", "fire_hip_01", "ads_fire_01",
          "sprint_01", *RELOADS)

def guard_frame(source: Image.Image, frame: str) -> tuple[Image.Image, dict]:
    im = source.convert("RGBA")
    w, h = im.size
    if w not in (482, 483) or h != 326:
        raise ValueError(f"MP40_PIXEL_FRAME_GUARD_RED unexpected real sheet cell {frame}: {w}x{h}")
    rgba = im.load()
    alpha = im.getchannel("A")
    px = alpha.load()
    removed = opened = 0

    if frame in RELOADS:
        # Small disconnected metal shards on the sheet's LEFT panel boundary.
        # Do not flood/delete into the actual arms/magazine, which enter x>=32.
        visited = bytearray(w * h)
        for yy in range(190, h):
            for xx in range(32):
                idx = yy * w + xx
                if visited[idx] or px[xx, yy] <= 40:
                    continue
                q = deque([(xx, yy)])
                visited[idx] = 1
                comp = []
                max_x = xx
                while q:
                    x, y = q.pop()
                    comp.append((x, y))
                    max_x = max(max_x, x)
                    for nx, ny in ((x-1,y), (x+1,y), (x,y-1), (x,y+1)):
                        if not (0 <= nx < 32 and 190 <= ny < h):
                            continue
                        ni = ny * w + nx
                        if visited[ni] or px[nx, ny] <= 40:
                            continue
                        visited[ni] = 1
                        q.append((nx, ny))
                if max_x < 20 and 10 < len(comp) < 1600:
                    for x,y in comp:
                        if px[x,y]:
                            removed += 1
                        px[x,y] = 0

        # Explicit frame-specific neighboring pose slivers. These fixed source
        # coordinates are validated on the actual 1448x1086 owner PNG.
        if frame in ("reload_03", "reload_04"):
            top = 210 if frame == "reload_03" else 218
            end = 317
            right = 26 if frame == "reload_03" else 28
            for y in range(top, end):
                for x in range(right):
                    if px[x,y]:
                        removed += 1
                    px[x,y] = 0

        # A copied 3x3 atlas caption rectangle sits below the gloves at
        # x155..339, y315..325 in reload frames (never firearm geometry).
        for y in range(315, h):
            for x in range(155, 340):
                if px[x,y]:
                    removed += 1
                px[x,y] = 0

    if frame == "ads_idle":
        # The rear-facing FRONT sight is a ring, not an opaque round plug.
        # Repair-alpha incorrectly painted the ring's interior black.
        # Clear only the measured dark aperture, keeping the original front
        # post + shiny metal ring intact. Never stretch or move the optic.
        center_x, center_y = 242.0, 136.0
        for y in range(123, 149):
            for x in range(229, 256):
                if ((x - center_x) / 10.0) ** 2 + ((y - center_y) / 11.0) ** 2 >= 1.0:
                    continue
                if abs(x - center_x) <= 2 and y >= 135:
                    continue
                r, g, b, _ = rgba[x,y]
                if r + g + b < 174 and px[x,y] > 0:
                    px[x,y] = 0
                    opened += 1
    im.putalpha(alpha)
    return im, {"edge_bleed_removed": removed, "sight_aperture_reopened": opened}

def gate(root: Path) -> None:
    frame_root = root / "mobile/mp40_pixel/frames"
    assert frame_root.is_dir(), "MP40_PIXEL_FRAME_GUARD_RED missing original-frame directory"
    report = {}
    for frame in FRAMES:
        png = frame_root / (frame + ".png")
        if not png.is_file():
            raise RuntimeError("MP40_PIXEL_FRAME_GUARD_RED missing " + str(png))
        original = Image.open(png).convert("RGBA")
        cleaned, stats = guard_frame(original, frame)
        if list(original.getdata(0)) != list(cleaned.getdata(0)):
            raise AssertionError("MP40_PIXEL_FRAME_GUARD_RED source RGB was altered")
        if sum(v > 40 for v in cleaned.getchannel("A").getdata()) < 3500:
            raise AssertionError("MP40_PIXEL_FRAME_GUARD_RED actual weapon erased: " + frame)
        if frame in RELOADS:
            a = cleaned.getchannel("A")
            if any(a.crop((155, 315, 340, 326)).getdata()):
                raise AssertionError("MP40_PIXEL_FRAME_GUARD_RED sheet footer visible: " + frame)
            if frame == "reload_03" and any(a.crop((0, 225, 26, 315)).getdata()):
                raise AssertionError("MP40_PIXEL_FRAME_GUARD_RED left reload_03 stock fragment")
            if frame == "reload_04" and any(a.crop((0, 240, 28, 315)).getdata()):
                raise AssertionError("MP40_PIXEL_FRAME_GUARD_RED left reload_04 stock fragment")
        if frame == "ads_idle":
            a = cleaned.getchannel("A")
            aperture = sum(a.getpixel((x,y)) < 10 for y in range(126,145) for x in range(234,250)
                          if abs(x-242) > 3)
            if aperture < 50 or a.getpixel((242,138)) < 80:
                raise AssertionError("MP40_PIXEL_FRAME_GUARD_RED hole filled / real front post lost")
        cleaned.save(png, format="PNG", optimize=True)
        report[frame] = stats
        print("MP40_PIXEL_FRAME_GUARD", frame, stats)
    output = root / "mobile/mp40_pixel/frame_guard_report.json"
    output.write_text(json.dumps(report, indent=2) + "\n")
    print("MP40_PIXEL_V52_OPTICAL_RELOAD_GREEN aperture_open=true reload_frames=4 preserved_weapons=9")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: guard_mp40_pixel_frames.py <assembled_godot_root>")
    gate(Path(sys.argv[1]))
