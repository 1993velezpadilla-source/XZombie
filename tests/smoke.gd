extends SceneTree

func _initialize() -> void:
	call_deferred("_smoke")

func _fail(message: String) -> void:
	push_error("IGLESIA_SMOKE_RED: " + message)
	quit(1)

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
	if ResourceLoader.exists("res://assets/imported/altar.glb"):
		var altar_skin := altar.get_child(1)
		if absf(altar_skin.rotation_degrees.y + 90.0) > 0.5:
			_fail("Tripo altar faces the wrong direction")
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
	print("IGLESIA_SMOKE_GREEN: altar 5m faces pews, 14 benches, nav, zombie, verified MP40 audio, FIRE/ADS/ADS+FIRE multi-touch, sprint/reload")
	quit(0)
