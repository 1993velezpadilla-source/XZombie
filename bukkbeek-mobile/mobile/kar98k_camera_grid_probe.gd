extends SceneTree
## Original source GLB Kar98k + real T4 hands. Exhaustive 5x5x2
## first-person lens/eye-relief search, unlike 2-landmark fake GREEN tests.
## Do not modify source PSA or hide any meshes for a candidate screenshot.
const RELIEF_SHIFTS := [0.0, -0.15, -0.30, -0.45, -0.60]
const VIEWMODEL_FOV := [65.0, 75.0, 90.0, 105.0, 120.0]
const NEAR_CLIPS := [0.03, 0.13]

func _init()->void:call_deferred("_run")
func _meshes(node:Node3D)->Array[MeshInstance3D]:
 var out:Array[MeshInstance3D]=[]
 for obj:Node in node.find_children("*","MeshInstance3D",true,false):
  if (obj as MeshInstance3D).mesh!=null:out.append(obj as MeshInstance3D)
 return out
func _frame(view:SubViewport)->Image:
 await process_frame
 await RenderingServer.frame_post_draw
 return view.get_texture().get_image()
func _stats(image:Image)->Dictionary:
 var num:=0
 var center:=0
 var lower:=0
 var w:int=image.get_width()
 var h:int=image.get_height()
 for yy in range(0,h,4):
  for xx in range(0,w,4):
   if image.get_pixel(xx,yy).a<=0.05:continue
   num+=16
   if xx>=int(w*0.39) and xx<=int(w*0.61) and yy>=int(h*0.37) and yy<=int(h*0.64):center+=16
   if yy>=int(h*0.75):lower+=16
 return {"pixels":num,"center":center,"lower":lower}
func _render(view:SubViewport,guns:Array[MeshInstance3D],hands:Array[MeshInstance3D],which:String)->Dictionary:
 for m in guns:m.visible=which!="hands"
 for m in hands:m.visible=which!="gun"
 var img:Image=await _frame(view)
 return {"metrics":_stats(img),"image":img}

func _run()->void:
 var main:Node=load("res://main.tscn").instantiate()
 root.add_child(main)
 await create_timer(0.75).timeout
 var player:Node=main.get_node("Player")
 var manager:Node=player.get_node("WeaponsManager")
 manager.call("switch_weapon",8)
 await create_timer(0.70).timeout
 var weapon:Node3D=manager.get("current_weapon") as Node3D
 if str(weapon.get("source_weapon_id"))!="kar98k":
  push_error("XZIEL_KAR_GRID_RED authentic rifle absent");quit(4);return
 var root_rig:Node3D=weapon.get("fps_arms_root") as Node3D
 var original:Transform3D=weapon.get("focused_aim_position").transform
 var ik:SkeletonModifier3D=weapon.get("_source_ads_ik") as SkeletonModifier3D
 var gun:Node3D=weapon.get("_gun") as Node3D
 var arms:Node3D=weapon.get("_hands") as Node3D
 var guns:=_meshes(gun)
 var hands:=_meshes(arms)
 for g in guns:hands.erase(g)
 var camera:Camera3D=player.get_node("WeaponSubViewport/SubViewport/Camera3D") as Camera3D
 var view:SubViewport=player.get_node("WeaponSubViewport/SubViewport") as SubViewport
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 camera.make_current()
 root.get_node("Global").emit_signal("aim_mode_changed",true)
 await create_timer(0.52).timeout
 if ik!=null:ik.influence=0.0
 var original_fov:float=camera.fov
 var original_near:float=camera.near
 var best:Dictionary={"score":-INF}
 var dir:="res://visual_probes/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
 var sample_count:=0
 var accepted:int=0
 for shift in RELIEF_SHIFTS:
  for fov in VIEWMODEL_FOV:
   for clipping in NEAR_CLIPS:
    var t:Transform3D=original
    t.origin.z+=float(shift)
    root_rig.transform=t
    camera.fov=float(fov)
    camera.near=float(clipping)
    var gr:Dictionary=await _render(view,guns,hands,"gun")
    var hr:Dictionary=await _render(view,guns,hands,"hands")
    var full:Dictionary=await _render(view,guns,hands,"all")
    var g:Dictionary=gr["metrics"]
    var h:Dictionary=hr["metrics"]
    var gp:float=float(g["pixels"])
    var hp:float=float(h["pixels"])
    var hand_ratio:float=hp/maxf(1.0,gp)
    var bottom:float=float(g["lower"])
    var center_arms:float=float(h["center"])
    # Make visible original receiver in lower quarter essential,
    # no reward for mere tiny centered iron sight.
    var score:float=bottom*1.2+gp*0.15-hp*0.15-center_arms*1.5
    # Adversarial critic: pure visible-pixel optimization selected a HUGE
    # Kar98k BUTTSTOCK pressed into the 3cm near-plane as previous "winner".
    # It looked like a giant round black block, not iron sights! Reject
    # total-gun blobs, sight-lane obstruction, lens-inside-stock artifacts,
    # and a screen full of unrelated Marine sleeves.
    var physically_plausible:bool=(
     gp>=12000 and gp<=85000 and bottom>=2500 and bottom<=30000
     and center_arms<=5000 and float(g["center"])>=2000
     and float(g["center"])<=15000 and hp<=115000
     and hand_ratio<=3.5 and float(fov)<=100.0
    )
    if not physically_plausible:score-=1000000.0
    else:accepted+=1
    var tag:="v13_kar_Z"+str(int(-float(shift)*100))+"_fov"+str(int(fov))+"_near"+str(int(float(clipping)*100))
    if score>float(best["score"]):
     best={"score":score,"label":tag,"gun":g,"hands":h,
      "original_iron_alignment_shift_z":shift,"fov":fov,"near":clipping}
     (gr["image"] as Image).save_png(dir+"v13_source_best_gun.png")
     (hr["image"] as Image).save_png(dir+"v13_source_best_hands.png")
     (full["image"] as Image).save_png(dir+"v13_source_best_full.png")
    if fov==75.0 or fov==105.0:
     if float(clipping)==0.03 and (float(shift)==-0.30 or float(shift)==-0.45):
      (full["image"] as Image).save_png(dir+tag+"_full.png")
    print("XZIEL_KAR_GRID_SAMPLE id=",tag," gun=",g," hands=",h,
     " gun_lower_pixels=",bottom," hand_ratio=",hand_ratio," score=",score)
    sample_count+=1
 for m in guns:m.visible=true
 for m in hands:m.visible=true
 root_rig.transform=original
 camera.fov=original_fov
 camera.near=original_near
 set_meta("kar98k_source_camera_candidates_accepted",accepted)
 print("XZIEL_KAR_GRID_COMPLETE samples=",sample_count," visually_plausible=",accepted,
  " geometry_only_max=",JSON.stringify(best))
 if accepted == 0:
  # Keep automation operational to upload all 50 diagnostic frames,
  # but NEVER mark the actual Kar98k release gauntlet GREEN.
  print("XZIEL_KAR_GRID_NO_SAFE_CAMERA source_rig_requires_anatomical_retarget=true")
 quit(0)
