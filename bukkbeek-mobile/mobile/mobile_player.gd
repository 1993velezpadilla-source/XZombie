extends "res://player/player.gd"
## Real Android first-person movement layered over the ORIGINAL Bukkbeek player.
## Weapon manager, health, hits, camera and existing MP40 source animation stay intact.
const STAND_HEIGHT := 1.85
const CROUCH_HEIGHT := 1.16
const PRONE_HEIGHT := 0.55
const SLIDE_TIME := 0.90
const SLIDE_DRAG := 5.5
const SLIDE_ENTRY_MULTIPLIER := 1.16
const CROUCH_SPEED_FACTOR := 0.51
const PRONE_SPEED_FACTOR := 0.23
const STANCE_LERP := 10.0

@onready var _xz_shape_node: CollisionShape3D = $CollisionShape3D
var _xz_capsule: CapsuleShape3D
var _xz_stance: String = "stand"
var _xz_slide_remaining: float = 0.0
var _xz_slide_velocity: Vector3 = Vector3.ZERO
var _xz_grenade_cooking: bool = false
var _xz_grenade_cooked_for: float = 0.0

func _ready() -> void:
 super._ready()
 for action_name in ["prone", "slide", "cook_grenade"]:
  if not InputMap.has_action(action_name): InputMap.add_action(action_name)


func _ensure_capsule() -> void:
 if _xz_capsule != null: return
 # Duplicate before editing so the source scene's shared shape is unchanged.
 _xz_capsule = _xz_shape_node.shape.duplicate() as CapsuleShape3D
 _xz_shape_node.shape = _xz_capsule

func _ceiling_clear(desired_height: float) -> bool:
 if desired_height <= _xz_capsule.height + 0.02: return true
 var query := PhysicsRayQueryParameters3D.create(
  global_position + Vector3.UP * (_xz_capsule.height - 0.08),
  global_position + Vector3.UP * (desired_height + 0.08))
 query.exclude = [get_rid()]
 return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _physics_process(delta: float) -> void:
 _ensure_capsule()
 if not is_alive: return
 if Input.is_action_just_pressed("cook_grenade") and Bullets._get_ammo(Bullets.AmmoType.HAND_GRENADE) != 0:
  _xz_grenade_cooking = true
  _xz_grenade_cooked_for = 0.0
 if _xz_grenade_cooking:
  _xz_grenade_cooked_for += delta
  if Input.is_action_just_released("cook_grenade") or _xz_grenade_cooked_for >= 3.2:
   _xz_throw_grenade()
   _xz_grenade_cooking = false
 if not is_on_floor():
  velocity.y += GRAVITY * delta
 if is_on_floor() and not was_on_floor and audio_manager:
  audio_manager.play_footstep(true)
 was_on_floor = is_on_floor()

 var input_dir: Vector2 = Input.get_vector("left", "right", "forward", "backward")
 var wish: Vector3 = camera_pivot.transform.basis * Vector3(input_dir.x, 0, input_dir.y)
 wish.y = 0.0
 wish = wish.normalized()
 var trying_sprint := Input.is_action_pressed("sprint") and input_dir.length() > 0.60

 if Input.is_action_just_pressed("prone"):
  if _xz_stance == "prone":
   if _ceiling_clear(STAND_HEIGHT): _xz_stance = "stand"
  else:
   _xz_stance = "prone"
   _xz_slide_remaining = 0.0
 elif Input.is_action_just_pressed("crouch"):
  if _xz_stance == "crouch":
   if _ceiling_clear(STAND_HEIGHT): _xz_stance = "stand"
  else:
   _xz_stance = "crouch"
   _xz_slide_remaining = 0.0

 # Slide is a physical momentum state: it continues when the finger leaves
 # the joystick. It DOES NOT call handle_sprint or secretly just crouch.
 if Input.is_action_just_pressed("slide") and _xz_slide_remaining <= 0.0:
  if is_on_floor() and trying_sprint and wish.length_squared() > 0.1:
   _xz_stance = "slide"
   _xz_slide_remaining = SLIDE_TIME
   _xz_slide_velocity = wish * maxf(sprint_speed * SLIDE_ENTRY_MULTIPLIER,
    Vector2(velocity.x, velocity.z).length())
 if Input.is_action_just_pressed("jump") and is_on_floor():
  if _xz_slide_remaining > 0.0:
   _xz_slide_remaining = 0.0
   _xz_stance = "crouch"
  velocity.y = jump_velocity

 var target_height := STAND_HEIGHT
 if _xz_stance == "crouch" or _xz_stance == "slide": target_height = CROUCH_HEIGHT
 if _xz_stance == "prone": target_height = PRONE_HEIGHT
 var physical_height := _xz_capsule.height
 if target_height > physical_height and not _ceiling_clear(target_height):
  target_height = physical_height
 # Keep bottom of capsule grounded while lowering; preserve all world geometry.
 var next_height := move_toward(physical_height, target_height, delta * STANCE_LERP)
 next_height = maxf(next_height, _xz_capsule.radius * 2.0 + 0.01)
 _xz_capsule.height = next_height
 _xz_shape_node.position.y = next_height * 0.5
 var eye_height: float = next_height - 0.15
 camera_pivot.position.y = lerpf(camera_pivot.position.y, eye_height,
  clampf(delta * STANCE_LERP, 0.0, 1.0))

 var really_sprinting := trying_sprint and not is_aiming and _xz_stance == "stand"
 if _xz_slide_remaining > 0.0:
  _xz_slide_remaining = maxf(0.0, _xz_slide_remaining - delta)
  _xz_slide_velocity = _xz_slide_velocity.move_toward(Vector3.ZERO, SLIDE_DRAG * delta)
  velocity.x = _xz_slide_velocity.x
  velocity.z = _xz_slide_velocity.z
  if _xz_slide_remaining <= 0.0 or _xz_slide_velocity.length() < walk_speed * 0.45:
   _xz_slide_remaining = 0.0
   _xz_stance = "crouch"
 else:
  speed = sprint_speed if really_sprinting else walk_speed
  if _xz_stance == "crouch": speed *= CROUCH_SPEED_FACTOR
  if _xz_stance == "prone": speed *= PRONE_SPEED_FACTOR
  var weight := clampf(delta * (inertia_ground if is_on_floor() else inertia_air),
   0.0, 1.0)
  velocity.x = lerpf(velocity.x, wish.x * speed, weight)
  velocity.z = lerpf(velocity.z, wish.z * speed, weight)

 Global.player_sprinting_changed.emit(really_sprinting)
 t_bob += Vector2(velocity.x, velocity.z).length() * float(is_on_floor()) * delta
 var bob: Vector3 = _headbob(t_bob)
 bob *= 0.2 if _xz_stance != "stand" else 1.0
 camera_holder.position = bob
 if _xz_slide_remaining <= 0.0: _handle_footsteps(delta)
 Global.player_velocity_changed.emit(velocity)
 move_and_slide()

func _xz_throw_grenade() -> void:
 if not Bullets._consume_ammo(Bullets.AmmoType.HAND_GRENADE, 1): return
 var bomb = preload("res://mobile/mobile_grenade.gd").new()
 bomb.fuse_remaining = maxf(0.05, 3.2 - _xz_grenade_cooked_for)
 get_tree().current_scene.add_child(bomb)
 var launch: Vector3 = -camera.global_transform.basis.z
 bomb.global_position = camera.global_position + launch * 0.55 - Vector3.UP * 0.10
 bomb.linear_velocity = launch * 14.0 + Vector3.UP * 2.8 + velocity
 Global.bullets_changed.emit()
