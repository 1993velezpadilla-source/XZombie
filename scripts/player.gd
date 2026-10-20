extends CharacterBody3D
## New Godot-native movement: no Virin, no imported controls.
var hud: Control
var camera: Camera3D
var health := 100
var mouse_sensitivity := 0.0024
var pitch := 0.0
var gravity := 23.0
var speed_walk := 5.1
var speed_sprint := 8.1
var speed_ads := 3.2
var sprinting := false

func _ready() -> void:
	name = "Survivor"
	collision_layer = 1
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.37
	cap.height = 1.75
	collider.shape = cap
	collider.position.y = 0.9
	add_child(collider)
	camera = Camera3D.new()
	camera.name = "Eyes"
	camera.position = Vector3(0, 1.55, 0)
	camera.current = true
	camera.fov = 80.0
	add_child(camera)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look(e.relative)
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func apply_look(delta: Vector2) -> void:
	rotate_y(-delta.x * mouse_sensitivity)
	pitch = clampf(pitch - delta.y * mouse_sensitivity, -1.45, 1.45)
	camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if is_instance_valid(hud) and hud.get("stick_axis") != null:
		var stick: Vector2 = hud.stick_axis
		if stick.length() > 0.06:
			axis = stick
	var ads := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or (is_instance_valid(hud) and hud.ads_active)
	sprinting = (Input.is_key_pressed(KEY_SHIFT) or (is_instance_valid(hud) and hud.sprint_active)) and axis.length() > 0.25 and not ads
	var speed := speed_ads if ads else (speed_sprint if sprinting else speed_walk)
	var move_direction := (global_transform.basis.x * axis.x + global_transform.basis.z * axis.y).normalized()
	velocity.x = move_direction.x * speed
	velocity.z = move_direction.z * speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump") or (is_instance_valid(hud) and hud.jump_requested):
		velocity.y = 7.0
	if is_instance_valid(hud):
		hud.jump_requested = false
		if hud.look_delta.length_squared() > 0.0:
			apply_look(hud.look_delta * 0.75)
			hud.look_delta = Vector2.ZERO
	move_and_slide()
