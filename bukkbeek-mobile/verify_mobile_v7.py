#!/usr/bin/env python3
"""Static source contract in addition to Godot 4.6 --headless --import and APK."""
from pathlib import Path
import sys
project = Path(sys.argv[1])
def data(path):
    p = project / path
    assert p.exists(), f"MOBILE_V7_MISSING {p}"
    return p.read_text()
player = data("mobile/mobile_player.gd")
hud = data("mobile/touch_hud.gd")
settings = data("mobile/mobile_settings.gd")
grenade = data("mobile/mobile_grenade.gd")
manager = data("common/managers/weapons_manager.gd")
ammo = data("common/utils/ammo_refil.gd")
scene = data("player/player.tscn")
mp40 = data("mobile/mp40_weapon.gd")
for marker in ('_xz_slide_remaining', '_xz_slide_velocity.move_toward',
               '"prone"', '"crouch"', 'velocity.y = jump_velocity',
               'func _xz_throw_grenade', '"cook_grenade"'):
    assert marker in player, f"MOBILE_V7_PLAYER_MISSING: {marker}"
for marker in ('Input.get_gyroscope()', 'resume_requested', 'mobile_settings.gd',
               '"precision_fire"', '"ads_mode"', 'release_fire_fingers',
               'Input.action_release("aim_mode")', 'func _toggle_pause'):
    assert marker in hud + settings, f"MOBILE_V7_HUD_MISSING: {marker}"
for marker in ('"gyro_mode"', '"gyro_invert_x"', '"gyro_invert_y"',
               '"gyro_deadzone"', '"look_sensitivity"', 'cfg.save(FILE_PATH)'):
    assert marker in settings, f"MOBILE_V7_SETTINGS_MISSING: {marker}"
assert 'res://mobile/mobile_player.gd' in scene
assert 'weapon.burst_mode = true' in manager
assert 'cancel_tactical_reload' in manager and 'cancel_tactical_reload' in mp40
assert 'Global.activate_pressed.connect(_on_android_interact)' in ammo
assert 'func _explode()' in grenade and 'BLAST_RADIUS' in grenade
# The stock F-interactable refill box must remain connected too.
assert 'event.is_action_pressed("activate")' in ammo
# No changes to authentic MP40 GLB/PSA/timing logic; only interrupt helper appended.
assert 'PSA_' in mp40
print("MOBILE_V7_SOURCE_CONTRACT_GREEN: advanced movement multitouch gyro settings")
print("MOBILE_V7_SOURCE_CONTRACT_GREEN: interact refills existing ammo chest")
print("MOBILE_V7_SOURCE_CONTRACT_GREEN: tactical reload cancel, precision trigger, grenade mechanics")
print("ANDROID_REAL_DEVICE_PENDING: Godot build GREEN is not an on-phone playtest")
