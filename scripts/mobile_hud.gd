extends Control
## Landscape touch HUD with reserved sprite slots; no obsolete buttons or visuals.
var game: Node3D
var stick_axis := Vector2.ZERO
var look_delta := Vector2.ZERO
var fire_active := false
var ads_active := false
var sprint_active := false
var jump_requested := false
var reload_requested := false
var use_requested := false
var weapon_anim := "idle_hip_01"
var pointer_id := -1
var pointer_origin := Vector2.ZERO
var look_id := -1
var status: Label
var weapon: TextureRect
var touch_buttons: Dictionary = {}
var frame_timer := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status = Label.new()
	status.position = Vector2(14, 10)
	status.add_theme_font_size_override("font_size", 23)
	add_child(status)
	weapon = TextureRect.new()
	weapon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weapon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(weapon)
	for action in ["fire", "aim", "reload", "interact", "jump"]:
		_add_touch_button(action)
	resized.connect(_layout)
	_layout()

func _add_touch_button(action: String) -> void:
	var b := TextureButton.new()
	b.name = action
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var texture_name := "vault_jump" if action == "jump" else action
	var tex_path := "res://assets/imported/buttons/" + texture_name + ".png""
	if ResourceLoader.exists(tex_path):
		b.texture_normal = load(tex_path)
	else:
		var label := Label.new()
		label.text = action.to_upper()
		label.add_theme_font_size_override("font_size", 21)
		b.add_child(label)
	b.pressed.connect(func(): _button(action, true))
	b.button_up.connect(func(): _button(action, false))
	add_child(b)
	touch_buttons[action] = b

func _button(action: String, down: bool) -> void:
	match action:
		"fire": fire_active = down
		"aim":
			if down:
				ads_active = not ads_active
		"reload":
			if down: reload_requested = true
		"interact":
			if down: use_requested = true
		"jump":
			if down: jump_requested = true


func _layout() -> void:
	var sz := get_viewport_rect().size
	if is_instance_valid(weapon):
		weapon.position = Vector2(sz.x * 0.5 - 290.0, sz.y - 370.0)
		weapon.size = Vector2(580, 370)
	var coords := {
		"fire": Vector2(sz.x - 145, sz.y - 180),
		"aim": Vector2(sz.x - 285, sz.y - 180),
		"reload": Vector2(sz.x - 155, sz.y - 310),
		"interact": Vector2(sz.x - 295, sz.y - 315),
		"jump": Vector2(sz.x - 420, sz.y - 140),
	}
	for action in coords:
		var b: TextureButton = touch_buttons.get(action)
		if is_instance_valid(b):
			b.position = coords[action]
			b.custom_minimum_size = Vector2(100, 100)
			b.size = Vector2(100, 100)
			b.modulate.a = 0.72

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed and e.position.x < size.x * 0.34 and e.position.y > size.y * 0.36 and pointer_id == -1:
			pointer_id = e.index
			pointer_origin = e.position
		elif e.pressed and e.position.x >= size.x * 0.34 and look_id == -1:
			look_id = e.index
		elif not e.pressed:
			if e.index == pointer_id:
				pointer_id = -1
				stick_axis = Vector2.ZERO
				sprint_active = false
			if e.index == look_id:
				look_id = -1
	elif e is InputEventScreenDrag:
		if e.index == pointer_id:
			var d: Vector2 = (e.position - pointer_origin) / 95.0
			stick_axis = d.limit_length(1.0)
			sprint_active = stick_axis.y < -0.85 and stick_axis.length() > 0.91
		elif e.index == look_id:
			look_delta += e.relative

func _process(delta: float) -> void:
	frame_timer += delta
	if frame_timer >= 0.11:
		frame_timer = 0.0
		if weapon_anim == "fire_hip_01":
			weapon_anim = "ads_idle" if ads_active else "idle_hip_01"
	if not is_instance_valid(weapon):
		return
	var frame := "ads_idle" if ads_active else "idle_hip_01"
	if is_instance_valid(game) and game.reload_timer > 0.0:
		var index := clampi(int((2.25 - game.reload_timer) / 0.5625), 0, 3)
		frame = "reload_%02d" % (index + 1)
	elif weapon_anim == "fire_hip_01":
		frame = "ads_fire_01" if ads_active else "fire_hip_01"
	elif sprint_active and not ads_active:
		frame = "sprint_01"
	var path := "res://assets/imported/mp40/" + frame + ".png"
	if ResourceLoader.exists(path):
		var t := load(path)
		if weapon.texture != t:
			weapon.texture = t
	weapon.visible = weapon.texture != null
	queue_redraw()

func set_status(round_id: int, pts: int, hp: int, mag: int, back: int, reloading: bool) -> void:
	status.text = "IGLESIA  |  RONDA %d   PUNTOS %d   VIDA %d   MP40 %d / %d%s" % [round_id, pts, hp, mag, back, "  RECARGANDO" if reloading else ""]

func show_game_over(reached: int) -> void:
	status.text = "IGLESIA  |  FIN DE PARTIDA  |  RONDA %d" % reached

func _draw() -> void:
	var s := get_viewport_rect().size
	var c := s * 0.5
	draw_line(c + Vector2(-14, 0), c + Vector2(-5, 0), Color(1, 1, 1, 0.75), 2.0)
	draw_line(c + Vector2(5, 0), c + Vector2(14, 0), Color(1, 1, 1, 0.75), 2.0)
	draw_line(c + Vector2(0, -14), c + Vector2(0, -5), Color(1, 1, 1, 0.75), 2.0)
	draw_line(c + Vector2(0, 5), c + Vector2(0, 14), Color(1, 1, 1, 0.75), 2.0)
	if pointer_id >= 0:
		draw_arc(pointer_origin, 80, 0, TAU, 32, Color(1, 1, 1, 0.18), 3.0)
		draw_circle(pointer_origin + stick_axis * 64, 28, Color(1, 1, 1, 0.22))
