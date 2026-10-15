# Bukkbeek Android — EXACT 12 OFFICIAL XZIEL PNG buttons

RECOVERED: The user's *actual* approved full-image button PNGs were already in
their GitHub repository: `1993velezpadilla-source/config-old-3`, branch
`recovery/xziel-nzp-v026-official-buttons-20261011`,
commit `0119c5b0f9109c4c88dbdd4173a9a2ba523abc3d`, directory
`assets/xziel/official_touch_skins_v1/`.

The official manifest says `status: official-approved`. Exactly 12 originals:
`aim.png`, `aim_fire.png`, `crouch.png`, `fire.png`,
`grenade.png`, `interact.png`, `knife.png`, `prone.png`,
`reload.png`, `slide.png`, `vault_jump.png`, `weapon_swap.png`.

The GitHub Android CI downloads the 12 exact original files with their pinned
commit and verifies each source Git blob SHA. This **does not run**
`build_xziel_icons.py` and never draws the rejected circle rings, separate
glyphs, generic fallbacks or imitations. Touch buttons are rendered directly
from these exact full PNGs only.

The Android left analog now has a **visible, responsive thumbstick** (subtle vector
base/thumb cap, NOT any obsolete touch-action button skins). A left-half touch
anchors the joystick at that thumb's location; dragging moves the knob and
drives the original Bukkbeek analog actions. Sprint is activated by pushing
fully forward. The 12 action buttons remain EXACTLY the official approved PNGs.

**New gesture behavior:** the FIRE or ADS+FIRE thumb may drag while staying
pressed: the camera tracks its motion at the same time as fire remains held.
Independent LOOK touches keep working as before.

**ADS-only PNG now defaults to TAP TO TOGGLE**: first touch enters ADS, second
exits ADS. Releasing the ADS-only button does not cancel ADS. ADS+FIRE remains
a hold behavior, with proper coexistence if ADS is toggled on already.
Possible settings for hold mode are deferred as explicitly requested.
There is no original pause PNG; Android back and an invisible top-right pause
zone are used instead. No counterfeit icon was added.
If Bukkbeek lacks gameplay support for slide, prone, or grenades, the original
textures appear but no substitute mechanics or animations are invented.

The original Bukkbeek environment, zombies, weapon meshes, and reload logic
are retained as in upstream `11619794d644e7933f87caa6099f3acc1f085f5d`.

A GREEN Android debug ARM64 export is still not proof of real-device touch
gameplay. An Android phone smoke test remains required.
