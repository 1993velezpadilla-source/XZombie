# Bukkbeek Android — 12 ORIGINAL PNG ONLY (NO OLD CONTROLS)

Source: original Bukkbeek GodotFPS-Template commit `11619794d644e7933f87caa6099f3acc1f085f5d`.

## Visual rule from the user — 15 October
The gray circled buttons, outlined joystick, white icon overlays and auto-generated
skinned button backgrounds from the previous APK are REJECTED. They must not
appear in any new Bukkbeek APK.

This version permanently removes all references to the old transparent rings,
old CC0 icon generator, separate glyph overlays, and generic fallback icons.

The input controller now loads **only** 12 approved original image PNG files
from `bukkbeek-mobile/official_png/`. Gameplay preserves upstream guns, models,
zombies, map, ADS and reload logic.

**Important:** the previously approved 12 individual PNGs have not yet been
recovered as actual files from the linked repositories / available Library.
The original repository contains only an OLD icon generation script and older
full-game screenshots. We deliberately do not mistake that for the requested
art. See `official_png/README.md` for the required image naming.

## Fail-closed Android release gate
`verify_official_png.py` blocks any APK export until all 12 actual PNGs are
present, transparent and valid. No more "GREEN" with wrong icons or silent
fallback. Earlier APK builds, including run #38742188897, are OLD/rejected
and should not be installed for HUD validation.

Controls: joystick, touch look, fire, ADS, ADS+fire, reload, use, jump, sprint,
crouch input, knife, switch, pause. Crouch animation is not in original Bukkbeek.
No new maps or weapons added.

Branch: `feature/bukkbeek-android-touch-v1`. Never merge back to existing
Quake/Vril or other Godot maps by mistake.
