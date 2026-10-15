# MP40 authentic Aether weapon sounds (2026-10-15)

Recovered from original Project Aether IoStore package directly, using the
existing project's *previously verified* retoc, repak and BINKA decoding route.

Source directory inside original game package:
`ProjectAether/Content/Assets/Sounds/Base/`.

Exact source `.uasset + .uexp + .ubulk` stems (see SOURCE_AETHER_PROVENANCE.json
for SHA256 of both exact original ubulk bytes and decoded WAV):
- `gr_mp40_mag_out` => `mag_out.wav` (real magazine removal)
- `gr_mp40_mag_in` => `mag_in.wav` (real magazine insertion)
- `gr_mp40_charge` => `charge.wav` (real MP40 charging handle action)

**No CC0 metal_close, metal_spring, Magnum cylinder, stock Bukkbeek
reload, guessed clack, or fake release sound belongs in this MP40 scene.**

Source cues are driven by original PSA `j_clip` and `j_bolt` movements.
Tactical reload uses gr_mp40_mag_out + gr_mp40_mag_in, without a fake charge.
Empty reload adds gr_mp40_charge after the magazine is seated.

Bukkbeek original five weapons, MP40 geometry, 13 original hands animations,
18 gun animations, HUD, joystick, map and zombies stay untouched.

Recovery proof: GitHub Actions #38779477219 (extract+decode GREEN). Earlier
historical inventory proof: config-old-3 Actions #37235151147.

The source game may contain third-party assets whose distribution terms
should be independently confirmed before shipping outside a test build.
