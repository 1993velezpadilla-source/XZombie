extends SceneTree
## Headless contract probe: source-based motion order, no art claim.
func _fail(why: String) -> void:
 push_error("MP40_25D_TIMELINE_RED " + why)
 quit(55)

func _initialize() -> void:
 var timeline = load("res://mobile/mp40_25d/timeline.gd").new()
 if not timeline.load_reference():
  _fail("reference failed to load"); return
 if timeline.frame_art_ready():
  _fail("unexpected full 2.5D art pack; review/re-certify first"); return
 for clip in ["reload_empty", "reload_tactical"]:
  if not timeline.begin(clip):
   _fail("missing clip " + clip); return
  var events: Array[String] = []
  var duration_s: float = timeline.duration()
  for i in range(241):
   events.append_array(timeline.advance(duration_s / 240.0))
   var state: Dictionary = timeline.sample()
   if state.is_empty() or not str(state["path"]).ends_with(".png"):
    _fail("invalid sampled frame " + clip); return
  var expected: Array[String] = ["mag_out", "bolt_pull", "mag_in", "bolt_release"] if clip == "reload_empty" else ["mag_out", "mag_in"]
  if events != expected:
   _fail(clip + " got=" + str(events) + " expected=" + str(expected)); return
 print("MP40_25D_REFERENCE_TIMELINE_GREEN source_order=bolt_before_fresh_mag tactical_no_bolt=true actual_25d_art_ready=false")
 quit(0)
