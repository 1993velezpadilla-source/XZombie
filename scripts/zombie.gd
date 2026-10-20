extends CharacterBody3D
## Original lightweight combat proxy: final 2.5D character artwork is not yet sourced.
signal eliminated(points: int)
var health := 120.0
var move_speed := 1.65
var target: Node3D
var world: Node3D
var attack_cooldown := 0.0
var path_timer := 0.0
var current_path: PackedVector2Array = PackedVector2Array()
var waypoint := 0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 4
	var c := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.37
	capsule.height = 1.8
	c.shape = capsule
	c.position.y = 0.9
	add_child(c)
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.34
	mesh.height = 1.65
	body.mesh = mesh
	body.position.y = 0.93
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.29, 0.37, 0.29)
	mat.roughness = 0.94
	body.material_override = mat
	add_child(body)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or not is_instance_valid(world):
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	path_timer -= delta
	if path_timer <= 0.0:
		current_path = world.path_between(global_position, target.global_position)
		waypoint = 0
		path_timer = 0.65 + randf() * 0.2
	var aim := target.global_position
	if waypoint < current_path.size():
		aim = Vector3(current_path[waypoint].x, global_position.y, current_path[waypoint].y)
		if global_position.distance_to(aim) < 0.48:
			waypoint += 1
			if waypoint < current_path.size():
				aim = Vector3(current_path[waypoint].x, global_position.y, current_path[waypoint].y)
	var direction := Vector3(aim.x - global_position.x, 0, aim.z - global_position.z).normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	if not is_on_floor():
		velocity.y -= 23.0 * delta
	move_and_slide()
	if global_position.distance_to(target.global_position) < 1.12 and attack_cooldown <= 0.0:
		target.health = maxi(0, target.health - 25)
		attack_cooldown = 1.1

func take_hit(damage: float) -> void:
	health -= damage
	if health <= 0:
		eliminated.emit(100)
		queue_free()
