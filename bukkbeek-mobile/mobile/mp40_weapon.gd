extends "res://common/weapon/weapon.gd"
## Source World-at-War/Aether MP40 adapter for Bukkbeek (not a new FPS engine).
## Own scene, authentic weapon/hand GLBs, independent imported animation players.
## Leave the five built-in Bukkbeek weapons and XZIEL mobile HUD untouched.

const HAND_ALBEDO := "res://mobile/mp40_source/viewmodel_usa_marine_c.png"
const HAND_NORMAL := "res://mobile/mp40_source/viewmodel_usa_marine_n.png"
const GUN_ALBEDO := "res://mobile/mp40_source/weapon_mp40_c.png"
const GUN_NORMAL := "res://mobile/mp40_source/weapon_mp40_n.png"
const GUN_SPECULAR := "res://mobile/mp40_source/_weapon_mp40_mp_s-rgb_weapon__08433bb1.png"

var _hands_root: Node3D
var _gun_root: Node3D
var _hands_anim: AnimationPlayer
var _gun_anim: AnimationPlayer
var _skeleton: Skeleton3D
var _socket: Node3D
var _bone_index: int = -1
var _idle_hands_clip: String = ""
var _fire_hands_clip: String = ""
var _reload_hands_clip: String = ""
var _gun_idle_clip: String = ""
var _gun_fire_clip: String = ""
var _gun_reload_clip: String = ""
var _hands_reload_empty_clip: String = ""
var _gun_reload_empty_clip: String = ""
var _active_reload_hands_clip: String = ""
var _active_reload_gun_clip: String = ""
var _source_ok: bool = false
# Small reversible on-device ADS calibration, not a source asset modification.
@export_range(-0.015, 0.015, 0.001) var ads_fine_x_metres: float = -0.004
# The ONLY allowed reload sounds for MP40 are the exact Project Aether sound
# assets gr_mp40_mag_out, gr_mp40_mag_in and gr_mp40_charge (source .ubulk).
# Never synthesize or route CC0 metal spring/close or Magnum sounds here.
var _mag_remove_sfx: AudioStreamPlayer3D
var _mag_insert_sfx: AudioStreamPlayer3D
var _bolt_charge_sfx: AudioStreamPlayer3D
var _cue_mag_remove_at: float = -1.0
var _cue_mag_insert_at: float = -1.0
var _cue_bolt_charge_at: float = -1.0
var _cue_remove_played: bool = false
var _cue_insert_played: bool = false
var _cue_charge_played: bool = false

func _ready() -> void:
 super._ready()
 # Old MP40 ADS screenshot has the iron sight slightly camera-right.
 # Shift only the Bukkbeek dedicated ADS Marker by 4 mm; HIP untouched.
 if focused_aim_position != null:
  focused_aim_position.position.x += ads_fine_x_metres
  set_meta("mp40_ads_fine_x", ads_fine_x_metres)
 # Bukkbeek stock reload sample is unrelated to MP40. Suppress it here:
 # real Aether magazine-out plays at j_clip removal time below instead.
 reload_sfx = null
 _mag_remove_sfx = get_node_or_null("SFX/MagazineRemoveCue") as AudioStreamPlayer3D
 _mag_insert_sfx = get_node_or_null("SFX/MagazineInsertCue") as AudioStreamPlayer3D
 _bolt_charge_sfx = get_node_or_null("SFX/BoltChargeCue") as AudioStreamPlayer3D
 for source_cue: AudioStreamPlayer3D in [_mag_remove_sfx, _mag_insert_sfx, _bolt_charge_sfx]:
  if source_cue == null or source_cue.stream == null:
   push_error("BUKKBEEK_MP40_RED: exact original Aether MP40 sound file missing")
   return
 set_meta("source_mp40_real_audio", ["gr_mp40_mag_out", "gr_mp40_mag_in", "gr_mp40_charge"])
 _hands_root = get_node_or_null("FPSHandsRoot/SourceHands") as Node3D
 _gun_root = get_node_or_null("FPSHandsRoot/SourceGun") as Node3D
 if _hands_root == null or _gun_root == null:
  push_error("BUKKBEEK_MP40_RED: missing real hand or gun source")
  return
 # Both source PSA sets use +X barrel-forward, whereas Godot cameras look -Z.
 _hands_root.rotation_degrees.y = 90.0
 _hands_anim = _find_anim_player(_hands_root)
 _gun_anim = _find_anim_player(_gun_root)
 _skeleton = _find_skeleton(_hands_root, "tag_weapon")
 if _hands_anim == null or _gun_anim == null or _skeleton == null:
  push_error("BUKKBEEK_MP40_RED: source skeleton / original PSA players missing")
  return
 _bone_index = _skeleton.find_bone("tag_weapon")
 if _bone_index < 0:
  push_error("BUKKBEEK_MP40_RED: exact tag_weapon missing")
  return

 _idle_hands_clip = _clip(_hands_anim, "PSA_HandIdleMP40")
 _fire_hands_clip = _clip(_hands_anim, "PSA_viewmodel_mp40_fire")
 _reload_hands_clip = _clip(_hands_anim, "PSA_MP40ReloadHands")
 if _reload_hands_clip.is_empty():
  _reload_hands_clip = _clip(_hands_anim, "PSA_viewmodel_mp40_reload_empty")
 _gun_idle_clip = _clip(_gun_anim, "PSA_HandIdleMP40")
 _gun_fire_clip = _clip(_gun_anim, "PSA_viewmodel_mp40_fire")
 _gun_reload_clip = _clip(_gun_anim, "PSA_viewmodel_mp40_reload")
 # Explicitly pair the two COMPLETE source reloads; do not borrow the short
 # gun-side 0.04s MP40ReloadHands stub in place of a full reload animation.
 _hands_reload_empty_clip = _clip(_hands_anim, "PSA_viewmodel_mp40_reload_empty")
 _gun_reload_empty_clip = _clip(_gun_anim, "PSA_viewmodel_mp40_reload_empty")
 if (_hands_reload_empty_clip.is_empty() != _gun_reload_empty_clip.is_empty()):
  push_error("BUKKBEEK_MP40_RED: only one empty reload source PSA is present")
  return
 if _fire_hands_clip.is_empty() or _reload_hands_clip.is_empty() or _gun_fire_clip.is_empty() or _gun_reload_clip.is_empty():
  push_error("BUKKBEEK_MP40_RED: missing source fire or reload PSA")
  return

 # Source evidence: the imported root quaternion is IDENTITY in idle, but
 # (-0.707107, 0, 0, 0.707107) in BOTH firing and reloading. This is a static
 # -90-degree frame mismatch, not intentional recoil. The original hand
 # tag_weapon pose already owns the grip; applying that key flips the *entire*
 # gun sideways on FIRE and sends the reload toward the wrong screen side.
 # Fix ONLY the single static root track. Do not touch animated j_clip/j_bolt
 # tracks (59 rotation/56 position magazine keys from the source GLB).
 if not _normalize_source_gun_root_basis():
  push_error("BUKKBEEK_MP40_RED: cannot safely neutralize source -90-degree animation root")
  return
 if not _normalize_source_bolt_idle_pose():
  push_error("BUKKBEEK_MP40_RED: cannot preserve authentic charging-handle final pose")
  return

 var textured_gun: int = _texture_source(_gun_root, GUN_ALBEDO, GUN_NORMAL, 0.40, 0.31)
 var textured_hands: int = _texture_source(_hands_root, HAND_ALBEDO, HAND_NORMAL, 0.0, 0.86)
 if textured_gun == 0 or textured_hands == 0:
  push_error("BUKKBEEK_MP40_RED: untextured source geometry")
  return

 # Source hand rig controls the actual grip: no free-floating gun placeholder.
 _socket = Node3D.new()
 _socket.name = "SourceMP40TagWeapon"
 _skeleton.add_child(_socket)
 _gun_root.reparent(_socket, false)
 _gun_root.transform = Transform3D.IDENTITY
 # MP40-specific original orientation; not applied to every weapon.
 _gun_root.rotation_degrees.x = 90.0
 _sync_grip()
 if not _skeleton.skeleton_updated.is_connected(_sync_grip):
  _skeleton.skeleton_updated.connect(_sync_grip)

 # Keep the source hands PSA as Bukkbeek's fire/reload authority.
 animation_player = _hands_anim
 animation_fire = _fire_hands_clip
 animation_reload = _reload_hands_clip
 # Source gun reload runs one 24fps frame longer than the hands (3.291667
 # vs 3.25s). Waiting for the LONGER real track prevents the bolt snap caused
 # by switching to the idle key one frame too early.
 reload_time = _synchronized_reload_seconds(_reload_hands_clip, _gun_reload_clip)
 _hands_anim.animation_finished.connect(_hands_anim_finished)
 _source_ok = true
 set_meta("source_mp40_ready", true)
 set_meta("source_mp40_textured_gun_meshes", textured_gun)
 set_meta("source_mp40_textured_hands_meshes", textured_hands)
 set_meta("source_mp40_normal_reload_pair", [_reload_hands_clip, _gun_reload_clip])
 set_meta("source_mp40_empty_reload_pair", [_hands_reload_empty_clip, _gun_reload_empty_clip])
 set_meta("source_mp40_reload_normal_duration", reload_time)
 set_meta("source_mp40_reload_empty_duration",
  _synchronized_reload_seconds(_hands_reload_empty_clip, _gun_reload_empty_clip))
 print("BUKKBEEK_MP40_SOURCE_READY gun=", textured_gun, " hands=", textured_hands,
  " source_hand_fire=", _fire_hands_clip, " source_hand_reload=", _reload_hands_clip,
  " original_gun_reload=", _gun_reload_clip)
 _play_idle()

const SOURCE_GUN_ROOT_TRACK := "MP40_SM_ao/Skeleton3D:viewmodel_ger_mp40_smg_LOD0_skel"

func _normalize_source_gun_root_basis() -> bool:
 # Preserve the idle-root source basis, which the user verified appears upright.
 # The imported firing/reload PSA both contain a SINGLE static -90 degree
 # root key; applying that key produces the observed sideways flip. Modify the
 # in-memory Animation only; downloaded authoring GLBs remain untouched.
 if _gun_anim == null or _gun_idle_clip.is_empty():
  return false
 if not _gun_anim.has_animation(_gun_idle_clip):
  return false
 var idle: Animation = _gun_anim.get_animation(_gun_idle_clip)
 var neutral_quat := Quaternion.IDENTITY
 var idle_found := false
 for track_idx: int in range(idle.get_track_count()):
  if (str(idle.track_get_path(track_idx)) == SOURCE_GUN_ROOT_TRACK
   and idle.track_get_type(track_idx) == Animation.TYPE_ROTATION_3D
   and idle.track_get_key_count(track_idx) == 1):
   neutral_quat = idle.track_get_key_value(track_idx, 0) as Quaternion
   idle_found = true
 if not idle_found:
  return false

 var source_animated_clips: Array[String] = [_gun_fire_clip, _gun_reload_clip]
 if not _gun_reload_empty_clip.is_empty():
  source_animated_clips.append(_gun_reload_empty_clip)
 for clip: String in source_animated_clips:
  if not _gun_anim.has_animation(clip):
   return false
  var animation: Animation = _gun_anim.get_animation(clip)
  var root_found := false
  for track_idx: int in range(animation.get_track_count()):
   if str(animation.track_get_path(track_idx)) != SOURCE_GUN_ROOT_TRACK:
    continue
   if (animation.track_get_type(track_idx) != Animation.TYPE_ROTATION_3D
    or animation.track_get_key_count(track_idx) != 1):
    return false  # Never strip legitimate animated multi-key weapon rotations.
   var source_quat: Quaternion = animation.track_get_key_value(track_idx, 0) as Quaternion
   var mismatch_degrees := rad_to_deg(neutral_quat.angle_to(source_quat))
   # Imported PSA sometimes already uses idle orientation, but the observed
   # original MP40 fire/normal reload root carries exactly -90 degrees.
   if mismatch_degrees > 1.0 and (mismatch_degrees < 70.0 or mismatch_degrees > 110.0):
    return false  # Fail closed if source/axis contract changed.
   animation.track_set_key_value(track_idx, 0, neutral_quat)
   root_found = true
   print("BUKKBEEK_MP40_SOURCE_ROOT_FIXED clip=", clip,
    " original_rotation_deg=", mismatch_degrees,
    " new_root_key=", animation.track_get_key_value(track_idx, 0),
    " preserved_magazine_and_bolt_tracks=", animation.get_track_count() - 1)
  if not root_found:
   return false
 set_meta("source_mp40_root_rotation_fixed", true)
 return true

# Source measurements from genuine MP40 GLB (CI 38774153525):
# idle PSA j_bolt=(-.064322,-.031814,-.025413) is an *incorrect*
# idle-frame conversion, while the original reload EMPTY finishes at
# (-.051676,+.021492,-.032661). The regular reload AND fire PSA
# use approximately that SAME genuine settled location. On switching
# to idle, the bad Y offset snapped the charging handle downward 53mm.
# Repair ONLY the SINGLE-KEY j_bolt IDLE track using the source
# normal+empty end consensus; do not modify the animated empty bolt
# (8 keys) or hand PSAs. This avoids a fabricated custom hand animation.
func _normalize_source_bolt_idle_pose() -> bool:
 if _gun_anim == null or _gun_idle_clip.is_empty() or _gun_reload_empty_clip.is_empty():
  return false
 var idle_anim := _gun_anim.get_animation(_gun_idle_clip)
 var normal_anim := _gun_anim.get_animation(_gun_reload_clip)
 var empty_anim := _gun_anim.get_animation(_gun_reload_empty_clip)
 if idle_anim == null or normal_anim == null or empty_anim == null:
  return false
 var track_suffix := ":j_bolt"
 var idle_pos_track := -1
 var idle_rot_track := -1
 var normal_pos_track := -1
 var normal_rot_track := -1
 var empty_pos_track := -1
 for i: int in range(idle_anim.get_track_count()):
  if str(idle_anim.track_get_path(i)).ends_with(track_suffix):
   if idle_anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
    idle_pos_track = i
   elif idle_anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
    idle_rot_track = i
 for i: int in range(normal_anim.get_track_count()):
  if str(normal_anim.track_get_path(i)).ends_with(track_suffix):
   if normal_anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
    normal_pos_track = i
   elif normal_anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
    normal_rot_track = i
 for i: int in range(empty_anim.get_track_count()):
  if (str(empty_anim.track_get_path(i)).ends_with(track_suffix)
   and empty_anim.track_get_type(i) == Animation.TYPE_POSITION_3D):
   empty_pos_track = i
 if mini(mini(idle_pos_track, normal_pos_track), empty_pos_track) < 0:
  return false
 if (idle_anim.track_get_key_count(idle_pos_track) != 1
  or normal_anim.track_get_key_count(normal_pos_track) != 1
  or empty_anim.track_get_key_count(empty_pos_track) < 8):
  return false
 var normal_bolt: Vector3 = normal_anim.track_get_key_value(normal_pos_track, 0) as Vector3
 var empty_end: Vector3 = empty_anim.position_track_interpolate(empty_pos_track, empty_anim.length)
 var idle_start: Vector3 = idle_anim.track_get_key_value(idle_pos_track, 0) as Vector3
 # These source variants agree on where the charging handle should settle.
 if normal_bolt.distance_to(empty_end) > 0.002:
  return false
 var error_m := idle_start.distance_to(empty_end)
 if error_m < 0.025 or error_m > 0.100:
  return false
 # The -90° source root is already normalized separately. A tiny residual
 # bolt orientation mismatch is also present in the idle source key.
 if idle_rot_track >= 0 and normal_rot_track >= 0:
  if (idle_anim.track_get_key_count(idle_rot_track) == 1
   and normal_anim.track_get_key_count(normal_rot_track) == 1):
   var settled_rotation: Quaternion = normal_anim.track_get_key_value(normal_rot_track, 0) as Quaternion
   var old_rotation: Quaternion = idle_anim.track_get_key_value(idle_rot_track, 0) as Quaternion
   if old_rotation.angle_to(settled_rotation) < deg_to_rad(5.0):
    idle_anim.track_set_key_value(idle_rot_track, 0, settled_rotation)
 idle_anim.track_set_key_value(idle_pos_track, 0, empty_end)
 set_meta("source_mp40_bolt_idle_snap_fixed", true)
 set_meta("source_mp40_bolt_idle_snap_error_m", error_m)
 print("BUKKBEEK_MP40_BOLT_END_FIX_GREEN prior_idle=", idle_start,
  " original_empty_end=", empty_end, " prior_snap_m=", error_m)
 return true

func _texture_source(root: Node3D, albedo_path: String, normal_path: String, metallic: float, roughness: float) -> int:
 var albedo: Texture2D = load(albedo_path) as Texture2D
 var normal: Texture2D = load(normal_path) as Texture2D
 if albedo == null or normal == null:
  push_error("BUKKBEEK_MP40_RED missing textures: " + albedo_path)
  return 0
 var material := StandardMaterial3D.new()
 material.albedo_texture = albedo
 material.albedo_color = Color.WHITE
 material.normal_enabled = true
 material.normal_texture = normal
 material.metallic = metallic
 material.roughness = roughness
 var count := 0
 for child: Node in root.find_children("*", "MeshInstance3D", true, false):
  var mesh := child as MeshInstance3D
  mesh.layers = 2 # Source Bukkbeek weapon-only camera layer.
  if mesh.mesh == null:
   continue
  for surface_index: int in range(mesh.mesh.get_surface_count()):
   mesh.set_surface_override_material(surface_index, material)
  count += 1
 return count

func _find_anim_player(root: Node) -> AnimationPlayer:
 if root is AnimationPlayer:
  return root as AnimationPlayer
 for node: Node in root.find_children("*", "AnimationPlayer", true, false):
  return node as AnimationPlayer
 return null

func _find_skeleton(root: Node, exact_bone: String) -> Skeleton3D:
 for node: Node in root.find_children("*", "Skeleton3D", true, false):
  var sk := node as Skeleton3D
  if sk.find_bone(exact_bone) >= 0:
   return sk
 return null

func _clip(player: AnimationPlayer, exact_clip: String) -> String:
 if player == null:
  return ""
 for animation_name: StringName in player.get_animation_list():
  var full_name := str(animation_name)
  if full_name == exact_clip or full_name.ends_with("/" + exact_clip):
   return full_name
 return ""

func _sync_grip() -> void:
 if not is_instance_valid(_socket) or not is_instance_valid(_skeleton) or not is_instance_valid(_gun_root):
  return
 _socket.transform = _skeleton.get_bone_global_pose(_bone_index)
 # Critical source bug fix: imported hands are centimeter rig (0.01) but the
 # gun mesh was already exported in meters. Cancel inherited scale exactly once.
 var unit_scale := _socket.global_transform.basis.get_scale()
 if unit_scale.x > 0.000001 and unit_scale.y > 0.000001 and unit_scale.z > 0.000001:
  _gun_root.scale = Vector3(1.0 / unit_scale.x, 1.0 / unit_scale.y, 1.0 / unit_scale.z)

func _synchronized_reload_seconds(hands_clip: String, gun_clip: String) -> float:
 if (hands_clip.is_empty() or gun_clip.is_empty()
  or not _hands_anim.has_animation(hands_clip)
  or not _gun_anim.has_animation(gun_clip)):
  return 0.0
 return maxf(_hands_anim.get_animation(hands_clip).length,
  _gun_anim.get_animation(gun_clip).length)


func _play_idle() -> void:
 if not _source_ok:
  return
 if not _idle_hands_clip.is_empty():
  _hands_anim.play(_idle_hands_clip, 0.12)
 if not _gun_idle_clip.is_empty():
  # This blends the j_bolt end pose back to source idle, rather than popping
  # instantly to a different static bolt pose at the end of the reload.
  _gun_anim.play(_gun_idle_clip, 0.12)

func _process(_delta: float) -> void:
 if not _source_ok or not is_reloading or _gun_anim == null:
  return
 var elapsed := _gun_anim.current_animation_position
 if not _cue_remove_played and _cue_mag_remove_at >= 0.0 and elapsed >= _cue_mag_remove_at:
  _cue_remove_played = true
  _mag_remove_sfx.play()
  print("BUKKBEEK_MP40_AUTHENTIC_EVENT gr_mp40_mag_out t=", elapsed)
 if not _cue_insert_played and _cue_mag_insert_at >= 0.0 and elapsed >= _cue_mag_insert_at:
  _cue_insert_played = true
  _mag_insert_sfx.play()
  print("BUKKBEEK_MP40_AUTHENTIC_EVENT gr_mp40_mag_in t=", elapsed)
 if not _cue_charge_played and _cue_bolt_charge_at >= 0.0 and elapsed >= _cue_bolt_charge_at:
  _cue_charge_played = true
  _bolt_charge_sfx.play()
  print("BUKKBEEK_MP40_AUTHENTIC_EVENT gr_mp40_charge t=", elapsed)


func _source_magazine_remove_time(clip: String) -> float:
 # First authentic j_clip displacement: remove-mag click belongs to the
 # actual source PSA, never to a guessed fixed-delay generic metal SFX.
 var a: Animation = _gun_anim.get_animation(clip)
 if a == null:
  return -1.0
 for i: int in range(a.get_track_count()):
  if (not str(a.track_get_path(i)).ends_with(":j_clip")
   or a.track_get_type(i) != Animation.TYPE_POSITION_3D
   or a.track_get_key_count(i) < 8):
   continue
  var initial: Vector3 = a.track_get_key_value(i, 0) as Vector3
  for j: int in range(1, a.track_get_key_count(i)):
   if initial.distance_to(a.track_get_key_value(i, j) as Vector3) >= 0.018:
    return a.track_get_key_time(i, j)
 return -1.0


func _source_magazine_insert_time(clip: String) -> float:
 # Use actual j_clip translation peaks and return-to-well timing; no fixed
 # 3.3s timer that also fires at the wrong moment in 4.2s empty reload.
 var a: Animation = _gun_anim.get_animation(clip)
 if a == null:
  return -1.0
 for i: int in range(a.get_track_count()):
  if not str(a.track_get_path(i)).ends_with(":j_clip"):
   continue
  if a.track_get_type(i) != Animation.TYPE_POSITION_3D or a.track_get_key_count(i) < 8:
   continue
  var start: Vector3 = a.track_get_key_value(i, 0) as Vector3
  var max_dist := 0.0
  var max_index := 0
  for j: int in range(a.track_get_key_count(i)):
   var dist := start.distance_to(a.track_get_key_value(i, j) as Vector3)
   if dist > max_dist:
    max_dist = dist
    max_index = j
  if max_dist < 0.025:
   break
  for j: int in range(max_index + 1, a.track_get_key_count(i)):
   if start.distance_to(a.track_get_key_value(i, j) as Vector3) < maxf(0.012, max_dist * 0.24):
    return clampf(a.track_get_key_time(i, j), a.length * 0.35, a.length - 0.17)
  break
 return a.length * 0.65


func _source_charging_bolt_cue_times(clip: String) -> Vector2:
 var a: Animation = _gun_anim.get_animation(clip)
 if a == null:
  return Vector2(-1.0, -1.0)
 for i: int in range(a.get_track_count()):
  if (not str(a.track_get_path(i)).ends_with(":j_bolt")
   or a.track_get_type(i) != Animation.TYPE_POSITION_3D
   or a.track_get_key_count(i) < 8):
   continue
  var first: Vector3 = a.track_get_key_value(i, 0) as Vector3
  var first_motion := -1.0
  var last_motion := -1.0
  var previous: Vector3 = first
  for j: int in range(1, a.track_get_key_count(i)):
   var pos: Vector3 = a.track_get_key_value(i, j) as Vector3
   if first_motion < 0.0 and first.distance_to(pos) >= 0.004:
    first_motion = a.track_get_key_time(i, j)
   if previous.distance_to(pos) >= 0.003:
    last_motion = a.track_get_key_time(i, j)
   previous = pos
  if first_motion < 0.0:
   return Vector2(-1.0, -1.0)
  # Release cue is reserved for a distinct later end of bolt travel.
  var release := last_motion if last_motion > first_motion + 0.12 else first_motion + 0.16
  return Vector2(clampf(first_motion, 0.1, a.length - 0.19),
   clampf(release, first_motion + 0.12, a.length - 0.02))
 return Vector2(-1.0, -1.0)


func _hands_anim_finished(finished: StringName) -> void:
 if str(finished) != _idle_hands_clip and _source_ok and not is_reloading:
  _play_idle()

func activate(current_aim_mode: bool = false) -> void:
 super.activate(current_aim_mode)
 if _source_ok:
  _play_idle()

func fire_weapon() -> void:
 if not _source_ok:
  return
 super.fire_weapon()
 _gun_anim.play(_gun_fire_clip, 0.02)

func start_reload() -> void:
 if not _source_ok or is_reloading:
  return
 # The gun's original *EMPTY* clip has eight charging-handle keys and a
 # matching 4.2083s hands PSA. The normal 3.29s reload has just one static
 # j_bolt key, so NEVER fake a left-hand handle pull for a tactical reload.
 var empty_mag := current_mag == 0
 var selected_hands := _reload_hands_clip
 var selected_gun := _gun_reload_clip
 if empty_mag and not _hands_reload_empty_clip.is_empty():
  selected_hands = _hands_reload_empty_clip
  selected_gun = _gun_reload_empty_clip
 var required_seconds := _synchronized_reload_seconds(selected_hands, selected_gun)
 if required_seconds < 0.2:
  push_error("BUKKBEEK_MP40_RED: selected source reload pair is invalid")
  return
 # Source strings are reassigned BEFORE Bukkbeek starts its AnimationPlayer
 # and timer, so both hands and gun run their corresponding original variant.
 animation_reload = selected_hands
 reload_time = required_seconds
 var was_reloading := is_reloading
 super.start_reload()
 if is_reloading and not was_reloading:
  _active_reload_hands_clip = selected_hands
  _active_reload_gun_clip = selected_gun
  _gun_anim.play(selected_gun, 0.04)
  _gun_anim.seek(0.0, true)
  _hands_anim.seek(0.0, true)
  _cue_mag_remove_at = _source_magazine_remove_time(selected_gun)
  _cue_mag_insert_at = _source_magazine_insert_time(selected_gun)
  _cue_bolt_charge_at = -1.0
  if empty_mag:
   # gr_mp40_charge is the original full charging action sample; do not
   # fake separate 'pull' and 'release' with unrelated sounds.
   _cue_bolt_charge_at = _source_charging_bolt_cue_times(selected_gun).x
  _cue_remove_played = false
  _cue_insert_played = false
  _cue_charge_played = false
  if _cue_mag_remove_at <= 0.0 or _cue_mag_insert_at <= _cue_mag_remove_at:
   push_error("BUKKBEEK_MP40_RED: original MP40 magazine sound events missing")
  if empty_mag and _cue_bolt_charge_at <= _cue_mag_insert_at:
   push_error("BUKKBEEK_MP40_RED: authentic charge event must follow magazine insert")
  set_meta("source_mp40_reload_audio_cues", {
   "mag_remove_at": _cue_mag_remove_at,
   "mag_insert_at": _cue_mag_insert_at,
   "bolt_charge_at": _cue_bolt_charge_at,
  })
  set_meta("source_mp40_reload_active_variant", "empty" if empty_mag else "normal")
  set_meta("source_mp40_reload_active_duration", required_seconds)
  print("BUKKBEEK_MP40_REAL_RELOAD variant=", "EMPTY" if empty_mag else "NORMAL",
   " hands=", selected_hands, " gun=", selected_gun, " duration=", required_seconds)


func _on_reload_timer_timeout() -> void:
 super._on_reload_timer_timeout()
 _active_reload_hands_clip = ""
 _active_reload_gun_clip = ""
 _cue_mag_remove_at = -1.0
 _cue_mag_insert_at = -1.0
 _cue_bolt_charge_at = -1.0
 if _source_ok:
  _play_idle()
