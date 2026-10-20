# IGLESIA — MAIN AISLE VISUAL AUTHORITY (20 Oct 2026)

This document records what the user actually approved in the last two provided
HIP and ADS reference images. **The real 3D scene in Godot is the deliverable.**
The supplied AI concept images are an **art-direction target only**, never a
playable screenshot and never a substitute for native Godot art and collisions.

## Camera and composition
- Player stands at the nave's rear, facing **negative Z** along the center aisle.
- Altar/crucifix remain centered at far end. Pews occupy two symmetrical banks,
  and EVERY seated congregation member would face the altar (toward -Z).
- Long, unobstructed center aisle with enough room for zombies and mobile FPS
  combat; keep wall-buy visible but outside the main optical line.
- HIP: MP40 held low and to the right, barrel projecting toward the crosshair.
  ADS: both iron sights aligned exactly at the screen center, matching hitscan.
- Third-artstyle FORGIVE-ME-FATHER-inspired gothic illustrated realism, **NOT**
  childish geometric hands or polygons pasted over a generic gray gun.

## Approved architectural art goals
- Stone gothic nave, vaulted roof and pillars; arched blue moonlit windows.
- Richly modeled Tripo pew and Tripo altar remain PRIMARY visual furniture.
  Do not replace them with primitive cubes or downloaded unrelated models.
- Wood pews in clear aligned rows with their BACKS toward the player's entrance.
- Raised three-step sanctuary, altar face toward congregation.
- Dark polished/wet-looking stone floor with warm candle reflections.
- Symmetric chandeliers, carved reredos, prominent crucifix, rich red banners,
  warm candle holders and cold blue volumetric accents.
- Optimized on mobile: lighting/shadows controlled; decorative meshes
  collision-free; solid physics retained on player paths and furniture.

## MP40 art acceptance (BLOCKING, NOT GREEN)
Authentic MP40 silhouette is non-negotiable: hooded front blade, rear notch,
stamped cylindrical receiver, straight detachable magazine, correct stock
and comfortable believable grip. The playable demonic nun wears black habit
sleeves and has pale fingers. HIP and ADS have to use the SAME exact art
pipeline, not different guns glued together. 2D/2.5D is desired — model-based
offline sprite rendering is valid as an art-production step, but the game
should still run on efficient 2D viewmodel frames.

Required 13+ distinct frames cover hip idle/fire, ADS idle/fire, sprint,
tactical and empty reload; gun/hand/socket placement is verified at 0%,
18%, 34%, 50%, 68%, 88%, with sound cues matching actual frame events.
Sprint MUST NOT cancel reload. No invented frame sequences presented as
authentic MP40 reload mechanics.

## Engineering status / anti-false GREEN
- Current native implementation uses `scripts/church_dressing.gd` atop
  `scripts/iglesia.gd` world geometry, plus user Tripo originals.
- Current MP40 v3 illustrated frames are **not aesthetically approved**;
  keep those assets separate from the next candidate. They remain an
  emergency playable fallback only, not a 1:1 sign-off.
- The new `tools/capture_church.gd` captures **real Godot camera frames**
  (HIP + ADS) in Xvfb and publishes them under the GitHub Actions run.
- GDScript parse, navigation, real GLB dimensions, exact pew yaw, controls,
  reload and artifact signing are separate gates. They CANNOT certify the
  scene matches the reference or that Android FPS is good.
- Do not publish "1:1" or "AAA finished" until human compares real render
  with concept + hands and actual Android gameplay, then approves.

## Working branch
`1993velezpadilla-source/XZombie`:
`iglesia-clean-20261020`. Never touch the APEX repository.
