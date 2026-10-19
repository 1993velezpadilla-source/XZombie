extends SceneTree
## Two REAL additional SMGs in the existing full Bukkbeek game.
## No simulated weapon UI, no recolored sprite, no MP40 source changes.
func _init() -> void:
 call_deferred("_run")

func _red(message: String) -> void:
 push_error("XZIEL_SMG_WAVE_RED "+message)
 quit(27)

func _pixels(img: Image) -> Dictionary:
 var px: int=0
 var bottom: int=0
 var w:=img.get_width()
 var h:=img.get_height()
 for y in range(h):
  for x in range(w):
   if img.get_pixel(x,y).a<0.05:continue
   px+=1
   if y>h*3/4:bottom+=1
 return {"all":px,"bottom":bottom,"coverage":float(px)/float(w*h)}

func _frame(player: Node, w: Node3D, ident: String, stance: String) -> bool:
 var view:SubViewport=player.get_node("WeaponSubViewport/SubViewport") as SubViewport
 await RenderingServer.frame_post_draw
 var img:=view.get_texture().get_image()
 if img==null or img.is_empty():
  _red(ident+" no physical weapon framebuffer");return false
 var cov:=_pixels(img)
 print("XZIEL_SMG_WAVE_PIXEL id=",ident," state=",stance," data=",cov)
 if cov["coverage"]<0.010 or cov["coverage"]>0.45:
  _red(ident+" physical model missing/camera swallowed "+stance);return false
 if stance=="ads":
  var camera:=player.get_node("WeaponSubViewport/SubViewport/Camera3D") as Camera3D
  var rig:=w.get("fps_arms_root") as Node3D
  for part in ["rear","front"]:
   var point:Vector3=w.get_meta("source_sight_"+part+"_rig",Vector3(999,999,999))
   var projected:=camera.unproject_position(rig.to_global(point))
   if projected.distance_to(Vector2(view.size)*0.5)>2.0:
    _red(ident+" physical source "+part+" metal cannot center ADS");return false
  if int(cov["bottom"])<800:
   _red(ident+" ADS receiver physically clipped");return false
 var folder:="res://visual_probes/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 if img.save_png(folder+"smg_wave_"+ident+"_"+stance+".png")!=OK:
  _red(ident+" screenshot save failed");return false
 return true

func _run() -> void:
 var world:PackedScene=load("res://main.tscn")
 if world==null:_red("original main game missing");return
 var main:Node3D=world.instantiate() as Node3D
 root.add_child(main)
 await create_timer(0.8).timeout
 var player:Node=main.get_node_or_null("Player")
 if player==null:_red("original player missing");return
 var mgr:Node=player.get_node_or_null("WeaponsManager")
 if mgr==null:_red("original weapon manager missing");return
 var arr:Array=mgr.get("weapons_array")
 if arr.size()!=11 or str(arr[5].name)!="MP40Source":
  _red("original 5 demo + MP40 + Colt Thompson Kar98k + 2 SMG count regression "+str(arr.size()));return
 var view:SubViewport=player.get_node("WeaponSubViewport/SubViewport") as SubViewport
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 var camera:=player.get_node("WeaponSubViewport/SubViewport/Camera3D") as Camera3D
 camera.make_current()
 for ix in [9,10]:
  mgr.call("switch_weapon",ix)
  await create_timer(0.85).timeout
  var w:Node3D=mgr.get("current_weapon") as Node3D
  var ident:=str(w.get("source_weapon_id"))
  var expected:="ppsh" if ix==9 else "type100"
  if ident!=expected:
   _red("source weapon index mismatch "+str(ix)+"/"+ident);return
  if not bool(w.get_meta("source_weapon_bound",false)) or not bool(w.get_meta("source_optics_calibrated",false)):
   _red(ident+" genuine PSA/material/physical sight solver did not bind");return
  if not bool(w.get_meta("source_original_gun_materials_verified",false)):
   _red(ident+" original imported GLB texture lost");return
  if not bool(w.get_meta("source_root_import_repaired",false)):
   _red(ident+" -90 degree original root orientation not corrected");return
  if not await _frame(player,w,ident,"hip"):return
  root.get_node("Global").emit_signal("aim_mode_changed",true)
  await create_timer(0.50).timeout
  if not await _frame(player,w,ident,"ads"):return
  root.get_node("Global").emit_signal("aim_mode_changed",false)
  await create_timer(0.3).timeout
  w.set("current_mag",0)
  w.call("start_reload")
  var h:AnimationPlayer=w.get("_hand_anim") as AnimationPlayer
  var g:AnimationPlayer=w.get("_gun_anim") as AnimationPlayer
  if not bool(w.get("is_reloading")) or h==null or g==null:
   _red(ident+" source hands/gun reload missing");return
  print("XZIEL_SMG_RELOAD_REAL id=",ident," hands=",h.current_animation," gun=",g.current_animation)
  Input.action_press("forward")
  Input.action_press("sprint")
  await create_timer(0.25).timeout
  Input.action_release("forward")
  Input.action_release("sprint")
  if not bool(w.get("is_reloading")):
   _red(ident+" original reload cancelled by sprint");return
  if not await _frame(player,w,ident,"reload_sprint"):return
  await create_timer(0.2).timeout
  print("XZIEL_SMG_WAVE_GUN_RENDER_GREEN id=",ident)
 mgr.call("switch_weapon",5)
 await create_timer(0.3).timeout
 if str(mgr.get("current_weapon").name)!="MP40Source":
  _red("approved V6 source MP40 not restored");return
 print("XZIEL_SMG_WAVE_VISUAL_GREEN additionalSourceSMGs=2 originalMP40Intact=true")
 quit(0)
