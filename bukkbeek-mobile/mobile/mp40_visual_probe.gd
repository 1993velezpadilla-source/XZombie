extends SceneTree
## Pixel-level MP40 diagnostic in real Bukkbeek scene, rendered with xvfb.
## CI headless-only gates cannot certify what the player sees on Android.
func _init() -> void:
 call_deferred("_run")

func _capture(root_window: Window, v: SubViewport, label: String) -> void:
 await RenderingServer.frame_post_draw
 var image: Image = root_window.get_texture().get_image()
 var isolated: Image = v.get_texture().get_image()
 if image == null or isolated == null or image.is_empty() or isolated.is_empty():
  push_error("MP40_VISUAL_RED frame unavailable: " + label)
  quit(6)
  return
 # An all-transparent subviewport was previously incorrectly labeled GREEN:
 # the original unbounded camera lerp threw the gun 479 km out of view.
 var used: Rect2i = isolated.get_used_rect()
 if used.size.x < 100 or used.size.y < 100:
  push_error("MP40_VISUAL_RED: gun/arms invisible in "+label+" subviewport used_rect="+str(used))
  quit(6)
  return
 var folder := "res://visual_probes/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 if image.save_png(folder + label + ".png") != OK:
  push_error("MP40_VISUAL_RED failed to save " + label)
  quit(6)
  return
 isolated.save_png(folder + label + "_weapon_only.png")
 # Quantitative real-render regression gate, NOT a guessed aiming coordinate:
 # original stable MP40 ADS occupied 8.03% alpha of this 1280x720 viewmodel,
 # but the source-landmark solver occupied 58.39% and put hands in camera.
 # Fail BEFORE Android export even if source markers project perfectly.
 if label == "ads":
  var viewport_pixels: int = isolated.get_width() * isolated.get_height()
  var occupied_pixels: int = 0
  for yy: int in range(isolated.get_height()):
   for xx: int in range(isolated.get_width()):
    if isolated.get_pixel(xx, yy).a > 0.04:
     occupied_pixels += 1
  var alpha_coverage: float = float(occupied_pixels) / float(viewport_pixels)
  print("MP40_VISUAL_ACTUAL_ADS_COVERAGE fraction=", alpha_coverage,
   " prior_visible_reference=0.0803 candidate_failed=0.5839")
  if alpha_coverage > 0.30:
   push_error("MP40_VISUAL_RED: optical solver moved source MP40 inside camera. No APK release.")
   quit(6)
   return
 print("MP40_VISUAL_SCREENSHOT_GREEN ", label, " ", image.get_width(), "x", image.get_height())

func _run() -> void:
 var world: PackedScene = load("res://main.tscn") as PackedScene
 if world == null:
  push_error("MP40_VISUAL_RED missing real world")
  quit(3)
  return
 var main: Node3D = world.instantiate() as Node3D
 root.add_child(main)
 await create_timer(0.3).timeout
 var player: Node = main.get_node_or_null("Player")
 var manager: Node = player.get_node_or_null("WeaponsManager") if player else null
 if manager == null:
  push_error("MP40_VISUAL_RED no player manager")
  quit(3)
  return
 manager.call("switch_weapon", 5)
 await create_timer(0.8).timeout
 var mp40: Node = player.get_node("WeaponsManager/MP40Source")
 var aim_camera: Camera3D = player.get_node("CameraPivot/CameraHolder/MainCamera")
 var weapon_view: SubViewport = player.get_node("WeaponSubViewport/SubViewport")
 var weapon_camera: Camera3D = player.get_node("WeaponSubViewport/SubViewport/Camera3D")
 weapon_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 weapon_camera.make_current()
 var gun: Node3D = mp40.get("_gun_root") as Node3D
 var hands: Node3D = mp40.get("_hands_root") as Node3D
 print("MP40_VISUAL_DEBUG actual_weapon=", manager.get("current_weapon").name,
  " visible=", mp40.visible,
  " gun=", gun.global_transform,
  " hands=", hands.global_transform,
  " camera_current=", weapon_view.get_camera_3d().name if weapon_view.get_camera_3d() != null else "NONE",
  " shared_world=", aim_camera.get_world_3d() == weapon_camera.get_world_3d(),
  " root_visible=", mp40.get_node("FPSHandsRoot").is_visible_in_tree(),
  " gun_camera_distance=", gun.global_position.distance_to(weapon_camera.global_position))
 print("MP40_VISUAL_CAMERA_FOV prior= ", aim_camera.fov, " weapon=", weapon_camera.fov)
 await _capture(root, weapon_view, "hip")
 root.get_node("Global").emit_signal("aim_mode_changed", true)
 await create_timer(0.8).timeout
 print("MP40_VISUAL_ADS_GEOMETRY main_fov=", aim_camera.fov,
  " weapon_fov=", weapon_camera.fov,
  " root_transform=", mp40.get_node("FPSHandsRoot").transform)
 if absf(aim_camera.fov - weapon_camera.fov) > 0.65:
  push_error("MP40_VISUAL_RED: two ADS camera FOVs still mismatched")
  quit(6)
  return
 # Certify original source 3D sight vertices projected by SAME Godot
 # Camera3D used to render the weapon, independent of screenshot appearance.
 var source_rig: Node3D = mp40.get_node("FPSHandsRoot") as Node3D
 if not bool(mp40.get_meta("source_mp40_optical_axis_solved", false)):
  push_error("MP40_VISUAL_RED: original GLB optical axis unsolved")
  quit(6)
  return
 var sight_center: Vector2 = Vector2(weapon_view.size) * 0.5
 for part: String in ["rear","front"]:
  var point: Vector3 = mp40.get_meta("source_mp40_" + ("rear_sight_rig" if part == "rear" else "front_post_rig")) as Vector3
  var pixel: Vector2 = weapon_camera.unproject_position(source_rig.to_global(point))
  print("MP40_VISUAL_PHYSICAL_SIGHT_PIXEL part=",part," projected=",pixel," target=",sight_center,
   " error_px=",pixel.distance_to(sight_center))
  if pixel.distance_to(sight_center) > 2.0:
   push_error("MP40_VISUAL_RED: real GLB "+part+" not on camera aim ray")
   quit(6)
   return
 var inspect_mesh: MeshInstance3D = mp40.call("_find_source_mesh", gun) as MeshInstance3D
 if inspect_mesh == null:
  push_error("MP40_VISUAL_RED unable to access drawn gun mesh")
  quit(6)
  return
 var raw_rear: Vector3 = inspect_mesh.to_global(Vector3(-0.157399, 0.060, -0.012522))
 var raw_front: Vector3 = inspect_mesh.to_global(Vector3(0.366805, 0.053975, -0.0125345))
 var computed_rear: Vector3 = mp40.get_node("FPSHandsRoot").to_global(mp40.get_meta("source_mp40_rear_sight_rig") as Vector3)
 var computed_front: Vector3 = mp40.get_node("FPSHandsRoot").to_global(mp40.get_meta("source_mp40_front_post_rig") as Vector3)
 print("MP40_VISUAL_SOURCE_POSED_MESH source_rear_px=",weapon_camera.unproject_position(raw_rear),
  " source_front_px=",weapon_camera.unproject_position(raw_front),
  " computed_rear_px=",weapon_camera.unproject_position(computed_rear),
  " computed_front_px=",weapon_camera.unproject_position(computed_front),
  " mesh_global=",inspect_mesh.global_transform)
 # Reject false GREEN from calibrating at the temporary bone-bind pose.
 # Both source-calibrated optical aperture and ORIGINAL front post must land on aiming ray once
 # the source hand idle animation is actually posed and the weapon rendered.
 var projected_rear_px: Vector2 = weapon_camera.unproject_position(raw_rear)
 var projected_front_px: Vector2 = weapon_camera.unproject_position(raw_front)
 if (projected_rear_px.distance_to(sight_center) > 2.0
  or projected_front_px.distance_to(sight_center) > 2.0):
  push_error("MP40_VISUAL_RED: real rendered mesh differs from calibration markers; source skeleton pose stale.")
  quit(6)
  return
 print("MP40_VISUAL_ACTUAL_MESH_VERTEX_GREEN projected_rear=",projected_rear_px,
  " projected_front=",projected_front_px)
 await _capture(root, weapon_view, "ads")
 # Optical fit is source-derived; do not run arbitrary X/Y/yaw sweeps.
 # Save real empty-reload samples before and after the hand withdraws.
 root.get_node("Global").emit_signal("aim_mode_changed", false)
 await create_timer(0.4).timeout
 mp40.set("current_mag", 0)
 mp40.call("start_reload")
 var hands_ap: AnimationPlayer = mp40.get("_hands_anim") as AnimationPlayer
 var gun_ap: AnimationPlayer = mp40.get("_gun_anim") as AnimationPlayer
 if not mp40.get("is_reloading") or hands_ap == null or gun_ap == null:
  push_error("MP40_VISUAL_RED no real source reload")
  quit(3)
  return
 var timepoints: Array = [2.2, 3.7, 4.12]
 for t in timepoints:
  hands_ap.seek(t, true)
  gun_ap.seek(t, true)
  hands_ap.pause()
  gun_ap.pause()
  await create_timer(0.15).timeout
  await _capture(root, weapon_view, "reload_" + str(t).replace(".", "_"))
 mp40.get_node("ReloadTimer").stop()
 mp40.call("_on_reload_timer_timeout")
 await create_timer(0.3).timeout
 await _capture(root, weapon_view, "reload_finished_idle")
 quit(0)
