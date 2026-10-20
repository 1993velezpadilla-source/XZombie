#!/usr/bin/env python3
"""Pin actual MP40 / original animated marine hands as *study only*.

This determines which source clips and meshes exist before doing a new
2.5D gothic nun sprite render. It does NOT greenlight marine-game mesh or
textures for inclusion in a public Android APK.
"""
from __future__ import annotations
import json
from pathlib import Path
import struct
import sys

BASE = Path(__file__).resolve().parents[1]
SOURCE = BASE / "build" / "source-audit-only"
MAGIC = 0x46546C67


def read_glb(path: Path) -> dict:
    blob = path.read_bytes()
    if len(blob) < 20:
        raise ValueError(f"truncated GLB: {path}")
    magic, version, declared = struct.unpack_from("<III", blob, 0)
    if magic != MAGIC or version != 2 or declared != len(blob):
        raise ValueError(f"bad glTF 2.0 header: {path}")
    pos = 12
    chunks: list[tuple[int, bytes]] = []
    while pos < len(blob):
        length, ctype = struct.unpack_from("<II", blob, pos)
        pos += 8
        chunks.append((ctype, blob[pos:pos + length]))
        pos += length
    if pos != len(blob) or not chunks or chunks[0][0] != 0x4E4F534A:
        raise ValueError(f"malformed JSON GLB chunk: {path}")
    return json.loads(chunks[0][1].rstrip(b" \x00\t\r\n"))


def main():
    files = {}
    for name in ("viewmodel.glb", "viewhands.glb"):
        doc = read_glb(SOURCE / name)
        bones = [node.get("name", "") for node in doc.get("nodes", [])]
        animations = [anim.get("name", "") for anim in doc.get("animations", [])]
        files[name] = {
            "nodes": len(bones),
            "meshes": len(doc.get("meshes", [])),
            "skins": len(doc.get("skins", [])),
            "animations": animations,
            "animation_count": len(animations),
            "joint_count": sum(len(s.get("joints", [])) for s in doc.get("skins", [])),
            "interesting_nodes": [x for x in bones if
                any(key in x.lower() for key in ("tag", "clip", "mag", "bolt", "wrist", "hand"))][:120],
            "materials": len(doc.get("materials", [])),
        }
        assert files[name]["meshes"] > 0, f"no visual mesh in {name}"
        print("MP40_SOURCE_GLTF", name, "animations", animations,
              "mesh_count", files[name]["meshes"])
    weapon = files["viewmodel.glb"]
    hands = files["viewhands.glb"]
    if weapon["animation_count"] < 1:
        raise ValueError("real MP40 source does not contain weapon action")
    if hands["animation_count"] < 4 or hands["joint_count"] < 40:
        raise ValueError("marine hands reference is not a proper animated rig")
    report = {
        "status": "REFERENCE_ONLY_NOT_SHIPPABLE_NOT_ANIMATED_IN_IGLESIA",
        "purpose": "Source-accurate MP40 optics, mechanical pose and animation timing reference for new gothic nun viewmodel artwork",
        "rights": "Treat existing game-model rights as unverified. Do not package original GLBs or textures into Android APK.",
        "separate_nun_hands_required": True,
        "hip_ads_hand_alignment": "requires visual comparison; math-only GREEN prohibited",
        "files": files,
    }
    out = BASE / "build" / "mp40-source-authority.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("MP40_SOURCE_AUDIT_GREEN rig evidence collected; ART_MATCH_STILL_RED; file=", out)


if __name__ == "__main__":
    main()
