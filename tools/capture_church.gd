extends SceneTree
## Render the actual Godot game scene in Github CI with Mesa/Xvfb.
## Target reference images from the user are NOT a build artifact;
## these are real camera screenshots for visual criticism, not invented art.
var _world: Node3D

func _initialize() -> void:
	call_deferred("_capture")

func _fail(msg: String) -> void:
	push_error("IGLESIA_REAL_CAMERA_RED: " + msg)
	quit(83)

func _frame(path: String, label: String) -> bool:
	for i in range(5):
		await process_frame
	var view := root.get_texture().get_image()
	if view == null or view.get_width() < 800 or view.get_height() < 450:
		_fail("failed to produce real viewport image " + label)
		return false
	var err := view.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		_fail("failed to save actual Godot " + label + ": " + str(err))
		return false
	print("IGLESIA_REAL_CAMERA_CAPTURED mode=", label, " file=", path,
		" size=", view.get_width(), "x", view.get_height())
	return true

func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var scene: PackedScene = load("res://main.tscn")
	if scene == null:
		_fail("main scene not loaded")
		return
	_world = scene.instantiate() as Node3D
	root.add_child(_world)
	await process_frame
	if _world.get("player") == null or _world.get("hud") == null:
		_fail("real player/hud missing")
		return
	var ply: CharacterBody3D = _world.get("player")
	ply.set_physics_process(false)
	ply.global_position = Vector3(0, 0.20, 11.1)
	ply.rotation = Vector3.ZERO
	var cam: Camera3D = ply.get("camera") as Camera3D
	cam.rotation = Vector3.ZERO
	cam.current = true
	# Match the user's specific Round-2 HIP/ADS screenshot reference
	# without altering the real running game or producing a fake mockup.
	_world.set("round_number", 2)
	_world.set("points", 1000)
	_world.set("bullets", 32)
	_world.set("reserve", 141)
	_world.set("next_round_timer", 60.0)
	var hud: Control = _world.get("hud")
	hud.set("ads_toggled", false)
	hud.set("ads_active", false)
	hud.call("set_status", 2, 1000, 100, 32, 141, false)
	if not await _frame("res://build/iglesia-main-aisle-HIP.png", "hip"):
		return
	_world.set("bullets", 6)
	_world.set("reserve", 167)
	hud.set("ads_toggled", true)
	hud.set("ads_active", true)
	hud.call("set_status", 2, 1000, 100, 6, 167, false)
	if not await _frame("res://build/iglesia-main-aisle-ADS.png", "ads"):
		return
	print("IGLESIA_REAL_CAMERA_2_CAPTURED review_status=PENDING_COMPARE_TO_USER_TARGET")
	quit(0)
