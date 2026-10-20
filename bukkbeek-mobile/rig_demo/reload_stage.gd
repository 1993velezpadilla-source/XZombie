extends Node2D
## Isolated feasibility experiment: REAL V6 artwork + actual Godot Bone2D.
## Never attached to the playable gun. No change to damage, ammo or game timing.
## Flat cutouts cannot recreate hidden geometry. Judge visible seams honestly.
const ART := "res://rig_demo/assets/"
const LENGTH := 2.80

var clock := 0.0
var capture_mode := false
var stage: Node2D
var skeleton: Skeleton2D
var upper: Bone2D
var wrist: Bone2D
var sleeve: Sprite2D
var mag_hand: Sprite2D
var bolt_hand: Sprite2D
var gun: Sprite2D
var phase_label: Label
var info_label: Label

func _ready() -> void:
 var background := ColorRect.new()
 background.name = "Background"
 background.color = Color("#313745")
 background.size = Vector2(1280,720)
 add_child(background)
 var header := Label.new()
 header.text = "MP40  |  GODOT 2D BONE STUDY"
 header.position = Vector2(38, 24)
 header.add_theme_font_size_override("font_size", 30)
 header.add_theme_color_override("font_color", Color("#f4f2e7"))
 add_child(header)
 info_label = Label.new()
 info_label.text = "Two existing V6 PNG poses • Two actual Bone2D joints • NOT a gameplay build"
 info_label.position = Vector2(40, 68)
 info_label.add_theme_font_size_override("font_size", 17)
 add_child(info_label)
 phase_label = Label.new()
 phase_label.name = "Phase"
 phase_label.position = Vector2(39, 649)
 phase_label.add_theme_font_size_override("font_size", 20)
 add_child(phase_label)
 var footer := Label.new()
 footer.text = "ART QUALITY GATE: arm seams / fingers / bolt manipulation are NOT production-ready. Tap to replay."
 footer.position = Vector2(39, 686)
 footer.add_theme_font_size_override("font_size", 15)
 footer.add_theme_color_override("font_color", Color("#ffb6a0"))
 add_child(footer)

 # Stable 483x326 frame coordinates: the WEAPON NEVER teleports between poses.
 stage = Node2D.new()
 stage.position = Vector2(310, 120)
 stage.scale = Vector2.ONE * 1.52
 add_child(stage)
 gun = _sprite("gun_right_arm.png","Stable Gun + Right Hand")
 stage.add_child(gun)
 gun.position = Vector2.ZERO

 skeleton = Skeleton2D.new()
 skeleton.name = "Actual_Skeleton2D"
 stage.add_child(skeleton)
 upper = Bone2D.new()
 upper.name = "LeftUpperArm"
 upper.position = Vector2(43, 295)
 skeleton.add_child(upper)
 sleeve = _sprite("left_sleeve.png","SleeveOnUpperArmBone")
 upper.add_child(sleeve)
 sleeve.position = -Vector2(43, 295)

 wrist = Bone2D.new()
 wrist.name = "LeftWrist"
 wrist.position = Vector2(32, -45)
 upper.add_child(wrist)
 mag_hand = _sprite("left_mag_hand.png","GripAndMagazineOnWristBone")
 wrist.add_child(mag_hand)
 mag_hand.position = -Vector2(75,250)
 bolt_hand = _sprite("left_bolt_hand.png","BoltGestureAlternativeOnSameWristBone")
 wrist.add_child(bolt_hand)
 bolt_hand.position = -Vector2(75,250)
 seek(0.0)

func _sprite(path: String, display_name: String) -> Sprite2D:
 var art: Texture2D = load(ART + path) as Texture2D
 if art == null:
  push_error("MP40_BONES_MISSING_SOURCE_ART: " + path)
 var node := Sprite2D.new()
 node.name = display_name
 node.centered = false
 node.texture = art
 node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
 return node

func _ease(a: float, b: float, t: float) -> float:
 var x := clampf((t - a) / maxf(0.001,b-a), 0.0, 1.0)
 return x*x*(3.0-2.0*x)

func _process(delta: float) -> void:
 if capture_mode: return
 clock = fmod(clock + delta, LENGTH)
 seek(clock)

func _unhandled_input(event: InputEvent) -> void:
 if (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
  clock = 0.0
  seek(0.0)

func seek(t: float) -> void:
 t = clampf(t, 0.0, LENGTH)
 var dx := 0.0
 var dy := 0.0
 var bend := 0.0
 var wrist_angle := 0.0
 var use_mag := true
 var phase := ""
 # Empty reload motion reference: mag out -> bolt gesture -> fresh mag in.
 # This is a 2D BONE MOTION TEST; the existing animation/timing is untouched.
 if t < 0.70:
  var k := _ease(0.0,0.70,t)
  dx = lerpf(100.0, -12.0, k)
  dy = lerpf(-20.0, 13.0, k)
  bend = lerpf(0.13, -0.06, k)
  wrist_angle = lerpf(-0.14, 0.07, k)
  phase = "01  /  Remove the old magazine — moving wrist bone"
 elif t < 1.15:
  var k := _ease(0.70,1.15,t)
  dx = lerpf(-12.0, -34.0, k)
  dy = lerpf(13.0, 52.0, k)
  bend = lerpf(-0.06, 0.07, k)
  wrist_angle = lerpf(0.07, 0.0, k)
  phase = "02  /  Move old magazine away — original artwork pose"
 elif t < 1.88:
  var k := _ease(1.15,1.50,t)
  var back := _ease(1.52,1.88,t)
  dx = lerpf(-34.0, 135.0, k) - 23.0 * back
  dy = lerpf(52.0, -65.0, k) + 8.0 * back
  bend = lerpf(0.07, -0.18, k)
  wrist_angle = lerpf(0.0, -0.23, k) + 0.16 * back
  use_mag = false
  phase = "03  /  Reach charging-handle area — second hand PNG"
 elif t < 2.53:
  var k := _ease(1.88,2.53,t)
  dx = lerpf(-35.0, 100.0, k)
  dy = lerpf(86.0, -20.0, k)
  bend = lerpf(0.11,0.13,k)
  wrist_angle = lerpf(-0.13,-0.14,k)
  phase = "04  /  Insert the new magazine — wrist interpolated"
 else:
  var k := _ease(2.53,2.80,t)
  dx = lerpf(100.0,90.0,k)
  dy = lerpf(-20.0,12.0,k)
  bend = lerpf(0.13,0.0,k)
  wrist_angle = lerpf(-0.14,0.0,k)
  phase = "05  /  Settle (art/hand continuity still requires redraw)"

 upper.position = Vector2(43.0 + dx, 295.0 + dy)
 upper.rotation = bend
 wrist.rotation = wrist_angle
 mag_hand.visible = use_mag
 bolt_hand.visible = not use_mag
 phase_label.text = phase + "  [%.2fs / 2.80s]" % t

func get_rig_metrics() -> Dictionary:
 return {"skeleton": skeleton != null, "upper": upper is Bone2D,
   "wrist": wrist is Bone2D, "gun": gun.texture != null,
   "mag": mag_hand.texture != null, "bolt": bolt_hand.texture != null}
