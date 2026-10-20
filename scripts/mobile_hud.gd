extends Control
## Iglesia-only modern touchscreen HUD. Official XZIEL PNGs, no legacy runtime.
## Multi-touch is owned by finger ID: fire/ADS/aim-fire never steal each other.
const SOURCE_BUTTONS := "res://assets/imported/buttons/"
const SOURCE_FRAMES := "res://assets/imported/mp40/"
const HIP_SIGHT_PX := Vector2(221.5, 105.0)
const ADS_SIGHT_PX := Vector2(242.0, 126.0)
const ADS_FIRE_SIGHT_PX := Vector2(245.0, 114.0)
const BUTTON_LAYOUT := {
    "fire": Vector2(0.885, 0.59),
    "aim_fire": Vector2(0.795, 0.405),
    "aim": Vector2(0.695, 0.60),
    "reload": Vector2(0.885, 0.815),
    "interact": Vector2(0.565, 0.685),
    "jump": Vector2(0.695, 0.815)
}
var game
var stick_axis := Vector2.ZERO
var look_delta := Vector2.ZERO
var fire_active := false
var ads_active := false
var ads_toggled := false
var sprint_active := false
var jump_requested := false
var reload_requested := false
var use_requested := false
var weapon_anim := "idle_hip_01"
var shot_remaining := 0.0
var pointer_id := -1
var pointer_origin := Vector2.ZERO
var touch_owners: Dictionary = {}
var held_actions: Dictionary = {}
var status: Label
var weapon: TextureRect
var touch_buttons: Dictionary = {}
var loaded_frames: Dictionary = {}

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    status = Label.new()
    status.name = "SurvivalStatus"
    status.position = Vector2(18, 12)
    status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    status.add_theme_font_size_override("font_size", 23)
    add_child(status)
    weapon = TextureRect.new()
    weapon.name = "NunMP40PixelViewmodel"
    weapon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    weapon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    weapon.stretch_mode = TextureRect.STRETCH_SCALE
    weapon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(weapon)
    for action in BUTTON_LAYOUT.keys():
        _add_touch_button(action)
    resized.connect(_layout)
    get_viewport().size_changed.connect(_layout)
    _layout()

func _add_touch_button(action: String) -> void:
    var b := TextureButton.new()
    b.name = action
    b.ignore_texture_size = true
    b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    b.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var texture_name := "vault_jump" if action == "jump" else action
    var tex_path := SOURCE_BUTTONS + texture_name + ".png"
    if ResourceLoader.exists(tex_path):
        b.texture_normal = load(tex_path)
    else:
        # Explicit warning: missing approved art should never be masqueraded
        # as a finished, old button skin.
        push_warning("IGLESIA_OFFICIAL_TOUCH_PNG_MISSING: " + tex_path)
        var label := Label.new()
        label.text = action.to_upper()
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        b.add_child(label)
    add_child(b)
    touch_buttons[action] = b

func _layout() -> void:
    var s := get_viewport_rect().size
    if s.x <= 0 or s.y <= 0:
        return
    var diameter := clampf(s.y * 0.13, 72.0, 116.0)
    for action in BUTTON_LAYOUT.keys():
        var b: TextureButton = touch_buttons.get(action)
        if is_instance_valid(b):
            var center: Vector2 = BUTTON_LAYOUT[action] * s
            b.position = center - Vector2.ONE * (diameter * 0.5)
            b.size = Vector2.ONE * diameter
            b.modulate.a = 0.85 if int(held_actions.get(action, 0)) > 0 else 0.68

func _action_at(pos: Vector2) -> String:
    for action in ["fire", "aim_fire", "aim", "reload", "jump", "interact"]:
        var b: TextureButton = touch_buttons.get(action)
        if is_instance_valid(b) and Rect2(b.position, b.size).has_point(pos):
            return action
    return ""

func _set_action(action: String, down: bool) -> void:
    if action == "aim":
        if down:
            ads_toggled = not ads_toggled
    elif action in ["fire", "aim_fire"]:
        var count := int(held_actions.get(action, 0))
        held_actions[action] = maxi(0, count + (1 if down else -1))
    elif down:
        match action:
            "reload": reload_requested = true
            "interact": use_requested = true
            "jump": jump_requested = true
    fire_active = int(held_actions.get("fire", 0)) + int(held_actions.get("aim_fire", 0)) > 0
    ads_active = ads_toggled or int(held_actions.get("aim_fire", 0)) > 0
    _layout()

func _input(e: InputEvent) -> void:
    if e is InputEventScreenTouch:
        if e.pressed:
            if touch_owners.has(e.index):
                _release_finger(e.index)
            var role := _action_at(e.position)
            if role.is_empty():
                if e.position.x < size.x * 0.40 and e.position.y > size.y * 0.34 and pointer_id < 0:
                    role = "move"
                    pointer_id = e.index
                    pointer_origin = e.position
                else:
                    role = "look"
            touch_owners[e.index] = role
            if role not in ["move", "look"]:
                _set_action(role, true)
        else:
            _release_finger(e.index)
    elif e is InputEventScreenDrag:
        var role: String = touch_owners.get(e.index, "")
        if role == "move" and e.index == pointer_id:
            stick_axis = ((e.position - pointer_origin) / maxf(80.0, size.y * 0.13)).limit_length(1.0)
            sprint_active = stick_axis.y < -0.87 and stick_axis.length() > 0.91
        elif role in ["look", "fire", "aim_fire"]:
            # Finger can drag camera while continuing to fire / aim+fire.
            look_delta += e.relative

func _release_finger(index: int) -> void:
    if not touch_owners.has(index):
        return
    var role: String = touch_owners[index]
    touch_owners.erase(index)
    if role == "move" and index == pointer_id:
        pointer_id = -1
        stick_axis = Vector2.ZERO
        sprint_active = false
    elif role not in ["look", "move"]:
        _set_action(role, false)

func trigger_shot() -> void:
    shot_remaining = 0.092
    weapon_anim = "fire_hip_01"

func _process(delta: float) -> void:
    shot_remaining = maxf(0.0, shot_remaining - delta)
    var frame := "ads_idle" if ads_active else "idle_hip_01"
    if is_instance_valid(game) and game.reload_timer > 0.0:
        var progress := 1.0 - clampf(game.reload_timer / game.RELOAD_SECONDS, 0.0, 1.0)
        frame = "reload_%02d" % clampi(int(progress * 4.0) + 1, 1, 4)
    elif shot_remaining > 0.0:
        frame = "ads_fire_01" if ads_active else "fire_hip_01"
    elif sprint_active and not ads_active:
        frame = "sprint_01"
    weapon_anim = frame
    if not loaded_frames.has(frame):
        var path := SOURCE_FRAMES + frame + ".png"
        if ResourceLoader.exists(path):
            loaded_frames[frame] = load(path)
    var image: Texture2D = loaded_frames.get(frame)
    if image == null:
        weapon.visible = false
        return
    if weapon.texture != image:
        weapon.texture = image
    weapon.visible = true
    _position_weapon(frame, image)

func _position_weapon(frame: String, image: Texture2D) -> void:
    var s := get_viewport_rect().size
    var scale_unit := minf(s.x / 1280.0, s.y / 720.0)
    var is_ads := frame.begins_with("ads")
    var optical := ADS_FIRE_SIGHT_PX if frame == "ads_fire_01" else ADS_SIGHT_PX
    if not is_ads:
        optical = HIP_SIGHT_PX
    var scale_factor := scale_unit * (1.87 if is_ads else 1.35)
    # Hip muzzle is aimed towards the CROSSHAIR, not the far left of screen.
    # Iron-sight center and hitscan ray share the exact viewport center.
    var target := s * 0.5 + (Vector2.ZERO if is_ads else Vector2(0, 22.0 * scale_unit))
    weapon.size = image.get_size() * scale_factor
    weapon.position = target - optical * scale_factor

func set_status(round_id: int, pts: int, hp: int, mag: int, back: int, reloading: bool) -> void:
    status.text = "VIDA %d      RONDA %d      %d PTS      MP40 %d / %d%s" % [
        hp, round_id, pts, mag, back, "   RECARGANDO" if reloading else ""
    ]

func show_game_over(reached: int) -> void:
    status.text = "IGLESIA  |  FIN DE PARTIDA  |  RONDA %d" % reached

func _draw() -> void:
    var s := get_viewport_rect().size
    var center := s * 0.5
    if not ads_active:
        draw_line(center + Vector2(-11, 0), center + Vector2(-4, 0), Color(1, 1, 1, 0.85), 2.0)
        draw_line(center + Vector2(4, 0), center + Vector2(11, 0), Color(1, 1, 1, 0.85), 2.0)
        draw_line(center + Vector2(0, -11), center + Vector2(0, -4), Color(1, 1, 1, 0.85), 2.0)
        draw_line(center + Vector2(0, 4), center + Vector2(0, 11), Color(1, 1, 1, 0.85), 2.0)
    if pointer_id >= 0:
        draw_arc(pointer_origin, 76, 0, TAU, 32, Color(1, 1, 1, 0.14), 3.0)
        draw_circle(pointer_origin + stick_axis * 63, 25, Color(1, 1, 1, 0.20))
