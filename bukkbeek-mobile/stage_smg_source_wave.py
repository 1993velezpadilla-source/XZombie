#!/usr/bin/env python3
"""Stage source-original PPSh-41 and Type 100 into the EXISTING WaW Godot game.

Do not touch the MP40 V6. Never use unverified conversation-only ADS offsets.
The shared source rig has been independently validated for all four SMGs.
Source geometry is exact from each GLB, while sight selection remains
experimental until the Godot physical-pixel/full-hand renderer approves it.
"""
from __future__ import annotations
import hashlib
import json
import math
import struct
import sys
import time
import urllib.request
from pathlib import Path

SOURCE = "1993velezpadilla-source/config-old-3"
COMMIT = "5c8093db6c5eab64d653f715813f1d70915d393f"
TX = "xogot/assets/weapons/aether_waw_textures/"
HT = "xogot/assets/weapons/aether_waw_hands/t4_marine/common/textures/"
HANDS = {
    "viewmodel_usa_marine_c.png": "91d95e6b711258c048768234dae9e6e71c86952d",
    "viewmodel_usa_marine_n.png": "bc1cd8e91a18be04309aea0f9ee8e7376940f903",
}
SMG = {
 "ppsh": {
  "node": "PPShSource", "magazine": 71, "cooldown": .09,
  "gun_sha": "87e9662b1ec9ffe91d32a721eae319bd98a9e90c",
  "hands_sha": "49893af20e66f41402b268a11d6d73fcaeb3547b",
  "wav_sha": "9cfd7554f1fd2c4dfbf00a4e9bdcfaf672efb0e5",
  "tex": {
   "rus_smg_ppsh41_c.png": "6f7c9ab8fe2f6cb983a7bab8ffc015fafdbaccd4",
   "rus_smg_ppsh41_n.png": "ef55105e2d276b32871ba01069feb7f1c5c7e06e",
   "_rus_smg_ppsh41_s-rgb_rus_smg_ea9bcaa8.png": "5ed97c2c2ed2af5f91df1a9c2a7f80ab52acb798"},
  "albedo": "rus_smg_ppsh41_c.png", "normal": "rus_smg_ppsh41_n.png",
  "specular": "_rus_smg_ppsh41_s-rgb_rus_smg_ea9bcaa8.png",
  "materials": ["mtl_weapon_mp_ppsh41_Inst"],
  "hands": {"idle":"PSA_viewmodel_ppsh_idle", "fire":"PSA_viewmodel_ppsh_fire",
            "reload":"PSA_viewmodel_ppsh_reload_notempty",
            "reload_empty":"PSA_viewmodel_ppsh_reload", "equip":"PSA_viewmodel_ppsh_pullout"},
  "gun": {"idle":"PSA_viewmodel_ppsh_idle", "fire":"PSA_viewmodel_ppsh_fire",
          "reload":"PSA_viewmodel_ppsh_reload_notempty",
          "reload_empty":"PSA_viewmodel_ppsh_reload", "equip":"PSA_viewmodel_ppsh_pullout"},
  "rear": (-.0304, .0782, -.0082), "front": (.3426, .0877, 0.0),
  "eye_relief": .17,
 },
 "type100": {
  "node": "Type100Source", "magazine": 30, "cooldown": .09,
  "gun_sha": "78b33650c481996ec67745fbbc0213b001666f84",
  "hands_sha": "d55fdabe132857e5b6cf870ec8ba926899c30531",
  "wav_sha": "f49bee315b6ddb14d6fb812134904132f1f53081",
  "tex": {
   "w_type100_c_new.png": "f02139a4e264496b8c6112e834509d3a1eaea3a8",
   "_w_type100_s-rgb_w_type100_g-l-11.png": "595695afb0097a4425f0f72ff99781e8575dd252"},
  "albedo": "w_type100_c_new.png", "normal": "",
  "specular": "_w_type100_s-rgb_w_type100_g-l-11.png",
  "materials": ["mtl_weapon_mp_type100_metal_Inst",
                "mtl_weapon_mp_type100_metal_Inst1"],
  "hands": {"idle":"PSA_viewmodel_type100_smg_idle", "fire":"PSA_viewmodel_type100_smg_fire",
            "reload":"PSA_viewmodel_type100_smg_reload",
            "reload_empty":"PSA_viewmodel_type100_smg_reload_empty", "equip":"PSA_Type100Equip"},
  "gun": {"idle":"PSA_viewmodel_type100_smg_idle", "fire":"PSA_viewmodel_type100_smg_fire",
          "reload":"PSA_viewmodel_type100_smg_reload",
          "reload_empty":"PSA_viewmodel_type100_smg_reload_empty", "equip":"PSA_Type100Equip"},
  "rear": (-.1599, .0661, .0012), "front": (.3206, .0661, .005),
  "eye_relief": .18,
 },
}

def blob_sha(data:bytes)->str:
 return hashlib.sha1(("blob %d\0" % len(data)).encode()+data).hexdigest()

def fetch(path:str, expected:str, dest:Path)->bytes:
 if dest.is_file():
  raw=dest.read_bytes()
  if blob_sha(raw)==expected:return raw
 url="https://raw.githubusercontent.com/"+SOURCE+"/"+COMMIT+"/"+path
 for attempt in range(3):
  try:
   req=urllib.request.Request(url,headers={"User-Agent":"XZIEL-WaW-4SMG/1"})
   with urllib.request.urlopen(req,timeout=45) as resp:raw=resp.read()
   if blob_sha(raw)!=expected:raise ValueError("SOURCE SHA MISMATCH "+path)
   dest.parent.mkdir(parents=True,exist_ok=True)
   dest.write_bytes(raw)
   return raw
  except (OSError,TimeoutError):
   if attempt==2:raise
   time.sleep(1+attempt)
 raise AssertionError("Source download impossible")

def glb_mesh_vertices(raw:bytes)->tuple[dict,list[tuple[float,float,float]]]:
 if raw[:4]!=b"glTF" or struct.unpack_from("<I",raw,8)[0]!=len(raw):
  raise ValueError("invalid original GLB")
 jsonlen=struct.unpack_from("<I",raw,12)[0]
 if raw[16:20]!=b"JSON":raise ValueError("GLB JSON missing")
 doc=json.loads(raw[20:20+jsonlen].decode("utf-8"))
 start=20+jsonlen
 if raw[start+4:start+8]!=b"BIN\0":raise ValueError("GLB BIN missing")
 start+=8
 positions=[]
 for mesh in doc.get("meshes",[]):
  for primitive in mesh.get("primitives",[]):
   accessor=doc["accessors"][primitive["attributes"]["POSITION"]]
   bv=doc["bufferViews"][accessor["bufferView"]]
   if accessor["componentType"]!=5126 or accessor["type"]!="VEC3":
    raise ValueError("unsupported original GLB position storage")
   off=start+bv.get("byteOffset",0)+accessor.get("byteOffset",0)
   stride=bv.get("byteStride",12)
   positions.extend(struct.unpack_from("<fff",raw,off+i*stride)
                    for i in range(accessor["count"]))
 return doc,positions

def nearest_original(verts:list,guess:tuple)->list[float]:
 v=min(verts,key=lambda v:sum((v[j]-guess[j])**2 for j in range(3)))
 error=math.sqrt(sum((v[j]-guess[j])**2 for j in range(3)))
 if error>.0035:raise ValueError("Iron sight candidate is not original mesh metal: error="+str(error))
 return list(v)

def make_scene(ident:str, item:dict)->str:
 d="res://mobile/weapon_sources/"+ident+"/"
 node=item["node"]
 # Using exact MP40 V6 HIP/ADS import markers, THEN weapon-unique physical
 # sight calibration performed by source_weapon_fit.gd in the real game.
 return f'''[gd_scene load_steps=6 format=3]

[ext_resource type="PackedScene" path="res://common/weapon/weapon_base.tscn" id="1_base"]
[ext_resource type="Script" path="res://mobile/source_weapon.gd" id="2_script"]
[ext_resource type="PackedScene" path="{d}viewhands.glb" id="3_hands"]
[ext_resource type="PackedScene" path="{d}viewmodel.glb" id="4_gun"]
[ext_resource type="AudioStream" path="{d}fire.wav" id="5_fire"]

[node name="{node}" node_paths=PackedStringArray("fps_arms_root", "animation_player", "firing_sfx", "reload_sfx", "empty_mag_sfx", "muzzle_flash_position") instance=ExtResource("1_base")]
script = ExtResource("2_script")
source_weapon_id = "{ident}"
fps_arms_root = NodePath("FPSHandsRoot")
animation_player = NodePath("fps_demo_arms/AnimationPlayer")
muzzle_flash_position = NodePath("FPSHandsRoot/MuzzleFlashPosition")
bullet_type = 2
damage = 36.0
cooldown = {item["cooldown"]}
burst_mode = true
mag_capacity = {item["magazine"]}
reload_time = 2.0
firing_distance = 110.0
focused_aim_fov = 45.0

[node name="StandardAimPosition" parent="." index="0"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.05, -0.05, -0.22)

[node name="FocusedAimPosition" parent="." index="1"]
transform = Transform3D(0.999857, 0.00464, 0.01696, -0.00512, 0.999583, 0.02845, -0.01682, -0.02854, 0.99945, -0.04142, 0.0104, -0.24045)

[node name="fps_demo_arms" parent="." index="6"]
visible = false

[node name="FiringSFX" parent="SFX" index="0"]
stream = ExtResource("5_fire")
volume_db = -7.0

[node name="FPSHandsRoot" type="Node3D" parent="."]

[node name="SourceHands" parent="FPSHandsRoot" instance=ExtResource("3_hands")]

[node name="SourceGun" parent="FPSHandsRoot" instance=ExtResource("4_gun")]

[node name="MuzzleFlashPosition" type="Marker3D" parent="FPSHandsRoot"]
position = Vector3(0.0, -0.08, -0.65)

[editable path="fps_demo_arms"]
'''

def main(root:Path)->None:
 scene=root/"player/player.tscn"
 current=scene.read_text()
 assert "NodePath(\"Kar98kSource\")" in current
 assert "NodePath(\"PPShSource\")" not in current
 for n, (ident,item) in enumerate(SMG.items()):
  folder=root/"mobile/weapon_sources"/ident
  gun=fetch("xogot/assets/weapons/aether_waw_real/"+ident+"/viewmodel.glb",
            item["gun_sha"],folder/"viewmodel.glb")
  hands=fetch("xogot/assets/weapons/aether_waw_hands/t4_marine/"+ident+"/viewhands.glb",
              item["hands_sha"],folder/"viewhands.glb")
  fetch("xogot/assets/audio/weapons/mapmod/"+ident+"/fire.wav",item["wav_sha"],folder/"fire.wav")
  for name,hash_ in item["tex"].items():fetch(TX+name,hash_,folder/name)
  for name,hash_ in HANDS.items():fetch(HT+name,hash_,folder/name)
  original_gun,vertices=glb_mesh_vertices(gun)
  original_hands,_=glb_mesh_vertices(hands)
  gun_clips={a.get("name") for a in original_gun["animations"]}
  hands_clips={a.get("name") for a in original_hands["animations"]}
  assert all(clip in gun_clips for clip in item["gun"].values())
  assert all(clip in hands_clips for clip in item["hands"].values())
  assert set(item["materials"])=={m.get("name") for m in original_gun["materials"]}
  rear=nearest_original(vertices,item["rear"])
  front=nearest_original(vertices,item["front"])
  separation=math.dist(rear,front)
  if not .25<separation<.9 or front[0]<rear[0]+.2:
   raise ValueError("Original iron-sight source geometry malformed "+ident)
  xmin=min(v[0] for v in vertices);xmax=max(v[0] for v in vertices)
  profile={
    "id":ident,"family":"smg","source":"Aether WaW (not BO3)",
    "has_original_fire_audio":True,
    "roles":{"gun":item["gun"],"hands":item["hands"]},
    "materials":[{
      "source_material":m,
      "albedo":"res://mobile/weapon_sources/"+ident+"/"+item["albedo"],
      "normal":("res://mobile/weapon_sources/"+ident+"/"+item["normal"]) if item["normal"] else "",
      "specular":"res://mobile/weapon_sources/"+ident+"/"+item["specular"],
      "metallic":.34,"roughness":.42,"normal_scale":1.0,"two_sided":False
     } for m in item["materials"]],
    "source_sights":{
      "rear_witness_vertices":[rear],"front_witness_vertices":[front],
      "source_witness_sep_m":separation,
      "source_body_length_m":xmax-xmin,"eye_relief_m":item["eye_relief"]},
    "source_sight_status":"ORIGINAL_MESH_VERTEX_CANDIDATE_UNTIL_CAMERA_VISUAL_GATE",
  }
  (folder/"profile.json").write_text(json.dumps(profile,indent=2)+"\n")
  (root/"mobile"/(ident+".tscn")).write_text(make_scene(ident,item))
  rid="4"+str(n)+"_"+ident
  ext=f'[ext_resource type="PackedScene" path="res://mobile/{ident}.tscn" id="{rid}"]'
  marker='[sub_resource type="CapsuleShape3D"'
  assert current.count(marker)==1
  current=current.replace(marker,ext+"\n\n"+marker,1)
  scene_anchor='[node name="WeaponSubViewport" type="SubViewportContainer"'
  assert current.count(scene_anchor)==1
  current=current.replace(scene_anchor,
    f'[node name="{item["node"]}" parent="WeaponsManager" instance=ExtResource("{rid}")]\n\n'
    +scene_anchor,1)
  print("XZIEL_SMG_ORIGINAL_SOURCE_SCENE_GREEN id="+ident+
        " source_sight_separation="+str(round(separation,6))+
        " gun_animations="+str(len(gun_clips))+
        " hand_animations="+str(len(hands_clips)))
 # Append without mutating or repositioning any earlier source weapon.
 needle='NodePath("Kar98kSource")]'
 assert current.count(needle)==1
 current=current.replace(needle,
  'NodePath("Kar98kSource"), NodePath("PPShSource"), NodePath("Type100Source")]',1)
 scene.write_text(current)
 print("XZIEL_SMG_SOURCE_SCENES_STAGED originals=PPSh,Type100; original_MP40_V6_UNCHANGED")

if __name__=="__main__":
 if len(sys.argv)!=2:raise SystemExit("usage: stage_smg_source_wave.py <assembled Godot directory>")
 main(Path(sys.argv[1]).resolve())
