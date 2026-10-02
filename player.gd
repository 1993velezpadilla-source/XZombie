extends CharacterBody3D

@export var speed := 6.0
@export var sprint_speed := 9.0
@export var jump_velocity := 5.0
@export var look_sensitivity := 0.0025
@onready var head: Node3D = $Head

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * look_sensitivity)
		head.rotate_x(-event.relative.y * look_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
	var current_speed := sprint_speed if Input.is_action_pressed("sprint") else speed
	if dir:
		velocity.x = dir.x * current_speed
		velocity.z = dir.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)
	move_and_slide()
