# V13 Kar98k — 50 original glTF viewmodel-camera combinations (forensic STOP)

Run 39201242548; Godot 4.6 real original Aether source gun + T4 Marine hand skeleton, real 1280×720 SubViewport, no image generation and no mesh replacement.

**Parameter grid:** rigid original source rig depths shift 0, -0.15, -0.30, -0.45, -0.60 m; source viewmodel FOV 65°,75°,90°,105°,120°; clipping planes 0.03 / 0.13 m. This is a diagnostic search, not documented official Call of Duty viewmodel parameters.

## Actual evidence

The original Kar98k rifle's 4,104 vertex main receiver contributes only 1,274 camera-visible vertices in prior ADR geometry pose, while 2,346 (57.2%) are BEHIND the lens and 484 (11.8%) are near-clipped. Camera alone cannot retarget true gun/hand wrist relationship.

**Dangerous FALSE best candidate:**
- Original test optimizer selected 0.15 m added back camera distance, FOV65, near 0.03m: **241,808** gun pixels, **71,248** hand pixels, 117,952 pixels in lower-quarter receiver, mathematically best naive score.
- Actual screenshot `v13_source_best_full.png` shows an enormous BLACK CIRCULAR STOCK/BUTTPLATE filling the center; it obliterates the iron sight. **Reject**. A purely numeric "more visible gun" score is NOT reliable. The winner is a catastrophic visual failure.
- Shift -0.30, FOV75, 0.03m showed extreme source Marine sleeve triangles and camera INSIDE the rifle/forearms.
- Independent adversarial critic enforces actual mid-screen rifle silhouette, <=85k total gun pixels and <=30k lower pixels, <=115k hands, <=5k centered arm pixels, <=100° FOV and real body visibility. **None** of the initial 50 samples meet those combined guards.

**Key causal conclusion:** source rifle+hands must be separately anatomically retargeted for ADS using existing original T4 Marine hand bones and gun grip source, not merely change FOV, eye relief, gun scale, clip plane, or center two gun sight vertices. Any workaround that places the eye inside a giant stock, hides hands, or paints replacement graphics violates the user's fidelity requirement.

## Shipped code status

- V12 already fixes original Marine skin/cloth/button glTF doubleSided=true import and source gun textured overrun.
- V11 Colt improved original HIP from 6,343 to 10,634 real gun pixels and ADS 12,367 to 30,510; keep these.
- Kar98k original glTF/PSA import preserved and new camera-depth probe runs in CI; **Kar98k intentionally RED**, no certified new APK.
- MP40 V6 untouched.

Next genuine implementation lane: analyze original tag_weapon relative to wrists at idle, fire_ads, and reload; retarget Kar98k shoulder+elbow to original gun grip and camera without changing bone animation keys; 3D skin/near-plane checks and side-by-side real GPU screenshots must pass *before* enabling Kar98k in a user-facing release.
