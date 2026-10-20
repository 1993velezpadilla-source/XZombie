#!/usr/bin/env python3
"""MP40 2.5D original-art flipbook assembler. No sourced game pixels.

Requires original animation sheet PNGs as input; cannot fabricate missing poses.
Creates the exact 107 frames named in motion_manifest.json.
Do not ship without human optical/limb-occlusion review and Pixel Fold test.
"""
from pathlib import Path
import json, math, argparse
from PIL import Image

SOURCES = {
 "master": ("master.png",3), "equip": ("equip.png",4),
 "hip": ("hip.png",6), "ads_in": ("ads_in.png",5),
 "ads_out": ("ads_out.png",6), "sprint": ("sprint.png",4),
 "tactical": ("reload_tactical.png",6), "empty": ("reload_empty.png",8),
}
# (phase_id, input source sheet, inclusive start pose, inclusive end pose)
MAPPING = {
 "hip_idle":[("hold_a","hip",0,0),("hold_b","hip",1,1)],
 "hip_fire":[("kick","hip",2,3),("return","hip",4,5)],
 "ads_in":[("raise","ads_in",0,2),("sight_settle","ads_in",3,4)],
 "ads_idle":[("ads_breathe_a","ads_in",3,3),("ads_breathe_b","ads_in",4,4)],
 "ads_fire":[("ads_kick","ads_out",0,1),("ads_return","ads_out",1,2)],
 "ads_out":[("lower","ads_out",3,4),("hip_settle","ads_out",4,5)],
 "sprint":[("sprint_left","sprint",0,1),("sprint_right","sprint",2,3)],
 "equip":[("draw","equip",0,2),("ready","equip",2,3)],
 "reload_tactical":[("reach_mag","tactical",0,1),("mag_out","tactical",1,2),
                   ("fresh_mag","tactical",2,3),("mag_in","tactical",3,4),("return","tactical",4,5)],
 "reload_empty":[("reach_mag","empty",0,0),("mag_out","empty",1,2),
                 # DICE source order: OLD mag stays held while bolt is racked.
                 ("bolt_lock_with_old_mag_held","master",2,2),
                 ("fresh_mag_upside_down_from_pouch","empty",3,3),
                 ("mag_in","empty",4,5),("bolt_release","empty",6,6),
                 ("return","empty",7,7)],
 # These three are WIP repurposed poses: NOT visually source-certified.
 "dry_fire":[("dry_click","hip",0,0),("dry_settle","hip",1,1)],
 "inspect":[("inspect_side","master",0,0),("inspect_return","hip",0,0)],
 "melee":[("melee_windup","sprint",1,1),("melee_impact","sprint",2,2),("melee_recover","hip",0,0)]
}

def assemble(source: Path, manifest: Path, out: Path):
    config=json.loads(manifest.read_text())
    assert config["schema_version"] == 1 and config["weapon_id"] == "mp40_25d"
    assert set(config["clips"]) == set(MAPPING), "Animation manifest drift"
    sheets={}
    for name,(filename,n) in SOURCES.items():
        path=source/filename
        if not path.is_file(): raise FileNotFoundError(f"MP40_25D_SOURCE_RED: required ART source {path}")
        im=Image.open(path).convert("RGBA")
        if im.size != (2172,724): raise ValueError(f"MP40_25D_SHEET_RED {path}: {im.size}")
        if im.getchannel("A").getextrema() != (0,255):
            raise ValueError(f"MP40_25D_ALPHA_RED no real transparent pixels {path}")
        sheets[name]=(im,n)
    out.mkdir(parents=True,exist_ok=True)
    count=0
    for clip,details in config["clips"].items():
        mapping=MAPPING[clip]
        if [x[0] for x in mapping] != [p["id"] for p in details["phases"]]:
            raise AssertionError("MP40_25D_PHASE_DRIFT "+clip)
        for phase,(phase_name,sheet_name,pose_start,pose_end) in zip(details["phases"],mapping):
            frames=phase["frames"]
            im,n=sheets[sheet_name]
            for idx in range(frames):
                source_pose=round(pose_start+(pose_end-pose_start)*idx/max(1,frames-1))
                x0=round(im.width*source_pose/n);x1=round(im.width*(source_pose+1)/n)
                pose=im.crop((x0,0,x1,724))
                canvas=Image.new("RGBA",(724,724),(0,0,0,0))
                canvas.alpha_composite(pose,((724-pose.width)//2,0))
                # modest positional easing: no morph or double-image ghost blend
                lift=-round(math.sin(math.pi*idx/max(1,frames-1))*2)
                if lift:
                    translated=Image.new("RGBA",(724,724),(0,0,0,0))
                    translated.alpha_composite(canvas,(0,lift))
                    canvas=translated
                path=out/clip/f'{phase_name}_{idx:02}.png'
                path.parent.mkdir(parents=True,exist_ok=True)
                canvas.save(path,optimize=True)
                count+=1
    if count != 107: raise AssertionError(f"MP40_25D_FRAMES_RED {count}/107")
    evidence={"frames_exported":count,"status":"WIP_NOT_PRODUCTION_APPROVED",
              "original_source_sheets":sorted(x[0] for x in SOURCES.values()),
              "known_visual_defects":["sheet boundary clipping","pose discontinuity","dry-fire/inspect/melee need original frames"],
              "source":"original concept art, NOT copied Battlefield V media",
              "empty_reload_order":"mag_out -> bolt_pull_while_old_mag_held -> fresh_mag -> mag_in -> release"}
    (out.parent/"frame_art_quality.json").write_text(json.dumps(evidence,indent=2)+"\n")
    print("MP40_25D_ASSEMBLY_PREVIEW_WIP frames=107 original_2_5d_art=true production_approved=false")

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("sheet_directory",type=Path);p.add_argument("manifest",type=Path);p.add_argument("out_directory",type=Path)
    args=p.parse_args()
    assemble(args.sheet_directory,args.manifest,args.out_directory)
