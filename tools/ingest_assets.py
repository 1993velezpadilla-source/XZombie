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
from PIL import Image, ImageDraw
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "imported"
ZOMBIE = "https://raw.githubusercontent.com/1993velezpadilla-source"
CHURCH_REF = "feature/sanctum-ash-tripo-furniture-swap-20261020"
BUTTON_REF = "0119c5b0f9109c4c88dbdd4173a9a2ba523abc3d"
WEAPON_REF = "experiment/nun-universal-bone2d-hands-v1-20261019"
FORWARD_REF = "96f9de7eaabf96793c245f686b00f85efa3b80e3"
SOURCE_AETHER_REF = "5c8093db6c5eab64d653f715813f1d70915d393f"
MP40_RELOAD_REF = "96f9de7eaabf96793c245f686b00f85efa3b80e3"

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
FORWARD_HIP_SHA = "8c12785297f4097b4a60fd21d50efab3cd87f958"
MP40_AUDIO_SHAS = {
    "fire.wav": ("config-old-3", SOURCE_AETHER_REF, "xogot/assets/audio/weapons/mapmod/mp40/fire.wav", "7ad21d2ac3281372f9e91ecae8e424f27dea308f"),
    "mag_out.wav": ("XZombie", MP40_RELOAD_REF, "bukkbeek-mobile/audio/aether/mp40/mag_out.wav", "b67bcbaa6fdddc2615e309605517fa39e2384e23"),
    "mag_in.wav": ("XZombie", MP40_RELOAD_REF, "bukkbeek-mobile/audio/aether/mp40/mag_in.wav", "b088b8d70c5e0737e6a695097889707ca8e6ac65"),
    "charge.wav": ("XZombie", MP40_RELOAD_REF, "bukkbeek-mobile/audio/aether/mp40/charge.wav", "46e6d265b141a2f275f4caa7b3003ea055ed6e7f"),
}
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

def nun_hand_palette(image: Image.Image) -> Image.Image:
    """Conservative 2D style pass for the protagonist's dark habit/pale hands.

    Recolors only olive fabric regions below the barrel, not black gun metal.
    Source silhouettes are preserved; art QA still required for final release.
    """
    im = image.convert("RGBA")
    pix = im.load()
    w, h = im.size
    for y in range(int(h * 0.44), h):
        for x in range(w):
            r, g, b, a = pix[x, y]
            if a < 32 or g < b * 1.09 or r < b * 1.09:
                continue
            strongest = max(r, g, b)
            weakest = min(r, g, b)
            if strongest - weakest < 12 or r > g * 1.42:
                continue
            shade = (r * 0.26 + g * 0.61 + b * 0.13) / 255.0
            hand_region = y < int(h * 0.79) and (int(w * 0.13) < x < int(w * 0.40) or int(w * 0.63) < x < int(w * 0.87))
            if hand_region:
                # Nun's exposed pale skin with source pixel shading intact.
                t = 0.65 + 0.35 * shade
                pix[x, y] = (int(215 * t), int(190 * t), int(180 * t), a)
            else:
                # Charcoal-black cloth instead of military-olive fabric.
                t = 0.50 + 0.85 * shade
                pix[x, y] = (int(43 * t), int(40 * t), int(48 * t), a)
    return im


def hip_fire_overlay(image: Image.Image) -> Image.Image:
    im = image.copy()
    d = ImageDraw.Draw(im, "RGBA")
    # Small hand-drawn 2.5D muzzle bloom; gun receiver remains authentic art.
    d.polygon([(218, 102), (209, 85), (219, 87), (216, 66),
               (226, 82), (236, 69), (232, 92), (241, 87),
               (227, 104)], fill=(243, 150, 68, 235))
    d.polygon([(219, 98), (217, 84), (224, 88), (226, 81),
               (230, 96)], fill=(255, 229, 157, 240))
    return im


def split_mp40(source: bytes, forward: bytes) -> None:
    sheet = Image.open(BytesIO(source)).convert("RGBA")
    if sheet.size != (1448, 1086):
        raise ValueError(f"MP40 must be full quality 1448x1086, got {sheet.size}")
    names = ["idle_hip_01","ads_idle","fire_hip_01","ads_fire_01",
             "sprint_01","reload_01","reload_02","reload_03","reload_04"]
    front = Image.open(BytesIO(forward)).convert("RGBA")
    if front.size != (482, 326) or front.getpixel((0, 0))[3] != 0:
        raise ValueError("approved frontal HIP sprite has wrong resolution or alpha")
    frontal_nun = nun_hand_palette(front)
    target = OUT / "mp40"
    target.mkdir(parents=True, exist_ok=True)
    for n, name in enumerate(names):
        col, row = n % 3, n // 3
        tile = sheet.crop((round(col * 1448 / 3), row*362,
                           round((col+1)*1448/3), row*362+326))
        if name == "idle_hip_01":
            tile = frontal_nun.copy()
        elif name == "fire_hip_01":
            tile = hip_fire_overlay(frontal_nun)
        if tile.getchannel("A").getbbox() is None:
            raise ValueError(f"transparent frame is empty: {name}")
        if tile.getchannel("A").getextrema()[0] >= 250:
            raise ValueError(f"frame has opaque background: {name}")
        tile.save(target / f"{name}.png", optimize=True)
        print("FRAME", name, tile.size)

def main() -> None:
    p = argparse.ArgumentParser(description="Verified owner-asset import for Iglesia")
    p.add_argument("--with-hero-models", action="store_true", help="All huge Tripo GLBs (art audit only)")
    p.add_argument("--with-furniture", action="store_true", help="Include real Tripo altar and pew GLBs in mobile preview; no FPS guarantee")
    p.add_argument("--full-textures", action="store_true", help="Also import 4K normal+roughness originals")
    args = p.parse_args()
    btn = "assets/xziel/official_touch_skins_v1/"
    for name, sha in BUTTON_SHAS.items():
        fetch("config-old-3", BUTTON_REF, btn+name, OUT/"buttons"/name, sha)
    remote = "bukkbeek-mobile/pixel_assets/WWII MP40 Pixel Art Sprite Sheet.png"
    data = fetch("XZombie", WEAPON_REF, remote, OUT/"mp40"/"source_sheet.png", MP40_SHEET_SHA)
    forward_path = "bukkbeek-mobile/pixel_assets/MP40_Pixel_Forward_HIP_482x326.png"
    forward = fetch("XZombie", FORWARD_REF, forward_path,
                    OUT/"mp40"/"source_forward_hip.png", FORWARD_HIP_SHA)
    split_mp40(data, forward)
    # Real recovered MP40 fire from Project Aether plus all three reload cues
    # from the user's authenticated XZombie source package; no fake SFX.
    for output, (repo, ref, remote, sha) in MP40_AUDIO_SHAS.items():
        local = OUT / "audio" / "mp40" / output
        fetch(repo, ref, remote, local, sha)
        with wave.open(str(local), "rb") as snd:
            if snd.getnframes() < 100 or not 8000 <= snd.getframerate() <= 96000:
                raise ValueError("invalid original MP40 WAV: " + output)
            print("MP40_AUDIO_VERIFIED", output, snd.getframerate(), snd.getnframes())
    for name, sha in WALL.items():
        if name != "stone_wall_diff_4k.jpg" and not args.full_textures:
            continue
        path = "xogot/assets/materials/church/stone_wall_4k/" + name
        fetch("config-old-3", CHURCH_REF, path, OUT/name, sha)
    if args.with_hero_models or args.with_furniture:
        for name, sha in MESHES.items():
            if args.with_furniture and not args.with_hero_models and name not in ("altar.glb", "bench.glb"):
                continue
            path = "xogot/assets/environment/church/" + name
            fetch("config-old-3", CHURCH_REF, path, OUT/name, sha)
        print("WARNING: authentic Tripo models installed; LOD/mobile FPS NOT validated")
    print("ASSET_INGEST_GREEN: verified inputs only (not an Android performance claim)")

if __name__ == "__main__":
    main()
