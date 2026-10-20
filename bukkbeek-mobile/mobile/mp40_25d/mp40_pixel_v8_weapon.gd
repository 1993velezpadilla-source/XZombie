extends "res://mobile/mp40_pixel_weapon.gd"
## MP40 V8 PLAYABLE ART PREVIEW: use 107 original concept frames with existing
## authoritative MP40Pixel gameplay, ballistics, controls and source audio.
## This is isolated to the V8 test APK, not the production MP40 3D or V6 APK.
const SpriteDeck = preload("res://mobile/mp40_25d/sprite_deck.gd")
var v8_deck = SpriteDeck.new()
var v8_sprite: Sprite2D
var v8_ready := false
var v8_clip := ""
var v8_last_aim := false
var v8_last_sprint := false

func _ready() -> void:
 super._ready()
 if not v8_deck.initialize():
  push_error("MP40_25D_V8_RED: full 107-frame art pack missing")
  return
 if v8_deck.expected_frame_count() != 107 or sprite_canvas == null:
  push_error("MP40_25D_V8_RED: missing canvas or wrong frame count")
  return
 v8_sprite = Sprite2D.new()
 v8_sprite.name = "MP40V8Original2Point5D"
 v8_sprite.centered = false
 v8_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 v8_sprite.z_index = 8
 sprite_canvas.add_child(v8_sprite)
 v8_clip = "hip_idle"
 v8_deck.begin(v8_clip)
 v8_ready = true
 set_meta("mp40_25d_v8_art_preview", true)
 set_meta("mp40_25d_frame_count", v8_deck.expected_frame_count())
 _display_v8()
 print("MP40_25D_V8_READY original_frames=107 old_3d_mp40_preserved=true art_review_pending=true")

func activate(current_aim_mode: bool = false) -> void:
 super.activate(current_aim_mode)
 if not v8_ready: return
 v8_last_aim = is_aimed
 v8_last_sprint = false
 _begin_v8("ads_idle" if is_aimed else "hip_idle")
 _display_v8()

func deactivate() -> void:
 if v8_sprite != null: v8_sprite.visible = false
 super.deactivate()

func start_reload() -> void:
 super.start_reload()
 if not is_reloading or not v8_ready: return
 # Prevent V6's late bolt cue; original V8 art motion uses bolt before fresh mag.
 # Sound is still the existing MP40 source WAV and played at visual V8 event time.
 played_mag_out = true
 played_mag_in = true
 played_bolt = true
 _begin_v8("reload_empty" if empty_reload else "reload_tactical")

func fire_weapon() -> void:
 super.fire_weapon() # Hit ray, ammo, recoil, cooldown and existing fire WAV.
 if v8_ready and not is_reloading:
  _begin_v8("ads_fire" if is_aimed else "hip_fire")

func cancel_tactical_reload() -> void:
 super.cancel_tactical_reload()
 if v8_ready and not is_reloading:
  _begin_v8("ads_idle" if is_aimed else "hip_idle")

func _process(delta: float) -> void:
 super._process(delta)
 if not v8_ready or v8_sprite == null: return
 if not active:
  v8_sprite.visible = false
  return
 _choose_v8_clip()
 # Preserve the authoritative 2.0s gameplay reload. Source BFV timing
 # 1.96/3.33s is animation reference, not a change to weapon stats.
 var clock_rate := 1.0
 if is_reloading:
  clock_rate = v8_deck.timeline.duration() / maxf(0.01, reload_time)
 var cues: Array[String] = v8_deck.update(maxf(0.0, delta) * clock_rate)
 if is_reloading:
  for cue in cues:
   match cue:
    "mag_out":
     if mag_out != null: mag_out.play()
    "mag_in":
     if mag_in != null: mag_in.play()
    "bolt_pull":
     if charge != null: charge.play()
 _display_v8()

func _choose_v8_clip() -> void:
 if is_reloading:
  if v8_clip != "reload_empty" and v8_clip != "reload_tactical":
   _begin_v8("reload_empty" if empty_reload else "reload_tactical")
  return
 if v8_clip == "reload_empty" or v8_clip == "reload_tactical":
  _begin_v8("ads_idle" if is_aimed else "hip_idle")
 if v8_clip == "hip_fire" or v8_clip == "ads_fire":
  if v8_deck.timeline.elapsed < v8_deck.timeline.duration(): return
 if shot_remaining > 0.0:
  _begin_v8("ads_fire" if is_aimed else "hip_fire")
  return
 if is_aimed != v8_last_aim:
  v8_last_aim = is_aimed
  _begin_v8("ads_in" if is_aimed else "ads_out")
  return
 if (v8_clip == "ads_in" or v8_clip == "ads_out") and v8_deck.timeline.elapsed < v8_deck.timeline.duration():
  return
 var sprinting := Input.is_action_pressed("sprint") and not is_aimed
 if sprinting != v8_last_sprint:
  v8_last_sprint = sprinting
  _begin_v8("sprint" if sprinting else "hip_idle")
  return
 var idle := "sprint" if sprinting else ("ads_idle" if is_aimed else "hip_idle")
 if v8_clip != idle: _begin_v8(idle)

func _begin_v8(clip: String) -> void:
 if not v8_deck.begin(clip):
  push_error("MP40_25D_V8_RED unknown animation: " + clip)
 else:
  v8_clip = clip

func _render() -> void:
 super._render()
 if v8_ready: _display_v8()

func _display_v8() -> void:
 if hip_sprite != null: hip_sprite.visible = false
 if ads_sprite != null: ads_sprite.visible = false
 if v8_sprite == null: return
 v8_sprite.visible = active and v8_ready
 if not v8_sprite.visible: return
 var art: Texture2D = v8_deck.current_image()
 if art == null:
  push_error("MP40_25D_V8_RED: missing original sprite image")
  v8_sprite.visible = false
  return
 v8_sprite.texture = art
 var view := get_viewport().get_visible_rect().size
 var fit := minf(view.x / 1280.0, view.y / 720.0)
 var scale_factor := fit * (1.06 if is_aimed else 1.02)
 v8_sprite.scale = Vector2.ONE * scale_factor
 v8_sprite.position = Vector2(view.x * 0.5 - art.get_width() * scale_factor * 0.5,
  view.y - art.get_height() * scale_factor * 0.98)
