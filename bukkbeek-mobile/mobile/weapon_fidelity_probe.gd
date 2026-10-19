extends SceneTree
## Adversarial review of REAL Godot 4.6 geometry. No "GREEN" certification
## from centered sight anchors alone: independently render GUN and HANDS.
## This directly detects sleeves occluding a correctly-centered optic.
func _init() -> void:
 call_deferred("_run")

func _mesh_list(root_node: Node3D) -> Array[MeshInstance3D]:
 var out: Array[MeshInstance3D] = []
 for n: Node in root_node.find_children("*","MeshInstance3D",true,false):
  if (n as MeshInstance3D).mesh != null: out.append(n as MeshInstance3D)
 return out

func _count_pixels(image: Image) -> Dictionary:
 var alpha_pixels: int = 0
 var sight_pixels: int = 0
 var middle_pixels: int = 0
 var bottom_pixels: int = 0
 var w:=image.get_width()
 var h:=image.get_height()
 for y in range(h):
  for x in range(w):
   if image.get_pixel(x,y).a <= 0.05:continue
   alpha_pixels+=1
   if absi(x-w/2)<85 and absi(y-h/2)<85:sight_pixels+=1
   if y>=h/4 and y<h*3/4:middle_pixels+=1
   if y>h*3/4:bottom_pixels+=1
 return {"all":alpha_pixels,"center":sight_pixels,"middle":middle_pixels,"bottom":bottom_pixels}

func _capture(view: SubViewport, id: String, mode: String,
 gun_meshes: Array[MeshInstance3D], hand_meshes: Array[MeshInstance3D]) -> Dictionary:
 for mesh in gun_meshes:mesh.visible=mode!="hands"
 for mesh in hand_meshes:mesh.visible=mode!="gun"
 # Always allow one fully rendered frame after mesh visibility changes.
 await process_frame
 await RenderingServer.frame_post_draw
 var image: Image=view.get_texture().get_image()
 if image==null or image.is_empty():
  push_error("XZIEL_REAL_FIDELITY_RED framebuffer unavailable "+id)
  quit(5);return {}
 var folder:="res://visual_probes/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 if image.save_png(folder+id+"_"+mode+".png") != OK:
  push_error("XZIEL_REAL_FIDELITY_RED failed screenshot "+id)
  quit(5);return {}
 var m:=_count_pixels(image)
 print("XZIEL_REAL_FIDELITY_LAYER id=",id," mode=",mode," pixels=",m,
  " mesh_guns=",gun_meshes.size()," mesh_hands=",hand_meshes.size())
 return m

func _run() -> void:
 var main_scene: PackedScene=load("res://main.tscn") as PackedScene
 if main_scene==null:push_error("XZIEL_REAL_FIDELITY_RED missing real game");quit(5);return
 var main:Node3D=main_scene.instantiate() as Node3D
 root.add_child(main)
 await create_timer(0.72).timeout
 var player:Node=main.get_node_or_null("Player")
 if player==null:push_error("XZIEL_REAL_FIDELITY_RED missing player");quit(5);return
 var mgr:Node=player.get_node_or_null("WeaponsManager")
 var view:SubViewport=player.get_node("WeaponSubViewport/SubViewport") as SubViewport
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 var cam:Camera3D=player.get_node("WeaponSubViewport/SubViewport/Camera3D") as Camera3D
 cam.make_current()
 for idx in [6,7,8]:
  mgr.call("switch_weapon",idx)
  await create_timer(0.7).timeout
  var w:Node3D=mgr.get("current_weapon") as Node3D
  var id:=str(w.get("source_weapon_id"))
  var hands:Node3D=w.get("_hands") as Node3D
  var gun:Node3D=w.get("_gun") as Node3D
  var hand_meshes:=_mesh_list(hands)
  var gun_meshes:=_mesh_list(gun)
  if hand_meshes.is_empty() or gun_meshes.is_empty():
   push_error("XZIEL_REAL_FIDELITY_RED real hand/gun surfaces absent "+id)
   quit(5);return
  for state in ["hip","ads"]:
   root.get_node("Global").emit_signal("aim_mode_changed",state=="ads")
   await create_timer(0.46).timeout
   var name:=id+"_"+state
   var full:Dictionary=await _capture(view,name,"full",gun_meshes,hand_meshes)
   var weapon:Dictionary=await _capture(view,name,"gun",gun_meshes,hand_meshes)
   var arm:Dictionary=await _capture(view,name,"hands",gun_meshes,hand_meshes)
   for mesh in gun_meshes:mesh.visible=true
   for mesh in hand_meshes:mesh.visible=true
   if full.is_empty() or weapon.is_empty() or arm.is_empty():return
   var center_g:=float(weapon["center"])
   var center_h:=float(arm["center"])
   var ratio:=center_h/maxf(1.0,center_g)
   print("XZIEL_REAL_FIDELITY_REPORT id=",id," stance=",state,
    " center_hands_over_gun_ratio=",ratio,
    " total_gun_px=",weapon["all"]," total_hands_px=",arm["all"],
    " screen_center_hand_px=",center_h," screen_center_gun_px=",center_g,
    " captured_source_materials=true")
  root.get_node("Global").emit_signal("aim_mode_changed",false)
 print("XZIEL_REAL_FIDELITY_AUDIT_CAPTURED originals_gun_hands_isolated=true NOT_PRODUCTION_APPROVED=true")
 quit(0)
