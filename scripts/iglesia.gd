extends Node3D
## IGLESIA: a fresh Godot-only playable nave. Reuses research, NOT legacy runtimes.
const SURVIVOR = preload("res://scripts/player.gd")
const UNDEAD = preload("res://scripts/zombie.gd")
const TOUCH_HUD = preload("res://scripts/mobile_hud.gd")
const CELL := 0.5
var nav := AStarGrid2D.new()
var blockers: Array[Rect2] = []
var player
var hud
var zombies: Array = []
var round_number := 0
var points := 500
var bullets := 32
var reserve := 192
const RELOAD_SECONDS := 2.25
const SOUND_ROOT := "res://assets/imported/audio/mp40/"
var sound_players: Dictionary = {}
var reload_started_empty := false
var reload_cues_played: Dictionary = {}
var shot_timer := 0.0
var reload_timer := 0.0
var next_round_timer := 3.0
var remaining_spawns := 0
var next_spawn_timer := 0.0
var wallbuy := Vector3(-7.35, 0, 11)
var stone: StandardMaterial3D
var wood: StandardMaterial3D
var iron: StandardMaterial3D

func _ready() -> void:
	randomize()
	_build_materials()
	_build_nave()
	_build_navigation()
	_setup_mp40_audio()
	player = SURVIVOR.new()
	add_child(player)
	player.global_position = Vector3(0, 0.2, 12.4)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = TOUCH_HUD.new()
	layer.add_child(hud)
	hud.game = self
	player.hud = hud
	_set_lighting()
	print("IGLESIA_BOOT: new Godot 4.6 room; NO Virin.")

func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	return m

func _build_materials() -> void:
	stone = _material(Color(0.25, 0.24, 0.27))
	wood = _material(Color(0.23, 0.12, 0.072))
	iron = _material(Color(0.10, 0.10, 0.14))
	var texture_path := "res://assets/imported/stone_wall_diff_4k.jpg"
	if ResourceLoader.exists(texture_path):
		stone.albedo_texture = load(texture_path)

func _solid(label: String, pos: Vector3, dimensions: Vector3, material: Material, visual: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	c.shape = shape
	body.add_child(c)
	if visual:
		var mesh_node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = dimensions
		mesh_node.mesh = mesh
		mesh_node.material_override = material
		body.add_child(mesh_node)
	add_child(body)
	return body

func _place_furniture(asset_name: String, parent_body: StaticBody3D, target_dimensions: Vector3) -> bool:
	# External owner GLBs are an OPTIONAL visual skin; physics always uses simple clean boxes.
	# Source audit has not yet proven GLB mobile import/LOD performance.
	var resource_path := "res://assets/imported/" + asset_name + ".glb"
	if not ResourceLoader.exists(resource_path):
		return false
	var packed := load(resource_path)
	if not packed is PackedScene:
		return false
	var instance := packed.instantiate() as Node3D
	if instance == null:
		push_error("IGLESIA_FURNITURE_INVALID_ROOT: " + asset_name)
		return false
	parent_body.add_child(instance)
	# Never rely on stale nominal metadata: measure actual nested GLB meshes
	# under the REAL runtime transform, then fit all dimensions against collider.
	# In the -90° yaw, source-local X maps to world Z; local Z maps to world X.
	instance.rotation_degrees.y = -90.0 if asset_name == "altar" else 0.0
	instance.scale = Vector3.ONE
	var raw_bounds := furniture_bounds(parent_body, instance)
	if raw_bounds.size.x < 0.00001 or raw_bounds.size.y < 0.00001 or raw_bounds.size.z < 0.00001:
		push_error("IGLESIA_TRIPO_ZERO_EXTENTS: " + asset_name)
		instance.queue_free()
		return false
	if asset_name == "altar":
		instance.scale = Vector3(target_dimensions.z / raw_bounds.size.z, target_dimensions.y / raw_bounds.size.y, target_dimensions.x / raw_bounds.size.x)
	else:
		instance.scale = target_dimensions / raw_bounds.size
	# Tripo scene origins are NOT necessarily at the bottom or center of art.
	# Survey every transformed mesh bound AFTER scale/rotation; stand visual on
	# the physics floor, and center it over the matching BoxShape3D footprint.
	# This fixes 14 buried pews and the altar without shifting the collider.
	var bounds := furniture_bounds(parent_body, instance)
	if bounds.size == Vector3.ZERO:
		push_error("IGLESIA_FURNITURE_NO_MESH: " + asset_name)
		instance.queue_free()
		return false
	var desired_floor_local := -target_dimensions.y * 0.5
	instance.position += Vector3(
		-(bounds.position.x + bounds.size.x * 0.5),
		desired_floor_local - bounds.position.y,
		-(bounds.position.z + bounds.size.z * 0.5)
	)
	var verified := furniture_bounds(parent_body, instance)
	if absf(verified.position.y - desired_floor_local) > 0.012:
		push_error("IGLESIA_FURNITURE_BURIED: " + asset_name)
		instance.queue_free()
		return false
	if absf(verified.position.x + verified.size.x * 0.5) > 0.02 or absf(verified.position.z + verified.size.z * 0.5) > 0.02:
		push_error("IGLESIA_FURNITURE_OFF_CENTER: " + asset_name)
		instance.queue_free()
		return false
	if absf(verified.size.x - target_dimensions.x) > 0.04 or absf(verified.size.y - target_dimensions.y) > 0.04 or absf(verified.size.z - target_dimensions.z) > 0.04:
		push_error("IGLESIA_FURNITURE_SCALE_MISMATCH: " + asset_name + " measured=" + str(verified.size) + " target=" + str(target_dimensions))
		instance.queue_free()
		return false
	instance.set_meta("floor_aligned", true)
	instance.set_meta("visual_bounds", verified)
	return true

func furniture_bounds(parent_body: Node3D, instance: Node3D) -> AABB:
	# Includes child MeshInstance3D nested inside imported GLB scene roots.
	# Transform ALL eight corners to body-local space, not only one AABB
	# origin: rotating an AABB with transform * position is mathematically wrong.
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var meshes: Array[Node] = instance.find_children("*", "MeshInstance3D", true, false)
	if instance is MeshInstance3D:
		meshes.append(instance)
	for node in meshes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var box := mesh_instance.get_aabb()
		for ix in [0, 1]:
			for iy in [0, 1]:
				for iz in [0, 1]:
					var p := box.position + Vector3(box.size.x * ix, box.size.y * iy, box.size.z * iz)
					var local_point := parent_body.to_local(mesh_instance.to_global(p))
					low = low.min(local_point)
					high = high.max(local_point)
	if not is_finite(low.x) or not is_finite(low.y) or not is_finite(low.z):
		return AABB()
	return AABB(low, high - low)

func _build_nave() -> void:
	_solid("Floor", Vector3(0, -0.3, 0), Vector3(18, 0.6, 35), stone)
	_solid("WallWest", Vector3(-9, 3.0, 0), Vector3(0.45, 6.0, 35), stone)
	_solid("WallEast", Vector3(9, 3.0, 0), Vector3(0.45, 6.0, 35), stone)
	_solid("AltarWall", Vector3(0, 3.0, -17.5), Vector3(18, 6.0, 0.45), stone)
	_solid("EntryWallL", Vector3(-5.5, 3.0, 17.5), Vector3(7, 6.0, 0.45), stone)
	_solid("EntryWallR", Vector3(5.5, 3.0, 17.5), Vector3(7, 6.0, 0.45), stone)
	_solid("EntryLintel", Vector3(0, 5.0, 17.5), Vector3(4, 2, 0.45), stone)
	for z in [-13.0, -7.0, -1.0, 5.0, 11.0]:
		_solid("PillarL", Vector3(-8.25, 2.65, z), Vector3(0.6, 5.3, 0.85), stone)
		_solid("PillarR", Vector3(8.25, 2.65, z), Vector3(0.6, 5.3, 0.85), stone)
	for row in range(7):
		var z := -9.8 + float(row) * 3.05
		for side in [-1, 1]:
			var x := float(side) * 4.48
			var size := Vector3(3.95, 1.10, 0.95)
			var pew := _solid("Bench_%02d_%s" % [row, "L" if side < 0 else "R"], Vector3(x, size.y / 2.0, z), size, wood, false)
			if not _place_furniture("bench", pew, size):
				var box := MeshInstance3D.new()
				var mesh := BoxMesh.new()
				mesh.size = size
				box.mesh = mesh
				box.material_override = wood
				pew.add_child(box)
			blockers.append(Rect2(x - size.x / 2 - 0.34, z - size.z / 2 - 0.34, size.x + 0.68, size.z + 0.68))
	# Wider altar faces the pews; keep enough room for both sanctuary lanes.
	var altar_dimensions := Vector3(4.8, 1.65, 2.7)
	var altar := _solid("Altar_Real_Collider", Vector3(0, altar_dimensions.y / 2.0, -14.1), altar_dimensions, stone, false)
	if not _place_furniture("altar", altar, altar_dimensions):
		var altar_mesh := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = altar_dimensions
		altar_mesh.mesh = mesh
		altar_mesh.material_override = stone
		altar.add_child(altar_mesh)
	blockers.append(Rect2(-2.80, -15.85, 5.6, 3.55))
	_solid("WallBuy_Kiosk", wallbuy + Vector3(-0.25, 1.1, 0), Vector3(0.15, 2.2, 1.5), iron)
	for x in [-8.65, 8.65]:
		for z in [-11.0, -4.0, 3.0, 10.0]:
			var glass := MeshInstance3D.new()
			var pane := BoxMesh.new()
			pane.size = Vector3(0.07, 2.5, 1.5)
			glass.mesh = pane
			glass.position = Vector3(x, 3.5, z)
			var light_blue := _material(Color(0.10, 0.18, 0.26))
			light_blue.emission_enabled = true
			light_blue.emission = Color(0.04, 0.09, 0.16)
			glass.material_override = light_blue
			add_child(glass)

func _build_navigation() -> void:
	nav.region = Rect2i(-17, -33, 35, 67)
	nav.cell_size = Vector2(CELL, CELL)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	nav.update()
	for x in range(-17, 18):
		for z in range(-33, 34):
			var p := Vector2(float(x) * CELL, float(z) * CELL)
			for b in blockers:
				if b.has_point(p):
					nav.set_point_solid(Vector2i(x, z), true)
					break

func path_between(start: Vector3, finish: Vector3) -> PackedVector2Array:
	var from_id := Vector2i(clampi(roundi(start.x / CELL), -17, 17), clampi(roundi(start.z / CELL), -33, 33))
	var to_id := Vector2i(clampi(roundi(finish.x / CELL), -17, 17), clampi(roundi(finish.z / CELL), -33, 33))
	if nav.is_point_solid(from_id) or nav.is_point_solid(to_id):
		return PackedVector2Array()
	var grid_path := nav.get_point_path(from_id, to_id)
	return grid_path

func _set_lighting() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.017, 0.020, 0.031)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.17, 0.21, 0.27)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-56, 28, 0)
	moon.light_color = Color(0.58, 0.70, 1.0)
	moon.light_energy = 0.58
	add_child(moon)
	var altar_light := OmniLight3D.new()
	altar_light.position = Vector3(0, 3.0, -13)
	altar_light.light_color = Color(1.0, 0.55, 0.26)
	altar_light.light_energy = 1.6
	altar_light.omni_range = 8.0
	add_child(altar_light)


func _setup_mp40_audio() -> void:
	# Do not invent replacement audio: these WAVs are recovered, hash-pinned
	# originals from the user's Project Aether / XZombie GitHub sources.
	for cue in ["fire", "mag_out", "mag_in", "charge"]:
		var path: String = SOUND_ROOT + str(cue) + ".wav"
		if not ResourceLoader.exists(path):
			push_warning("IGLESIA_MP40_SOURCE_AUDIO_MISSING: " + path)
			continue
		var sound := AudioStreamPlayer.new()
		sound.name = "MP40_" + cue
		sound.stream = load(path) as AudioStream
		sound.max_polyphony = 8 if cue == "fire" else 1
		sound.volume_db = -7.0 if cue == "fire" else -9.0
		add_child(sound)
		sound_players[cue] = sound

func _play_mp40_cue(cue: String) -> void:
	var audio: AudioStreamPlayer = sound_players.get(cue)
	if is_instance_valid(audio) and audio.stream != null:
		audio.play()

func _update_reload_cues() -> void:
	if reload_timer <= 0.0:
		return
	var t := 1.0 - reload_timer / RELOAD_SECONDS
	for cue in ["mag_out", "mag_in", "charge"]:
		if cue == "charge" and not reload_started_empty:
			continue
		var threshold := 0.18 if cue == "mag_out" else (0.66 if cue == "mag_in" else 0.89)
		if t >= threshold and not reload_cues_played.get(cue, false):
			reload_cues_played[cue] = true
			_play_mp40_cue(cue)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	shot_timer = maxf(0.0, shot_timer - delta)
	if reload_timer > 0.0:
		reload_timer -= delta
		if reload_timer > 0.0:
			_update_reload_cues()
		if reload_timer <= 0.0:
			var transfer := mini(32 - bullets, reserve)
			bullets += transfer
			reserve -= transfer
	if Input.is_key_pressed(KEY_R) or hud.reload_requested:
		begin_reload()
	hud.reload_requested = false
	if reload_timer <= 0.0 and _is_fire_requested():
		fire()
	if Input.is_key_pressed(KEY_E) or hud.use_requested:
		purchase_wallgun()
	hud.use_requested = false
	_run_rounds(delta)
	hud.set_status(round_number, points, player.health, bullets, reserve, reload_timer > 0)
	if player.health == 0:
		get_tree().paused = true
		hud.show_game_over(round_number)

func _is_fire_requested() -> bool:
	# Android emits synthetic LEFT MOUSE events for EVERY screen tap.
	# Those events must NEVER bypass the dedicated HUD FIRE/ADS+FIRE hit zones.
	# On desktop genuine left click retains mouse shooting.
	if is_instance_valid(hud) and hud.fire_active:
		return true
	return not OS.has_feature("mobile") and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func begin_reload() -> void:
	if reload_timer <= 0.0 and bullets < 32 and reserve > 0:
		reload_started_empty = bullets == 0
		reload_cues_played.clear()
		reload_timer = RELOAD_SECONDS
		hud.weapon_anim = "idle_hip_01"

func fire() -> void:
	if shot_timer > 0.0:
		return
	if bullets == 0:
		begin_reload()
		return
	bullets -= 1
	shot_timer = 0.102
	hud.trigger_shot()
	_play_mp40_cue("fire")
	var a: Vector3 = player.camera.global_position
	var b: Vector3 = a - player.camera.global_transform.basis.z * 120.0
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.collider.has_method("take_hit"):
		hit.collider.take_hit(34.0)

func purchase_wallgun() -> void:
	if player.global_position.distance_to(wallbuy) < 2.15 and points >= 1000:
		points -= 1000
		reserve += 128

func _run_rounds(delta: float) -> void:
	for z in zombies.duplicate():
		if not is_instance_valid(z):
			zombies.erase(z)
	if remaining_spawns == 0 and zombies.is_empty():
		next_round_timer -= delta
		if next_round_timer <= 0.0:
			round_number += 1
			remaining_spawns = 3 + round_number * 2
			next_round_timer = 4.0
			next_spawn_timer = 0.0
	if remaining_spawns > 0:
		next_spawn_timer -= delta
		if next_spawn_timer <= 0.0 and zombies.size() < 15:
			spawn_undead()
			remaining_spawns -= 1
			next_spawn_timer = 1.55

func spawn_undead() -> void:
	var z = UNDEAD.new()
	add_child(z)
	var candidates := [Vector3(-7.4, 0.2, -12.2), Vector3(7.4, 0.2, -12.2), Vector3(-7.4, 0.2, 9.8), Vector3(7.4, 0.2, 9.8)]
	z.global_position = candidates[randi() % candidates.size()]
	z.target = player
	z.world = self
	z.health = 120.0 + float(round_number - 1) * 30.0
	z.move_speed = minf(3.6, 1.5 + float(round_number - 1) * 0.16)
	z.eliminated.connect(_on_undead_eliminated)
	zombies.append(z)

func _on_undead_eliminated(earned: int) -> void:
	points += earned
