extends "res://common/weapon/weapon.gd"
## Data-driven viewmodel bridge for Project Aether / WaW source weapons.
## This is NOT a Black Ops 3 mesh importer and never modifies approved MP40.
## All clips, hands, gun, sounds and materials come from pinned source inventory.
@export var source_weapon_id: String = ""
var _profile: Dictionary = {}
var _hands: Node3D
var _gun: Node3D
var _hand_anim: AnimationPlayer
var _gun_anim: AnimationPlayer
var _hand_skeleton: Skeleton3D
var _weapon_socket: Node3D
var _weapon_bone: int = -1
var _motion_pivot: Node3D
var _source_ready: bool = false
var _hands_clips: Dictionary = {}
var _gun_clips: Dictionary = {}
var _current_reload_gun: String = ""
var _rechamber_pending: bool = false

func _ready() -> void:
 super._ready()
 if source_weapon_id.is_empty():
  push_error("XZIEL_WEAPON_RED source_weapon_id missing")
  return
 var profile_path := "res://mobile/weapon_sources/" + source_weapon_id + "/profile.json"
 if not FileAccess.file_exists(profile_path):
  push_error("XZIEL_WEAPON_RED missing source profile " + profile_path)
  return
 var loaded = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
 if not (loaded is Dictionary):
  push_error("XZIEL_WEAPON_RED invalid profile " + profile_path)
  return
 _profile = loaded as Dictionary
 set_meta("weapon_family", str(_profile.get("family", "")))
 if str(_profile.get("id", "")) != source_weapon_id or not bool(_profile.get("has_original_fire_audio", false)):
  push_error("XZIEL_WEAPON_RED source identity or authentic audio unavailable " + source_weapon_id)
  return
 _hands = get_node_or_null("FPSHandsRoot/SourceHands") as Node3D
 _gun = get_node_or_null("FPSHandsRoot/SourceGun") as Node3D
 if _hands == null or _gun == null or fps_arms_root == null:
  push_error("XZIEL_WEAPON_RED source viewmodels missing " + source_weapon_id)
  return
 _hand_anim = _find_animation_player(_hands)
 _gun_anim = _find_animation_player(_gun)
 _hand_skeleton = _find_tagged_skeleton(_hands, "tag_weapon")
 if _hand_anim == null or _gun_anim == null or _hand_skeleton == null:
  push_error("XZIEL_WEAPON_RED real rigs/animation players missing " + source_weapon_id)
  return
 _weapon_bone = _hand_skeleton.find_bone("tag_weapon")
 if _weapon_bone < 0: return
 var role_map: Dictionary = _profile.get("roles", {})
 if not (role_map.get("hands", {}) is Dictionary and role_map.get("gun", {}) is Dictionary):
  push_error("XZIEL_WEAPON_RED source roles missing " + source_weapon_id)
  return
 var hands_roles: Dictionary = role_map["hands"]
 var gun_roles: Dictionary = role_map["gun"]
 for role in ["idle", "fire", "reload"]:
  _hands_clips[role] = _resolve_clip(_hand_anim, str(hands_roles.get(role, "")))
  _gun_clips[role] = _resolve_clip(_gun_anim, str(gun_roles.get(role, "")))
  if str(_hands_clips[role]).is_empty() or str(_gun_clips[role]).is_empty():
   push_error("XZIEL_WEAPON_RED real PSA missing id=" + source_weapon_id + " role=" + role)
   return
 for role in ["reload_empty", "rechamber", "equip", "fire_ads"]:
  _hands_clips[role] = _resolve_clip(_hand_anim, str(hands_roles.get(role, "")))
  _gun_clips[role] = _resolve_clip(_gun_anim, str(gun_roles.get(role, "")))

 # Preserve the user's approved model's entire source code and its exact hand
 # pose as a separate sixth original weapon; use the universal locomotion pivot.
 _motion_pivot = preload("res://mobile/universal_weapon_motion.gd").new() as Node3D
 _motion_pivot.name = "UniversalWeaponMotion"
 fps_arms_root.add_child(_motion_pivot)
 _hands.reparent(_motion_pivot, false)
 _gun.reparent(_motion_pivot, false)
 if muzzle_flash_position != null:
  muzzle_flash_position.reparent(_motion_pivot, false)
 _hands.rotation_degrees.y = 90.0
 _weapon_socket = Node3D.new()
 _weapon_socket.name = "SourceTagWeapon_" + source_weapon_id
 _hand_skeleton.add_child(_weapon_socket)
 _gun.reparent(_weapon_socket, false)
 _gun.transform = Transform3D.IDENTITY
 # Axis policy matches the already functioning MP40 importer. This is an
 # initial test orientation, NOT validated gun-specific ADS calibration.
 _gun.rotation_degrees.x = 90.0
 _sync_weapon_socket()
 _hand_skeleton.skeleton_updated.connect(_sync_weapon_socket)

 if not _apply_source_materials(_gun, true):
  push_error("XZIEL_WEAPON_RED gun missing original material/texture " + source_weapon_id)
  return
 if not _apply_source_materials(_hands, false):
  push_error("XZIEL_WEAPON_RED hands missing original material/texture " + source_weapon_id)
  return
 reload_sfx = null # Upstream stock reload != real source; never substitute it.
 animation_player = _hand_anim
 animation_fire = str(_hands_clips["fire"])
 animation_reload = str(_hands_clips["reload"])
 reload_time = _reload_length(animation_reload, str(_gun_clips["reload"]))
 if reload_time <= 0.0:
  push_error("XZIEL_WEAPON_RED invalid paired reload times " + source_weapon_id)
  return
 _source_ready = true
 set_meta("source_weapon_bound", true)
 set_meta("source_weapon_status", "BOUND_NEEDS_DEVICE_VERIFICATION")
 set_meta("source_weapon_id", source_weapon_id)
 _hand_anim.animation_finished.connect(_on_hand_clip_finished)
 _gun_anim.animation_finished.connect(_on_gun_clip_finished)
 var player = Global.player
 if player != null and _motion_pivot.has_method("configure"):
  _motion_pivot.call("configure", player, self)
 _play_source_idle()
 print("XZIEL_SOURCE_WEAPON_BOUND id=", source_weapon_id, " pairedPSA=true real_audio=true")
 
func _find_animation_player(root: Node) -> AnimationPlayer:
 for n: Node in root.find_children("*", "AnimationPlayer", true, false):
  return n as AnimationPlayer
 return null

func _find_tagged_skeleton(root: Node, bone: String) -> Skeleton3D:
 for n: Node in root.find_children("*", "Skeleton3D", true, false):
  var s := n as Skeleton3D
  if s.find_bone(bone) != -1: return s
 return null

func _resolve_clip(player: AnimationPlayer, name: String) -> String:
 if name.is_empty(): return ""
 for n: StringName in player.get_animation_list():
  if str(n) == name or str(n).ends_with("/" + name): return str(n)
 return ""

func _sync_weapon_socket() -> void:
 if not is_instance_valid(_weapon_socket) or not is_instance_valid(_hand_skeleton) or not is_instance_valid(_gun):
  return
 _weapon_socket.transform = _hand_skeleton.get_bone_global_pose(_weapon_bone)
 # The imported Marine armature scales 0.01; GLB weapon meshes already meters.
 var scaling := _weapon_socket.global_transform.basis.get_scale()
 if scaling.x > 0.000001 and scaling.y > 0.000001 and scaling.z > 0.000001:
  _gun.scale = Vector3(1.0 / scaling.x, 1.0 / scaling.y, 1.0 / scaling.z)

func _apply_source_materials(root: Node3D, gun_mesh: bool) -> bool:
 var materials: Array = _profile.get("materials", []) if gun_mesh else []
 var basename := "res://mobile/weapon_sources/" + source_weapon_id + "/"
 var colored := 0
 for n: Node in root.find_children("*", "MeshInstance3D", true, false):
  var mesh := n as MeshInstance3D
  mesh.layers = 2
  if mesh.mesh == null: continue
  for surface in range(mesh.mesh.get_surface_count()):
   var spec: Dictionary = {}
   if gun_mesh:
    var original: Material = mesh.mesh.surface_get_material(surface)
    var orig_name := str(original.resource_name).to_lower() if original != null else ""
    for candidate in materials:
     if str(candidate.get("source_material", "")).to_lower() == orig_name:
      spec = candidate
      break
    if spec.is_empty() and materials.size() == 1:
     spec = materials[0]
    if spec.is_empty():
     # Mark uncertain surface-to-material mapping. Never invent a texture.
     push_warning("XZIEL_WEAPON_UNMATCHED_MATERIAL id=" + source_weapon_id + " surface=" + orig_name)
     continue
   else:
    spec = {
     "albedo": basename + "viewmodel_usa_marine_c.png",
     "normal": basename + "viewmodel_usa_marine_n.png",
     "metallic": 0.0,
     "roughness": 0.86
    }
   var albedo_path := str(spec.get("albedo", ""))
   var normal_path := str(spec.get("normal", ""))
   var diffuse: Texture2D = load(albedo_path) as Texture2D
   var normals: Texture2D = load(normal_path) as Texture2D
   if diffuse == null or normals == null: continue
   var m := StandardMaterial3D.new()
   m.albedo_texture = diffuse
   m.normal_enabled = true
   m.normal_texture = normals
   m.metallic = float(spec.get("metallic", 0.0))
   m.roughness = float(spec.get("roughness", 0.7))
   m.cull_mode = BaseMaterial3D.CULL_DISABLED if bool(spec.get("two_sided", false)) else BaseMaterial3D.CULL_BACK
   mesh.set_surface_override_material(surface, m)
   colored += 1
 return colored > 0

func _reload_length(hand: String, gun: String) -> float:
 if hand.is_empty() or gun.is_empty(): return 0.0
 return maxf(_hand_anim.get_animation(hand).length, _gun_anim.get_animation(gun).length)

func _play_source_idle() -> void:
 if not _source_ready: return
 _hand_anim.play(str(_hands_clips["idle"]), 0.08)
 _gun_anim.play(str(_gun_clips["idle"]), 0.08)

func _on_hand_clip_finished(name: StringName) -> void:
 if _source_ready and not is_reloading and not _rechamber_pending and str(name) != str(_hands_clips["idle"]):
  _play_source_idle()

func _on_gun_clip_finished(name: StringName) -> void:
 if not _source_ready or is_reloading: return
 if _rechamber_pending and str(name) == str(_gun_clips["fire"]):
  _rechamber_pending = false
  if not str(_gun_clips["rechamber"]).is_empty() and not str(_hands_clips["rechamber"]).is_empty():
   _hand_anim.play(str(_hands_clips["rechamber"]))
   _gun_anim.play(str(_gun_clips["rechamber"]))
   return
 if str(name) != str(_gun_clips["idle"]):
  _play_source_idle()

func activate(current_aim_mode: bool = false) -> void:
 super.activate(current_aim_mode)
 if _source_ready: _play_source_idle()

func fire_weapon() -> void:
 if not _source_ready: return
 super.fire_weapon()
 _gun_anim.play(str(_gun_clips["fire"]), 0.02)
 _rechamber_pending = source_weapon_id == "kar98k"

func start_reload() -> void:
 if not _source_ready or is_reloading: return
 var use_empty := current_mag == 0 and not str(_hands_clips["reload_empty"]).is_empty() and not str(_gun_clips["reload_empty"]).is_empty()
 var hand := str(_hands_clips["reload_empty"] if use_empty else _hands_clips["reload"])
 var gun := str(_gun_clips["reload_empty"] if use_empty else _gun_clips["reload"])
 var duration := _reload_length(hand, gun)
 if duration <= 0.0: return
 animation_reload = hand
 reload_time = duration
 var previous := is_reloading
 super.start_reload()
 if is_reloading and not previous:
  _rechamber_pending = false
  _current_reload_gun = gun
  _gun_anim.play(gun, 0.03)
  _gun_anim.seek(0.0, true)
  _hand_anim.seek(0.0, true)

func _on_reload_timer_timeout() -> void:
 super._on_reload_timer_timeout()
 _current_reload_gun = ""
 _play_source_idle()

func cancel_tactical_reload() -> bool:
 if not _source_ready or not is_reloading or current_mag <= 0: return false
 reload_timer.stop()
 is_reloading = false
 _current_reload_gun = ""
 _rechamber_pending = false
 _play_source_idle()
 return true
