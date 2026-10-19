extends RefCounted
## Streaming sprite deck for MP40 2.5D, entirely isolated from MP40Pixel V6.
## Refuse to activate with missing / half-shipped art.
const Timeline := preload("res://mobile/mp40_25d/timeline.gd")
const MAX_CACHE := 12
var timeline = Timeline.new()
var textures: Dictionary = {}
var lru: Array[String] = []
var art_available := false

func initialize() -> bool:
 if not timeline.load_reference(): return false
 art_available = timeline.frame_art_ready()
 if not art_available:
  print("MP40_25D_ASSET_PENDING: motion ready, original 107-frame sprite pack not installed")
 return art_available

func begin(name: String) -> bool:
 if not art_available: return false
 return timeline.begin(name)

func update(delta: float) -> Array[String]:
 if not art_available: return []
 return timeline.advance(delta)

func current_image() -> Texture2D:
 if not art_available: return null
 var sample: Dictionary = timeline.sample()
 var path: String = str(sample.get("path", ""))
 if path.is_empty() or not ResourceLoader.exists(path):
  push_error("MP40_25D_SPRITE_RED missing expected visual frame " + path)
  art_available = false
  return null
 if textures.has(path):
  lru.erase(path)
  lru.append(path)
  return textures[path] as Texture2D
 var resource: Resource = ResourceLoader.load(path,"Texture2D",ResourceLoader.CACHE_MODE_IGNORE)
 var tex: Texture2D = resource as Texture2D
 if tex == null:
  push_error("MP40_25D_SPRITE_RED unusable Texture2D at " + path)
  art_available = false
  return null
 textures[path] = tex
 lru.append(path)
 while lru.size() > MAX_CACHE:
  var old: String = lru.pop_front()
  textures.erase(old)
 return tex

func expected_frame_count() -> int:
 var count := 0
 for name in timeline.clips.keys():
  for phase in timeline.clips[name]["phases"]:
   count += int(phase["frames"])
 return count
