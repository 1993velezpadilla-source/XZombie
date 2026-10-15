extends SkeletonModifier3D
## Pure additive FIRST-PERSON arm pose for the source MP40 iron-sight view.
## Godot 4.6 guarantees this modifier runs AFTER original source PSAs.
## Never edits GLBs/animations, and never modifies tag_weapon, hand fingers,
## wrists or magazine/bolt. Two-bone arm IK is constrained by the original
## shoulder-elbow-wrist lengths and original CAMERA-PROJECTED elbow target.
##
## Important: this does not create new weapon animations or fake a hand grip.
## The original source wrist *global pose* is preserved at every frame.
var _weapon: Node3D
var _rig: Node3D
var _original_focus: Transform3D
var _solved_focus: Transform3D
var _shoulder: Array[int] = []
var _elbow: Array[int] = []
var _wrist: Array[int] = []
var _enabled: bool = false
var _max_modified_elbow_m: float = 0.0
var _worst_wrist_anchor_m: float = 0.0
var _frames: int = 0
var _callbacks: int = 0
var _eligible_frames: int = 0
var _guard_skips: int = 0
var _solver_attempts: int = 0

func configure(weapon: Node3D, rig: Node3D, reference: Transform3D,
 solved: Transform3D) -> bool:
 var sk: Skeleton3D = get_skeleton()
 if sk == null or weapon == null or rig == null:
  return false
 _weapon = weapon
 _rig = rig
 _original_focus = reference
 _solved_focus = solved
 for side: String in ["le", "ri"]:
  var sh: int = sk.find_bone("j_shoulder_" + side)
  var el: int = sk.find_bone("j_elbow_" + side)
  var wr: int = sk.find_bone("j_wrist_" + side)
  if (sh < 0 or el < 0 or wr < 0
   or sk.get_bone_parent(el) != sh
   or sk.get_bone_parent(wr) != el):
   push_error("MP40_ADS_IK_RED original bone chain missing: " + side)
   return false
  _shoulder.append(sh)
  _elbow.append(el)
  _wrist.append(wr)
 _enabled = true
 # Source pose/animation remain completely authoritative until ADS settles.
 print("MP40_ADS_IK_SOURCE_INITIALIZED original_chains=2 wrists_locked=2 source_PSA_preserved=true")
 return true

func _process_modification_with_delta(_delta: float) -> void:
 _callbacks += 1
 var sk: Skeleton3D = get_skeleton()
 if _callbacks == 1:
  print("MP40_ADS_IK_FIRST_CALLBACK active=",active," enabled=",_enabled,
   " source_skeleton=",sk != null, " original_hand_anim=",str(_weapon.get("_idle_hands_clip")) if _weapon != null else "NONE")
 if not _enabled or sk == null or _weapon == null or not _weapon.is_inside_tree():
  return
 if (not _weapon.visible or not bool(_weapon.get("is_aimed"))
  or bool(_weapon.get("is_reloading"))):
  return
 var player: AnimationPlayer = _weapon.get("_hands_anim") as AnimationPlayer
 if player == null:
  return
 # The original HandIdleMP40 source animation is NOT looping.
 # Godot's AnimationPlayer.current_animation becomes empty AFTER the clip
 # ends, even though all its source hand bone poses stay fixed in idle.
 # Allow both the active idle clip and its finished/frozen pose. Every
 # non-idle source FIRE/RELOAD/EQUIP PSA remains untouchable.
 var playing_clip: String = str(player.current_animation)
 if not playing_clip.is_empty() and playing_clip != str(_weapon.get("_idle_hands_clip")):
  _guard_skips += 1
  return # FIRE, RELOAD and SWAP source PSAs are untouched.
 _eligible_frames += 1
 var modified: int = 0
 for side: int in range(_shoulder.size()):
  if _correct_arm_chain(sk, side):
   modified += 1
 if modified > 0:
  _frames += 1
  if _frames == 1:
   print("MP40_ADS_IK_SOURCE_ACTIVE modified_arms=", modified,
    " source_idle=", player.current_animation, " aiming=", _weapon.get("is_aimed"))

func _correct_arm_chain(sk: Skeleton3D, side: int) -> bool:
 _solver_attempts += 1
 var sh: int = _shoulder[side]
 var el: int = _elbow[side]
 var wr: int = _wrist[side]
 var sh_pose: Transform3D = sk.get_bone_global_pose(sh)
 var el_pose: Transform3D = sk.get_bone_global_pose(el)
 var wr_pose: Transform3D = sk.get_bone_global_pose(wr)
 var a: Vector3 = sh_pose.origin
 var b: Vector3 = el_pose.origin
 var c: Vector3 = wr_pose.origin
 var len_upper: float = a.distance_to(b)
 var len_forearm: float = b.distance_to(c)
 var distance: float = a.distance_to(c)
 if len_upper < 0.0001 or len_forearm < 0.0001 or distance < 0.0001:
  return false
 # Preserve the ORIGINAL elbow's position in CAMERA SPACE, but calculate
 # the required bone endpoint inside the CURRENT physical skeleton's space.
 # This target originates from the original fully-authored source ADS marker
 # and original source limb bone; not an invented screen coordinate.
 var elbow_world: Vector3 = sk.to_global(b)
 var elbow_local_rig: Vector3 = _rig.to_local(elbow_world)
 var original_camera_elbow: Vector3 = _original_focus * elbow_local_rig
 var wanted_rig: Vector3 = _solved_focus.affine_inverse() * original_camera_elbow
 var wanted_skeleton: Vector3 = sk.to_local(_rig.to_global(wanted_rig))
 # Project desired elbow to the valid 2-bone IK circle (shoulder/wrist fixed).
 var axis: Vector3 = (c-a) / distance
 var projection: float = (
  len_upper*len_upper - len_forearm*len_forearm + distance*distance
 ) / (2.0*distance)
 var radial_sq: float = len_upper*len_upper-projection*projection
 if radial_sq < 0.0:
  return false
 var center: Vector3 = a + axis*projection
 var ideal_radial: Vector3 = wanted_skeleton-center
 ideal_radial -= axis*ideal_radial.dot(axis)
 if ideal_radial.length_squared() < 0.000001:
  ideal_radial = b-center
  ideal_radial -= axis*ideal_radial.dot(axis)
 if ideal_radial.length_squared() < 0.000001:
  return false
 var target_elbow: Vector3 = center + ideal_radial.normalized()*sqrt(radial_sq)
 # Conservative safety gate: avoid flipping the original shoulder/elbow.
 var shoulder_angle: float = rad_to_deg((b-a).angle_to(target_elbow-a))
 if shoulder_angle > 22.0:
  return false
 var elbow_displacement: float = b.distance_to(target_elbow)
 # Shoulder rotation swings original humerus exactly into IK elbow target.
 var swing: Quaternion = Quaternion((b-a).normalized(),
  (target_elbow-a).normalized())
 var new_shoulder := Transform3D(
  (Basis(swing)*sh_pose.basis).orthonormalized(), sh_pose.origin)
 sk.set_bone_global_pose(sh, new_shoulder)
 # The original elbow->wrist lower arm needs to point to the SAME wrist anchor
 # after shoulder rotation. Restore the entire wrist world pose afterward to
 # guarantee no hand/finger grip or tag_weapon attachment moves.
 var bent_elbow: Transform3D = sk.get_bone_global_pose(el)
 var current_wrist: Transform3D = sk.get_bone_global_pose(wr)
 var now_dir: Vector3 = current_wrist.origin-bent_elbow.origin
 var want_dir: Vector3 = wr_pose.origin-bent_elbow.origin
 if now_dir.length_squared() < 0.000001 or want_dir.length_squared() < 0.000001:
  sk.set_bone_global_pose(sh, sh_pose)
  return false
 var forearm_rot: Quaternion = Quaternion(now_dir.normalized(),want_dir.normalized())
 var new_elbow: Transform3D = Transform3D(
  (Basis(forearm_rot)*bent_elbow.basis).orthonormalized(),bent_elbow.origin)
 sk.set_bone_global_pose(el,new_elbow)
 sk.set_bone_global_pose(wr,wr_pose)
 var anchored: Transform3D = sk.get_bone_global_pose(wr)
 var anchor_err: float = anchored.origin.distance_to(wr_pose.origin)
 if anchor_err > 0.005*len_forearm:
  # Do not EVER pull the hand off the authentic pistol grip.
  sk.set_bone_global_pose(sh,sh_pose)
  sk.set_bone_global_pose(el,el_pose)
  sk.set_bone_global_pose(wr,wr_pose)
  return false
 _max_modified_elbow_m = maxf(_max_modified_elbow_m,elbow_displacement)
 _worst_wrist_anchor_m = maxf(_worst_wrist_anchor_m,anchor_err)
 return true
