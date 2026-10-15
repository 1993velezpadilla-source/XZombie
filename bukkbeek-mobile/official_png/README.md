# XZIEL Official Touch PNGs — Bukkbeek Android

## Permanent ban
The round outlined controls in the rejected 15 Oct screenshot are from the earlier
PNG generator and layered ring + white glyph renderer. Those are **NOT** the
approved final user-provided art. They must never be generated or loaded.

The Android CI workflow no longer fetches or runs the old generator. The HUD script
only loads original PNG textures, **one bitmap per action**, without adding
circular borders, an artificial background, or a generic substitute.

## Exactly 12 source PNGs
Place the **actual previously approved user-made images**, without recreating or
redrawing them, in `bukkbeek-mobile/official_png/` as:

- `move.png` (used by dynamic joystick; reused scaled for its moving center)
- `fire.png`, `ads.png`, `adsfire.png`, `reload.png`
- `interact.png`, `jump.png`, `sprint.png`, `crouch.png`
- `knife.png`, `switch.png`, `pause.png`

These semantic filenames are a **packaging convention**, not a claim that
the original files already exist under those names. Map the real user-provided
art correctly; never use the rejected CC0 generated art as a substitute.

## Release gate
The build intentionally FAILS before exporting the APK when ANY PNG is absent,
non-transparent, corrupted or substituted with a forbidden legacy-named file.
No more Android GREEN builds that silently ship those ugly old controls.

Preserve Bukkbeek map, arms, 4 firearms, knife, animations and zombies untouched.

**Asset discovery (Oct 15):** The linked GitHub repository contains the
script `scripts/build_xziel_icons.py` that generated the old-style rings,
but it does not have the separately approved original button PNG files.
The user's earlier screenshots in Library are full gameplay captures, not
individually extracted approved button artwork.
