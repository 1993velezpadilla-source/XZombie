#!/usr/bin/env python3
"""Fail-closed V8 source pack checks before Godot import and Android export.
Real animation binding and MP40 regression run in Godot separately.
"""
from pathlib import Path
import json
import sys

root = Path(sys.argv[1])
manifest = json.loads((Path(__file__).parent / "weapon_library/source_library_manifest.json").read_text())
assert manifest["asset_source"]["commit"] == "5c8093db6c5eab64d653f715813f1d70915d393f"
assert set(w["id"] for w in manifest["weapons"]) == {"colt", "thompson", "kar98k", "mg42"}
player_scene = (root / "player/player.tscn").read_text()
manager = (root / "common/managers/weapons_manager.gd").read_text()
assert 'NodePath("MP40Source"), NodePath("ColtSource"), NodePath("ThompsonSource"), NodePath("Kar98kSource")' in player_scene
assert 'current_weapon_index = 5' in manager and 'weapons_array[5].name == "MP40Source"' in manager
assert (root / "mobile/mp40_weapon.gd").is_file()

# MP40 V6 is the real source-viewmodel UX authority, not demo Bukkbeek.
# Fail immediately when a newly generated source gun inherits its generic
# base StandardAimPosition/FocusedAimPosition instead of true MP40 poses.
def inherited_marker(scene: str, name: str) -> str:
    lines = scene.splitlines()
    for i, line in enumerate(lines):
        if line.startswith('[node name="' + name + '"'):
            for entry in lines[i+1:i+6]:
                if entry.startswith("transform = Transform3D("):
                    return entry.split(" = ", 1)[1]
    raise AssertionError("Source scene missing authoritative " + name)

mp40_scn = (root / "mobile/mp40.tscn").read_text()
for weapon_id in ["colt", "thompson", "kar98k"]:
    actual_scn = (root / "mobile" / (weapon_id + ".tscn")).read_text()
    for marker_name in ["StandardAimPosition", "FocusedAimPosition"]:
        assert inherited_marker(actual_scn, marker_name) == inherited_marker(mp40_scn, marker_name), (
          f"{weapon_id} reintroduced generic Bukkbeek {marker_name}: MP40 V6 baseline lost"
        )
    print("XZIEL_V14_MP40_POSE_AUTHORITY_GREEN "+weapon_id)
assert (root / "mobile/source_weapon.gd").is_file()
for w in manifest["weapons"]:
    ident = w["id"]
    folder = root / "mobile/weapon_sources" / ident
    profile = json.loads((folder / "profile.json").read_text())
    assert profile["id"] == ident
    assert profile["source"] == "Aether WaW (not BO3)"
    assert (folder / "viewmodel.glb").stat().st_size > 100_000
    assert (folder / "viewhands.glb").stat().st_size > 1_000_000
    for part in ("gun", "hands"):
        for key in ("idle", "fire", "reload"):
            clip = profile["roles"][part][key]
            assert clip in w["animations"][part], f"Missing exact source PSA {ident}:{part}:{key}"
    if ident == "mg42":
        assert not profile["has_original_fire_audio"], "No invented MG42 firing sound allowed"
        assert not (root / "mobile/mg42.tscn").exists()
        print("XZIEL_MULTIWEAPON_AUDIO_PENDING mg42; staged source models, no playable substitute")
    else:
        assert profile["has_original_fire_audio"]
        assert (folder / "fire.wav").stat().st_size > 10000
        script = (root / "mobile" / (ident + ".tscn")).read_text()
        assert 'res://mobile/source_weapon.gd' in script
        assert 'SourceHands' in script and 'SourceGun' in script
        print("XZIEL_MULTIWEAPON_FILES_GREEN id=" + ident)
print("XZIEL_MULTIWEAPON_SOURCE_PRECHECK_GREEN")
