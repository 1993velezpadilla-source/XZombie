#!/usr/bin/env python3
"""Apply mobile gameplay to assembled Bukkbeek 4.6 project, not XZombie's
minimal main skeleton. Fail closed when upstream anchors change."""
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
def change(path: str, old: str, new: str):
    target = root / path
    txt = target.read_text()
    assert txt.count(old) == 1, f"MOBILE_V7_UPSTREAM_CHANGED: {path}: {old[:60]!r}"
    target.write_text(txt.replace(old, new, 1))

# Use original player as base class for Android movement; MP40/weapon nodes untouched.
change(
    "player/player.tscn",
    'path="res://player/player.gd" id="1_oul6g"',
    'path="res://mobile/mobile_player.gd" id="1_oul6g"',
)
# Original source is kept for script inheritance; don't modify it.
assert (root / "player/player.gd").is_file()
for file in ("mobile_player.gd", "mobile_grenade.gd",
             "mobile_settings.gd", "touch_hud.gd"):
    assert (root / "mobile" / file).is_file(), file

# Bukkbeek already has a PISTOL and existing cooldown-controlled fire.
# Android hold-fire repeats through stock cooldown, desktop is unchanged.
change(
    "common/managers/weapons_manager.gd",
    "\t\tweapon.initialize(main_camera, weapon_ray_cast, ray_cast_origin)",
    "\t\tweapon.initialize(main_camera, weapon_ray_cast, ray_cast_origin)\n"
    "\t\tif OS.get_name() == \"Android\" and weapon.name == \"Pistol\":\n"
    "\t\t\tweapon.burst_mode = true",
)
# Tactical reload: stop the timer and return to existing idle *only* when
# cartridges remain. Empty magazine must finish its full reload.
change(
    "common/managers/weapons_manager.gd",
    "\tcurrent_weapon.try_fire(true)",
    """\tif current_weapon.is_reloading and current_weapon.current_mag > 0:
\t\tif current_weapon.has_method("cancel_tactical_reload"):
\t\t\tcurrent_weapon.cancel_tactical_reload()
\t\telse:
\t\t\tcurrent_weapon.reload_timer.stop()
\t\t\tcurrent_weapon.is_reloading = false
\t\t\tif current_weapon.animation_player:
\t\t\t\tcurrent_weapon.animation_player.stop()
\t\t\tif current_weapon.reload_sfx:
\t\t\t\tcurrent_weapon.reload_sfx.stop()
\tcurrent_weapon.try_fire(true)""",
)
# The stock ammo refill listens only for keyboard F _unhandled_input, whereas
# Android calls Input.action_press("activate") and the Global signal.
# Connect the EXACT same _refill_player implementation; no fake chest item.
change(
    "common/utils/ammo_refil.gd",
    "\tif outline_mesh:\n\t\toutline_mesh.visible = false",
    """\tif outline_mesh:
\t\toutline_mesh.visible = false
\tif OS.get_name() == "Android":
\t\tGlobal.activate_pressed.connect(_on_android_interact)

func _on_android_interact() -> void:
\tif player_in_range and not is_depleted and not Global.in_vehicle:
\t\t_refill_player()""",
)
print("BUKKBEEK_MOBILE_V7_PATCH_GREEN real_slide_prone_crouch+settings+ammo_interact+reload_cancel")
