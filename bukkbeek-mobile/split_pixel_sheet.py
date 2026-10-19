from PIL import Image
from pathlib import Path
import json
import sys
from collections import deque

frames = ("idle_hip_01", "ads_idle", "fire_hip_01", "ads_fire_01",
          "sprint_01", "reload_01", "reload_02", "reload_03", "reload_04")

def clean_ads_orphans(tile, name):
    """Erase only DETACHED sprite-sheet leftovers at the outer ADS edges.

    Prior source grid crops leave two tiny pieces at the left/right, visible
    against the sky in the owner's on-device screenshot. Never draw a rectangle
    over the central sights, receiver, or hands, and never blur the source RGB.
    Connected components touching the central 60% are always preserved.
    """
    w, h = tile.size
    a = tile.getchannel("A")
    pix = a.load()
    visited = bytearray(w * h)
    removed = 0
    for y in range(h):
        for x in range(w):
            index = y * w + x
            if visited[index] or pix[x, y] < 48:
                continue
            visited[index] = 1
            q = deque([(x, y)])
            component = []
            min_x, max_x = x, x
            touches_core = False
            while q:
                px, py = q.pop()
                component.append((px, py))
                min_x = min(min_x, px)
                max_x = max(max_x, px)
                if w * 0.20 <= px <= w * 0.80:
                    touches_core = True
                for ny in range(max(0, py - 1), min(h, py + 2)):
                    for nx in range(max(0, px - 1), min(w, px + 2)):
                        ni = ny * w + nx
                        if not visited[ni] and pix[nx, ny] >= 48:
                            visited[ni] = 1
                            q.append((nx, ny))
            outer_edge = max_x < int(w * .20) or min_x > int(w * .80)
            if outer_edge and not touches_core and len(component) < int(w * h * .04):
                for px, py in component:
                    pix[px, py] = 0
                removed += len(component)
    tile.putalpha(a)
    print(f"MP40_PIXEL_ADS_EDGE_CLEAN frame={name} removed_orphan_px={removed}")
    return tile

def split(sheet_path, project_root):
    sheet = Image.open(sheet_path).convert("RGBA")
    if sheet.size != (1448, 1086):
        raise ValueError("Expected original 1448x1086 sheet, not tiny atlas")
    out = Path(project_root) / "mobile/mp40_pixel/frames"
    out.mkdir(parents=True, exist_ok=True)
    for n, label in enumerate(frames):
        col, row = n % 3, n // 3
        x0 = round(col * 1448 / 3)
        x1 = round((col + 1) * 1448 / 3)
        tile = sheet.crop((x0, row * 362, x1, row * 362 + 326))
        if label in ("ads_idle", "ads_fire_01"):
            tile = clean_ads_orphans(tile, label)
        alpha = tile.getchannel("A")
        if alpha.getbbox() is None:
            raise ValueError("Empty sprite: " + label)
        if alpha.getextrema()[0] >= 250:
            raise ValueError("Opaque full-sheet backdrop: true transparent PNG required, source=" + label)
        if sum(p > 40 for p in alpha.getdata()) < 3500:
            raise ValueError("Source silhouette has too few visible pixels: " + label)
        tile.save(out / (label + ".png"))
    (out.parent / "hires_manifest.json").write_text(
        json.dumps({"real_highres": True, "source": Path(sheet_path).name,
                    "ads_anchors": [[242, 126], [245, 114]],
                    "edge_orphan_clean": True, "screen_bottom_grounding": True}))
    print("MP40_PIXEL_HIRES_GREEN source=1448x1086 nine_sprites=true")

if __name__ == "__main__":
    split(sys.argv[1], sys.argv[2])
