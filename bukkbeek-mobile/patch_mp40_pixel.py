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
