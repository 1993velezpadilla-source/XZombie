#!/usr/bin/env python3
"""Source-locked 3 playable WaW weapons + 1 source-staged MG42. No fake assets.
Patches the existing *assembled* Bukkbeek game after V7, never resets Godot.
"""
import hashlib
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

root = Path(sys.argv[1]).resolve()
spec = json.loads((Path(__file__).parent / "weapon_library/source_library_manifest.json").read_text())
source = spec["asset_source"]
assert source["repo"] == "1993velezpadilla-source/config-old-3"
commit = source["commit"]
assert len(commit) == 40 and all(c in "0123456789abcdef" for c in commit)
source_dir = root / "mobile/weapon_sources"
source_dir.mkdir(parents=True, exist_ok=True)

ROLES = {
 "colt": {
  "hands": dict(idle="PSA_ColtIdleHandHold",fire="PSA_viewmodel_colt45_fire",
                reload="PSA_viewmodel_colt45_reload_notempty",
                reload_empty="PSA_viewmodel_colt45_reloadempty",
                equip="PSA_Colt45WAWBringOut"),
  "gun": dict(idle="PSA_Colt1911Idle",fire="PSA_viewmodel_colt45_fire",
              reload="PSA_viewmodel_colt45_reload_notempty",
              reload_empty="PSA_viewmodel_colt45_reloadempty",
              equip="PSA_Colt45WAWBringOut")
 },
 "thompson": {
  "hands": dict(idle="PSA_viewmodel_thompson_idle",fire="PSA_viewmodel_thompson_fire",
                reload="PSA_viewmodel_thompson_reload",
                reload_empty="PSA_viewmodel_thompson_reload_empty",
                equip="PSA_viewmodel_thompson_pullout"),
  "gun": dict(idle="PSA_viewmodel_thompson_idle",fire="PSA_viewmodel_thompson_fire",
              reload="PSA_viewmodel_thompson_reload",
              reload_empty="PSA_viewmodel_thompson_reload_empty",
              equip="PSA_viewmodel_thompson_pullout")
 },
 "kar98k": {
  "hands": dict(idle="PSA_viewmodel_kar98_idle",fire="PSA_viewmodel_kar98_fire",
                reload="PSA_viewmodel_kar98_reload",
                rechamber="PSA_viewmodel_kar98_rechamber",
                equip="PSA_viewmodel_kar98_pullout",fire_ads="PSA_viewmodel_kar98_fire_ads"),
  "gun": dict(idle="PSA_viewmodel_kar98_idle",fire="PSA_viewmodel_kar98_fire",
              reload="PSA_viewmodel_kar98_reload",
              rechamber="PSA_viewmodel_kar98_rechamber",
              equip="PSA_viewmodel_kar98_pullout",fire_ads="PSA_viewmodel_kar98_fire_ads")
 },
 "mg42": {
  "hands": dict(idle="PSA_MG42Idle",fire="PSA_viewmodel_mg42_fire",
                reload="PSA_viewmodel_mg42_reload",equip="PSA_MG42Equip"),
  "gun": dict(idle="PSA_MG42Idle",fire="PSA_viewmodel_mg42_fire",
              reload="PSA_viewmodel_mg42_reload",equip="PSA_MG42Equip")
 }
}
AMMO_KIND = {"pistol": 1, "smg": 2, "sniper": 6, "lmg": 5}

def download_pinned(record: dict, directory: Path) -> None:
    path = record["path"]
    dest = directory / Path(path).name
    url = "https://raw.githubusercontent.com/" + source["repo"] + "/" + commit + "/" + path
    if dest.is_file():
        blob = dest.read_bytes()
        if len(blob) == record["bytes"] and hashlib.sha1(
                ("blob %s\0" % len(blob)).encode() + blob).hexdigest() == record["sha"]:
            return
    for attempt in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent":"XZIEL-Source-Audit/1.0"}), timeout=45) as resp:
                blob = resp.read()
            actual = hashlib.sha1(("blob %s\0" % len(blob)).encode() + blob).hexdigest()
            if actual != record["sha"] or len(blob) != record["bytes"]:
                raise RuntimeError("Original source hash changed: " + path)
            dest.write_bytes(blob)
            return
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as exc:
            if attempt == 2: raise
            time.sleep(1 + attempt)
    raise RuntimeError("Could not stage " + path)

def runtime_materials(weapon: dict) -> list:
    d = weapon["id"]
    result = []
    for m in weapon["materials"]:
        row = dict(m)
        for field in ["albedo", "normal", "specular"]:
            if row.get(field):
                row[field] = f"res://mobile/weapon_sources/{d}/{Path(row[field]).name}"
        result.append(row)
    return result

def make_scene(weapon: dict) -> str:
    ident = weapon["id"]
    g = weapon["gameplay"]
    node = {"colt":"ColtSource","thompson":"ThompsonSource","kar98k":"Kar98kSource"}[ident]
    b = f"res://mobile/weapon_sources/{ident}/"
    # Stage Godot inherited source weapon + two original independent PSA GLBs.
    # No authored fake reload/empty SFX: only source-confirmed firing WAV.
    return f"""[gd_scene load_steps=6 format=3]

[ext_resource type="PackedScene" path="res://common/weapon/weapon_base.tscn" id="1_base"]
[ext_resource type="Script" path="res://mobile/source_weapon.gd" id="2_script"]
[ext_resource type="PackedScene" path="{b}viewhands.glb" id="3_hands"]
[ext_resource type="PackedScene" path="{b}viewmodel.glb" id="4_gun"]
[ext_resource type="AudioStream" path="{b}fire.wav" id="5_fire"]

[node name="{node}" node_paths=PackedStringArray("fps_arms_root", "animation_player", "firing_sfx", "reload_sfx", "empty_mag_sfx", "muzzle_flash_position") instance=ExtResource("1_base")]
script = ExtResource("2_script")
source_weapon_id = "{ident}"
fps_arms_root = NodePath("FPSHandsRoot")
animation_player = NodePath("fps_demo_arms/AnimationPlayer")
muzzle_flash_position = NodePath("FPSHandsRoot/MuzzleFlashPosition")
bullet_type = {AMMO_KIND[g["family"]]}
damage = {g["damage"]}
cooldown = {g["cooldown"]}
burst_mode = {str(g["automatic"] or g["family"]=="pistol").lower()}
mag_capacity = {g["magazine"]}
reload_time = {g["reload_time_catalog"]}
firing_distance = {g["range_m"]}
focused_aim_fov = {g["ads_fov"]}

[node name="fps_demo_arms" parent="." index="6"]
visible = false

[node name="FiringSFX" parent="SFX" index="0"]
stream = ExtResource("5_fire")
volume_db = -7.0

[node name="FPSHandsRoot" type="Node3D" parent="."]

[node name="SourceHands" parent="FPSHandsRoot" instance=ExtResource("3_hands")]

[node name="SourceGun" parent="FPSHandsRoot" instance=ExtResource("4_gun")]

[node name="MuzzleFlashPosition" type="Marker3D" parent="FPSHandsRoot"]
position = Vector3(0.0, -0.08, -0.65)

[editable path="fps_demo_arms"]
"""

active = []
for w in spec["weapons"]:
    ident = w["id"]
    assert ident in ROLES
    target = source_dir / ident
    target.mkdir(exist_ok=True)
    for f in w["source_files"]:
        download_pinned(f, target)
    # Do not stage a playable MG42 until its actual source firing clip exists.
    has_audio = w["playable_gate"] == "candidate"
    roles = ROLES[ident]
    for part in ["gun", "hands"]:
        declared = set(w["animations"][part])
        for kind, value in roles[part].items():
            assert value in declared, f"{ident} missing source {part} PSA {kind}: {value}"
    profile = {
        "id":ident, "family":w["family"],
        "source":"Aether WaW (not BO3)",
        "has_original_fire_audio":has_audio,
        "roles":roles,
        "materials":runtime_materials(w)
    }
    (target / "profile.json").write_text(json.dumps(profile, indent=2) + "\n")
    if has_audio:
        assert (target / "fire.wav").stat().st_size > 10000
        (root / f"mobile/{ident}.tscn").write_text(make_scene(w))
        active.append(ident)
    print(f"XZIEL_SOURCE_STAGE id={ident} real_hands=true real_glb=true gunPSA={len(w['animations']['gun'])} handsPSA={len(w['animations']['hands'])} authentic_fire={has_audio}")

assert active == ["colt", "thompson", "kar98k"], active
scene = root / "player/player.tscn"
s = scene.read_text()
anchor = '[node name="WeaponSubViewport" type="SubViewportContainer"'
assert s.count(anchor) == 1, "Original Bukkbeek scene changed"
extras = []
for n, ident in enumerate(active):
    name = {"colt":"ColtSource","thompson":"ThompsonSource","kar98k":"Kar98kSource"}[ident]
    ext_id = f"3{n}_{ident}"
    resource = f'[ext_resource type="PackedScene" path="res://mobile/{ident}.tscn" id="{ext_id}"]'
    assert resource not in s
    # Add external scene refs before source nodes.
    scene_ext_anchor = '[node name="Player" type="CharacterBody3D"'
    assert s.count(scene_ext_anchor) == 1
    s = s.replace(scene_ext_anchor, resource + "\n\n" + scene_ext_anchor, 1)
    extras.append(f'[node name="{name}" parent="WeaponsManager" instance=ExtResource("{ext_id}")]')
    before = 'NodePath("MP40Source")]'
    if before not in s:
        before = ', '.join([])
        raise AssertionError("MP40 weapon collection not found")
    s = s.replace(before, f'NodePath("MP40Source"), NodePath("{name}")]')
s = s.replace(anchor, "\n\n".join(extras) + "\n\n" + anchor, 1)
scene.write_text(s)

# The original MP40 is ALWAYS the tested starting gun, even with more weapons.
manager = root / "common/managers/weapons_manager.gd"
m = manager.read_text()
old = 'current_weapon_index = weapons_array.size() - 1 if OS.get_name() == "Android" and weapons_array.size() == 6 else 0'
assert m.count(old) == 1, "Android starting source MP40 selection changed"
m = m.replace(old,
 'current_weapon_index = 5 if OS.get_name() == "Android" and weapons_array.size() >= 6 and weapons_array[5].name == "MP40Source" else 0')
manager.write_text(m)
assert "MP40Source" in scene.read_text()
print("XZIEL_MULTIWEAPON_V8_STAGED: 5 Bukkbeek + source MP40 V6 + real-source Colt, Thompson, Kar98k; MG42 audio-gated")
