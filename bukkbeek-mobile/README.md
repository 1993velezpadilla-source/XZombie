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

Left analog movement and right touch look are invisible gesture zones.
Sprint is activated by pushing the left thumb fully forward.
There is no original pause PNG; Android back and an invisible top-right pause
zone are used instead. No counterfeit icon was added.
If Bukkbeek lacks gameplay support for slide, prone, or grenades, the original
textures appear but no substitute mechanics or animations are invented.

The original Bukkbeek environment, zombies, weapon meshes, and reload logic
are retained as in upstream `11619794d644e7933f87caa6099f3acc1f085f5d`.

A GREEN Android debug ARM64 export is still not proof of real-device touch
gameplay. An Android phone smoke test remains required.
