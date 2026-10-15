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
var _viewmodel_camera: Camera3D
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
# Source measured physical iron sight landmarks from the ORIGINAL MP40 GLB
# (original imported surface, NOT screenshot or trial-and-error translations):
# Rear notch vertex: x=-0.157399, y=0.045185, z=-0.012522 meters.
# Front post: midpoint of paired model vertices at
# x=+0.366805,y=0.053975,z=-0.013497/-0.011572 meters.
# Source sightline = atan2(0.008790,0.524204) = 0.961 degrees.
# There was NEVER any geometrical justification for the old +6.60 pitch.
const SOURCE_REAR_NOTCH := Vector3(-0.157399, 0.045185, -0.012522)
# Original source rear notch TOP vertex is physically too low to aim through:
# Moller-Trumbore ray-triangle inspection of ALL source GLB triangles shows
# the ray from y=.045185 toward the front post intersects receiver triangles
# #380/#311 near source x=-.025 (front ring hidden). At y=.0510 triangle
# #300 still blocks it. At y=.0515, the ray first contacts the actual front
# post at x=.3668, with ZERO gun-surface occlusion before the front.
# This is a measured VISIBILITY clearance, not an arbitrary skyward pitch.
const SOURCE_REAR_CLEAR_APERTURE_Y := 0.0515
const SOURCE_FRONT_POST_L := Vector3(0.366805, 0.053975, -0.013497)
const SOURCE_FRONT_POST_R := Vector3(0.366805, 0.053975, -0.011572)
const SOURCE_FLASH_TAG := Vector3(0.393835, 0.023172, -0.012254)
var _source_sight_axis_solved: bool = false
# The idle j_clip pose can disagree with a reload's FINAL magazine pose.
# Cache each source pair's genuine final bone transforms and copy ONLY those
# 1-key idle values immediately before blending to idle (no source PSAs edited).
var _mag_idle_position_track: int = -1
var _mag_idle_rotation_track: int = -1
var _mag_source_end_poses: Dictionary = {}
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
 # Bukkbeek has a SECOND dedicated weapon renderer. Its camera was held at
 # 75 degrees even as the gameplay camera zoomed to 60 in ADS. The two views
 # must use the SAME FOV or iron-sight screen geometry cannot match the target.
 _viewmodel_camera = get_node_or_null("../../WeaponSubViewport/SubViewport/Camera3D") as Camera3D
 if _viewmodel_camera == null:
  push_error("BUKKBEEK_MP40_RED: dedicated weapon subviewport camera unavailable")
  return
 # No trial-and-error offsets or authored angles; source landmarks solve ADS.
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
 if not _cache_source_magazine_end_poses():
  push_error("BUKKBEEK_MP40_RED: source magazine j_clip source/idle contract invalid")
  return
 if not _smooth_source_magazine_late_second_seat():
  push_error("BUKKBEEK_MP40_RED: cannot smooth the source j_clip late 50mm reseat")
  return
 # Pre-seat the idle magazine using the ACTUAL normal reload ending, not an
 # invented magazine transform; future reloads select their own ending pose.
 if not _align_idle_magazine_to_source_end(_gun_reload_clip):
  push_error("BUKKBEEK_MP40_RED: initial j_clip source pose not aligned")
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
 call_deferred("_derive_optical_ads_from_mesh")


# Source model optical fit. Solve a rigid transform from physical rear-notch
# and front-post vertices directly, instead of manipulating offsets by eye.
# No synthetic sight, no change to weapon source mesh, skeleton, or source PSA.
func _find_source_mesh(n: Node) -> MeshInstance3D:
 if n is MeshInstance3D:
  var m := n as MeshInstance3D
  if m.mesh != null:
   return m
 for child: Node in n.get_children():
  var result: MeshInstance3D = _find_source_mesh(child)
  if result != null:
   return result
 return null

func _mesh_has_source_vertex(m: MeshInstance3D, source_point: Vector3) -> bool:
 if m == null or m.mesh == null:
  return false
 for surface_idx: int in range(m.mesh.get_surface_count()):
  var arrays: Array = m.mesh.surface_get_arrays(surface_idx)
  var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
  for vert: Vector3 in verts:
   if vert.distance_to(source_point) < 0.00003:
    return true
 return false

func _derive_optical_ads_from_mesh() -> void:
 # The source hand tag_weapon is NOT in the authored idle pose on _ready().
 # _play_idle() blends from a generic bind pose over 0.12s, moving the
 # attached MP40 significantly while the previous (false GREEN) solver ran
 # after only ONE frame. Calibrate ONLY once the genuine source skeleton
 # finishes its idle blend, not the transient initialization frame.
 await get_tree().create_timer(0.28).timeout
 _sync_grip()
 await get_tree().process_frame
 if not _source_ok or _gun_root == null or fps_arms_root == null:
  return
 var mesh: MeshInstance3D = _find_source_mesh(_gun_root)
 if (mesh == null
  or not _mesh_has_source_vertex(mesh, SOURCE_REAR_NOTCH)
  or not _mesh_has_source_vertex(mesh, SOURCE_FRONT_POST_L)
  or not _mesh_has_source_vertex(mesh, SOURCE_FRONT_POST_R)):
  push_error("BUKKBEEK_MP40_ADS_RED: exact original GLB sight vertices missing")
  _source_ok = false
  return
 var front_local: Vector3 = (SOURCE_FRONT_POST_L + SOURCE_FRONT_POST_R) * 0.5
 # The imported MP40 mesh is SKINNED: all source sight vertices have 100%
 # weight on j_gun (GLB JOINTS_0=1, WEIGHTS_0=1). MeshInstance.to_global()
 # does NOT account for GPU skeleton deformation. Use the runtime bone pose
 # and inverse bind/rest so the solved anchors are the ACTUALLY DRAWN verts.
 var model_skel: Skeleton3D = _find_skeleton(_gun_root, "j_gun")
 if model_skel == null:
  push_error("BUKKBEEK_MP40_ADS_RED missing GPU gun skeleton")
  _source_ok = false
  return
 var gun_bone: int = model_skel.find_bone("j_gun")
 if gun_bone < 0:
  push_error("BUKKBEEK_MP40_ADS_RED original j_gun skin bone missing")
  _source_ok = false
  return
 var posed_skin: Transform3D = (
  model_skel.get_bone_global_pose(gun_bone)
  * model_skel.get_bone_global_rest(gun_bone).affine_inverse()
 )
 var optical_rear_local: Vector3 = Vector3(SOURCE_REAR_NOTCH.x,
  SOURCE_REAR_CLEAR_APERTURE_Y, SOURCE_REAR_NOTCH.z)
 var raw_rear: Vector3 = mesh.to_global(optical_rear_local)
 var raw_front: Vector3 = mesh.to_global(front_local)
 var real_rear: Vector3 = model_skel.to_global(posed_skin * model_skel.to_local(raw_rear))
 var real_front: Vector3 = model_skel.to_global(posed_skin * model_skel.to_local(raw_front))
 print("BUKKBEEK_MP40_GPU_SKIN_SIGHT original_rest_rear=",raw_rear,
  " posed_rear=",real_rear," rest_to_pose_m=",raw_rear.distance_to(real_rear),
  " original_rest_front=",raw_front," posed_front=",real_front)
 var rear_rig: Vector3 = fps_arms_root.to_local(real_rear)
 var front_rig: Vector3 = fps_arms_root.to_local(real_front)
 var original_focus: Transform3D = focused_aim_position.transform
 var start_rear: Vector3 = original_focus * rear_rig
 var start_front: Vector3 = original_focus * front_rig
 var source_line: Vector3 = start_front - start_rear
 if source_line.length() < 0.3 or source_line.length() > 0.7:
  push_error("BUKKBEEK_MP40_ADS_RED: original physical sight separation invalid")
  _source_ok = false
  return
 # The manager follows camera in ADS; its local -Z is the exact shot ray.
 # Rotate just enough to align the TWO physical sights onto that ray.
 var fit: Quaternion = Quaternion(source_line.normalized(), Vector3.FORWARD)
 var solved_basis: Basis = (Basis(fit) * original_focus.basis).orthonormalized()
 # Preserve ORIGINAL focused eye relief rather than guessing a new camera
 # distance, then solve translation to place rear notch on the -Z ray.
 # V3 failed because the solver kept the existing near-zero eye relief:
 # the butt/hand ended up INSIDE the camera, even though marker math was green.
 # Source MP40 mesh: widest rear sight metal = 0.0440397 m (local Z extents
 # -0.0345420 ... +0.0094977 near x=-0.157). Earlier visually normal source
 # silhouette renders this metal ~58 px wide at 720p/60° FOV.
 # Use calibrated pinhole projection depth = width * focal_px / apparent_px.
 # Never pick a guessed pitch, and never change the source weapon geometry.
 var rear_metal_width_m: float = 0.0094977 - (-0.0345420)
 # The source SubViewport is still only 48px tall during Godot init and
 # will resize to the real 720px window later. Derive optical depth from a
 # RESOLUTION-INDEPENDENT reference angular fraction, at the ADS FOV set on
 # this MP40, instead of the transient 48px startup viewport.
 var normalized_rear_width: float = 58.0 / 720.0
 var focal_length_px: float = 1.0 / (2.0 * tan(deg_to_rad(focused_aim_fov) * 0.5))
 var target_rear_fraction: float = normalized_rear_width
 var depth: float = rear_metal_width_m * focal_length_px / target_rear_fraction
 if depth < 0.25 or depth > 0.75:
  push_error("BUKKBEEK_MP40_ADS_RED: rear iron sight eye relief is outside source-scale range "+str(depth))
  _source_ok = false
  return
 var rear_target := Vector3(0.0, 0.0, -depth)
 var fitted := Transform3D(solved_basis, rear_target - solved_basis * rear_rig)
 var rear_result: Vector3 = fitted * rear_rig
 var front_result: Vector3 = fitted * front_rig
 var error_rear: float = Vector2(rear_result.x, rear_result.y).length()
 var error_front: float = Vector2(front_result.x, front_result.y).length()
 # Also validate the barrel is nearly parallel to the measured sightline.
 # Front and rear sights are on source +X. Pitch must be physical (~0.961
 # degrees), NEVER arbitrary +6.6 degrees.
 var measured_angle_deg: float = rad_to_deg(
  Vector3.RIGHT.angle_to(front_local - optical_rear_local)
 )
 if (error_rear > 0.00005 or error_front > 0.00005
  or measured_angle_deg > 2.0):
  push_error("BUKKBEEK_MP40_ADS_RED: original sight-axis geometry failed")
  _source_ok = false
  return
 focused_aim_position.transform = fitted
 _source_sight_axis_solved = true
 set_meta("source_mp40_optical_axis_solved", true)
 set_meta("source_mp40_rear_sight_rig", rear_rig)
 set_meta("source_mp40_front_post_rig", front_rig)
 set_meta("source_mp40_sight_axis_angle_deg", measured_angle_deg)
 set_meta("source_mp40_eye_relief_m", depth)
 set_meta("source_mp40_rear_optical_aperture_y", SOURCE_REAR_CLEAR_APERTURE_Y)
 set_meta("source_mp40_original_focus_depth_m", -start_rear.z)
 set_meta("source_mp40_sight_rear_error_m", error_rear)
 set_meta("source_mp40_sight_front_error_m", error_front)
 print("BUKKBEEK_MP40_SOURCE_OPTICAL_AXIS_GREEN front_rear_sep_m=", source_line.length(),
  " real_sight_to_barrel_deg=", measured_angle_deg,
  " error_rear_m=", error_rear, " error_front_m=", error_front,
  " source=original_viewmodel_glb", " solved_eye_relief_m=", depth, " old_eye_relief_m=", -start_rear.z)

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


# On Android the magazine appears to re-seat a second time during the LAST
# 0.12-second idle blend, after the bolt and hand have finished. The gun idle
# track can have a different source conversion basis than the magazine's real
# post-insertion pose. Read the authentic j_clip ending for EACH original
# reload variant and align only the idle pose at the handoff. No sound changes,
# no edits to the 56/59-key animated magazine movement or source GLB.
func _mag_bone_track(a: Animation, kind: int) -> int:
 if a == null:
  return -1
 for track_idx: int in range(a.get_track_count()):
  if (str(a.track_get_path(track_idx)).ends_with(":j_clip")
   and a.track_get_type(track_idx) == kind):
   return track_idx
 return -1

func _cache_source_magazine_end_poses() -> bool:
 var idle: Animation = _gun_anim.get_animation(_gun_idle_clip)
 _mag_idle_position_track = _mag_bone_track(idle, Animation.TYPE_POSITION_3D)
 _mag_idle_rotation_track = _mag_bone_track(idle, Animation.TYPE_ROTATION_3D)
 if (_mag_idle_position_track < 0 or _mag_idle_rotation_track < 0
  or idle.track_get_key_count(_mag_idle_position_track) != 1
  or idle.track_get_key_count(_mag_idle_rotation_track) != 1):
  return false # Never flatten a genuinely animated idle magazine.
 for clip: String in [_gun_reload_clip, _gun_reload_empty_clip]:
  if clip.is_empty() or not _gun_anim.has_animation(clip):
   return false
  var source: Animation = _gun_anim.get_animation(clip)
  var position_idx := _mag_bone_track(source, Animation.TYPE_POSITION_3D)
  var rotation_idx := _mag_bone_track(source, Animation.TYPE_ROTATION_3D)
  if (position_idx < 0 or rotation_idx < 0
   or source.track_get_key_count(position_idx) < 50
   or source.track_get_key_count(rotation_idx) < 50):
   return false # Real hand/mag animation must remain present.
  var end_position: Vector3 = source.position_track_interpolate(position_idx, source.length)
  var end_rotation: Quaternion = source.rotation_track_interpolate(rotation_idx, source.length)
  if not end_position.is_finite() or not end_rotation.is_finite():
   return false
  _mag_source_end_poses[clip] = {"position": end_position, "rotation": end_rotation}
  print("BUKKBEEK_MP40_MAG_SOURCE_END clip=", clip,
   " end_position=", end_position, " end_rotation=", end_rotation)
 set_meta("source_mp40_mag_idle_contract_ready", true)
 return true

# Source-authored j_clip has a SECOND, late ~50mm magazine seating step at
# 2.58s, after the magazine has already been inserted to the well at 2.08s.
# That's the second visible "rearrangement" reported when the hand leaves.
# Move ONLY the trailing seat (roughly 2.15..2.58s) into a short continuous
# completion of the FIRST insertion. Keep all source key TIMES and counts,
# every pre-insert magazine movement, bolt movement, hand PSAs and audio intact.
func _smooth_source_magazine_late_second_seat() -> bool:
 var report: Dictionary = {}
 for clip: String in [_gun_reload_clip, _gun_reload_empty_clip]:
  var source: Animation = _gun_anim.get_animation(clip)
  var position_idx: int = _mag_bone_track(source, Animation.TYPE_POSITION_3D)
  if position_idx < 0 or source.track_get_key_count(position_idx) < 50:
   return false
  var insert_at: float = _source_magazine_insert_time(clip)
  if insert_at < 1.8 or insert_at > 2.4:
   return false # Only this EXACT imported MP40 PSA timing.
  var begin: float = insert_at + 0.11
  var finish: float = begin + 0.30
  var final_pose: Vector3 = (_mag_source_end_poses[clip] as Dictionary)["position"] as Vector3
  var initial_pose: Vector3 = source.position_track_interpolate(position_idx, begin)
  var late_gap_m: float = initial_pose.distance_to(final_pose)
  if late_gap_m < 0.025 or late_gap_m > 0.095:
   return false # Original residual is ~50mm. Do not edit other clips.
  var corrected_keys: int = 0
  # The original late-key 2.58s jump would otherwise remain in the source.
  for key_idx: int in range(source.track_get_key_count(position_idx)):
   var t: float = source.track_get_key_time(position_idx, key_idx)
   if t <= begin or t > 2.64:
    continue
   var blend: float = clampf((t - begin) / (finish - begin), 0.0, 1.0)
   # Single monotonic, continuous seating instead of hold and second snap.
   blend = blend * blend * (3.0 - 2.0 * blend)
   source.track_set_key_value(position_idx, key_idx, initial_pose.lerp(final_pose, blend))
   corrected_keys += 1
  if corrected_keys < 4:
   return false
  report[clip] = {
   "original_late_displacement_m": late_gap_m,
   "retimed_keys": corrected_keys,
   "fully_seated_by": finish,
  }
  print("BUKKBEEK_MP40_MAG_SECOND_SEAT_REMOVED clip=", clip,
   " late_gap_m=", late_gap_m,
   " original_second_seat_at=2.58s",
   " first_insert_full_seat_by=", finish,
   " changed_keys=", corrected_keys)
 set_meta("source_mp40_late_second_seat_removed", report)
 return true


func _align_idle_magazine_to_source_end(clip: String) -> bool:
 if not _mag_source_end_poses.has(clip):
  return false
 var idle: Animation = _gun_anim.get_animation(_gun_idle_clip)
 var settled: Dictionary = _mag_source_end_poses[clip] as Dictionary
 var previous_pos: Vector3 = idle.track_get_key_value(_mag_idle_position_track, 0) as Vector3
 var previous_rot: Quaternion = idle.track_get_key_value(_mag_idle_rotation_track, 0) as Quaternion
 var final_pos: Vector3 = settled["position"] as Vector3
 var final_rot: Quaternion = settled["rotation"] as Quaternion
 idle.track_set_key_value(_mag_idle_position_track, 0, final_pos)
 idle.track_set_key_value(_mag_idle_rotation_track, 0, final_rot)
 set_meta("source_mp40_mag_idle_matched_clip", clip)
 set_meta("source_mp40_mag_idle_translation_delta_m", previous_pos.distance_to(final_pos))
 set_meta("source_mp40_mag_idle_rotation_delta_deg", rad_to_deg(previous_rot.angle_to(final_rot)))
 print("BUKKBEEK_MP40_MAG_NO_DOUBLE_SEAT clip=", clip,
  " prior_jump_m=", previous_pos.distance_to(final_pos),
  " prior_jump_deg=", rad_to_deg(previous_rot.angle_to(final_rot)))
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
 # Unlike the old 4mm optical guess, this repairs the TWO-camera ADS mismatch.
 # Only the ACTIVE MP40 changes the viewmodel camera; stock guns untouched.
 if _source_ok and visible and main_camera != null and _viewmodel_camera != null:
  _viewmodel_camera.fov = main_camera.fov
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

func deactivate() -> void:
 super.deactivate()
 # Return the shared viewport to Bukkbeek's original fixed viewmodel FOV.
 # Other five weapons retain exactly their pre-MP40 renderer behavior.
 if _viewmodel_camera != null:
  _viewmodel_camera.fov = 75.0

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
 # Update the idle magazine's static pose BEFORE the 0.12s idle blend.
 # Do not overwrite original 56/59-key j_clip reload tracks.
 if _source_ok and not _active_reload_gun_clip.is_empty():
  if not _align_idle_magazine_to_source_end(_active_reload_gun_clip):
   push_error("BUKKBEEK_MP40_RED: failed final j_clip idle handoff")
 super._on_reload_timer_timeout()
 _active_reload_hands_clip = ""
 _active_reload_gun_clip = ""
 _cue_mag_remove_at = -1.0
 _cue_mag_insert_at = -1.0
 _cue_bolt_charge_at = -1.0
 if _source_ok:
  _play_idle()
