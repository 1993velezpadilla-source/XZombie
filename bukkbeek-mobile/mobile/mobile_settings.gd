extends Control
## Settings for the existing XZIEL 12-PNG HUD; no new action-button artwork.
signal profile_changed(profile: Dictionary)
signal resume_requested

const FILE_PATH := "user://xziel_mobile_settings.cfg"
const DEFAULTS := {
 "ads_mode": "toggle",
 "precision_fire": "release",
 "gyro_mode": "ads",
 "look_sensitivity": 0.0032,
 "ads_multiplier": 0.62,
 "gyro_sensitivity_x": 1.0,
 "gyro_sensitivity_y": 1.0,
 "gyro_deadzone": 0.03,
 "gyro_invert_x": false,
 "gyro_invert_y": false,
 "joystick_deadzone": 0.12
}
var profile: Dictionary = {}
var _column: VBoxContainer

static func load_profile() -> Dictionary:
 var data: Dictionary = DEFAULTS.duplicate(true)
 var cfg := ConfigFile.new()
 if cfg.load(FILE_PATH) == OK:
  for key in DEFAULTS:
   data[key] = cfg.get_value("mobile", key, DEFAULTS[key])
 return data

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 mouse_filter = Control.MOUSE_FILTER_STOP
 set_anchors_preset(Control.PRESET_FULL_RECT)
 profile = load_profile()
 var shade := ColorRect.new()
 shade.color = Color(0.0, 0.0, 0.0, 0.86)
 shade.set_anchors_preset(Control.PRESET_FULL_RECT)
 shade.mouse_filter = Control.MOUSE_FILTER_STOP
 add_child(shade)
 var scroller := ScrollContainer.new()
 scroller.anchor_left = 0.20
 scroller.anchor_right = 0.80
 scroller.anchor_top = 0.06
 scroller.anchor_bottom = 0.94
 scroller.mouse_filter = Control.MOUSE_FILTER_STOP
 add_child(scroller)
 var panel := PanelContainer.new()
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroller.add_child(panel)
 _column = VBoxContainer.new()
 _column.add_theme_constant_override("separation", 7)
 panel.add_child(_column)
 var title := Label.new()
 title.text = "XZIEL · PAUSE / MOBILE SETTINGS"
 title.add_theme_font_size_override("font_size", 24)
 _column.add_child(title)
 _choice("Aim down sights", "ads_mode", ["toggle", "hold"], ["Toggle", "Hold"])
 _choice("Sniper / shotgun firing", "precision_fire", ["press", "release"], ["On press", "On release"])
 _choice("Gyroscope", "gyro_mode", ["off", "ads", "always"], ["Off", "Only ADS", "Always"])
 _choice("Gyro invert X", "gyro_invert_x", [false, true], ["Normal", "Inverted"])
 _choice("Gyro invert Y", "gyro_invert_y", [false, true], ["Normal", "Inverted"])
 _slider("Look sensitivity", "look_sensitivity", 0.0010, 0.0090, 0.0002)
 _slider("ADS look multiplier", "ads_multiplier", 0.2, 1.5, 0.05)
 _slider("Gyro X sensitivity", "gyro_sensitivity_x", 0.2, 3.0, 0.1)
 _slider("Gyro Y sensitivity", "gyro_sensitivity_y", 0.2, 3.0, 0.1)
 _slider("Gyro deadzone", "gyro_deadzone", 0.0, 0.35, 0.01)
 _slider("Joystick deadzone", "joystick_deadzone", 0.02, 0.30, 0.01)
 var resume := Button.new()
 resume.text = "RESUME GAME"
 resume.custom_minimum_size = Vector2(0.0, 56.0)
 resume.pressed.connect(func(): resume_requested.emit())
 _column.add_child(resume)
 visible = false

func _choice(caption: String, key: String, values: Array, labels: Array) -> void:
 var row := HBoxContainer.new()
 _column.add_child(row)
 var label := Label.new()
 label.text = caption
 label.custom_minimum_size.x = 280.0
 row.add_child(label)
 var picker := OptionButton.new()
 picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 for i in range(values.size()):
  picker.add_item(str(labels[i]))
  if profile.get(key) == values[i]:
   picker.select(i)
 picker.item_selected.connect(func(index: int):
  profile[key] = values[index]
  _save()
 )
 row.add_child(picker)

func _slider(caption: String, key: String, low: float, high: float, step_value: float) -> void:
 var row := HBoxContainer.new()
 _column.add_child(row)
 var label := Label.new()
 label.text = caption
 label.custom_minimum_size.x = 280.0
 row.add_child(label)
 var slider := HSlider.new()
 slider.min_value = low
 slider.max_value = high
 slider.step = step_value
 slider.custom_minimum_size.x = 190.0
 slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 slider.value = float(profile.get(key, low))
 slider.value_changed.connect(func(value: float):
  profile[key] = value
  _save()
 )
 row.add_child(slider)

func _save() -> void:
 var cfg := ConfigFile.new()
 for key in profile:
  cfg.set_value("mobile", key, profile[key])
 var err := cfg.save(FILE_PATH)
 if err != OK:
  push_warning("XZIEL_SETTINGS_SAVE_FAILED " + str(err))
 profile_changed.emit(profile.duplicate(true))
