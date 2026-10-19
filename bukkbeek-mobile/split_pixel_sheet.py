from PIL import Image
from pathlib import Path
import json
import sys

frames = ("idle_hip_01", "ads_idle", "fire_hip_01", "ads_fire_01",
          "sprint_01", "reload_01", "reload_02", "reload_03", "reload_04")

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
                    "ads_anchors": [[242, 126], [245, 114]]}))
    print("MP40_PIXEL_HIRES_GREEN source=1448x1086 nine_sprites=true")

if __name__ == "__main__":
    split(sys.argv[1], sys.argv[2])
