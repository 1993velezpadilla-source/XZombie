# V12 source reverse engineering — EXACT rendered Kar98k failure

Source: original pinned Aether / World at War `viewmodel.glb` and `viewhands.glb`. BO3-authenticity unverified. **No MP40 V6 changes.**

## Independent authoritative evidence (Godot 4.6 GPU-skinned model + actual FPS Camera3D)

Workflow 39200406684 `XZIEL_SOURCE_FRUSTUM` report (in genuine game scene).
This transforms **every original surface vertex** with `j_gun`'s real GPU skin offset before evaluating eye plane, 0.13 m near clipping, FOV, and frame coordinates, rather than relying on two sight-post landmarks.

Kar98k original `mtl_weapon_mp_kar98_Inst` **4,104** mesh vertices:

| View | Behind eye | Between eye and near plane | In view frustum |
|---|---:|---:|---:|
| HIP | 0 | 0 | **4,104** |
| ADS | **2,346 (57.16%)** | **484 (11.79%)** | **1,274 (31.04%)** |

Original buttstock `mtl_weapon_mp_kar98_Inst1` 224 vertices: ADS **105 behind eye**, **22 near-clipped**, **97 in frustum**. Offstage genuine cartridge/stripper surfaces 251+90 vertices are all behind/near in ADS (correctly not visible except genuine reload). This is **not** a fake generic material bug; the rifle receiver really passes through the camera on the original socket-derived ADS pose.

**Root failure confirmed**: solver aligns the true rear/front notch but places the Camera3D in the skinned rifle *body*, so large parts disappear despite iron sights perfectly centered. Simply shifting whole grip+rifle away grows original Marine sleeves to gigantic size; source PSA fire_ads alternative does not fix whole receiver. Previous V9 green proved only iron sight ray, not functional COD first-person framing.

## 3-material ORIGINAL Marine hands import error

Original `viewhands.glb` 3 primitives: cloth 1945 verts, skin 5227, button 68. ALL three original GLTF materials are `doubleSided=true`. V8/V9/V10 converters overrode them with Godot `StandardMaterial3D` **CULL_BACK**, which created giant open black/pale triangular holes on sleeve and skin when viewed inside the near lens.

V12 honors all three original surfaces and enables CULL_DISABLED, distinct plausible roughness/metallic per authentic material. Source mesh and genuine original hand UV/albedo/normal are unchanged, all animations preserved. Runtime gate ensures exactly three original surfaces, original source name, and CULL_DISABLED on each. Native Godot screenshots confirm previously missing underside fabric/hand triangles are filled. **This does NOT by itself correct arm intrusion or rifle clipping.** New gauntlet deliberately fails on those cosmetic defects.

## Stop conditions

- MP40 V6 unchanged.
- Accept no Kar98k ADS release until behind-eye receiver >50% becomes 0; near clipping eliminated without clipping original wrist animation; photo matches COD sight/receiver proportions and confirms no giant sleeves.
- Colt HIP/ADS renderer pixels must stay at least 9.5k/25k; Thompson 11k/44k.
- No substitution of original audio or reuse of Marine cloth as firearm material; all original material identities verified.

V12 is **forensic + partial material repair, not a release-ready APK**. Source proof: run 39200406684 and the original `viewhands.glb` material metadata; no guessing.
