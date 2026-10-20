extends SceneTree

func _initialize() -> void:
	call_deferred("_smoke")

func _fail(message: String) -> void:
	push_error("IGLESIA_SMOKE_RED: " + message)
	quit(1)

func _screen_touch(hud: Control, finger: int, pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = pos
	event.pressed = pressed
	hud._input(event)

func _check_prop(world: Node3D, path: String, target: Vector3) -> bool:
	var prop: StaticBody3D = world.get_node_or_null(path) as StaticBody3D
	if prop == null or prop.get_child_count() < 2:
		return false
	var art := prop.get_child(1) as Node3D
	if art == null or not art.has_meta("floor_aligned"):
		return false
	var box: AABB = world.furniture_bounds(prop, art)
	var floor_global := prop.to_global(box.position).y
	var center_x := box.position.x + box.size.x * 0.5
	var center_z := box.position.z + box.size.z * 0.5
	return absf(floor_global) < 0.02 and absf(center_x) < 0.02 and absf(center_z) < 0.02 \
		and box.size.distance_to(target) < 0.08

func _smoke() -> void:
	if ProjectSettings.get_setting("application/config/name") != "Iglesia":
		_fail("project name")
		return
	var scene: PackedScene = load("res://main.tscn")
	if scene == null:
		_fail("missing scene")
		return
	var world = scene.instantiate()
	root.add_child(world)
	await process_frame
	if world.get_node_or_null("Altar_Real_Collider") == null:
		_fail("altar collision not created")
		return
	if world.get_node_or_null("Bench_00_L") == null or world.get_node_or_null("Bench_06_R") == null:
		_fail("14 church benches not generated")
		return
	var altar: StaticBody3D = world.get_node("Altar_Real_Collider")
	var altar_shape: CollisionShape3D = altar.get_child(0)
	if altar_shape.shape.size.x < 4.7 or altar_shape.shape.size.z < 2.6:
		_fail("Tripo altar collider still undersized")
		return
	if not ResourceLoader.exists("res://assets/imported/altar.glb") or not ResourceLoader.exists("res://assets/imported/bench.glb"):
		_fail("real original Tripo altar and benches MUST be imported before testing")
		return
	var altar_skin := altar.get_child(1)
	if absf(altar_skin.rotation_degrees.y + 90.0) > 0.5:
		_fail("Tripo altar faces the wrong direction")
		return
	if not _check_prop(world, "Altar_Real_Collider", Vector3(4.8, 1.65, 2.7)):
		_fail("real Tripo altar does not stand on floor / is undersized")
		return
	for row in range(7):
		for side in ["L", "R"]:
			var label := "Bench_%02d_%s" % [row, side]
			if not _check_prop(world, label, Vector3(3.95, 1.10, 0.95)):
				_fail("real Tripo pew SUNK or collider/mat mismatch: " + label)
				return
	if world.player == null or world.player.camera == null:
		_fail("first person player/camera missing")
		return
	if world.hud == null:
		_fail("touch UI missing")
		return
	for action in ["fire", "aim", "aim_fire", "reload"]:
		if not world.hud.touch_buttons.has(action):
			_fail("official touch action missing: " + action)
			return
	world.hud._set_action("aim_fire", true)
	if not world.hud.fire_active or not world.hud.ads_active:
		_fail("ADS+FIRE finger does not hold both inputs")
		return
	world.hud._set_action("aim_fire", false)
	if world.hud.fire_active or world.hud.ads_active:
		_fail("ADS+FIRE finger release left stuck input")
		return
	world.hud._set_action("aim", true)
	if not world.hud.ads_active:
		_fail("ADS toggle missing")
		return
	world.hud._set_action("aim_fire", true)
	world.hud._set_action("aim_fire", false)
	if not world.hud.ads_active or world.hud.fire_active:
		_fail("ADS+FIRE release incorrectly cleared persistent ADS toggle")
		return
	world.hud._set_action("aim", true)
	# Regression: touching empty look space is NOT fire, even with Android's
	# emulated mouse-left event. Only official FIRE / AIM+FIRE hit zones.
	world.force_touch_mode_for_tests = true
	var stray: Vector2 = Vector2(760, 140)
	_screen_touch(world.hud, 7, stray, true)
	# Android synthesizes a mouse LEFT button for this ordinary look tap.
	# Inject its desktop equivalent into the Linux headless engine so this
	# exact regression fails if the mobile mouse-input guard is ever removed.
	var synthetic_mouse := InputEventMouseButton.new()
	synthetic_mouse.button_index = MOUSE_BUTTON_LEFT
	synthetic_mouse.position = stray
	synthetic_mouse.pressed = true
	Input.parse_input_event(synthetic_mouse)
	if world.hud.fire_active or world._is_fire_requested():
		_fail("ANDROID_GHOST_FIRE: touching look zone triggered bullets")
		return
	synthetic_mouse.pressed = false
	Input.parse_input_event(synthetic_mouse)
	_screen_touch(world.hud, 7, stray, false)
	var aim_button: TextureButton = world.hud.touch_buttons["aim"]
	var aim_pos: Vector2 = aim_button.position + aim_button.size * 0.5
	_screen_touch(world.hud, 7, aim_pos, true)
	if world.hud.fire_active:
		_fail("ANDROID_GHOST_FIRE: touching AIM button triggered bullets")
		return
	_screen_touch(world.hud, 7, aim_pos, false)
	var fire_button: TextureButton = world.hud.touch_buttons["fire"]
	var fire_pos: Vector2 = fire_button.position + fire_button.size * 0.5
	_screen_touch(world.hud, 8, fire_pos, true)
	if not world.hud.fire_active or not world._is_fire_requested():
		_fail("Android FIRE zone did not activate shooting")
		return
	_screen_touch(world.hud, 8, fire_pos, false)
	if world.hud.fire_active or world._is_fire_requested():
		_fail("Android FIRE finger release stuck shooting")
		return
	world.hud._set_action("aim", true)
	for frame in ["idle_hip_01", "fire_hip_01", "ads_idle", "ads_fire_01", "sprint_01",
		"reload_01", "reload_02", "reload_03", "reload_04",
		"reload_empty_01", "reload_empty_02", "reload_empty_03", "reload_empty_04"]:
		if not ResourceLoader.exists("res://assets/imported/mp40/" + frame + ".png"):
			_fail("original gothic nun MP40 v3 frame missing: " + frame)
			return
	var source_in_bench = world.path_between(Vector3(-4.48,0,-9.8), Vector3(0,0,-12))
	if not source_in_bench.is_empty():
		_fail("zombie path must not start inside a pew")
		return
	var center_aisle = world.path_between(Vector3(0,0,12),Vector3(0,0,-12))
	if center_aisle.size() < 10:
		_fail("nave central aisle not navigable")
		return
	world.spawn_undead()
	if world.zombies.size() != 1:
		_fail("zombie instance missing")
		return
	var z = world.zombies[0]
	if not z.has_method("take_hit"):
		_fail("zombie combat entry missing")
		return
	for cue in ["fire", "mag_out", "mag_in", "charge"]:
		if not world.sound_players.has(cue):
			_fail("recovered Project Aether MP40 audio is missing: " + cue)
			return
	world.bullets = 3
	world.reserve = 33
	world.begin_reload()
	if world.reload_timer <= 0:
		_fail("reload does not start")
		return
	world.player.sprinting = true
	if world.reload_timer <= 0:
		_fail("sprint incorrectly cancels reload")
		return
	print("IGLESIA_SMOKE_GREEN: original nun MP40 v3 13-frame; all 14 Tripo pews and altar EXACT floor fitted; Android ghost-fire guarded; independent FIRE+ADS; reload preserved")
	quit(0)
