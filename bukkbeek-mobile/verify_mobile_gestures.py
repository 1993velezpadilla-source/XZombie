#!/usr/bin/env python3
"""Fail-closed source contract for Android touch adapter (NOT a device playtest)."""
from pathlib import Path
import sys

root = Path(sys.argv[1])
hud = (root / "touch_hud.gd").read_text()
stick = (root / "virtual_joystick.gd").read_text()

def require(condition: bool, name: str) -> None:
    if not condition:
        raise SystemExit("MOBILE_GESTURE_RED: " + name)

require('role in ["look", "fire", "adsfire"]' in hud,
        "fire and adsfire pointer drag must also drive look")
require('_rotate_look(delta)' in hud,
        "unified drag look function missing")
require('elif role in ["look", "fire", "adsfire"]:' in hud,
        "fire pointer ownership lost on drag")
require('var ads_toggled: bool = false' in hud,
        "ADS-only must default OFF and support toggle")
require('ads_toggled = not ads_toggled' in hud and
        'var aim: bool = ads_toggled or hold_counts.get("aim_mode",0)>0' in hud,
        "ADS-only toggle must coexist with ADS+FIRE temporary hold")
held = hud.split("const HELD :=", 1)[1].split("const DEADZONE", 1)[0]
require('"ads":' not in held, "ADS-only must not remain HOLD")
require('"adsfire":["fire","aim_mode"]' in held,
        "combined ADS+FIRE must still fire and aim")
require('Input.action_press(action)' in hud and 'Input.action_release(action)' in hud,
        "source-game input actions must be driven and released")
require('joystick_visual.set("direction", stick_value)' in hud and
        '"move"' in hud and '_movement()' in hud,
        "touch movement must visibly move joystick and drive analog actions")
require('draw_circle(knob,' in stick and
        'draw_arc(center,' in stick,
        "interactive joystick must have a real visible thumb-cap and base")
require('preload("res://mobile/virtual_joystick.gd")' in hud,
        "joystick script must be instantiated in HUD")
for icon in ("aim", "aim_fire", "crouch", "fire", "grenade", "interact",
             "knife", "prone", "reload", "slide", "vault_jump", "weapon_swap"):
    require(f'"{icon}.png"' in hud, f"official PNG missing: {icon}")
for rejected in ("touch_idle", "touch_pressed", "joystick_ring",
                 "touch_fire_idle", "touch_fire_pressed"):
    require(rejected not in hud + stick, "rejected legacy asset: " + rejected)
print("MOBILE_GESTURE_SOURCE_GREEN: analog joystick, fire-drag aim, ADS toggle, 12 official PNGs")
print("DEVICE_VISUAL_AND_TOUCH_UNVERIFIED: requires real Android screen and multitouch playtest")
