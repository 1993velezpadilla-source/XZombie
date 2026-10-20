# MP40 2.5D — V8 original flipbook, ART REVIEW REQUIRED

A separate, future-first-person MP40 viewmodel. The installed MP40 Pixel V6
and the nine original weapons stay unchanged.

## Source
Original drawn/generated 2.5D sprite strips in this project conversation
(hip, ADS, tactical and empty reload, equip, sprint, master).
**NO EA DICE or FAB artwork is redistributed.** The MP40 mechanical **motion
order** was taken from first-person animator Oskar Wetterbrandt at EA DICE:
https://ea_dice.artstation.com/blog/jMao/animating-weapons-for-battlefield-v

The MP40 **empty reload** is:
1. magazine out;
2. bolt manipulated while the old magazine is STILL held;
3. a fresh magazine is pulled from the pouch;
4. fresh mag installed;
5. bolt released;
6. return to ready.

The generic AI-generated 8-cell empty-reload strip placed the bolt pull too
late, so the **assembler reorders source poses**, never blindly plays the sheet
left to right. Tactical reload does **not** play a bolt cycle.

## Source sheet inputs / unpacker

Copy independently authored, permissioned RGBA 2172x724 PNG strips to the
input folder named:

- `master.png` (3 columns)
- `equip.png` (4 columns)
- `hip.png` (6 columns)
- `ads_in.png` (5 columns)
- `ads_out.png` (6 columns)
- `sprint.png` (4 columns)
- `reload_tactical.png` (6 columns)
- `reload_empty.png` (8 columns)

Then run:

```bash
python3 bukkbeek-mobile/build_mp40_25d_from_sheets.py \
  /path/to/owned_sheets \
  bukkbeek-mobile/mobile/mp40_25d/motion_manifest.json \
  bukkbeek-mobile/mobile/mp40_25d/frames
```

Output is exactly **107 RGBA PNGs** with names matching the motion state machine.

## RESTRICTED V8 PREVIEW — not an approved weapon yet

Source sheets are concept art with detected **vertical-column clipping**,
pose mismatch and temporary reuse for inspect, melee and dry fire. This means
107 files is **not equivalent to 107 visually correct poses**. Do not merge
or release from a frame-count-only green test. A full-art hand/limb continuity
review and real Pixel Fold acceptance are still required.

`sprite_deck.gd` intentionally fails closed without all frames. It can cache
12 textures without preloading 107 high-resolution frames into Android RAM.
It is **not** registered as an in-game weapon until visual QA passes.

Current CI confirms the original V6 Android APK remains the same and the
**V8 motion interface** imports; no V8 APK is claimed.
