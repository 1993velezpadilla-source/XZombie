extends SceneTree
## Production blocker: verify V3 MP40Pixel actually DRAWING in the game,
## not merely node-valid / alpha / transform-correct with no pixels visible.
const OUT_DIR := "res://pixel_visual_probes/"

func _die(why: String) -> void:
 push_error("MP40_PIXEL_VISIBLE_RED " + why)
 quit(11)

func _capture(label: String) -> Image:
 await RenderingServer.frame_post_draw
 var img: Image = root.get_texture().get_image()
 if img == null or img.is_empty():
  _die("No framebuffer at " + label)
  return null
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
 img.save_png(OUT_DIR + label + ".png")
 return img

func _differ(a: Image, b: Image, focus_ads: bool) -> int:
 if a == null or b == null or a.get_size() != b.get_size():
  return -1
 var w := a.get_width()
 var h := a.get_height()
 var left := int(w * (0.36 if focus_ads else 0.28))
 var right := int(w * (0.66 if focus_ads else 0.76))
 var top := int(h * (0.49 if focus_ads else 0.48))
 var bottom := int(h * (0.90 if focus_ads else 0.94))
 var changed := 0
 for y in range(top,bottom,2):
  for x in range(left,right,2):
   var ca := a.get_pixel(x,y)
   var cb := b.get_pixel(x,y)
   if (absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)) > 0.19:
    changed += 1
 return changed

func _run() -> void:
 var world: PackedScene = load("res://main.tscn") as PackedScene
 if world == null: _die("original main.tscn missing"); return
 var main := world.instantiate()
 root.add_child(main)
 await create_timer(0.25).timeout
 var player: Node = main.get_node_or_null("Player")
 if player == null: _die("real Bukkbeek Player missing"); return
 var manager: Node = player.get_node_or_null("WeaponsManager")
 if manager == null: _die("weapon manager missing"); return
 manager.call("switch_weapon",9)
 await create_timer(0.75).timeout
 var gun: Node = manager.get("current_weapon")
 if gun == null or gun.name != "MP40Pixel":
  _die("pixel gun not selected after switch: "+str(gun)); return
 var layer: CanvasLayer = gun.get("sprite_canvas") as CanvasLayer
 var hip: Sprite2D = gun.get("hip_sprite") as Sprite2D
 var ads: Sprite2D = gun.get("ads_sprite") as Sprite2D
 if layer == null or hip == null or ads == null:
  _die("sprites / canvas did not initialize");return
 # Park all world movement; only test direct canvas ON/OFF influence.
 gun.is_aimed = false
 gun.set("ads_weight",0.0)
 gun.call("_render")
 if not layer.visible:
  _die("gun selected but CanvasLayer hidden");return
 layer.visible = false
 await process_frame
 var without: Image = await _capture("V3_HIP_without_weapon")
 layer.visible = true
 await process_frame
 var with_hip: Image = await _capture("V3_HIP_MP40Pixel")
 var changes: int = _differ(without,with_hip,false)
 print("MP40_PIXEL_HIP_RENDER_DIFF checked_half_resolution_changed_pixels=",changes)
 if changes < 3000:
  _die("HIP weapon missing from actual framebuffer, despite 9 imported PNGs; changed="+str(changes));return
 # ADS canvas visibility proof with truly centered sight. Renderer may have
 # different alpha because source texture is an atlas or individual PNG.
 gun.is_aimed = true
 gun.set("ads_weight",1.0)
 gun.call("_render")
 layer.visible=false
 await process_frame
 var without_ads: Image = await _capture("V3_ADS_without_weapon")
 layer.visible=true
 await process_frame
 var with_ads: Image = await _capture("V3_ADS_MP40Pixel")
 var ads_changes: int = _differ(without_ads,with_ads,true)
 print("MP40_PIXEL_ADS_RENDER_DIFF checked_half_resolution_changed_pixels=",ads_changes)
 if ads_changes < 1200:
  _die("ADS weapon missing from actual framebuffer; changed="+str(ads_changes));return
 print("MP40_PIXEL_ACTUAL_FRAMEBUFFER_GREEN hip_changed=",changes,
  " ads_changed=",ads_changes," weapon=MP40Pixel original_map=true")
 quit(0)

func _init() -> void:
 call_deferred("_run")
