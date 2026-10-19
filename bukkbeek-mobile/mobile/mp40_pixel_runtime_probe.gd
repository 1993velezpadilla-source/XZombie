extends SceneTree
## Lightweight real assembled-player smoke test for the ADDITIVE sprite variant.
func _init() -> void:
 call_deferred("_run")

func _fail(why: String) -> void:
 push_error("MP40_PIXEL_TEST_RED " + why)
 quit(3)

func _run() -> void:
 var packed: PackedScene = load("res://player/player.tscn") as PackedScene
 if packed == null: _fail("original player does not load"); return
 var player: Node = packed.instantiate()
 root.add_child(player)
 await process_frame
 await process_frame
 var manager: Node = player.get_node_or_null("WeaponsManager")
 if manager == null: _fail("original weapon manager absent"); return
 var weapons: Array = manager.get("weapons_array")
 if weapons.size() != 10: _fail("9 retained weapons + pixel variant required; found " + str(weapons.size())); return
 var expected: Array[String] = ["Knife", "Pistol", "AssualtRifle", "AssualtBurstRifle", "LMG", "MP40Source", "ColtSource", "ThompsonSource", "Kar98kSource", "MP40Pixel"]
 for i in range(expected.size()):
  if str(weapons[i].name) != expected[i]:
   _fail("slot " + str(i) + " unexpectedly replaced: " + str(weapons[i].name));return
 var sprite: Node = weapons[9]
 if not bool(sprite.get_meta("mp40_pixel", false)): _fail("sprite weapon script not running");return
 var sprite_textures: Array = sprite.get("textures")
 if sprite_textures.size() != 9 or sprite_textures[0] == null:
  _fail("V2 sprite frame texture cache missing");return
 if not bool(weapons[5].get_meta("source_mp40_ready", false)): _fail("original fully working MP40 disturbed");return
 for sound in ["FiringSFX", "MagazineRemoveCue", "MagazineInsertCue", "BoltChargeCue"]:
  var a: AudioStreamPlayer3D = sprite.get_node_or_null("SFX/" + sound) as AudioStreamPlayer3D
  if a == null or a.stream == null: _fail("exact MP40 audio cue missing: " + sound); return
 manager.switch_weapon(9)
 await create_timer(0.65).timeout
 if manager.current_weapon != sprite or not bool(sprite.get("active")):
  _fail("cannot select MP40Pixel without replacing old MP40");return
 var before: int = int(sprite.get("current_mag"))
 sprite.fire_weapon()
 if int(sprite.get("current_mag")) != before - 1:
  _fail("stock MP40 projectile/ammo flow not working");return
 sprite.start_reload()
 if not bool(sprite.get("is_reloading")):
  _fail("stock reload clock did not start");return
 # V2 composition contract: user-reported gun clipping is RED even if
 # hit detection and ammo still work. Probe actual drawn Sprite2D transforms.
 var hip: Sprite2D = sprite.get("hip_sprite") as Sprite2D
 var ads: Sprite2D = sprite.get("ads_sprite") as Sprite2D
 if hip == null or ads == null:
  _fail("V2 viewmodel sprites were not constructed");return
 if not bool(sprite.get_meta("mp40_pixel_v2_layout", false)):
  _fail("old atlas-only positioning is still active");return
 var original_art_count: int = int(sprite.get_meta("mp40_pixel_highres_frame_count", -1))
 if original_art_count != 0 and original_art_count != 9:
  _fail("partial native PNG asset pack: "+str(original_art_count));return
 # Re-enter HIP for safe-zone test; ADS sight test after that.
 sprite.cancel_tactical_reload()
 sprite.is_aimed = false
 sprite.set("ads_weight", 0.0)
 sprite.call("_render")
 var view: Vector2 = root.get_viewport().get_visible_rect().size
 var max_x: float = hip.position.x + hip.texture.get_width() * hip.scale.x
 var max_y: float = hip.position.y + hip.texture.get_height() * hip.scale.y
 if max_x > view.x * 0.80 or max_y > view.y * 1.01:
  _fail("HIP sprite extends beyond HUD safe-zone: "+str(Vector2(max_x,max_y)));return
 sprite.is_aimed = true
 sprite.set("ads_weight", 1.0)
 sprite.call("_render")
 var aim_x: float = ads.position.x + ads.texture.get_width() * ads.scale.x * 0.625
 var aim_y: float = ads.position.y + ads.texture.get_height() * ads.scale.y * 0.090
 if Vector2(aim_x,aim_y).distance_to(view*0.5) > 1.5:
  _fail("ADS true front sight does not coincide with screen-center ray");return
 print("MP40_PIXEL_V2_LAYOUT_GREEN hip_inside_safe_zone=true ads_iron_sight_centered=true original_png_count=",original_art_count)
 print("MP40_PIXEL_TEST_GREEN map=original weapons=10 approved_mp40_unchanged=true sprites=9 mp40_source_sfx=true hit_and_reload_calls=true")
 quit(0)
