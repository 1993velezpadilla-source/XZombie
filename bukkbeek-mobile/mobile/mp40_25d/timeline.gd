extends RefCounted
## MP40 2.5D production timeline. Distinct from installed MP40Pixel V6.
## Only motion semantics. NEVER substitutes missing 2.5D art with guessed poses.
const MANIFEST_PATH := "res://mobile/mp40_25d/motion_manifest.json"
var clips: Dictionary = {}
var clip_name := ""
var elapsed := 0.0
var sent: Dictionary = {}

func load_reference() -> bool:
 if not FileAccess.file_exists(MANIFEST_PATH):
  push_error("MP40_25D_REFERENCE_RED missing manifest")
  return false
 var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
 if typeof(data) != TYPE_DICTIONARY:
  push_error("MP40_25D_REFERENCE_RED invalid JSON")
  return false
 if int(data.get("schema_version", 0)) != 1 or str(data.get("weapon_id", "")) != "mp40_25d":
  push_error("MP40_25D_REFERENCE_RED schema/weapon ID")
  return false
 clips = data.get("clips", {})
 return clips.has("reload_empty") and clips.has("reload_tactical")

func begin(name: String) -> bool:
 if not clips.has(name): return false
 clip_name = name
 elapsed = 0.0
 sent.clear()
 return true

func duration() -> float:
 if not clips.has(clip_name): return 0.0
 return float(clips[clip_name]["duration_sec"])

func advance(delta: float) -> Array[String]:
 var cues: Array[String] = []
 if not clips.has(clip_name): return cues
 var clip: Dictionary = clips[clip_name]
 var duration_s := maxf(0.001, float(clip["duration_sec"]))
 var before := elapsed / duration_s
 elapsed += maxf(0.0, delta)
 if bool(clip.get("loop", false)) and elapsed >= duration_s:
  elapsed = fmod(elapsed, duration_s)
  sent.clear()
  before = -0.001
 var after := minf(1.0, elapsed / duration_s)
 for event in clip["events"]:
  var name: String = str(event["id"])
  var moment: float = float(event["at"])
  if not sent.has(name) and before <= moment and after >= moment:
   sent[name] = true
   cues.append(name)
 return cues

func sample() -> Dictionary:
 if not clips.has(clip_name): return {}
 var clip: Dictionary = clips[clip_name]
 var duration_s := maxf(0.001, float(clip["duration_sec"]))
 var t := clampf(elapsed / duration_s, 0.0, 0.999999)
 var prior := 0.0
 for phase in clip["phases"]:
  var end_time := float(phase["end"])
  if t < end_time:
   var frame_count := int(phase["frames"])
   var local_t := clampf((t - prior) / maxf(0.000001, end_time - prior), 0.0, 0.999999)
   var index := mini(frame_count - 1, int(floor(local_t * frame_count)))
   var id: String = str(phase["id"])
   return {"clip": clip_name, "phase": id, "frame": index, "path": "res://mobile/mp40_25d/frames/%s/%s_%02d.png" % [clip_name, id, index]}
  prior = end_time
 return {}

func frame_art_ready() -> bool:
 ## Reference timeline can be certified before drawing. An ART/RELEASE gate
 ## must require ALL original frame PNGs in place; no implicit fallback.
 if clips.is_empty(): return false
 for name in clips.keys():
  for phase in clips[name]["phases"]:
   for i in range(int(phase["frames"])):
    var path: String = "res://mobile/mp40_25d/frames/%s/%s_%02d.png" % [name, str(phase["id"]), i]
    if not ResourceLoader.exists(path) and not FileAccess.file_exists(path): return false
 return true
