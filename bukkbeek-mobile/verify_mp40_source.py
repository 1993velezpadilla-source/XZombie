#!/usr/bin/env python3
"""Strict provenance gate for the ORIGINAL Project Aether/WaW MP40 proof of concept.

Copies are used only inside the ephemeral GitHub Actions game build. The source
assets are not checked into XZombie; the live 5 Bukkbeek weapons are preserved.
The reference files are recovered verbatim from an existing user project.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
import sys

SOURCE_REPOSITORY = "1993velezpadilla-source/config-old-3"
SOURCE_COMMIT = "498891d9226ed00357fb0d6bc5758a5d68d8fedb"
FILES: dict[str, tuple[str, str]] = {
    "viewmodel.glb": (
        "xogot/assets/weapons/aether_waw_real/mp40/viewmodel.glb",
        "b14d2cc66f8601555119a7737d87acc8ed349508",
    ),
    "viewhands.glb": (
        "xogot/assets/weapons/aether_waw_hands/t4_marine/mp40/viewhands.glb",
        "fe1b0735cd4b768ae3a6bfeb731fc61050cdb1f2",
    ),
    "weapon_mp40_c.png": (
        "xogot/assets/weapons/aether_waw_textures/weapon_mp40_c.png",
        "1e0b3090a85a01b729c7708ac7adfbf0aa535215",
    ),
    "weapon_mp40_n.png": (
        "xogot/assets/weapons/aether_waw_textures/weapon_mp40_n.png",
        "2374f2b0743b0a541ab1abfafc7951647d0cf7dc",
    ),
    "_weapon_mp40_mp_s-rgb_weapon__08433bb1.png": (
        "xogot/assets/weapons/aether_waw_textures/_weapon_mp40_mp_s-rgb_weapon__08433bb1.png",
        "578d21aabd46112948e27865a1374bab277eb3df",
    ),
    "viewmodel_usa_marine_c.png": (
        "xogot/assets/weapons/aether_waw_hands/t4_marine/common/textures/viewmodel_usa_marine_c.png",
        "91d95e6b711258c048768234dae9e6e71c86952d",
    ),
    "viewmodel_usa_marine_n.png": (
        "xogot/assets/weapons/aether_waw_hands/t4_marine/common/textures/viewmodel_usa_marine_n.png",
        "bc1cd8e91a18be04309aea0f9ee8e7376940f903",
    ),
    "viewmodel_usa_marine_specular.png": (
        "xogot/assets/weapons/aether_waw_hands/t4_marine/common/textures/viewmodel_usa_marine_specular.png",
        "c024c0eb95aec22614aa5249f30a7eba6b7cdf9c",
    ),
    "fire.wav": (
        "xogot/assets/audio/weapons/mapmod/mp40/fire.wav",
        "7ad21d2ac3281372f9e91ecae8e424f27dea308f",
    ),
    # Independent CC0 mechanical foley cues (NOT falsely attributed to WaW).
    # Provenance: assets/audio/cc0_horror_library/wood_metal_rubberduck/SOURCE.txt
    "metal_close_01.ogg": (
        "assets/audio/cc0_horror_library/wood_metal_rubberduck/metal_close_01.ogg",
        "a8b6479ef2d5f826051e7a2374afbaaff5c3e230",
    ),
    "metal_spring_01.ogg": (
        "assets/audio/cc0_horror_library/wood_metal_rubberduck/metal_spring_01.ogg",
        "394de5acc9c9c4caf5bac2eca38afe9d440a18a6",
    ),
    "metal_spring_02.ogg": (
        "assets/audio/cc0_horror_library/wood_metal_rubberduck/metal_spring_02.ogg",
        "bda4055d4edb47272ac417e18554c1db392221fb",
    ),
}


def source_url(name: str) -> str:
    source_path, _ = FILES[name]
    return (
        f"https://raw.githubusercontent.com/{SOURCE_REPOSITORY}/"
        f"{SOURCE_COMMIT}/{source_path}"
    )


def verify(root: Path) -> None:
    for name, (_, expected_sha) in FILES.items():
        path = root / name
        if not path.is_file():
            raise SystemExit(f"BUKKBEEK_MP40_SOURCE_RED: missing {path}")
        raw = path.read_bytes()
        actual = hashlib.sha1(f"blob {len(raw)}\0".encode() + raw).hexdigest()
        if actual != expected_sha:
            raise SystemExit(f"BUKKBEEK_MP40_SOURCE_RED: SHA mismatch {name}")
        if name.endswith(".glb"):
            if raw[:4] != b"glTF":
                raise SystemExit(f"BUKKBEEK_MP40_SOURCE_RED: not GLB {name}")
        if name.endswith(".png"):
            if raw[:8] != b"\x89PNG\r\n\x1a\n":
                raise SystemExit(f"BUKKBEEK_MP40_SOURCE_RED: not PNG {name}")
        print(f"BUKKBEEK_MP40_ASSET_GREEN {name} {len(raw)} bytes GitBlob={actual}")


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--urls":
        for name in FILES:
            print(name + " " + source_url(name))
    elif len(sys.argv) == 2:
        verify(Path(sys.argv[1]))
    else:
        raise SystemExit("usage: verify_mp40_source.py --urls | <staged-asset-directory>")
