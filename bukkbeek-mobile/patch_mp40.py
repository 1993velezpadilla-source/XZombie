#!/usr/bin/env python3
"""Add REAL source MP40 with WaW PSA hands to the already working Bukkbeek game.

Build-only overlay, never create a new Godot project. It is intentionally
idempotent and refuses to replace any existing weapon/HUD files.
"""
from pathlib import Path
import sys

source = Path(sys.argv[1]).resolve()
mp40 = source / "mobile/mp40_source"
expected = {
    "viewmodel.glb": (501256, "b14d2cc66f8601555119a7737d87acc8ed349508"),
    "viewhands.glb": (1437940, "fe1b0735cd4b768ae3a6bfeb731fc61050cdb1f2"),
    "weapon_mp40_c.png": (154396, "1e0b3090a85a01b729c7708ac7adfbf0aa535215"),
    "weapon_mp40_n.png": (302004, "2374f2b0743b0a541ab1abfafc7951647d0cf7dc"),
    "_weapon_mp40_mp_s-rgb_weapon__08433bb1.png": (326591, "578d21aabd46112948e27865a1374bab277eb3df"),
    "viewmodel_usa_marine_c.png": (2176739, "91d95e6b711258c048768234dae9e6e71c86952d"),
    "viewmodel_usa_marine_n.png": (2413151, "bc1cd8e91a18be04309aea0f9ee8e7376940f903"),
    "viewmodel_usa_marine_specular.png": (557400, "c024c0eb95aec22614aa5249f30a7eba6b7cdf9c"),
    "fire.wav": (102380, "7ad21d2ac3281372f9e91ecae8e424f27dea308f"),
}
import hashlib
for filename, (length, git_sha) in expected.items():
    blob = (mp40 / filename).read_bytes()
    actual = hashlib.sha1(("blob %d\\0" % len(blob)).encode()+blob).hexdigest()
    # Code in this script must contain a literal null byte in the Git hash prefix.
    actual = hashlib.sha1(("blob %d" % len(blob)).encode()+bytes([0])+blob).hexdigest()
    assert len(blob) == length and actual == git_sha, f"ORIGINAL_MP40_SOURCE_RED {filename}"
    if filename.endswith(".glb"):
        assert blob[:4] == b"glTF", f"not an authentic GLB {filename}"
    elif filename.endswith(".png"):
        assert blob[:8] == b"\\x89PNG\\r\\n\\x1a\\n", f"not a PNG {filename}"
print("ORIGINAL_MP40_GIT_BLOBS_GREEN: 9/9 original source assets exact")

player = source / "player/player.tscn"
content = player.read_text()
ext_anchor = '[ext_resource type="PackedScene" uid="uid://c5cmenins5u2w" path="res://weapons/knife.tscn" id="8_yllr7"]'
ext_add = '[ext_resource type="PackedScene" path="res://weapons/mp40.tscn" id="mp40_real_source"]'
assert content.count(ext_anchor) == 1, "Bukkbeek weapon scene upstream changed"
content = content.replace(ext_anchor, ext_anchor + "\\n" + ext_add, 1)
old_weapons = 'weapons_array = [NodePath("Knife"), NodePath("Pistol"), NodePath("AssualtRifle"), NodePath("AssualtBurstRifle"), NodePath("LMG")]'
new_weapons = old_weapons[:-1] + ', NodePath("MP40")]'
assert content.count(old_weapons) == 1, "Bukkbeek source list changed"
content = content.replace(old_weapons, new_weapons, 1)
assert content.count('[node name="LMG" parent="WeaponsManager"') == 1
content += '\\n[node name="MP40" parent="WeaponsManager" instance=ExtResource("mp40_real_source")]\\n'
player.write_text(content)

weapon_scene = """[gd_scene load_steps=8 format=3]

[ext_resource type="Script" path="res://mobile/mp40_weapon.gd" id="source_mp40_script"]
[ext_resource type="PackedScene" path="res://mobile/mp40_source/viewmodel.glb" id="source_mp40_gun"]
[ext_resource type="PackedScene" path="res://mobile/mp40_source/viewhands.glb" id="source_mp40_hands"]
[ext_resource type="AudioStream" path="res://mobile/mp40_source/fire.wav" id="source_mp40_fire"]
[ext_resource type="AudioStream" path="res://resources/sfx/weapons/reload.wav" id="stock_reload"]
[ext_resource type="AudioStream" path="res://resources/sfx/weapons/no_bullets.wav" id="stock_empty"]

[node name="MP40" type="Node3D" node_paths=PackedStringArray("fps_arms_root", "firing_sfx", "reload_sfx", "empty_mag_sfx", "muzzle_flash_position")]
script = ExtResource("source_mp40_script")
fps_arms_root = NodePath("FPSHandsRoot")
firing_sfx = NodePath("FiringSFX")
reload_sfx = NodePath("ReloadSFX")
empty_mag_sfx = NodePath("EmptyMagSFX")
muzzle_flash_position = NodePath("FPSHandsRoot/Muzzle")
firing_distance = 100.0
bullet_type = 2
damage = 165.0
cooldown = 0.112
burst_mode = true
reload_required = true
mag_capacity = 32
reload_time = 2.0
focused_aim_fov = 60.0
focused_aim_angle = 0.5
standard_aim_angle = 2.0

[node name="StandardAimPosition" type="Marker3D" parent="."]
position = Vector3(0.05, -0.05, -0.22)

[node name="FocusedAimPosition" type="Marker3D" parent="."]
position = Vector3(-0.04142, 0.0104, -0.24045)

[node name="FPSHandsRoot" type="Node3D" parent="."]

[node name="SourceHands" parent="FPSHandsRoot" instance=ExtResource("source_mp40_hands")]

[node name="SourceGun" parent="FPSHandsRoot" instance=ExtResource("source_mp40_gun")]

[node name="Muzzle" type="Marker3D" parent="FPSHandsRoot"]
position = Vector3(0, -0.1, -1)

[node name="CooldownTimer" type="Timer" parent="."]
one_shot = true

[node name="ReloadTimer" type="Timer" parent="."]
one_shot = true

[node name="FiringSFX" type="AudioStreamPlayer3D" parent="."]
stream = ExtResource("source_mp40_fire")

[node name="ReloadSFX" type="AudioStreamPlayer3D" parent="."]
stream = ExtResource("stock_reload")

[node name="EmptyMagSFX" type="AudioStreamPlayer3D" parent="."]
stream = ExtResource("stock_empty")

[node name="TestCamera" type="Camera3D" parent="."]
current = false

[node name="TestTarget" type="Node3D" parent="."]

[connection signal="timeout" from="CooldownTimer" to="." method="_on_cooldown_timer_timeout"]
[connection signal="timeout" from="ReloadTimer" to="." method="_on_reload_timer_timeout"]
"""
dest = source / "weapons/mp40.tscn"
assert not dest.exists(), "MP40 already exists in upstream; refuse overwrite"
dest.write_text(weapon_scene)
assert (source / "mobile/mp40_weapon.gd").exists(), "source MP40 GDScript adapter missing"
print("BUKKBEEK_MP40_OVERLAY_GREEN: authentic MP40 added as sixth optional gun, no stock weapon touched")
