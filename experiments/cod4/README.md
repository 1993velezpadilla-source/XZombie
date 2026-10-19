# COD4 Android — PeZBOT source experiment

**Status: source recovered and stored; Android compatibility NOT proven.**

This isolated branch contains source-side mod resources for investigating offline enemy AI within a COD4-compatible runtime. The original Zombies Portable/Godot content remains untouched.

## Files retrieved
- `third_party/PeZBOT/svr/PeZBOT.gsc` — original PeZBOT server-side AI script (158,692 bytes)
- `third_party/PeZBOT/waypoints/mp_shipment_waypoints.gsc` — waypoint data for COD4's Shipment test map (12,253 bytes)
- `third_party/PeZBOT/weapon_defs/PeZBOT_WeaponDefs.csv` — AI weapon definitions (1,344 bytes)

Original community source: https://github.com/K-Faktor/PeZBOT-011p_Source
Original PeZBOT project and permission notes: https://www.moddb.com/mods/pezbot/downloads/pezbot-011p-for-call-of-duty-4

## Important limitations
- This is **not an APK**, a playable map, or a standalone AI system. It must be integrated with an appropriate COD4 runtime and assets.
- These resources are NOT a replacement for the commercial game data or the native Android port.
- Android port mod support (GSC, IWD, FF) and offline local server/bot support have not been demonstrated.
- No Call of Duty proprietary commercial assets, models, sounds, maps, textures, or executable code are packaged here.
- The PeZBOT developers permit modding and sharing modified versions with attribution and a distinct `PeZBOT_<mod name><version>` name; verify obligations before publishing derivatives.

## Experiment gate
Validate that the Android runtime accepts compiled `mod.ff`, mounts `.iwd`, can instantiate a local game, and exposes the engine functions that `PeZBOT.gsc` calls. If not, loading these source files alone will do nothing.
