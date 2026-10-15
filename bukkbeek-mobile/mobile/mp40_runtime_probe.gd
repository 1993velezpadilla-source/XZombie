extends SceneTree
## Actual original-game runtime gate, not a mock nor a build-only success check.
## Headless cannot certify screenshot composition/ADS visual/reload hand contact.
## It CAN reject missing source animation players, broken tag_weapon, absent
## textured meshes, unbound Bukkbeek player weapon, and dead fire/reload paths.

func _init() -> void:
 call_deferred("_run")

func _fail(reason: String) -> void:
 push_error("BUKKBEEK_MP40_LIVE_RED: " + reason)
 quit(3)

func _run() -> void:
 var packed: PackedScene = load("res://player/player.tscn") as PackedScene
 if packed == null:
  _fail("real Bukkbeek player scene unavailable")
  return
 var player: Node = packed.instantiate()
 root.add_child(player)
 await process_frame
 await process_frame
 var manager: Node = player.get_node_or_null("WeaponsManager")
 var mp40: Node3D = player.get_node_or_null("WeaponsManager/MP40Source") as Node3D
 if manager == null or mp40 == null:
  _fail("real player is missing sixth MP40")
  return
 var weapon_nodes: Array = manager.get("weapons_array")
 if weapon_nodes.size() != 6 or not weapon_nodes.has(mp40):
  _fail("five old guns plus new MP40 were not registered")
  return
 if not bool(mp40.get_meta("source_mp40_ready", false)):
  _fail("MP40 did not bind real original hands/gun/PSAs/textures")
  return
 if not bool(mp40.get_meta("source_mp40_root_rotation_fixed", false)):
  _fail("source gun root animation -90 degree flip not corrected")
  return
 if not bool(mp40.get_meta("source_mp40_bolt_idle_snap_fixed", false)):
  _fail("charging bolt end-of-reload idle pose was not repaired")
  return
 # Source-compatible complete front ring confirmed in the rendered
 # scene. Viewmodel/gameplay camera FOV must also match (test below).
 if absf(float(mp40.get_meta("mp40_ads_fine_x", 0.0)) + 0.004) > 0.0001:
  _fail("proven source ADS X marker offset missing")
  return
 if (absf(float(mp40.get_meta("mp40_ads_fine_y", 0.0)) + 0.011) > 0.0001
  or absf(float(mp40.get_meta("mp40_ads_fine_pitch", 0.0)) - 0.60) > 0.001):
  _fail("source ADS front ring marker height / pitch missing")
  return
 var hip_marker: Marker3D = mp40.get_node_or_null("StandardAimPosition") as Marker3D
 var ads_marker: Marker3D = mp40.get_node_or_null("FocusedAimPosition") as Marker3D
 if hip_marker == null or ads_marker == null:
  _fail("original Bukkbeek ADS and HIP markers missing")
  return
 if not bool(mp40.get_meta("source_mp40_mag_idle_contract_ready", false)):
  _fail("j_clip authentic magazine end-to-idle pose contract not loaded")
  return
 var reseat_report: Dictionary = mp40.get_meta("source_mp40_late_second_seat_removed", {}) as Dictionary
 if reseat_report.size() != 2:
  _fail("two source reload variants have no late second seating correction")
  return
 var gun_ap: AnimationPlayer = mp40.get("_gun_anim") as AnimationPlayer
 for variant: String in [str(mp40.get("_gun_reload_clip")), str(mp40.get("_gun_reload_empty_clip"))]:
  if not reseat_report.has(variant):
   _fail("missing magazine late-seating correction for " + variant)
   return
  var orig_gap: float = float((reseat_report[variant] as Dictionary).get("original_late_displacement_m", -1))
  if orig_gap < 0.025 or orig_gap > 0.095:
   _fail("source late 50mm magazine motion provenance invalid: " + variant)
   return
  var a: Animation = gun_ap.get_animation(variant)
  var mag_pos_track: int = -1
  for i: int in range(a.get_track_count()):
   if str(a.track_get_path(i)).ends_with(":j_clip") and a.track_get_type(i) == Animation.TYPE_POSITION_3D:
    mag_pos_track = i
    break
  if mag_pos_track < 0 or a.track_get_key_count(mag_pos_track) < 50:
   _fail("original >50 j_clip position keys were removed")
   return
  var late_pose: Vector3 = a.position_track_interpolate(mag_pos_track, 2.55)
  var final_pose: Vector3 = a.position_track_interpolate(mag_pos_track, a.length)
  if late_pose.distance_to(final_pose) > 0.002:
   _fail("MP40 magazine still has second seat after 2.55s: " + variant)
   return
 for cue_name: String in ["MagazineRemoveCue", "MagazineInsertCue", "BoltChargeCue"]:
  var cue: AudioStreamPlayer3D = mp40.get_node_or_null("SFX/" + cue_name) as AudioStreamPlayer3D
  if cue == null or cue.stream == null:
   _fail("missing ORIGINAL Aether MP40 audio cue: " + cue_name)
   return
 if mp40.get("reload_sfx") != null:
  _fail("MP40 still using Bukkbeek stock gun reload sample")
  return
 var required_source_names := ["gr_mp40_mag_out", "gr_mp40_mag_in", "gr_mp40_charge"]
 if mp40.get_meta("source_mp40_real_audio", []) != required_source_names:
  _fail("MP40 authentic Project Aether audio source manifest mismatch")
  return
 var skeleton: Skeleton3D = mp40.get("_skeleton") as Skeleton3D
 var gun: Node3D = mp40.get("_gun_root") as Node3D
 var hands: Node3D = mp40.get("_hands_root") as Node3D
 var socket: Node3D = mp40.get("_socket") as Node3D
 var hands_anim: AnimationPlayer = mp40.get("_hands_anim") as AnimationPlayer
 var gun_anim: AnimationPlayer = mp40.get("_gun_anim") as AnimationPlayer
 if skeleton == null or gun == null or hands == null or socket == null or hands_anim == null or gun_anim == null:
  _fail("missing real hand skeleton, gun, socket or source animation players")
  return
 if gun.get_parent() != socket or skeleton.find_bone("tag_weapon") < 0:
  _fail("real MP40 did not connect to exact tag_weapon")
  return
 if int(mp40.get_meta("source_mp40_textured_gun_meshes", 0)) < 1 or int(mp40.get_meta("source_mp40_textured_hands_meshes", 0)) < 1:
  _fail("one or both original meshes lack actual source textures")
  return
 if str(mp40.get("_fire_hands_clip")).is_empty() or str(mp40.get("_reload_hands_clip")).is_empty():
  _fail("original source hand fire/reload clips missing")
  return

 # Regression gate: source IDLE root is identity; imported FIRE/RELOAD root
 # was -90 degrees around X. Only normalize the root, not j_clip/j_bolt.
 var idle_clip: String = str(mp40.get("_gun_idle_clip"))
 var idle_anim: Animation = gun_anim.get_animation(idle_clip)
 var reference: Quaternion = Quaternion.IDENTITY
 var root_track_path := "MP40_SM_ao/Skeleton3D:viewmodel_ger_mp40_smg_LOD0_skel"
 for idx: int in range(idle_anim.get_track_count()):
  if str(idle_anim.track_get_path(idx)) == root_track_path:
   reference = idle_anim.track_get_key_value(idx, 0) as Quaternion
 var source_reload: Animation = gun_anim.get_animation(str(mp40.get("_gun_reload_clip")))
 var mag_position_keys := 0
 var mag_rotation_keys := 0
 for idx: int in range(source_reload.get_track_count()):
  var path_name := str(source_reload.track_get_path(idx))
  if path_name.ends_with(":j_clip"):
   if source_reload.track_get_type(idx) == Animation.TYPE_POSITION_3D:
    mag_position_keys = source_reload.track_get_key_count(idx)
   if source_reload.track_get_type(idx) == Animation.TYPE_ROTATION_3D:
    mag_rotation_keys = source_reload.track_get_key_count(idx)
 if mag_position_keys < 50 or mag_rotation_keys < 50:
  _fail("real source magazine motion tracks were removed")
  return
 for role: String in ["fire", "reload", "reload_empty"]:
  var clip: String = ""
  match role:
   "fire":
    clip = str(mp40.get("_gun_fire_clip"))
   "reload":
    clip = str(mp40.get("_gun_reload_clip"))
   "reload_empty":
    clip = str(mp40.get("_gun_reload_empty_clip"))
  var animated: Animation = gun_anim.get_animation(clip)
  var hit := false
  for idx: int in range(animated.get_track_count()):
   if str(animated.track_get_path(idx)) == root_track_path:
    var actual: Quaternion = animated.track_get_key_value(idx, 0) as Quaternion
    if reference.angle_to(actual) > deg_to_rad(1.0):
     _fail("source gun rotated during " + role)
     return
    hit = true
  if not hit:
   _fail("source gun has no " + role + " root track")
   return
 print("BUKKBEEK_MP40_90DEG_FIX_GREEN fire=neutral reload=neutral "
  + "original_magazine_pos_keys=" + str(mag_position_keys)
  + " original_magazine_rot_keys=" + str(mag_rotation_keys))

 # The current Android build starts on MP40; Linux CI switches explicitly.
 manager.call("switch_weapon", 5)
 await create_timer(0.4).timeout
 var current: Node = manager.get("current_weapon")
 if current != mp40 or not mp40.visible:
  _fail("live Bukkbeek weapon manager cannot activate MP40")
  return
 var world_size: Vector3 = gun.global_transform.basis.get_scale()
 print("BUKKBEEK_MP40_LIVE_GRIP world_meter_scale=", world_size)
 if world_size.x < 0.2 or world_size.x > 5.0 or world_size.y < 0.2 or world_size.y > 5.0 or world_size.z < 0.2 or world_size.z > 5.0:
  _fail("source cm-to-meter grip mis-scaled")
  return

 # The TWO cameras used to disagree (world=60° ADS, weapon=75°).
 # Exercise real Bukkbeek global ADS signal and assert synchronized optics.
 var globals_node: Node = root.get_node_or_null("Global")
 if globals_node == null:
  _fail("Bukkbeek autoload Global unavailable for ADS test")
  return
 globals_node.emit_signal("aim_mode_changed", true)
 await create_timer(0.48).timeout
 var main_cam: Camera3D = player.get_node("CameraPivot/CameraHolder/MainCamera")
 var view_cam: Camera3D = player.get_node("WeaponSubViewport/SubViewport/Camera3D")
 if (main_cam.fov < 57 or main_cam.fov > 65
  or absf(main_cam.fov - view_cam.fov) > 0.75):
  _fail("world and weapon camera ADS FOV do not match: "+ str(main_cam.fov)+" vs "+str(view_cam.fov))
  return
 print("BUKKBEEK_MP40_TWO_CAMERA_ADS_GREEN world_fov=", main_cam.fov, " weapon_fov=", view_cam.fov)
 globals_node.emit_signal("aim_mode_changed", false)
 await create_timer(0.25).timeout

 # Simulate a bad 170ms renderer stall. The upstream manager's
 # lerp(t = 50 * 0.17 = 8.5) explodes offscreen; the patched renderer MUST
 # clamp the camera-follow coefficient to <= 1 and snap back safely.
 manager.global_position = main_cam.global_position + Vector3(1.0, 0.0, 0.0)
 manager.call("_process", 0.17)
 var camera_follow_error: float = manager.global_position.distance_to(main_cam.global_position)
 if camera_follow_error > 0.005:
  _fail("weapon/camera follow extrapolates on low FPS; error_m="+str(camera_follow_error))
  return
 print("BUKKBEEK_MP40_CAMERA_FOLLOW_STALL_GREEN delta=0.17s error_m=", camera_follow_error)

 # Diagnostic ONLY: enumerate exact imported PSA tracks to find whether gun
 # bone/root transform tracks double-drive the tag_weapon grip during FIRE/RELOAD.
 for animation_mode: String in ["idle", "fire", "reload"]:
  var name_var: String = ""
  match animation_mode:
   "idle":
    name_var = str(mp40.get("_gun_idle_clip"))
   "fire":
    name_var = str(mp40.get("_gun_fire_clip"))
   "reload":
    name_var = str(mp40.get("_gun_reload_clip"))
  if gun_anim.has_animation(name_var):
   var a: Animation = gun_anim.get_animation(name_var)
   print("MP40_DIAG_GUN_ANIM role=", animation_mode, " clip=", name_var, " tracks=", a.get_track_count(), " seconds=", a.length)
   for idx: int in range(mini(a.get_track_count(), 80)):
    print("MP40_DIAG_GUN_TRACK role=", animation_mode, " n=", idx, " path=", a.track_get_path(idx),
     " type=", a.track_get_type(idx), " keys=", a.track_get_key_count(idx),
     " first_key=", str(a.track_get_key_value(idx, 0)) if a.track_get_key_count(idx) > 0 and (idx == 0 or idx == 4 or idx == 5) else "omitted")
 print("MP40_DIAG_GUN_PARENT ", gun.get_parent().get_path(), " gun_rot=", gun.rotation_degrees,
  " hands_rot=", hands.rotation_degrees, " socket_rot=", socket.rotation_degrees)
 for role: String in ["fire", "reload"]:
  var clip: String = str(mp40.get("_fire_hands_clip")) if role == "fire" else str(mp40.get("_reload_hands_clip"))
  var a: Animation = hands_anim.get_animation(clip)
  print("MP40_DIAG_HANDS_ANIM role=", role, " clip=", clip, " tracks=", a.get_track_count(), " seconds=", a.length)
  for idx: int in range(mini(a.get_track_count(), 100)):
   var track_path := str(a.track_get_path(idx))
   if "tag_weapon" in track_path.to_lower() or "root" in track_path.to_lower() or "tag_view" in track_path.to_lower() or "tag_ads" in track_path.to_lower() or idx < 3:
    print("MP40_DIAG_HANDS_TRACK role=", role, " n=", idx, " path=", track_path)

 # Source provenance check: determine what MP40 reload clips REALLY animate.
 # The old Vril demo is not part of this source GLB. Inspect the j_bolt
 # (charging handle), j_clip (magazine), and both source hand reload variants.
 var clips_to_inspect := [
  "PSA_viewmodel_mp40_reload",
  "PSA_viewmodel_mp40_reload_empty",
  "PSA_MP40ReloadHands",
  "PSA_viewmodel_mp40_fire",
 ]
 for clip_name: String in clips_to_inspect:
  for lane: String in ["gun", "hands"]:
   var ap: AnimationPlayer = gun_anim if lane == "gun" else hands_anim
   if not ap.has_animation(clip_name):
    print("MP40_SOURCE_INSPECT lane=", lane, " clip=", clip_name, " absent")
    continue
   var animation: Animation = ap.get_animation(clip_name)
   print("MP40_SOURCE_INSPECT lane=", lane, " clip=", clip_name,
    " seconds=", animation.length, " tracks=", animation.get_track_count())
   for track_idx: int in range(animation.get_track_count()):
    var track_path := str(animation.track_get_path(track_idx))
    var track_path_lower := track_path.to_lower()
    if (track_path_lower.contains("j_bolt") or track_path_lower.contains("j_clip")
     or track_path_lower.contains("tag_weapon") or track_path_lower.contains("tag_view")
     or track_path_lower.contains("j_hand_le") or track_path_lower.contains("j_wrist_le")
     or track_path_lower.contains("j_hand_ri")):
     var count := animation.track_get_key_count(track_idx)
     var key_preview := ""
     if count > 0:
      key_preview = str(animation.track_get_key_value(track_idx, 0))
     print("MP40_SOURCE_INSPECT_TRACK lane=", lane, " clip=", clip_name,
      " n=", track_idx, " path=", track_path, " type=",
      animation.track_get_type(track_idx), " keys=", count, " first=", key_preview)
 var before: int = mp40.get_current_mag()
 var did_try: bool = mp40.try_fire(true)
 var after: int = mp40.get_current_mag()
 if not did_try or before != 32 or after != 31:
  _fail("original MP40 did not fire from Bukkbeek 32-round magazine")
  return
 if not gun_anim.is_playing():
  _fail("original source MP40 fire animation did not start")
  return

 mp40.call("start_reload")
 if not bool(mp40.get("is_reloading")):
  _fail("Bukkbeek MP40 source reload did not start")
  return
 var reload_timer: Timer = mp40.get_node_or_null("ReloadTimer") as Timer
 if reload_timer == null or reload_timer.is_stopped() or not hands_anim.is_playing():
  _fail("source hands reload PSA or reload timer did not start")
  return
 var normal_hands: String = str(mp40.get("_reload_hands_clip"))
 var normal_gun: String = str(mp40.get("_gun_reload_clip"))
 var normal_duration := maxf(hands_anim.get_animation(normal_hands).length,
  gun_anim.get_animation(normal_gun).length)
 if str(hands_anim.current_animation) != normal_hands or str(gun_anim.current_animation) != normal_gun:
  _fail("normal reload isn't paired to matching original gun and hand PSA")
  return
 if absf(reload_timer.wait_time - normal_duration) > 0.005:
  _fail("normal source gun/hand reload timer not synchronized")
  return
 if str(mp40.get_meta("source_mp40_reload_active_variant", "")) != "normal":
  _fail("non-empty MP40 incorrectly picked empty reload")
  return
 var normal_audio: Dictionary = mp40.get_meta("source_mp40_reload_audio_cues", {}) as Dictionary
 if (float(normal_audio.get("mag_remove_at", -1.0)) <= 0.0
  or float(normal_audio.get("mag_insert_at", -1.0)) <= float(normal_audio.get("mag_remove_at", -1.0))
  or float(normal_audio.get("bolt_charge_at", 0.0)) >= 0.0):
  _fail("normal reload must play original Aether mag-out/in but NOT charge")
  return
 print("BUKKBEEK_MP40_NORMAL_RELOAD_GREEN duration=", normal_duration,
  " gun=", normal_gun, " hands=", normal_hands)

 # Finish test tactical reload, then emulate a mag fired down to exactly zero.
 # This must choose the *authentic* empty gun and hands PSA, where j_bolt has
 # real keyframes. This is an independent source animation pair, NOT old Vril.
 reload_timer.stop()
 mp40.call("_on_reload_timer_timeout")
 if str(mp40.get_meta("source_mp40_mag_idle_matched_clip", "")) != normal_gun:
  _fail("normal magazine idle pose did not inherit source normal ending")
  return
 if not _magazine_idle_matches_reload_end(gun_anim, idle_clip, normal_gun):
  _fail("magazine re-seats between normal reload and gun idle")
  return
 mp40.set("current_mag", 0)
 mp40.call("start_reload")
 if not bool(mp40.get("is_reloading")):
  _fail("empty magazine cannot start original empty reload")
  return
 var empty_hands: String = str(mp40.get("_hands_reload_empty_clip"))
 var empty_gun: String = str(mp40.get("_gun_reload_empty_clip"))
 if empty_hands.is_empty() or empty_gun.is_empty():
  _fail("original source empty reload hand or gun PSA missing")
  return
 if str(hands_anim.current_animation) != empty_hands or str(gun_anim.current_animation) != empty_gun:
  _fail("original empty hand and gun PSAs are not both playing")
  return
 var empty_length := maxf(hands_anim.get_animation(empty_hands).length,
  gun_anim.get_animation(empty_gun).length)
 if absf(reload_timer.wait_time - empty_length) > 0.005:
  _fail("source empty reload timer not synchronized")
  return
 var animated_bolt_position_keys := 0
 var empty_animation := gun_anim.get_animation(empty_gun)
 for track_idx: int in range(empty_animation.get_track_count()):
  if (str(empty_animation.track_get_path(track_idx)).ends_with(":j_bolt")
   and empty_animation.track_get_type(track_idx) == Animation.TYPE_POSITION_3D):
   animated_bolt_position_keys = empty_animation.track_get_key_count(track_idx)
 if animated_bolt_position_keys < 8:
  _fail("original charging handle animated bolt keys missing")
  return
 if str(mp40.get_meta("source_mp40_reload_active_variant", "")) != "empty":
  _fail("empty MP40 incorrectly picked non-empty reload")
  return
 var idle_gun_clip: String = str(mp40.get("_gun_idle_clip"))
 var probe_samples: Array[float] = [0.0, 0.18, 0.42, 0.66, 0.85, 0.96, 1.0]
 for role: String in ["idle", "normal", "empty"]:
  var inspect_clip: String = idle_gun_clip if role == "idle" else (normal_gun if role == "normal" else empty_gun)
  var track: Animation = gun_anim.get_animation(inspect_clip)
  for i: int in range(track.get_track_count()):
   if str(track.track_get_path(i)).ends_with(":j_bolt") and track.track_get_type(i) == Animation.TYPE_POSITION_3D:
    print("MP40_BOLT_SOURCE_DIAG role=", role, " keys=", track.track_get_key_count(i),
     " seconds=", track.length)
    for fraction: float in probe_samples:
     var pose: Vector3 = track.position_track_interpolate(i, track.length * fraction)
     print("MP40_BOLT_KEY role=", role, " fraction=", fraction, " position=", pose)
    break
 # Source skeleton's bone rest is another independent reference.
 var gun_skel: Skeleton3D = gun.get_node_or_null("MP40_SM_ao/Skeleton3D") as Skeleton3D
 if gun_skel != null:
  var bolt_idx := gun_skel.find_bone("j_bolt")
  if bolt_idx >= 0:
   print("MP40_BOLT_REST rest_position=", gun_skel.get_bone_rest(bolt_idx).origin,
    " current_pose=", gun_skel.get_bone_pose_position(bolt_idx))

 var empty_audio: Dictionary = mp40.get_meta("source_mp40_reload_audio_cues", {}) as Dictionary
 var remove_time := float(empty_audio.get("mag_remove_at", -1.0))
 var insert_time := float(empty_audio.get("mag_insert_at", -1.0))
 var charge_time := float(empty_audio.get("bolt_charge_at", -1.0))
 if (remove_time <= 0.0 or insert_time <= remove_time
  or charge_time <= insert_time or charge_time >= empty_length):
  _fail("empty reload missing actual gr_mp40_mag_out, mag_in, charge timing")
  return
 var idle_animation: Animation = gun_anim.get_animation(idle_gun_clip)
 var idle_bolt_pos := Vector3.ZERO
 var empty_bolt_end := Vector3.ZERO
 var found_idle := false
 var found_empty := false
 for i: int in range(idle_animation.get_track_count()):
  if str(idle_animation.track_get_path(i)).ends_with(":j_bolt") and idle_animation.track_get_type(i) == Animation.TYPE_POSITION_3D:
   idle_bolt_pos = idle_animation.track_get_key_value(i, 0) as Vector3
   found_idle = true
 for i: int in range(empty_animation.get_track_count()):
  if str(empty_animation.track_get_path(i)).ends_with(":j_bolt") and empty_animation.track_get_type(i) == Animation.TYPE_POSITION_3D:
   empty_bolt_end = empty_animation.position_track_interpolate(i, empty_animation.length)
   found_empty = true
 if not found_idle or not found_empty or idle_bolt_pos.distance_to(empty_bolt_end) > 0.002:
  _fail("end-to-idle charging handle still snaps downward")
  return
 print("BUKKBEEK_MP40_BOLT_AUDIO_ADS_GREEN idle=", idle_bolt_pos,
  " empty_end=", empty_bolt_end, " remove_at=", remove_time,
  " insert_at=", insert_time, " authentic_charge_at=", charge_time)
 print("BUKKBEEK_MP40_EMPTY_SOURCE_GREEN hands=", empty_hands, " gun=", empty_gun,
  " duration=", empty_length, " charging_handle_keys=", animated_bolt_position_keys)
 # Drive the real animation player forward to each source-derived event.
 # Merely having SFX cue metadata is NOT evidence of sounds being scheduled.
 for event in [
  {"name": "gr_mp40_mag_out", "when": remove_time, "flag": "_cue_remove_played"},
  {"name": "gr_mp40_mag_in", "when": insert_time, "flag": "_cue_insert_played"},
  {"name": "gr_mp40_charge", "when": charge_time, "flag": "_cue_charge_played"},
 ]:
  gun_anim.seek(float(event["when"]) + 0.025, true)
  # SceneTree.process_frame is emitted *before* node _process, so wait through
  # a real engine timer frame for the audio dispatch code to run.
  await create_timer(0.08).timeout
  if not bool(mp40.get(str(event["flag"]))):
   _fail("real MP40 original empty reload did not trigger SFX event: " + str(event["name"]))
   return
  print("BUKKBEEK_MP40_SFX_LIVE_GREEN event=", event["name"],
   " triggered_at=", event["when"])
 # Complete the empty clip and ensure the original magazine cannot visibly
 # re-seat for a SECOND time when j_bolt finishes and the hand withdraws.
 gun_anim.seek(empty_length, true)
 reload_timer.stop()
 mp40.call("_on_reload_timer_timeout")
 if str(mp40.get_meta("source_mp40_mag_idle_matched_clip", "")) != empty_gun:
  _fail("empty reload was not selected for the idle magazine handoff")
  return
 if not _magazine_idle_matches_reload_end(gun_anim, idle_gun_clip, empty_gun):
  _fail("magazine re-seats during empty reload charging-handle exit")
  return
 print("BUKKBEEK_MP40_ADS_MAG_SETTLE_GREEN x=-0.004 y=-0.011 pitch=0.60 idle_mag=exact_final_source_pose")
 print("BUKKBEEK_MP40_LIVE_GREEN "
  + "stock_weapon_count=" + str(weapon_nodes.size() - 1)
  + " hands_bones=" + str(skeleton.get_bone_count())
  + " gun_source_animations=" + str(gun_anim.get_animation_list().size())
  + " hands_source_animations=" + str(hands_anim.get_animation_list().size())
  + " hip_fire=triggered reload=running world_scale=" + str(world_size))
 quit(0)

# Independent source-bone continuity check for BOTH tactical and empty reload.
# A 0.12s blend to an incorrect idle j_clip is the unwanted second seating.
func _magazine_idle_matches_reload_end(player: AnimationPlayer, idle_clip: String, source_clip: String) -> bool:
 var idle: Animation = player.get_animation(idle_clip)
 var source: Animation = player.get_animation(source_clip)
 if idle == null or source == null:
  return false
 for kind: int in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D]:
  var idle_idx := -1
  var end_idx := -1
  for i: int in range(idle.get_track_count()):
   if str(idle.track_get_path(i)).ends_with(":j_clip") and idle.track_get_type(i) == kind:
    idle_idx = i
    break
  for i: int in range(source.get_track_count()):
   if str(source.track_get_path(i)).ends_with(":j_clip") and source.track_get_type(i) == kind:
    end_idx = i
    break
  if idle_idx < 0 or end_idx < 0 or idle.track_get_key_count(idle_idx) != 1:
   return false
  if kind == Animation.TYPE_POSITION_3D:
   var final_position: Vector3 = source.position_track_interpolate(end_idx, source.length)
   var idle_position: Vector3 = idle.track_get_key_value(idle_idx, 0) as Vector3
   if idle_position.distance_to(final_position) > 0.0005:
    return false
  else:
   var final_rotation: Quaternion = source.rotation_track_interpolate(end_idx, source.length)
   var idle_rotation: Quaternion = idle.track_get_key_value(idle_idx, 0) as Quaternion
   if rad_to_deg(idle_rotation.angle_to(final_rotation)) > 0.05:
    return false
 return true
