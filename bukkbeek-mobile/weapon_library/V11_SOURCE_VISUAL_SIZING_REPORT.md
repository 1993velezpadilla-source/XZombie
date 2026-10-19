# V11 Actual Godot Optical/Composition Audit — ORIGINAL 3D Models (October 2026)

**Branch:** fix/v11-cod-fps-visual-weapon-calibration-20261018
**MP40:** approved original V6 source preserved in full; no edits to `mp40_weapon.gd`.
**Source:** Project Aether/World at War models and T4 Marine hands; not verified BO3-original assets.
**Authorization:** do not merge before owner on-phone visual playtest. Do not distribute a "GREEN" APK based only on source PSA or compiler tests.

## Real diagnosis

Original GLB weapon-only/HANDS-only render screenshots were compared separately, after repairing the recursive Marine uniform material override (V10).

Source exact GLB x bounds (meters, original mesh coordinates):
- Colt: -0.0827..+0.1467 (0.2293m). This is a real compact pistol.
- Thompson: -0.2216..+0.4616 (0.6833m).
- Kar98k: -0.4873..+0.7551 (1.2424m). Source asset *also* contains two legitimate cartridge/clip submeshes parked at z≈-0.94m, visible only on reload.

### Colt (real improvement implemented)

**ADS (1280x720, actual Godot SubViewport):**
- Original: 12,367 gun pixels / 122,135 original hand-arm pixels, 9.88:1 sleeves vs pistol.
- Source model+hands rigid move **+0.12m toward camera**, with original PSA, material surfaces and grip socket unchanged:
  **30,510 visible gun pixels / 81,485 hand-arm pixels, 2.67:1.**
- Authored front/rear physical sight axes remain centered.
- This is a measured screen-space composition correction, NOT claimed to be an official Call of Duty ADS meter value.

**HIP:**
- Before: 6,343 gun pixels / 33,537 hand pixels.
- Moving together +0.12m toward lens produced **10,634 gun / 17,340 hands**.
- Additional +0.07m vertical framing lifts the pistol from the extreme bottom quarter.
- Actual reference frames stored in CI artifacts run 39197857890.

### Thompson

Real restored metal/wood material surfaces, sight upright. Rendered ADS 50,510 gun pixels vs 95,432 arms; HIP 12,808 gun pixels. Current source-authoritative FPS pose maintained rather than choosing a new unverified profile. Must pass on-phone test of reload, recoil, ADS, fire and movement.

### Kar98k — HARD RED, DO NOT RELEASE

The previous V9 2-point optical solver centered the iron sights but almost the entire real gun receiver was missing at ADS. It passed a geometric-only test falsely.

Independent source GLB near-plane/FOV sweep (CI run 39198414481) evaluated real rear and barrel models at + source eye distances and 48°/60° viewmodel lens. **All six candidates are visibly worse**: huge Marine sleeves remain close to/in the view frustum, actual receiver still has zero or near-zero pixels in the lower screen quarter. Genuine source 1.24m-long rifle stock lies ~0.618m behind selected optical rear landmark. Moving the entire hand skeleton to reveal that stock does not solve the source ADS arm clip and skinning. DO NOT mask by a forced profile distance, hide original hands or paint fake weapon textures.

Need novel real-source rig fix for Kar: preserve its HIP posture, derive camera-to-wrist rig pose for ADS by source animation and wrist anchor, validate GPU-skinned gun mesh at idle/fire/bolt/reload and constrain sleeves to remain outside center firing lane. Then acceptance: the actual 3D receiver and iron sights must be visible and original hand meshes must grip the bolt rifle without giant foreground wedges. Previous optical-only green gate is insufficient. Live visual-coverage gate intentionally remains **RED** for Kar98k.

## Regression policy

Godot run must fail if Colt HIP gun <9,500 visible pixels; Colt ADS <25,000; Thompson HIP <11,000; Thompson ADS <44,000; any weapon with non-original weapon material; any source GLB gun without true hands/PSA; any ADS missing visible original receiver; any source handgun with arms >5.5× gun pixels. Real Android screenshot still wins over headless desktop evidence.
