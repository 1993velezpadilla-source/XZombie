extends SceneTree
## V8 playable preview gate: proves it actually appears and can fire/reload.
## This is NOT visual approval of arms, ADS geometry or frame continuity.
func _initialize() -> void:
 call_deferred("_run")

func _fail(reason: String) -> void:
 push_error("MP40_25D_V8_PLAYABLE_RED " + reason)
 quit(77)

func _run() -> void:
 var pack: PackedScene = load("res://player/player.tscn") as PackedScene
 if pack == null: _fail("source player scene missing"); return
 var player: Node = pack.instantiate()
 root.add_child(player)
 await process_frame
 await process_frame
 var manager: Node = player.get_node_or_null("WeaponsManager")
 if manager == null: _fail("weapon manager missing"); return
 var all_weapons: Array = manager.get("weapons_array")
 if all_weapons.size() != 10: _fail("existing 9 weapons + 1 Pixel expected"); return
 if str(all_weapons[5].name) != "MP40Source" or str(all_weapons[9].name) != "MP40Pixel":
  _fail("old 3D MP40 or sprite slot replaced"); return
 var gun: Node = all_weapons[9]
 if not bool(gun.get_meta("mp40_25d_v8_art_preview", false)):
  _fail("V8 script not installed into actual player"); return
 var deck: RefCounted = gun.get("v8_deck")
 if not bool(deck.get("art_available")) or int(deck.call("expected_frame_count")) != 107:
  _fail("original PNG deck incomplete"); return
 manager.switch_weapon(9)
 await create_timer(0.35).timeout
 if manager.current_weapon != gun:
  _fail("cannot equip V8"); return
 var visual: Sprite2D = gun.get("v8_sprite") as Sprite2D
 if visual == null or not visual.visible or visual.texture == null:
  _fail("V8 sprite does not render when equipped"); return
 if visual.texture.get_width() != 724 or visual.texture.get_height() != 724:
  _fail("V8 strip artwork geometry unexpectedly changed"); return
 var initial: int = int(gun.get("current_mag"))
 gun.fire_weapon()
 if int(gun.get("current_mag")) != initial-1:
  _fail("authoritative MP40 shot or ammo broke"); return
 gun.call("_process", 0.04)
 if str(gun.get("v8_clip")) != "hip_fire":
  _fail("V8 fire pose not selected"); return
 gun.start_reload()
 if not bool(gun.get("is_reloading")) or str(gun.get("v8_clip")) != "reload_tactical":
  _fail("tactical reload lost"); return
 gun.cancel_tactical_reload()
 gun.set("current_mag", 0)
 gun.start_reload()
 if not bool(gun.get("is_reloading")) or str(gun.get("v8_clip")) != "reload_empty":
  _fail("empty reload with real bolt motion not selected"); return
 gun.call("_process", 0.04)
 if visual.texture == null:
  _fail("V8 empty reload has no art"); return
 for name in ["FiringSFX", "MagazineRemoveCue", "MagazineInsertCue", "BoltChargeCue"]:
  var audio: AudioStreamPlayer3D = gun.get_node_or_null("SFX/" + name) as AudioStreamPlayer3D
  if audio == null or audio.stream == null:
   _fail("original MP40 source WAV missing: " + name); return
 print("MP40_25D_V8_PLAYABLE_GREEN frames=107 clips=13 selected=true fire=true tactical_reload=true empty_reload=true source_sounds=true weapons=10 art_review_pending=true")
 quit(0)
