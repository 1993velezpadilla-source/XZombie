extends SceneTree
## Real framebuffer screenshots in original map (not composed reference renders).
const OUT := "res://v8_visual_probes/"

func _die(reason: String) -> void:
 push_error("MP40_25D_V8_FRAMEBUFFER_RED " + reason)
 quit(76)

func _shot(name: String) -> Image:
 await RenderingServer.frame_post_draw
 var image_out: Image = root.get_texture().get_image()
 if image_out == null or image_out.is_empty():
  _die("empty real framebuffer " + name)
  return null
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 image_out.save_png(OUT + name + ".png")
 return image_out

func _delta_count(left: Image, right: Image) -> int:
 if left == null or right == null or left.get_size() != right.get_size(): return -1
 var w := left.get_width()
 var h := left.get_height()
 var changed := 0
 for y in range(int(h * 0.30), int(h * 0.94), 3):
  for x in range(int(w * 0.23), int(w * 0.77), 3):
   var a := left.get_pixel(x,y)
   var b := right.get_pixel(x,y)
   if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > 0.25:
    changed += 1
 return changed

func _run() -> void:
 var packed: PackedScene = load("res://main.tscn") as PackedScene
 if packed == null: _die("original map not loaded"); return
 var world: Node = packed.instantiate()
 root.add_child(world)
 await create_timer(0.2).timeout
 var player: Node = world.get_node_or_null("Player")
 if player == null: _die("original player absent"); return
 var manager: Node = player.get_node_or_null("WeaponsManager")
 if manager == null: _die("original weapons manager absent"); return
 manager.call("switch_weapon", 9)
 await create_timer(0.5).timeout
 var gun: Node = manager.get("current_weapon")
 if gun == null or gun.name != "MP40Pixel" or not bool(gun.get_meta("mp40_25d_v8_art_preview",false)):
  _die("V8 gun missing from game"); return
 var layer: CanvasLayer = gun.get("sprite_canvas") as CanvasLayer
 var display: Sprite2D = gun.get("v8_sprite") as Sprite2D
 if layer == null or display == null or display.texture == null:
  _die("original V8 frame is not rendered"); return
 gun.is_aimed = false
 gun.call("_process", 0.05)
 layer.visible = false
 await process_frame
 var clean_hip: Image = await _shot("V8_original_map_HIP_without_gun")
 layer.visible = true
 await process_frame
 var hip: Image = await _shot("V8_original_map_HIP_with_2point5D")
 if _delta_count(clean_hip, hip) < 700:
  _die("HIP art missing from framebuffer");return
 gun.is_aimed = true
 gun.call("_process", 0.26)
 gun.call("_process", 0.05)
 layer.visible = false
 await process_frame
 var clean_ads: Image = await _shot("V8_original_map_ADS_without_gun")
 layer.visible = true
 await process_frame
 var ads: Image = await _shot("V8_original_map_ADS_with_2point5D")
 if _delta_count(clean_ads, ads) < 700:
  _die("ADS art missing from framebuffer");return
 print("MP40_25D_V8_FRAMEBUFFER_GREEN original_map=true hip_visible=true ads_visible=true real_screenshots=true art_quality_unreviewed=true")
 quit(0)

func _init() -> void:
 call_deferred("_run")
