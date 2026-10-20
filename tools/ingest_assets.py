#!/usr/bin/env python3
"""Fetch ORIGINAL owner assets into a new clean Godot project; never re-create their artwork.
Public repositories only, pinned Git blob SHAs; no credentials, no Virin/Quake runtime.
Large GLBs intentionally opt-in until mobile LOD gate passes.
"""
from __future__ import annotations
import argparse
import hashlib
from io import BytesIO
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "imported"
ZOMBIE = "https://raw.githubusercontent.com/1993velezpadilla-source"
CHURCH_REF = "feature/sanctum-ash-tripo-furniture-swap-20261020"
BUTTON_REF = "0119c5b0f9109c4c88dbdd4173a9a2ba523abc3d"
WEAPON_REF = "experiment/nun-universal-bone2d-hands-v1-20261019"

BUTTON_SHAS = {
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
    "weapon_swap.png": "b297eae9f3cc108d600333c3402d71987c986421"
}
MP40_SHEET_SHA = "ec99d9508409ff9e16afc481c919ef1fd3ca36be"
MESHES = {
    "altar.glb": "30516ffc82687374793e555fbe66f6f4b325e206",
    "bench.glb": "12fff5499483ce023803f4460e0b52190d2799be",
    "church_final_architecture.glb": "6a6578cecd24e13e87a4594a46ab0b55e6d8fa9c"
}
WALL = {
    "stone_wall_diff_4k.jpg": "77d080a53db66d15a5cbde6fb103700ea333b6a6",
    "stone_wall_nor_gl_4k.jpg": "b6aac7fe11a8131b70543a4736d7b1b1af87fa9b",
    "stone_wall_rough_4k.jpg": "111801b34155b3733a8f41f179eda54a5019c6a3",
}

def git_blob_sha(data: bytes) -> str:
    return hashlib.sha1(f"blob {len(data)}".encode() + bytes([0]) + data).hexdigest()

def fetch(repo: str, ref: str, remote: str, local: Path, sha: str) -> bytes:
    if local.is_file() and git_blob_sha(local.read_bytes()) == sha:
        print("CACHED VERIFIED", local.relative_to(ROOT))
        return local.read_bytes()
    url = f"{ZOMBIE}/{repo}/{ref}/{quote(remote, safe='/')}"
    req = Request(url, headers={"User-Agent": "IglesiaAssetProvenance/1.0"})
    with urlopen(req, timeout=180) as r:
        data = r.read()
    actual = git_blob_sha(data)
    if actual != sha:
        raise ValueError(f"FAIL provenance {remote}: expected {sha}, got {actual}")
    local.parent.mkdir(parents=True, exist_ok=True)
    local.write_bytes(data)
    print("VERIFIED", local.relative_to(ROOT), len(data), "bytes")
    return data

def split_mp40(source: bytes) -> None:
    sheet = Image.open(BytesIO(source)).convert("RGBA")
    if sheet.size != (1448, 1086):
        raise ValueError(f"MP40 must be full quality 1448x1086, got {sheet.size}")
    names = ["idle_hip_01","ads_idle","fire_hip_01","ads_fire_01",
             "sprint_01","reload_01","reload_02","reload_03","reload_04"]
    target = OUT / "mp40"
    target.mkdir(parents=True, exist_ok=True)
    for n, name in enumerate(names):
        col, row = n % 3, n // 3
        tile = sheet.crop((round(col * 1448 / 3), row*362,
                           round((col+1)*1448/3), row*362+326))
        if tile.getchannel("A").getbbox() is None:
            raise ValueError(f"transparent frame is empty: {name}")
        if tile.getchannel("A").getextrema()[0] >= 250:
            raise ValueError(f"frame has opaque background: {name}")
        tile.save(target / f"{name}.png", optimize=True)
        print("FRAME", name, tile.size)

def main() -> None:
    p = argparse.ArgumentParser(description="Verified owner-asset import for Iglesia")
    p.add_argument("--with-hero-models", action="store_true", help="Huge Tripo GLB test only; do not ship before mobile LOD")
    p.add_argument("--full-textures", action="store_true", help="Also import 4K normal+roughness originals")
    args = p.parse_args()
    btn = "assets/xziel/official_touch_skins_v1/"
    for name, sha in BUTTON_SHAS.items():
        fetch("config-old-3", BUTTON_REF, btn+name, OUT/"buttons"/name, sha)
    remote = "bukkbeek-mobile/pixel_assets/WWII MP40 Pixel Art Sprite Sheet.png"
    data = fetch("XZombie", WEAPON_REF, remote, OUT/"mp40"/"source_sheet.png", MP40_SHEET_SHA)
    split_mp40(data)
    for name, sha in WALL.items():
        if name != "stone_wall_diff_4k.jpg" and not args.full_textures:
            continue
        path = "xogot/assets/materials/church/stone_wall_4k/" + name
        fetch("config-old-3", CHURCH_REF, path, OUT/name, sha)
    if args.with_hero_models:
        for name, sha in MESHES.items():
            path = "xogot/assets/environment/church/" + name
            fetch("config-old-3", CHURCH_REF, path, OUT/name, sha)
        print("WARNING: heavy original GLBs present; LOD/mobile FPS NOT validated")
    print("ASSET_INGEST_GREEN: verified inputs only (not an Android performance claim)")

if __name__ == "__main__":
    main()
