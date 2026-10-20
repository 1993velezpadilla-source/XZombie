# MP40 Pixel source import (Godot 4.6)

We recovered the name and actual dimensions of the original generated sprite
asset in the project Library: **WWII MP40 Pixel Art Sprite Sheet.png**
(**1448 x 1086**). This is **not** the old 240x150 smoke-test atlas.

## Exact source destination for the user's PNG
Upload that source image to GitHub on branch:
`fix/mp40-pixel-alpha-matte-v4-20261019`

Repository path (no renaming necessary):
`bukkbeek-mobile/pixel_assets/WWII MP40 Pixel Art Sprite Sheet.png`

The alternative name `MP40_Pixel_Source_1448x1086.png` also works.

The focused Android workflow automatically:
1. Starts with the existing game, 9 original weapons and all original controls.
2. Repairs fallback transparency without touching source PNG art.
3. Splits the exact approved image into **9 full-resolution PNGs**, excluding
   the lower text labels: HIP, ADS, HIP fire, ADS fire, sprint, reload 1-4.
4. Uses original-sheet iron-sight anchor positions, not the obsolete
   low-resolution bitmap anchors.
5. Verifies the existing weapon manager keeps 10 weapons and captures actual
   in-game HIP/ADS screenshots before attempting Android ARM64 export.

Do **not** relabel or enlarge the existing 80x50 atlas and claim the missing
detail was restored. The approved 1448x1086 file must be committed. Binary
image bytes are not provided in this branch yet, and neither Android success
nor on-phone rendering has been confirmed.

**Note:** The source must retain an actual transparent PNG alpha channel.
Opaque black-backdrop cells are rejected rather than hiding the iron sights.
