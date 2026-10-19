extends "res://common/weapon/weapon.gd"
## MP40Pixel V2: independent 2D first-person renderer. No edits to 3D MP40.
## Draws ALL frames above world, below native XZIEL HUD. Coexists with 9 guns.
const SOURCE_ROOT := "res://mobile/mp40_pixel/"
const SOURCE_ATLAS := SOURCE_ROOT + "atlas.png"
const SOURCE_FRAMES := SOURCE_ROOT + "frames/"
const FRAME_NAMES: Array[String] = [
 "idle_hip_01", "ads_idle", "fire_hip_01", "ads_fire_01",
 "sprint_01", "reload_01", "reload_02", "reload_03", "reload_04"
]
const HIP := 0
const ADS := 1
const HIP_FIRE := 2
const ADS_FIRE := 3
const SPRINT := 4
const RELOAD_01 := 5
const ADS_TIME := 0.20
## Measured directly from the original transparent 400x200 ADS frame.
## Sight center is at x ~= 250 / 400; centering sprite bounds is WRONG.
const ADS_SIGHT_X := 0.625
const ADS_SIGHT_Y := 0.090
## The supplied FIRE PNG is reframed: its front post is x~=220/472,
## y~=110/301, NOT the idle post at x~=255/400, y~=18/200.
const ADS_FIRE_SIGHT_X := 0.466
const ADS_FIRE_SIGHT_Y := 0.365

var textures: Array[Texture2D] = []
var sprite_canvas: CanvasLayer
var hip_sprite: Sprite2D
var ads_sprite: Sprite2D
var loaded_original_pngs := 0
var active := false
var ads_weight := 0.0
var shot_remaining := 0.0
var motion_time := 0.0
var empty_reload := false
var played_mag_out := false
var played_mag_in := false
var played_bolt := false
var mag_out: AudioStreamPlayer3D
var mag_in: AudioStreamPlayer3D
var charge: AudioStreamPlayer3D
var _current_hip_frame := -1
var _current_ads_frame := -1

func _ready() -> void:
 super._ready()
 var demo: Node3D = get_node_or_null("fps_demo_arms") as Node3D
 if demo: demo.visible = false
 animation_fire = ""
 animation_reload = ""
 reload_sfx = null
 mag_out = get_node_or_null("SFX/MagazineRemoveCue") as AudioStreamPlayer3D
 mag_in = get_node_or_null("SFX/MagazineInsertCue") as AudioStreamPlayer3D
 charge = get_node_or_null("SFX/BoltChargeCue") as AudioStreamPlayer3D
 if not _load_art():
  push_error("MP40_PIXEL_RED missing weapon sprite art")
  return

 sprite_canvas = CanvasLayer.new()
 sprite_canvas.name = "MP40PixelV2"
 sprite_canvas.layer = 1
 add_child(sprite_canvas)
 hip_sprite = Sprite2D.new()
 hip_sprite.name = "HipView"
 hip_sprite.centered = false
 hip_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 sprite_canvas.add_child(hip_sprite)
 ads_sprite = Sprite2D.new()
 ads_sprite.name = "ADSIronSight"
 ads_sprite.centered = false
 ads_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 sprite_canvas.add_child(ads_sprite)
 _set_hip(HIP)
 _set_ads(ADS)
 sprite_canvas.visible = false
 set_meta("mp40_pixel", true)
 set_meta("mp40_pixel_v2_layout", true)
 set_meta("mp40_pixel_highres_frame_count", loaded_original_pngs)
 print("MP40_PIXEL_V2_READY original_png=", loaded_original_pngs, " total_frames=9 same_mp40_audio=true")

func _load_art() -> bool:
 var atlas: Texture2D = null
 if ResourceLoader.exists(SOURCE_ATLAS):
  atlas = load(SOURCE_ATLAS) as Texture2D
 textures.resize(9)
 var cell := Vector2i.ZERO
 if atlas != null and atlas.get_width() % 3 == 0 and atlas.get_height() % 3 == 0:
  cell = Vector2i(atlas.get_width() / 3, atlas.get_height() / 3)
 for i in range(FRAME_NAMES.size()):
  var path := SOURCE_FRAMES + FRAME_NAMES[i] + ".png"
  var source: Texture2D = null
  if ResourceLoader.exists(path):
   source = load(path) as Texture2D
   if source != null and source.get_width() >= 256:
    loaded_original_pngs += 1
   else:
    source = null
  if source == null and atlas != null and cell.x > 0 and cell.y > 0:
   var clipped := AtlasTexture.new()
   clipped.atlas = atlas
   clipped.region = Rect2((i % 3) * cell.x, int(i / 3) * cell.y, cell.x, cell.y)
   clipped.filter_clip = true
   source = clipped
  if source == null:
   return false
  textures[i] = source
 return true

func activate(current_aim_mode: bool = false) -> void:
 super.activate(current_aim_mode)
 active = true
 ads_weight = 1.0 if current_aim_mode else 0.0
 shot_remaining = 0.0
 if sprite_canvas != null: sprite_canvas.visible = true
 _render()

func deactivate() -> void:
 active = false
 if sprite_canvas != null: sprite_canvas.visible = false
 super.deactivate()

func _on_aim_mode_changed(aim_mode: bool) -> void:
 super._on_aim_mode_changed(aim_mode)
 if active: is_aimed = aim_mode

func fire_weapon() -> void:
 super.fire_weapon() # Never replace authoritative fire sound, hit ray, cooldown.
 shot_remaining = 0.085
 _render()

func start_reload() -> void:
 var was_empty := current_mag == 0
 super.start_reload()
 if not is_reloading: return
 empty_reload = was_empty
 played_mag_out = false
 played_mag_in = false
 played_bolt = false
 _render()

func cancel_tactical_reload() -> void:
 if not is_reloading or current_mag <= 0: return
 reload_timer.stop()
 is_reloading = false
 _render()

func _process(delta: float) -> void:
 if not active or hip_sprite == null: return
 shot_remaining = maxf(0.0, shot_remaining - delta)
 ads_weight = move_toward(ads_weight, 1.0 if is_aimed else 0.0, delta / ADS_TIME)
 motion_time += delta * (11.0 if Input.is_action_pressed("sprint") else 3.0)
 _render()

func _render() -> void:
 if hip_sprite == null or ads_sprite == null: return
 var frame := HIP
 var can_ads := not is_reloading
 if is_reloading:
  var done := clampf(1.0 - reload_timer.time_left / maxf(0.01, reload_time), 0.0, 1.0)
  if done < 0.24: frame = RELOAD_01
  elif done < 0.44: frame = RELOAD_01 + 1
  elif done < 0.61: frame = RELOAD_01 + 2
  else: frame = RELOAD_01 + 3
  if done >= 0.24 and not played_mag_out:
   played_mag_out = true
   if mag_out != null: mag_out.play()
  if done >= 0.72 and not played_mag_in:
   played_mag_in = true
   if mag_in != null: mag_in.play()
  if done >= 0.86 and empty_reload and not played_bolt:
   played_bolt = true
   if charge != null: charge.play()
 elif shot_remaining > 0.0:
  frame = HIP_FIRE
 elif Input.is_action_pressed("sprint") and not is_aimed:
  frame = SPRINT
 _set_hip(frame)
 _set_ads(ADS_FIRE if shot_remaining > 0.0 else ADS)

 # Use TWO distinct native sprite cameras, not one huge atlas sprite translated
 # from hip into ADS. The iron-sight marker, not its visual bounding box,
 # coincides with screen center. HUD is untouched and renders over the gun.
 var view := get_viewport().get_visible_rect().size
 var unit := minf(view.x / 1280.0, view.y / 720.0)
 var h_frame := textures[frame]
 var a_frame := textures[ADS_FIRE if shot_remaining > 0.0 else ADS]
 var hip_width := 1280.0 * unit * 0.43
 var hip_left := view.x * 0.31
 var hip_bottom := view.y * 0.955
 if frame == SPRINT:
  hip_width = 1280.0 * unit * 0.48
  hip_left = view.x * 0.30
  hip_bottom = view.y * 0.98
 elif is_reloading:
  hip_width = 1280.0 * unit * 0.49
  hip_left = view.x * 0.275
  hip_bottom = view.y * 0.97
 hip_sprite.scale = Vector2(hip_width / float(h_frame.get_width()),
  hip_width * _hip_aspect(frame) / float(h_frame.get_height()))
 var hip_height := hip_width * _hip_aspect(frame)
 var moving := not is_reloading and not is_aimed and shot_remaining <= 0.0
 var bob := sin(motion_time) * 2.0 * unit if moving else 0.0
 var sway := cos(motion_time * 0.52) * 1.5 * unit if moving else 0.0
 hip_sprite.position = Vector2(hip_left + sway, hip_bottom - hip_height + bob)

 var ads_width := 1280.0 * unit * 0.36
 var ads_height := ads_width * _ads_aspect(shot_remaining > 0.0)
 ads_sprite.scale = Vector2(ads_width / float(a_frame.get_width()),
  ads_height / float(a_frame.get_height()))
 var sight_x := ADS_FIRE_SIGHT_X if shot_remaining > 0.0 else ADS_SIGHT_X
 var sight_y := ADS_FIRE_SIGHT_Y if shot_remaining > 0.0 else ADS_SIGHT_Y
 ads_sprite.position = Vector2(view.x * 0.50 - ads_width * sight_x,
  view.y * 0.50 - ads_height * sight_y)
 var w := ads_weight if can_ads else 0.0
 hip_sprite.modulate.a = clampf(1.0 - w, 0.0, 1.0)
 ads_sprite.modulate.a = clampf(w, 0.0, 1.0)
 ads_sprite.visible = w > 0.001
 hip_sprite.visible = w < 0.999

func _hip_aspect(frame: int) -> float:
 if frame == HIP_FIRE: return 302.0 / 497.0
 if frame == SPRINT: return 244.0 / 512.0
 if frame == RELOAD_01: return 308.0 / 503.0
 if frame == RELOAD_01 + 1: return 322.0 / 508.0
 if frame == RELOAD_01 + 2: return 323.0 / 512.0
 if frame == RELOAD_01 + 3: return 323.0 / 509.0
 return 290.0 / 504.0

func _ads_aspect(firing: bool) -> float:
 return 301.0 / 472.0 if firing else 200.0 / 400.0

func _set_hip(frame: int) -> void:
 if frame != _current_hip_frame:
  hip_sprite.texture = textures[frame]
  _current_hip_frame = frame

func _set_ads(frame: int) -> void:
 if frame != _current_ads_frame:
  ads_sprite.texture = textures[frame]
  _current_ads_frame = frame
