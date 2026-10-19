# V10 Weapon Fidelity Audit (2026-10-18)

Status: FAILING mobile visual acceptance. Do not ship a new APK on a compilation-only GREEN.
Source: Project Aether / World at War T4 Marine (BO3 authenticity NOT verified).
MP40 V6 remains approved and unmodified.

## CONFIRMED ROOT CAUSE: textures

The generic source_weapon.gd first attached SourceGun below SourceHands.tag_weapon, then applied original gun materials, then applied the Marine HAND material recursively to SourceHands. The second step traversed the nested gun mesh and OVERWROTE Colt, Thompson, and Kar98k weapon metal/wood with the cloth/skin atlas. MP40 V6 avoided this by texturing before attaching the real gun to the Marine skeleton.

Fix in V10: never traverse SourceGun meshes during hand-material assignment. Assert every gun material albedo path matches the pinned original weapon-material bindings; preserve Kar98k stripper clip's original absence of normal map. CI source-material verification passes: Colt 1 original material, Thompson 1, Kar98k 4.

## CONFIRMED CURRENT ADS PROBLEMS

Independent, actual Godot SubViewport rendered pixels:
Colt ADS: 12,367 weapon pixels and 122,135 hand pixels (9.88:1 hand to gun). Massive source sleeve intrusion.
Thompson ADS: 50,510 gun and 95,432 hands. Requires manual fidelity validation.
Kar98k ADS: 6,419 gun pixels; ZERO gun pixels in the bottom quarter of screen, despite 64,991 hand pixels. Most of actual rifle body is outside the render frustum.

The former 2-pixel rear/front sight alignment gate falsely labeled these ugly compositions GREEN. A new adversarial per-mesh visual gate now rejects Colt giant-arm and Kar98k missing-gun-body renders before exporting.

## Original rig evidence

Source T4 Marine hands include 113 bones, tag_view, tag_camera, tag_ads, tag_weapon, wrist, elbow, and shoulder bones.
tag_view/tag_camera/tag_ads are all at the imported skeleton origin and have identical static orientation: they do NOT encode usable per-weapon sight eye-relief values.

Measured original tag_weapon relative to camera skeleton bone distance (ORIGINAL BONE UNITS, NOT OFFICIAL COD ADS METERS):
MP40 12.4665; Colt 11.3399; Thompson 18.0179; Kar98k 11.3221.

These are authoritative original positional evidence, but should not be treated as user-approved ADS numbers until full skeleton scale and physical optical landmarks are validated.

## Release conditions

Keep MP40 V6 untouched. For every new weapon, match original PSA root, real hand rig/visible sleeve silhouette, gun surface materials, gun rear+front aperture, complete 3D weapon receiver, hip ADS reload fire swap and recoils. Publish Godot actual HIP/ADS screenshots from separate hands-only and gun-only renderers. Reject off-camera guns, intrusive foreground arms, wrong texture, and any missing source audio; never substitute with generic template assets. User on-device validation is authoritative. V10 is an audit/fix branch and not yet an approved release.
