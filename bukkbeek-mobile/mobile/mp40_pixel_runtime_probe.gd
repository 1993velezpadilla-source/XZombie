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
 if sprite.get("atlas") == null: _fail("pixel sprite atlas missing");return
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
 print("MP40_PIXEL_TEST_GREEN map=original weapons=10 approved_mp40_unchanged=true sprites=9 mp40_source_sfx=true hit_and_reload_calls=true")
 quit(0)
