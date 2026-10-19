#!/usr/bin/env python3
"""Audit the four WaW/Project Aether SMGs from ORIGINAL GLBs.

This is a fail-closed SOURCE gate, not a fabricated gameplay/ADS approval.
PPSh and Type 100 are audited in the ephemeral Actions workspace; they are
NOT inserted into the existing game until their textures, FPS iron-sight
witnesses and real runtime/phone frames have separately passed.

Uses the actual source mesh/animation metadata, not the unverified ADS XYZ
numbers previously discussed in chat. No MP40 project/source code is changed.
"""
from __future__ import annotations

import hashlib
import json
import struct
import sys
import time
import urllib.request
from pathlib import Path

SOURCE_REPO = "1993velezpadilla-source/config-old-3"
WAW_COMMIT = "5c8093db6c5eab64d653f715813f1d70915d393f"
MP40_COMMIT = "498891d9226ed00357fb0d6bc5758a5d68d8fedb"
ASSET_ROOT = "xogot/assets/weapons"
SOURCE_FIRE_SHA = {
    "mp40": "7ad21d2ac3281372f9e91ecae8e424f27dea308f",
    "thompson": "93d6a2d346830cc17693125eb00ff788d83a1410",
    "ppsh": "9cfd7554f1fd2c4dfbf00a4e9bdcfaf672efb0e5",
    "type100": "f49bee315b6ddb14d6fb812134904132f1f53081",
}
# SHA-1 values are Git blob object IDs obtained for the ORIGINAL pinned files.
# No guessed V5/V6 transforms appear here.
PINNED = {
    "mp40": {
        "commit": MP40_COMMIT,
        "gun": ("aether_waw_real/mp40/viewmodel.glb",
                "b14d2cc66f8601555119a7737d87acc8ed349508"),
        "hands": ("aether_waw_hands/t4_marine/mp40/viewhands.glb",
                  "fe1b0735cd4b768ae3a6bfeb731fc61050cdb1f2"),
    },
    "thompson": {
        "commit": WAW_COMMIT,
        "gun": ("aether_waw_real/thompson/viewmodel.glb",
                "2dda02bb523e98519a7bf2682d86f03bd62a9488"),
        "hands": ("aether_waw_hands/t4_marine/thompson/viewhands.glb",
                  "fc838513b3f2e347e81766c79fb847f6bbf237b9"),
    },
    "ppsh": {
        "commit": WAW_COMMIT,
        "gun": ("aether_waw_real/ppsh/viewmodel.glb",
                "87e9662b1ec9ffe91d32a721eae319bd98a9e90c"),
        "hands": ("aether_waw_hands/t4_marine/ppsh/viewhands.glb",
                  "49893af20e66f41402b268a11d6d73fcaeb3547b"),
    },
    "type100": {
        "commit": WAW_COMMIT,
        "gun": ("aether_waw_real/type100/viewmodel.glb",
                "78b33650c481996ec67745fbbc0213b001666f84"),
        "hands": ("aether_waw_hands/t4_marine/type100/viewhands.glb",
                  "d55fdabe132857e5b6cf870ec8ba926899c30531"),
    },
}


def blob_sha(payload: bytes) -> str:
    return hashlib.sha1(
        ("blob %d\0" % len(payload)).encode("ascii") + payload
    ).hexdigest()


def original_glb(workspace: Path, weapon: str, part: str) -> tuple[bytes, str]:
    entry = PINNED[weapon]
    rel, expected = entry[part]
    # First reuse precisely the already staged, hash-checked game assets.
    place = (workspace / "mobile" /
             ("mp40_source" if weapon == "mp40" else
              "weapon_sources/" + weapon) /
             ("viewmodel.glb" if part == "gun" else "viewhands.glb"))
    if place.is_file():
        raw = place.read_bytes()
        if blob_sha(raw) == expected:
            return raw, str(place)
    # Unstaged original PPSh/Type100 are pulled only for transient auditing.
    path = ASSET_ROOT + "/" + rel
    url = (
        "https://raw.githubusercontent.com/" + SOURCE_REPO + "/" +
        entry["commit"] + "/" + path
    )
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "XZIEL-SMG-Class-Gate/1"})
            with urllib.request.urlopen(req, timeout=45) as response:
                raw = response.read()
            if blob_sha(raw) != expected:
                raise ValueError("Original source hash mismatch: " + weapon + "/" + part)
            if len(raw) < 100_000:
                raise ValueError("Truncated original GLB: " + weapon + "/" + part)
            place.parent.mkdir(parents=True, exist_ok=True)
            place.write_bytes(raw)
            return raw, str(place)
        except (OSError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(1 + attempt)
    raise AssertionError("Unexpected asset-fetch path")


def original_fire_audio(workspace: Path, weapon: str) -> dict:
    """Require the actual WaW fire sample before even marking source ready."""
    expected = SOURCE_FIRE_SHA[weapon]
    place = (workspace / "mobile" /
             ("mp40_source" if weapon == "mp40" else
              "weapon_sources/" + weapon) / "fire.wav")
    if place.is_file():
        audio = place.read_bytes()
        if blob_sha(audio) == expected:
            return {"git_blob_sha": expected, "bytes": len(audio)}
    url = (
        "https://raw.githubusercontent.com/" + SOURCE_REPO + "/" +
        PINNED[weapon]["commit"] +
        "/xogot/assets/audio/weapons/mapmod/" + weapon + "/fire.wav"
    )
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "XZIEL-SMG-Class-Gate/1"})
            with urllib.request.urlopen(req, timeout=45) as response:
                audio = response.read()
            if blob_sha(audio) != expected:
                raise ValueError("Original firing sound hash mismatch for " + weapon)
            if not audio.startswith(b"RIFF") or audio[8:12] != b"WAVE":
                raise ValueError("Invalid original firing WAV " + weapon)
            place.parent.mkdir(parents=True, exist_ok=True)
            place.write_bytes(audio)
            return {"git_blob_sha": expected, "bytes": len(audio)}
        except (OSError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(1 + attempt)
    raise AssertionError("Unexpected original-audio fetch path")


def unpack_glb(data: bytes) -> dict:
    if len(data) < 20:
        raise ValueError("GLB too small")
    magic, version, size = struct.unpack_from("<4sII", data)
    if magic != b"glTF" or version != 2 or size != len(data):
        raise ValueError("Not a complete original glTF 2.0 binary")
    offset = 12
    while offset + 8 <= len(data):
        n, typ = struct.unpack_from("<I4s", data, offset)
        offset += 8
        if offset + n > len(data):
            raise ValueError("Malformed GLB chunk")
        payload = data[offset:offset + n]
        if typ == b"JSON":
            return json.loads(payload.decode("utf-8").rstrip("\0 \t\r\n"))
        offset += n
    raise ValueError("Original GLB JSON chunk missing")


def inspect_gltf(document: dict) -> dict:
    nodes = document.get("nodes", [])
    node_names = {n.get("name", "") for n in nodes}
    animations = [a.get("name", "") for a in document.get("animations", [])]
    roles = {
        role: [s for s in animations if role in s.lower()]
        for role in ("idle", "fire", "reload")
    }
    for role, clips in roles.items():
        if not clips:
            raise ValueError("Original weapon missing PSA " + role)
    anchors = {}
    for n in nodes:
        name = n.get("name", "")
        if name in {"j_gun", "tag_weapon", "tag_iron_sights", "tag_flash",
                    "j_clip", "j_bolt"}:
            # LOCAL GLB node pose, NOT a Call of Duty ADS camera transform.
            anchors[name] = {
                "translation": n.get("translation", [0, 0, 0]),
                "rotation_xyzw": n.get("rotation", [0, 0, 0, 1]),
                "matrix": n.get("matrix"),
            }
    return {
        "animation_count": len(animations),
        "role_clips": roles,
        "node_count": len(nodes),
        "materials": [m.get("name", "") for m in document.get("materials", [])],
        "anchors_local_glb_only": anchors,
        "all_animations": animations,
        "meshes": len(document.get("meshes", [])),
    }


def run(workspace: Path) -> None:
    report = {
        "source": SOURCE_REPO,
        "status": "SOURCE_AUDIT_ONLY_NOT_GAMEPLAY_CERTIFIED",
        "conversion_authority": "UNVERIFIED; no class-wide ADS or camera offsets assigned",
        "weapons": {},
    }
    for weapon in PINNED:
        row = {}
        for part in ("gun", "hands"):
            raw, place = original_glb(workspace, weapon, part)
            meta = inspect_gltf(unpack_glb(raw))
            if part == "gun" and "j_gun" not in meta["anchors_local_glb_only"]:
                raise ValueError("Original " + weapon + " lacks j_gun skeleton anchor")
            if part == "hands" and "tag_weapon" not in meta["anchors_local_glb_only"]:
                raise ValueError("Original " + weapon + " lacks tag_weapon hand socket")
            row[part] = {
                "git_blob_sha": blob_sha(raw),
                "bytes": len(raw),
                "staged_path": place,
                **meta,
            }
        row["source_fire_audio"] = original_fire_audio(workspace, weapon)
        report["weapons"][weapon] = row
        print("XZIEL_SMG_SOURCE_GREEN id=" + weapon +
              " gunPSA=" + str(row["gun"]["animation_count"]) +
              " handsPSA=" + str(row["hands"]["animation_count"]) +
              " originalGunMaterial=" + ",".join(row["gun"]["materials"]))
    if len(report["weapons"]) != 4:
        raise AssertionError("All four WaW SMGs required")
    out_dir = workspace / "smg_gauntlet"
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "source_audit.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n"
    )
    lines = [
        "# World at War SMG — original-source comparison",
        "",
        "| SMG | Original gun PSA | Original hands PSA | Original fire WAV | Gun materials | Status |",
        "| --- | ---: | ---: | --- | --- | --- |",
    ]
    for name, parts in report["weapons"].items():
        lines.append("| " + name + " | " + str(parts["gun"]["animation_count"]) +
                     " | " + str(parts["hands"]["animation_count"]) +
                     " | source SHA verified | " + ", ".join(parts["gun"]["materials"]) +
                     " | GLB + animations verified |")
    lines += [
        "",
        "**NOT VERIFIED:** The numerical Aether ADS camera X/Y/Z values from the",
        "previous chart are not proven original source camera metadata.",
        "Do not copy them into Godot as if they were verified poses.",
        "",
        "**Next gameplay gate:** Verify original textures and physical front/rear",
        "sight vertices for PPSh-41 and Type 100, then render real HIP/ADS frames.",
        "The approved MP40 remains byte-for-byte untouched.",
        "",
    ]
    (out_dir / "comparison.md").write_text("\n".join(lines))
    print("XZIEL_SMG_CLASS_SOURCE_AUDIT_GREEN count=4")
    print("XZIEL_SMG_GAMEPLAY_STATUS RED_UNTIL_VISUAL_GAUNTLET")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: audit_smg_source_class.py <assembled-godot-root>")
    run(Path(sys.argv[1]).resolve())
