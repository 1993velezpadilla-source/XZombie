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
	if world.player == null or world.player.camera == null:
		_fail("first person player/camera missing")
		return
	if world.hud == null:
		_fail("touch UI missing")
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
	print("IGLESIA_SMOKE_GREEN: nave, 14 pews, altar collider, center route, 1 zombie, fps HUD, sprint/reload contract")
	quit(0)
