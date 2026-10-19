#!/usr/bin/env python3
"""Add MP40Pixel after existing 9 weapons; never replace an existing scene."""
from pathlib import Path
import sys
root=Path(sys.argv[1]).resolve()
source=Path(__file__).parent
for file in ("mp40_pixel.tscn","mp40_pixel_weapon.gd"):
    (root/"mobile"/file).write_bytes((source/"mobile"/file).read_bytes())
atlas=source/"pixel_assets"/"atlas.png"
assert atlas.is_file(), "MP40_PIXEL_RED: user-approved PNG atlas missing"
(root/"mobile"/"mp40_pixel").mkdir(parents=True,exist_ok=True)
(root/"mobile"/"mp40_pixel"/"atlas.png").write_bytes(atlas.read_bytes())

# Prefer INDIVIDUAL, full-resolution original PNGs when installed.
# The tiny low-res atlas is a smoke-test FALLBACK, never considered final art.
# No touching the 3D MP40 scene, its rig or any existing weapon texture.
from struct import unpack
names=("idle_hip_01","ads_idle","fire_hip_01","ads_fire_01","sprint_01",
       "reload_01","reload_02","reload_03","reload_04")
frames=source/"pixel_assets"/"frames"
installed=0
if frames.exists():
    (root/"mobile"/"mp40_pixel"/"frames").mkdir(parents=True,exist_ok=True)
    for name in names:
        origin=frames/(name+".png")
        if not origin.exists():
            continue
        data=origin.read_bytes()
        assert data[:8]==b"\\x89PNG\\r\\n\\x1a\\n", "MP40_PIXEL_RED corrupt PNG: "+name
        width,height=unpack(">II",data[16:24])
        assert width>=256 and height>=160, "MP40_PIXEL_RED low-resolution source: "+name
        (root/"mobile"/"mp40_pixel"/"frames"/origin.name).write_bytes(data)
        installed+=1
assert installed in (0,9), "MP40_PIXEL_RED partial high-resolution pack; all 9 required"
print("MP40_PIXEL_SPRITES_INSTALLED high_resolution=",installed," / 9",
      " source=",str(frames)," legacy_atlas_fallback=",installed==0)
for audio in ("fire.wav", "mag_out.wav", "mag_in.wav", "charge.wav"):
    assert (root/"mobile"/"mp40_source"/audio).is_file(), "MP40_PIXEL_RED missing source "+audio
player=root/"player"/"player.tscn"
text=player.read_text()
marker='[node name="WeaponSubViewport"'
assert text.count(marker)==1
text=text.replace(marker,'[node name="MP40Pixel" parent="WeaponsManager" instance=ExtResource("90_mp40pixel")]\n\n'+marker,1)
needle='NodePath("Kar98kSource")]'
assert text.count(needle)==1, "MP40_PIXEL_RED source weapon ordering changed"
text=text.replace(needle,'NodePath("Kar98kSource"), NodePath("MP40Pixel")]',1)
anchor='[ext_resource type="PackedScene" path="res://mobile/kar98k.tscn"'
assert text.count(anchor)==1
text=text.replace(anchor,'[ext_resource type="PackedScene" path="res://mobile/mp40_pixel.tscn" id="90_mp40pixel"]\n'+anchor,1)
player.write_text(text)
print("MP40_PIXEL_STAGE_GREEN original 5 + Aether MP40 Colt Thompson Kar98k + sprite MP40Pixel")

# Keep this APK installed NEXT TO the established 3D MP40 test build.
# New package ID is a smoke-test namespace, not a renamed production game.
preset=root/"export_presets.cfg"
data=preset.read_text()
original='package/unique_name="org.xziel.bukkbeek.mobilev9"'
assert data.count(original)==1, "MP40_PIXEL_RED existing Android package identity changed"
data=data.replace(original,'package/unique_name="org.xziel.bukkbeek.mp40pixeltest"',1)
data=data.replace('package/name="XZIEL ORIGINAL WEAPONS V9"','package/name="XZIEL MP40 PIXEL TEST"',1)
data=data.replace('version/name="0.9-xziel-original-optical-fit"','version/name="0.1-mp40-pixel-smoke"',1)
preset.write_text(data)
print("MP40_PIXEL_ANDROID_SIDE_BY_SIDE_GREEN original 3D APK package untouched")
