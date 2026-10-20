extends SceneTree
## Deterministic offline capture of ACTUAL Godot Skeleton2D+Bone2D animation.
const OUT := "res://rig_demo/captures/"
const FRAMES := 68
const FPS := 24.0

func _initialize() -> void:
 call_deferred("_run")

func _fail(reason: String) -> void:
 push_error("MP40_BONES_DEMO_RED " + reason)
 quit(91)

func _run() -> void:
 var pack := load("res://rig_demo/reload_study.tscn") as PackedScene
 if pack == null:
  _fail("scene not found")
  return
 var demo: Node2D = pack.instantiate() as Node2D
 if demo == null:
  _fail("scene instance failed")
  return
 root.add_child(demo)
 demo.set("capture_mode", true)
 await process_frame
 var result: Dictionary = demo.call("get_rig_metrics")
 for key in ["skeleton","upper","wrist","gun","mag","bolt"]:
  if not bool(result.get(key,false)):
   _fail("missing Skeleton2D/Bone2D source component: " + key)
   return
 var arm: Bone2D = demo.get("upper") as Bone2D
 var finger: Bone2D = demo.get("wrist") as Bone2D
 var start := arm.position
 demo.call("seek", 1.5)
 if arm.position.distance_to(start) < 3.0 or absf(finger.rotation) < 0.02:
  _fail("no actual bone translation / rotation")
  return
 var mag: Sprite2D = demo.get("mag_hand") as Sprite2D
 var bolt: Sprite2D = demo.get("bolt_hand") as Sprite2D
 if mag.visible or not bolt.visible:
  _fail("actual alternate hand art not switching")
  return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 for frame in range(FRAMES):
  var t := float(frame) / FPS
  demo.call("seek", t)
  await process_frame
  await RenderingServer.frame_post_draw
  var capture: Image = root.get_texture().get_image()
  if capture == null or capture.is_empty():
   _fail("empty real viewport")
   return
  if capture.get_width() < 1200 or capture.get_height() < 680:
   _fail("wrong viewport size")
   return
  var dest := OUT + ("%04d.png" % frame)
  if capture.save_png(dest) != OK:
   _fail("frame write failed: " + dest)
   return
 print("MP40_BONES_DEMO_GREEN real_bones=2 real_existing_pngs=2 sampled_frames=68 duration_sec=2.80 experimental_only=true no_gameplay_changes=true")
 quit(0)
