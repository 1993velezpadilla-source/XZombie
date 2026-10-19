extends "res://common/weapon/weapon.gd"
## Independent sprite-viewmodel experiment. Never modifies MP40Source or other guns.
const ATLAS := "res://mobile/mp40_pixel/atlas.png"
const ADS_SECONDS := 0.20
const HIP := 0
const ADS := 1
const FIRE_HIP := 2
const FIRE_ADS := 3
const SPRINT := 4
const RELOAD_FIRST := 5
var atlas: Texture2D
var frame_size: Vector2i
var canvas: CanvasLayer
var drawing: Sprite2D
var last_frame := -1
var ads_weight := 0.0
var shot_left := 0.0
var bob_time := 0.0
var active := false
var empty_reload := false
var played_out := false
var played_in := false
var played_charge := false
var mag_out: AudioStreamPlayer3D
var mag_in: AudioStreamPlayer3D
var charge: AudioStreamPlayer3D

func _ready() -> void:
 super._ready()
 var original_demo_arms := get_node_or_null("fps_demo_arms") as Node3D
 if original_demo_arms != null: original_demo_arms.visible = false
 animation_fire = ""
 animation_reload = ""
 reload_sfx = null
 mag_out = get_node_or_null("SFX/MagazineRemoveCue") as AudioStreamPlayer3D
 mag_in = get_node_or_null("SFX/MagazineInsertCue") as AudioStreamPlayer3D
 charge = get_node_or_null("SFX/BoltChargeCue") as AudioStreamPlayer3D
 atlas = load(ATLAS) as Texture2D
 if atlas == null or atlas.get_width() % 3 != 0 or atlas.get_height() % 3 != 0:
  push_error("MP40_PIXEL_RED: missing/invalid user sprite atlas")
  return
 frame_size = Vector2i(atlas.get_width() / 3, atlas.get_height() / 3)
 canvas = CanvasLayer.new()
 canvas.name = "MP40PixelViewmodel"
 canvas.layer = 1
 add_child(canvas)
 drawing = Sprite2D.new()
 drawing.centered = false
 drawing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 canvas.add_child(drawing)
 _set_frame(HIP)
 canvas.visible = false
 set_meta("mp40_pixel", true)
 print("MP40_PIXEL_READY: user sprites=9; original MP40 sounds; stock bullet simulation")

func activate(current_aim_mode: bool = false) -> void:
 super.activate(current_aim_mode)
 active = true
 ads_weight = 1.0 if current_aim_mode else 0.0
 shot_left = 0.0
 if canvas != null: canvas.visible = true
 _refresh()

func deactivate() -> void:
 active = false
 if canvas != null: canvas.visible = false
 super.deactivate()

func _on_aim_mode_changed(aim_mode: bool) -> void:
 super._on_aim_mode_changed(aim_mode)
 if active: is_aimed = aim_mode

func fire_weapon() -> void:
 super.fire_weapon() # keeps exact existing fire sound, hit detection and ammo
 shot_left = 0.082
 _refresh()

func start_reload() -> void:
 var previously_empty := current_mag == 0
 super.start_reload()
 if not is_reloading: return
 empty_reload = previously_empty
 played_out = false
 played_in = false
 played_charge = false
 _refresh()

func cancel_tactical_reload() -> void:
 if not is_reloading or current_mag <= 0: return
 reload_timer.stop()
 is_reloading = false
 _refresh()

func _process(delta: float) -> void:
 if not active or drawing == null: return
 shot_left = maxf(0.0, shot_left - delta)
 ads_weight = move_toward(ads_weight, 1.0 if is_aimed else 0.0, delta / ADS_SECONDS)
 bob_time += delta * (9.0 if Input.is_action_pressed("sprint") else 3.0)
 _refresh()

func _refresh() -> void:
 if drawing == null: return
 var frame := HIP
 if is_reloading:
  var progress := clampf(1.0 - reload_timer.time_left / maxf(reload_time, 0.01), 0.0, 1.0)
  if progress < 0.25: frame = RELOAD_FIRST
  elif progress < 0.44: frame = RELOAD_FIRST + 1
  elif progress < 0.61: frame = RELOAD_FIRST + 2
  else: frame = RELOAD_FIRST + 3
  if progress >= 0.24 and not played_out:
   played_out = true
   if mag_out != null: mag_out.play()
  if progress >= 0.72 and not played_in:
   played_in = true
   if mag_in != null: mag_in.play()
  if progress >= 0.86 and empty_reload and not played_charge:
   played_charge = true
   if charge != null: charge.play()
 elif shot_left > 0.0:
  frame = FIRE_ADS if ads_weight > 0.7 else FIRE_HIP
 elif ads_weight > 0.7:
  frame = ADS
 elif Input.is_action_pressed("sprint") and not is_aimed:
  frame = SPRINT
 _set_frame(frame)
 var viewport_size: Vector2 = get_viewport().get_visible_rect().size
 var s := minf(viewport_size.x / 1280.0, viewport_size.y / 720.0) * 1.25
 drawing.scale = Vector2.ONE * s * (512.0 / float(frame_size.x))
 var pos_x := lerpf(viewport_size.x * 0.515, viewport_size.x * 0.326, ads_weight)
 var pos_y := viewport_size.y - 326.0 * s - viewport_size.y * 0.14 * ads_weight
 drawing.position = Vector2(pos_x, pos_y + sin(bob_time) * (0.0 if is_aimed or is_reloading else 2.0 * s))

func _set_frame(frame: int) -> void:
 if drawing == null or frame == last_frame: return
 last_frame = frame
 var cropped := AtlasTexture.new()
 cropped.atlas = atlas
 cropped.region = Rect2((frame % 3) * frame_size.x, int(frame / 3) * frame_size.y, frame_size.x, frame_size.y)
 cropped.filter_clip = true
 drawing.texture = cropped
