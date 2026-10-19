extends SceneTree
## Render actual current source weapon in Bukkbeek scene using source camera.
## No invented mock weapon sprites: captures GPU output from Godot 4.6 xvfb.
func _init() -> void:
 call_deferred("_run")
 
func _fail(label: String) -> void:
 push_error("XZIEL_MULTI_GUN_VISUAL_RED " + label)
 quit(5)

func _capture(player: Node, weapon: Node3D, label: String, ads: bool) -> bool:
 await RenderingServer.frame_post_draw
 var view: SubViewport=player.get_node("WeaponSubViewport/SubViewport") as SubViewport
 var cam: Camera3D=player.get_node("WeaponSubViewport/SubViewport/Camera3D") as Camera3D
 var shot: Image=root.get_texture().get_image()
 var weapon_image: Image=view.get_texture().get_image()
 if shot==null or weapon_image==null or shot.is_empty() or weapon_image.is_empty():
  _fail(label+" empty framebuffer");return false
 var used:Rect2i=weapon_image.get_used_rect()
 var area:float=float(weapon_image.get_width()*weapon_image.get_height())
 var coverage:float=0.0
 for y in range(weapon_image.get_height()):
  for x in range(weapon_image.get_width()):
   if weapon_image.get_pixel(x,y).a>0.04:coverage+=1.0
 coverage/=area
 print("XZIEL_MULTI_GUN_VISUAL_FRAME id=",label," ads=",ads,
  " alpha_coverage=",coverage," used=",used,
  " viewport=",weapon_image.get_size())
 # Distinct from original MP40 gate. Every new gun must visibly occupy
 # the real weapon renderer and must not swallow the whole viewport.
 if coverage<0.012 or coverage>0.35 or used.size.x<100 or used.size.y<80:
  _fail(label+" invisible/clipped/oversized coverage="+str(coverage));return false
 if ads:
  var source_rig: Node3D=weapon.get("fps_arms_root")
  for part in ["rear","front"]:
   var local:Vector3=weapon.get_meta("source_sight_"+part+"_rig",Vector3(999,999,999)) as Vector3
   var pixel:Vector2=cam.unproject_position(source_rig.to_global(local))
   var center:Vector2=Vector2(view.size)*0.5
   print("XZIEL_MULTI_GUN_SIGHT_PIXEL id=",label," part=",part," px=",pixel,
    " target=",center," error_px=",pixel.distance_to(center))
   if pixel.distance_to(center)>2.0:
    _fail(label+" authentic source front/rear aperture not on aim ray "+part);return false
 var folder:="res://visual_probes/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 if shot.save_png(folder+label+".png")!=OK:
  _fail(label+" unable to save frame");return false
 weapon_image.save_png(folder+label+"_weapon_only.png")
 print("XZIEL_MULTI_GUN_SCREENSHOT_GREEN "+label)
 return true
 
func _run() -> void:
 var scene:PackedScene=load("res://main.tscn") as PackedScene
 if scene==null:_fail("no genuine game scene");return
 var main:Node3D=scene.instantiate() as Node3D
 root.add_child(main)
 await create_timer(0.6).timeout
 var player:Node=main.get_node_or_null("Player")
 if player==null:_fail("real player missing");return
 var mgr:Node=player.get_node_or_null("WeaponsManager")
 if mgr==null:_fail("manager missing");return
 var view:SubViewport=player.get_node("WeaponSubViewport/SubViewport") as SubViewport
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 var view_camera:Camera3D=player.get_node("WeaponSubViewport/SubViewport/Camera3D") as Camera3D
 view_camera.make_current()
 for i in [6,7,8]:
  mgr.call("switch_weapon",i)
  await create_timer(0.65).timeout
  var gun:Node3D=mgr.get("current_weapon") as Node3D
  var id:=str(gun.get("source_weapon_id"))
  if not bool(gun.get_meta("source_optics_calibrated",false)):
   _fail(id+" source vertex fit not completed");return
  if not await _capture(player,gun,"v9_"+id+"_hip",false):return
  main.get_node("Global").emit_signal("aim_mode_changed",true)
  await create_timer(0.55).timeout
  if not await _capture(player,gun,"v9_"+id+"_ads",true):return
  main.get_node("Global").emit_signal("aim_mode_changed",false)
  await create_timer(0.25).timeout
 print("XZIEL_MULTI_GUN_VISUAL_GREEN genuineCameras=3 sourceWeapons=3")
 quit(0)
