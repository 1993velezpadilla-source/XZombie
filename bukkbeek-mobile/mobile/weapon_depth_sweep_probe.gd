extends SceneTree
## Exhaustive *visible* camera-depth probe. Original gun+hands rig moves in
## unison, preserving grip. Do not mistake source line optical anchor for
## accepted first-person composition. Source source_weapon_fit owns the basis.
const DEPTH_STEPS := [-0.22, -0.12, 0.0, 0.12, 0.22, 0.35]
const WIDTH := 1280
const HEIGHT := 720
func _init()->void:
 call_deferred("_run")

func _meshes(rootnode:Node3D)->Array[MeshInstance3D]:
 var out:Array[MeshInstance3D]=[]
 for node:Node in rootnode.find_children("*","MeshInstance3D",true,false):
  var m:=node as MeshInstance3D
  if m.mesh!=null:out.append(m)
 return out

func _image(view:SubViewport)->Image:
 await process_frame
 await RenderingServer.frame_post_draw
 return view.get_texture().get_image()

func _pixels(img:Image)->Dictionary:
 var occupied:=0
 var center:=0
 var upper:=0
 var lower:=0
 var half:=0
 var w:=img.get_width()
 var h:=img.get_height()
 for y in range(h):
  for x in range(w):
   if img.get_pixel(x,y).a<=0.06:continue
   occupied+=1
   if absi(x-w/2)<=110 and absi(y-h/2)<=100:center+=1
   if y<h/2:upper+=1
   if y>=h*3/4:lower+=1
   if y>=h/4 and y<h*3/4:half+=1
 return {"all":occupied,"center":center,"upper":upper,"lower":lower,"middle":half}

func _render_layer(view:SubViewport,gun_meshes:Array[MeshInstance3D],hand_meshes:Array[MeshInstance3D],layer:String)->Dictionary:
 for m in gun_meshes:m.visible=layer!="arms"
 for m in hand_meshes:m.visible=layer!="gun"
 var img:Image=await _image(view)
 var metric:Dictionary=_pixels(img)
 return {"image":img,"metric":metric}

func _run()->void:
 var scene:PackedScene=load("res://main.tscn") as PackedScene
 if scene==null:
  push_error("XZIEL_SWEEP_RED source game missing");quit(3);return
 var main:Node=scene.instantiate()
 root.add_child(main)
 await create_timer(0.8).timeout
 var p:Node=main.get_node_or_null("Player")
 if p==null:push_error("XZIEL_SWEEP_RED player missing");quit(3);return
 var mgr:Node=p.get_node("WeaponsManager")
 var view:SubViewport=p.get_node("WeaponSubViewport/SubViewport") as SubViewport
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 var view_cam:Camera3D=p.get_node("WeaponSubViewport/SubViewport/Camera3D") as Camera3D
 view_cam.make_current()
 var path:="res://visual_probes/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
 for idx in [6,7,8]:
  mgr.call("switch_weapon",idx)
  await create_timer(0.6).timeout
  var w:Node3D=mgr.get("current_weapon") as Node3D
  var id:String=str(w.get("source_weapon_id"))
  var rig:Node3D=w.get("fps_arms_root") as Node3D
  var gun:Node3D=w.get("_gun") as Node3D
  var hands:Node3D=w.get("_hands") as Node3D
  var original:=w.get("focused_aim_position").transform as Transform3D
  var gun_meshes:=_meshes(gun)
  var hand_meshes:=_meshes(hands)
  for m in gun_meshes:hand_meshes.erase(m)
  root.get_node("Global").emit_signal("aim_mode_changed",true)
  await create_timer(0.38).timeout
  # Only adjusting viewmodel ROOT depth, never deforming or rotating source
  # geometry. Individual cameras/family need their own photographic fit.
  for i in range(DEPTH_STEPS.size()):
   var delta:float=DEPTH_STEPS[i]
   var test:=original
   test.origin.z+=delta
   rig.transform=test
   var g:Dictionary=await _render_layer(view,gun_meshes,hand_meshes,"gun")
   var h:Dictionary=await _render_layer(view,gun_meshes,hand_meshes,"arms")
   var all_m:Dictionary=await _render_layer(view,gun_meshes,hand_meshes,"all")
   var gp:Dictionary=g["metric"]
   var hp:Dictionary=h["metric"]
   var ratio:float=float(hp["all"])/maxf(float(gp["all"]),1.0)
   var bottom_fraction:float=float(gp["lower"])/maxf(float(gp["all"]),1.0)
   print("XZIEL_V11_SWEEP id=",id," shift_z=",delta,
    " gun_pixels=",gp," hand_pixels=",hp," hand_gun_ratio=",ratio,
    " receiver_bottom_fraction=",bottom_fraction)
   (g["image"] as Image).save_png(path+id+"_shift"+str(i)+"_gun.png")
   (h["image"] as Image).save_png(path+id+"_shift"+str(i)+"_arms.png")
   (all_m["image"] as Image).save_png(path+id+"_shift"+str(i)+"_full.png")
  if id=="kar98k":
   var old_fov:float=view_cam.fov
   for relief_shift in [-0.45,-0.65,-0.80]:
    for fov_candidate in [48.0,60.0]:
     var test_rifle:=original
     test_rifle.origin.z+=float(relief_shift)
     rig.transform=test_rifle
     view_cam.fov=float(fov_candidate)
     var kar_g:Dictionary=await _render_layer(view,gun_meshes,hand_meshes,"gun")
     var kar_h:Dictionary=await _render_layer(view,gun_meshes,hand_meshes,"arms")
     var kar_all:Dictionary=await _render_layer(view,gun_meshes,hand_meshes,"all")
     var px:Dictionary=kar_g["metric"]
     print("XZIEL_V11_RIFLE_BODY id=",id," shift_z=",relief_shift,
      " viewmodel_fov=",fov_candidate," gun_pixels=",px,
      " arm_pixels=",kar_h["metric"],
      " bottom_body_fraction=",float(px["lower"])/maxf(1.0,float(px["all"])))
     var label:="kar98k_deep"+str(int(-relief_shift*100))+"_fov"+str(int(fov_candidate))
     (kar_g["image"] as Image).save_png(path+label+"_gun.png")
     (kar_all["image"] as Image).save_png(path+label+"_full.png")
   view_cam.fov=old_fov
  rig.transform=original
  root.get_node("Global").emit_signal("aim_mode_changed",false)
  if id=="colt":
   await create_timer(0.45).timeout
   var hip_pose:Transform3D=w.get("standard_aim_position").transform
   for h in range(DEPTH_STEPS.size()):
    var offset:float=DEPTH_STEPS[h]
    var hip_test:=hip_pose
    hip_test.origin.z+=offset
    rig.transform=hip_test
    var hg:Dictionary=await _render_layer(view,gun_meshes,hand_meshes,"gun")
    var hh:Dictionary=await _render_layer(view,gun_meshes,hand_meshes,"arms")
    var ha:Dictionary=await _render_layer(view,gun_meshes,hand_meshes,"all")
    print("XZIEL_V11_COLT_HIP_SHIFT id=",id," shift_z=",offset,
     " gun_pixels=",hg["metric"]," arms_pixels=",hh["metric"])
    (ha["image"] as Image).save_png(path+id+"_hip_shift"+str(h)+"_full.png")
   rig.transform=hip_pose
 print("XZIEL_V11_DEPTH_SWEEP_COMPLETE independent_original_source_guns=3 candidates_each=6")
 quit(0)
