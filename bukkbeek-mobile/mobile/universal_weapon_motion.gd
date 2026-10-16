extends Node3D
## UNIVERSAL FPS WEAPON MOTION LAYER — per-weapon, original rig preserving.
## This child pivot lives *inside* FPSHandsRoot and owns only the hand scene.
## Source-authored weapon PSAs, real gun grip and the focused ADS marker stay
## unchanged. Other weapons can reuse it with configure() and different values.
##
## Weapon motion never affects the authoritative shot ray, magazine count,
## reload timer, muzzle ballistics or camera FOV.
@export_group("Walking")
@export_range(0.0, 0.03, 0.0005) var walk_sway_x_m: float = 0.005
@export_range(0.0, 0.03, 0.0005) var walk_bob_y_m: float = 0.006
@export_range(0.0, 5.0, 0.05) var walk_frequency_hz: float = 1.7
@export_group("Sprinting")
@export_range(0.0, 0.08, 0.001) var sprint_lower_y_m: float = 0.032
@export_range(0.0, 0.06, 0.001) var sprint_tuck_z_m: float = 0.018
@export_range(0.0, 15.0, 0.5) var sprint_lower_pitch_deg: float = 7.0
@export_range(0.0, 0.03, 0.0005) var sprint_bob_y_m: float = 0.011
@export_range(0.0, 5.0, 0.05) var sprint_frequency_hz: float = 2.7
@export_group("Smoothing")
@export_range(2.0, 30.0, 0.5) var settle_rate_hz: float = 12.0
@export_range(0.0, 0.5, 0.01) var reload_bob_multiplier: float = 0.20

var _character: CharacterBody3D
var _weapon: Node3D
var _phase: float = 0.0
var _smoothed_speed: float = 0.0
var _motion_state: String = "idle"
var _last_motion_state: String = "idle"
var _run_peak_m: float = 0.0
var _sprint_frames: int = 0
var _moving_reload_frames: int = 0
var _ads_neutral_frames: int = 0
var _idle_neutral_frames: int = 0
var _max_local_displacement_m: float = 0.0
var _ready_to_tick: bool = false

func configure(character: CharacterBody3D, weapon: Node3D) -> bool:
 if character == null or weapon == null:
  return false
 _character = character
 _weapon = weapon
 transform = Transform3D.IDENTITY
 _ready_to_tick = true
 print("UNIVERSAL_FPS_MOTION_READY weapon=", weapon.name,
  " original_hand_scene_pose_preserved=true")
 return true

func _process(delta: float) -> void:
 if not _ready_to_tick or not is_instance_valid(_character) or not is_instance_valid(_weapon):
  return
 # An inactive weapon must not keep an old sprint pose when switched back.
 if not _weapon.visible:
  _tick_motion(delta, 0.0, false, false, false, 0.0)
  return
 var v: Vector3 = _character.velocity
 var horizontal_speed: float = Vector2(v.x, v.z).length()
 var walking_speed: float = maxf(float(_character.get("walk_speed")), 0.1)
 var sprinting_speed: float = maxf(float(_character.get("sprint_speed")), walking_speed)
 var sprint_requested: bool = Input.is_action_pressed("sprint")
 var aimed: bool = bool(_weapon.get("is_aimed"))
 var reloading: bool = bool(_weapon.get("is_reloading"))
 # The original player blocks sprint during ADS. Never change that behavior.
 var physically_sprinting: bool = sprint_requested and not aimed and (
  horizontal_speed > walking_speed * 0.7)
 var local_v: Vector3 = _character.global_transform.basis.inverse() * v
 _tick_motion(delta, horizontal_speed / sprinting_speed, physically_sprinting,
  aimed, reloading, clampf(local_v.x / sprinting_speed, -1.0, 1.0))

# Public deterministic motion sample for the ACTUAL scene runtime gauntlet.
# It uses the same codepath as live movement; no separate fake motion math.
func _tick_motion(delta: float, speed_ratio: float, sprinting: bool,
 aimed: bool, reloading: bool, strafe_ratio: float) -> void:
 if not _ready_to_tick:
  return
 var frame_delta: float = clampf(delta, 0.0, 0.050)
 var weight: float = 1.0 - exp(-settle_rate_hz * frame_delta)
 var movement: float = clampf(speed_ratio, 0.0, 1.0)
 _smoothed_speed = lerpf(_smoothed_speed, movement, weight)
 # Reload retains original source hand tracks. A SMALL whole-body bob is
 # allowed while running and reloading, but no lowering/pose change.
 var sprint_pose: bool = sprinting and not aimed and not reloading
 var intensity: float = 0.0 if aimed else _smoothed_speed
 var gait_hz: float = sprint_frequency_hz if sprint_pose else walk_frequency_hz
 if intensity > 0.015 and not aimed:
  _phase = fposmod(_phase + frame_delta * TAU * gait_hz, TAU)
 var bob_scale: float = reload_bob_multiplier if reloading else 1.0
 var bob_y: float = sin(_phase * 2.0) * (
  sprint_bob_y_m if sprint_pose else walk_bob_y_m) * intensity * bob_scale
 var sway_x: float = sin(_phase) * walk_sway_x_m * intensity * bob_scale
 var target_position := Vector3(
  sway_x + clampf(strafe_ratio, -1.0, 1.0) * 0.0025 * intensity,
  bob_y - (sprint_lower_y_m * intensity if sprint_pose else 0.0),
  sprint_tuck_z_m * intensity if sprint_pose else 0.0)
 var pitch: float = (
  -sprint_lower_pitch_deg * intensity if sprint_pose else
  sin(_phase * 2.0) * 0.60 * intensity * bob_scale)
 var yaw: float = sin(_phase) * 0.60 * intensity * bob_scale
 var roll: float = sin(_phase) * (
  1.80 if sprint_pose else 0.65) * intensity * bob_scale
 var target_basis := Basis.from_euler(Vector3(
  deg_to_rad(pitch), deg_to_rad(yaw), deg_to_rad(roll)))
 # These pose changes occur on the SINGLE common parent of hands+gun.
 # They DO NOT touch Bukkbeek's FocusedAimPosition or FPSHandsRoot transform.
 position = position.lerp(target_position, weight)
 quaternion = quaternion.slerp(target_basis.get_rotation_quaternion(), weight).normalized()
 _max_local_displacement_m = maxf(_max_local_displacement_m, position.length())
 _run_peak_m = maxf(_run_peak_m, position.length())
 if reloading and intensity > 0.08:
  _moving_reload_frames += 1
 if aimed and position.length() <= 0.001:
  _ads_neutral_frames += 1
 if not aimed and intensity < 0.01 and position.length() <= 0.001:
  _idle_neutral_frames += 1
 if sprint_pose and intensity > 0.15:
  _sprint_frames += 1
 if aimed:
  _motion_state = "ads"
 elif reloading:
  _motion_state = "reload_moving" if intensity > 0.08 else "reload"
 elif sprint_pose and intensity > 0.15:
  _motion_state = "sprint"
 elif intensity > 0.08:
  _motion_state = "walk"
 else:
  _motion_state = "idle"
 if _motion_state != _last_motion_state:
  print("UNIVERSAL_FPS_MOTION_STATE weapon=", _weapon.name,
   " state=", _motion_state,
   " reloading=", reloading, " aimed=", aimed)
  _last_motion_state = _motion_state
