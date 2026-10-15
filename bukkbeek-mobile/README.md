# Bukkbeek FPS Android touch-only port (Godot 4.6)

The source used is Bukkbeek GodotFPS-Template commit 11619794d644e7933f87caa6099f3acc1f085f5d (upstream https://github.com/bukkbeek/GodotFPS-Template).

This overlay downloads the unchanged original project at build time; Android input is added without replacing weapon models, zombies, animations, maps, or reworking reload.

The exact user's XZIEL official HUD PNG generation script is taken from config-old-3/scripts/build_xziel_icons.py (original black/white/yellow, transparent button rings and joystick PNGs, fire/ADS/ADS+FIRE pressed states).

Landscape mobile inputs: move joystick, camera swipe on right, fire, ADS, ADS+FIRE, reload, use, jump, sprint, crouch action, knife select, weapon switch, pause. Upstream currently binds crouch but does not implement crouch motion, so no animation has been invented. No gyro, no new weapons, no new map.

GitHub Actions workflow builds a debug ARM64 Android APK and uploads the assembled full Godot project and APK as artifacts. A pass requires a successful Actions run and Android device smoke test.

This branch is isolated from the user's Quake/Vril and other advanced Godot builds.
