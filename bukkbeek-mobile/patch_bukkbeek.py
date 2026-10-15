#!/usr/bin/env python3
"""Patch a pristine Bukkbeek Godot 4.6 template for Android touch only."""
import sys
from pathlib import Path
src = Path(sys.argv[1]).resolve()
inp = src / "common/managers/input_manager.gd"
txt = inp.read_text()
anchor = "func _ready() -> void:\n\tInput.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)"
replacement = """func _ready() -> void:
\tif OS.get_name() == "Android":
\t\tInput.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
\t\tvar mobile_ui: CanvasLayer = preload("res://mobile/touch_hud.gd").new()
\t\tget_parent().call_deferred("add_child", mobile_ui)
\telse:
\t\tInput.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)"""
assert txt.count(anchor)==1, "Upstream input manager changed"
txt=txt.replace(anchor,replacement,1)
txt=txt.replace('if Input.is_action_just_pressed("exit"):', 'if OS.get_name() != "Android" and Input.is_action_just_pressed("exit"):')
inp.write_text(txt)
p=src/"project.godot"
txt=p.read_text()
assert 'window/size/viewport_width=1920' in txt
txt=txt.replace('config/name="fps-demo"','config/name="Bukkbeek XZIEL Mobile Touch"')
txt=txt.replace('window/size/viewport_width=1920','window/size/viewport_width=1280')
txt=txt.replace('window/size/viewport_height=1080','window/size/viewport_height=720')
txt+='\n[rendering]\nrenderer/rendering_method.mobile="mobile"\ntextures/vram_compression/import_etc2_astc=true\n\n[input_devices]\npointing/emulate_mouse_from_touch=false\n'
p.write_text(txt)
(src/"export_presets.cfg").write_text("""[preset.0]
name="Android"
platform="Android"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/bukkbeek_xziel_touch_arm64.apk"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]
custom_template/debug=""
custom_template/release=""
gradle_build/use_gradle_build=false
gradle_build/export_format=0
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=2
version/name="0.2-mp40-ads-fov-magazine"
package/unique_name="org.xziel.bukkbeektouch.mp40fixv2"
package/name="XZIEL MP40 FIX V2"
package/signed=true
screen/orientation=4
screen/immersive_mode=true
graphics/opengl_debug=false
""")
assert (src/"mobile/touch_hud.gd").exists()
print("XZIEL Android touch overlay ready; Bukkbeek world, zombies, weapons retained")

# Install a SIXTH source MP40 weapon inside the ORIGINAL Bukkbeek scene.
# This is an additive overlay only: never change any existing 5 weapon scenes,
# the map, zombie logic, player movement code, or XZIEL touch controls.
mp40_scene = src / "mobile/mp40.tscn"
mp40_script = src / "mobile/mp40_weapon.gd"
mp40_source = src / "mobile/mp40_source"
assert mp40_scene.is_file() and mp40_script.is_file(), "Original MP40 adapter missing"
assert (mp40_source/"viewhands.glb").stat().st_size > 1000000
assert (mp40_source/"viewmodel.glb").stat().st_size > 100000

player_scene = src / "player/player.tscn"
p_text = player_scene.read_text()
reference = '[ext_resource type="Script" uid="uid://crk1vovs3vyif" path="res://common/managers/weapons_manager.gd" id="3_rgyib"]'
assert p_text.count(reference) == 1, "Bukkbeek player source changed; refuse partial patch"
p_text = p_text.replace(
    reference,
    reference + '\n[ext_resource type="PackedScene" path="res://mobile/mp40.tscn" id="22_mp40"]',
    1,
)
old_array = 'weapons_array = [NodePath("Knife"), NodePath("Pistol"), NodePath("AssualtRifle"), NodePath("AssualtBurstRifle"), NodePath("LMG")]'
assert p_text.count(old_array) == 1, "Bukkbeek stock weapon array changed"
p_text = p_text.replace(
    old_array,
    'weapons_array = [NodePath("Knife"), NodePath("Pistol"), NodePath("AssualtRifle"), NodePath("AssualtBurstRifle"), NodePath("LMG"), NodePath("MP40Source")]',
    1,
)
anchor_mp40 = '[node name="WeaponSubViewport" type="SubViewportContainer"'
assert p_text.count(anchor_mp40) == 1, "Bukkbeek viewport changed; refuse partial patch"
p_text = p_text.replace(
    anchor_mp40,
    '[node name="MP40Source" parent="WeaponsManager" instance=ExtResource("22_mp40")]\n\n' + anchor_mp40,
    1,
)
player_scene.write_text(p_text)

# For the Android TEST BUILD, start holding the new MP40 so QA can see it
# immediately. Existing knife remains weapon index 0 for the knife PNG action.
manager = src / "common/managers/weapons_manager.gd"
manager_src = manager.read_text()
original_line = '\tcurrent_weapon_index = 0\n\t_setup_current_weapon()'
assert manager_src.count(original_line) == 1, "Source Bukkbeek startup weapon changed"
manager_src = manager_src.replace(
    original_line,
    '\tcurrent_weapon_index = weapons_array.size() - 1 if OS.get_name() == "Android" and weapons_array.size() == 6 else 0\n\t_setup_current_weapon()',
    1,
)
# Real rendered Linux proof diagnosed 479,810m weapon displacement during a
# ~130ms software-renderer frame. Upstream weapon manager uses unbounded
# Vector3.lerp / Basis.slerp(follow_speed * delta). A frame > 20ms at the
# user's effective 50Hz follow factor produces t>1, extrapolates, and can
# then diverge exponentially after further frame hitches on Android.
# Clamp the mathematically legal interpolation interval to [0, 1]; the
# original 5 weapons, movement speeds, aim controls and assets are untouched.
source_lerp = "global_position = global_position.lerp(target_transform.origin, follow_speed * _delta)"
source_slerp = "global_transform.basis = current_basis.slerp(target_basis, follow_speed * _delta)"
assert manager_src.count(source_lerp) == 1 and manager_src.count(source_slerp) == 1, (
    "Bukkbeek camera-follow math changed; refuse to patch without inspection"
)
manager_src = manager_src.replace(
    source_lerp,
    "global_position = global_position.lerp(target_transform.origin, clampf(follow_speed * _delta, 0.0, 1.0))",
    1,
).replace(
    source_slerp,
    "global_transform.basis = current_basis.slerp(target_basis, clampf(follow_speed * _delta, 0.0, 1.0))",
    1,
)
manager.write_text(manager_src)
print("BUKKBEEK_MP40_CAMERA_FOLLOW_CLAMP_GREEN: no extrapolation on Android frame drops")
print("BUKKBEEK_MP40_PATCH_GREEN: sixth Bukkbeek weapon, Android starts MP40, knife remains index=0, old five remain")

