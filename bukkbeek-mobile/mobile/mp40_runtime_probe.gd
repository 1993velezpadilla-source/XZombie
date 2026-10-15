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
 for role: String in ["fire", "reload"]:
  var clip: String = str(mp40.get("_gun_fire_clip")) if role == "fire" else str(mp40.get("_gun_reload_clip"))
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
 print("BUKKBEEK_MP40_LIVE_GREEN "
  + "stock_weapon_count=" + str(weapon_nodes.size() - 1)
  + " hands_bones=" + str(skeleton.get_bone_count())
  + " gun_source_animations=" + str(gun_anim.get_animation_list().size())
  + " hands_source_animations=" + str(hands_anim.get_animation_list().size())
  + " hip_fire=triggered reload=running world_scale=" + str(world_size))
 quit(0)
