extends CanvasLayer
## XZIEL official mobile HUD for the pristine Bukkbeek Godot 4.6 FPS template.
const ICONS := "res://mobile/icons/"
const LAYOUT := {
 "fire": {"p":Vector2(0.885,0.585),"r":0.075,"icon":"fire"},
 "adsfire": {"p":Vector2(0.795,0.435),"r":0.057,"icon":"adsfire"},
 "ads": {"p":Vector2(0.695,0.575),"r":0.051,"icon":"ads"},
 "reload": {"p":Vector2(0.805,0.785),"r":0.046,"icon":"reload"},
 "use": {"p":Vector2(0.605,0.675),"r":0.046,"icon":"use"},
 "jump": {"p":Vector2(0.695,0.790),"r":0.047,"icon":"jump"},
 "knife": {"p":Vector2(0.915,0.800),"r":0.046,"icon":"knife"},
 "weapon": {"p":Vector2(0.905,0.300),"r":0.044,"icon":"weapon"},
 "sprint": {"p":Vector2(0.300,0.555),"r":0.046,"icon":"sprint"},
 "crouch": {"p":Vector2(0.555,0.845),"r":0.044,"icon":"slide"},
 "pause": {"p":Vector2(0.960,0.100),"r":0.041,"icon":"pause"}
}
const HELD := {
 "fire":["fire"],"adsfire":["fire","aim_mode"],"ads":["aim_mode"],
 "reload":["reload"],"use":["activate"],"jump":["jump"],
 "sprint":["sprint"],"crouch":["crouch"]
}
const DEADZONE := 0.12
const LOOK_SENSITIVITY := 0.0032
const ADS_LOOK_MULTIPLIER := 0.62
var layer_root: Control
var images: Dictionary = {}
var active: Dictionary = {}
var hold_counts: Dictionary = {}
var stick_index: int = -1
var stick_origin: Vector2 = Vector2.ZERO
var stick_value: Vector2 = Vector2.ZERO
var stick_ring: TextureRect
var stick_knob: TextureRect
var is_aiming: bool = false
var paused: bool = false

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 layer = 20
 layer_root = Control.new()
 layer_root.name = "XZIEL_Official_Touch"
 layer_root.set_anchors_preset(Control.PRESET_FULL_RECT)
 layer_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(layer_root)
 for key in LAYOUT.keys():
  var ring := _image("touch_idle")
  var glyph := _image(str(LAYOUT[key]["icon"]))
  layer_root.add_child(ring)
  layer_root.add_child(glyph)
  images[key] = {"ring":ring,"glyph":glyph}
 stick_ring = _image("joystick_ring")
 stick_knob = _image("joystick_knob")
 layer_root.add_child(stick_ring)
 layer_root.add_child(stick_knob)
 get_viewport().size_changed.connect(_layout)
 _layout()

func _image(asset_name: String) -> TextureRect:
 var rect := TextureRect.new()
 var path := ICONS + asset_name + ".png"
 if ResourceLoader.exists(path):
  rect.texture = load(path)
 rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
 rect.modulate.a = 0.82
 return rect

func _place(img: TextureRect, center: Vector2, diameter: float) -> void:
 var v := Vector2(diameter,diameter)
 img.position = center - v * 0.5
 img.size = v

func _layout() -> void:
 var s := Vector2(get_viewport().get_visible_rect().size)
 if s.x < 1.0 or s.y < 1.0: return
 layer_root.size = s
 for key in LAYOUT.keys():
  var spec: Dictionary = LAYOUT[key]
  var center := Vector2(spec["p"].x * s.x, spec["p"].y * s.y)
  var d: float = s.y * spec["r"] * 2.0
  _place(images[key]["ring"],center,d)
  _place(images[key]["glyph"],center,d*0.52)
 var center := stick_origin if stick_index != -1 else Vector2(s.x*0.17,s.y*0.74)
 var d := s.y*0.32
 _place(stick_ring,center,d)
 _place(stick_knob,center+stick_value*s.y*0.105,d*0.46)

func _visual(role: String, down: bool) -> void:
 if not images.has(role): return
 var name := "touch_pressed" if down else "touch_idle"
 if role == "fire":
  name = "touch_fire_pressed" if down else "touch_fire_idle"
 elif role == "ads":
  name = "touch_ads_pressed" if down else "touch_ads_idle"
 elif role == "adsfire":
  name = "touch_adsfire_pressed" if down else "touch_adsfire_idle"
 var path := ICONS+name+".png"
 if ResourceLoader.exists(path):
  images[role]["ring"].texture = load(path)

func _role_for(pos: Vector2) -> String:
 var s := Vector2(get_viewport().get_visible_rect().size)
 if s.x <= 0.0 or s.y <= 0.0: return ""
 for key in LAYOUT.keys():
  var spec: Dictionary = LAYOUT[key]
  var center := Vector2(spec["p"].x*s.x,spec["p"].y*s.y)
  if pos.distance_to(center) <= s.y*spec["r"]: return key
 if pos.x < s.x*0.45 and pos.y > s.y*0.30: return "move"
 return "look"

func _input(event: InputEvent) -> void:
 if event is InputEventScreenTouch:
  if event.pressed: _down(event.index,event.position)
  else: _up(event.index)
  get_viewport().set_input_as_handled()
 elif event is InputEventScreenDrag:
  _drag(event.index,event.position,event.relative)
  get_viewport().set_input_as_handled()

func _down(index: int, pos: Vector2) -> void:
 if active.has(index): _up(index)
 var role := _role_for(pos)
 active[index] = role
 if role == "move" and stick_index == -1 and not paused:
  stick_index = index
  stick_origin = pos
  stick_value = Vector2.ZERO
  _update_stick(pos)
 elif role == "pause":
  _toggle_pause()
 elif role != "look" and not paused:
  _press(role)
 _layout()

func _drag(index: int, pos: Vector2, delta: Vector2) -> void:
 if not active.has(index) or paused: return
 var role: String = active[index]
 if role == "move" and index == stick_index:
  _update_stick(pos)
 elif role == "look":
  if Global.in_vehicle or not is_instance_valid(Global.player): return
  var p = Global.player
  var m := ADS_LOOK_MULTIPLIER if is_aiming else 1.0
  p.camera_pivot.rotate_y(-delta.x*LOOK_SENSITIVITY*m)
  p.camera_holder.rotate_x(-delta.y*LOOK_SENSITIVITY*m)
  p.camera_holder.rotation.x = clampf(p.camera_holder.rotation.x,deg_to_rad(-60.0),deg_to_rad(60.0))

func _up(index: int) -> void:
 if not active.has(index): return
 var role: String = active[index]
 active.erase(index)
 if role == "move" and stick_index == index:
  stick_index = -1
  stick_value = Vector2.ZERO
  _movement()
 elif HELD.has(role) and not paused:
  _release(role)
 _layout()

func _update_stick(pos: Vector2) -> void:
 var radius := maxf(1.0,get_viewport().get_visible_rect().size.y*0.16)
 stick_value = (pos-stick_origin).limit_length(radius)/radius
 if stick_value.length() < DEADZONE: stick_value=Vector2.ZERO
 _movement()
 _layout()

func _drive(action: String, strength: float) -> void:
 if strength > 0.01: Input.action_press(action,strength)
 else: Input.action_release(action)

func _movement() -> void:
 _drive("left",maxf(0.0,-stick_value.x))
 _drive("right",maxf(0.0,stick_value.x))
 _drive("forward",maxf(0.0,-stick_value.y))
 _drive("backward",maxf(0.0,stick_value.y))

func _press(role: String) -> void:
 _visual(role,true)
 if HELD.has(role):
  for action in HELD[role]:
   var count: int = hold_counts.get(action,0)+1
   hold_counts[action]=count
   if count == 1: Input.action_press(action)
  _sync_aim()
 elif role == "weapon":
  Global.weapon_switch_next.emit()
 elif role == "knife" and is_instance_valid(Global.player):
  Global.player.weapons_manager.switch_weapon(0)

func _release(role: String) -> void:
 _visual(role,false)
 if HELD.has(role):
  for action in HELD[role]:
   var count: int = maxi(0,hold_counts.get(action,0)-1)
   hold_counts[action]=count
   if count == 0: Input.action_release(action)
  _sync_aim()

func _sync_aim() -> void:
 var aim: bool = hold_counts.get("aim_mode",0)>0
 if aim != is_aiming:
  is_aiming=aim
  Global.aim_mode_changed.emit(aim)

func _toggle_pause() -> void:
 if paused:
  paused=false
  get_tree().paused=false
 else:
  _release_all()
  paused=true
  get_tree().paused=true
 _visual("pause",paused)

func _release_all() -> void:
 for action in ["fire","aim_mode","reload","activate","jump","sprint","crouch","left","right","forward","backward"]:
  Input.action_release(action)
 hold_counts.clear()
 active.clear()
 stick_index=-1
 stick_value=Vector2.ZERO
 _sync_aim()
 for key in LAYOUT.keys(): _visual(key,false)
 _layout()

func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
  if is_inside_tree(): _release_all()

func _exit_tree() -> void:
 _release_all()
