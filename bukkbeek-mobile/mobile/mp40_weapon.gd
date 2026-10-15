extends "res://common/weapon/weapon.gd"
## Source World-at-War/Aether MP40 adapter for Bukkbeek (not a new FPS engine).
## Own scene, authentic weapon/hand GLBs, independent imported animation players.
## Leave the five built-in Bukkbeek weapons and XZIEL mobile HUD untouched.

const HAND_ALBEDO := "res://mobile/mp40_source/viewmodel_usa_marine_c.png"
const HAND_NORMAL := "res://mobile/mp40_source/viewmodel_usa_marine_n.png"
const GUN_ALBEDO := "res://mobile/mp40_source/weapon_mp40_c.png"
const GUN_NORMAL := "res://mobile/mp40_source/weapon_mp40_n.png"
const GUN_SPECULAR := "res://mobile/mp40_source/_weapon_mp40_mp_s-rgb_weapon__08433bb1.png"

var _hands_root: Node3D
var _gun_root: Node3D
var _hands_anim: AnimationPlayer
var _gun_anim: AnimationPlayer
var _skeleton: Skeleton3D
var _socket: Node3D
var _bone_index: int = -1
var _idle_hands_clip: String = ""
var _fire_hands_clip: String = ""
var _reload_hands_clip: String = ""
var _gun_idle_clip: String = ""
var _gun_fire_clip: String = ""
var _gun_reload_clip: String = ""
var _source_ok: bool = false

func _ready() -> void:
 super._ready()
 _hands_root = get_node_or_null("FPSHandsRoot/SourceHands") as Node3D
 _gun_root = get_node_or_null("FPSHandsRoot/SourceGun") as Node3D
 if _hands_root == null or _gun_root == null:
  push_error("BUKKBEEK_MP40_RED: missing real hand or gun source")
  return
 # Both source PSA sets use +X barrel-forward, whereas Godot cameras look -Z.
 _hands_root.rotation_degrees.y = 90.0
 _hands_anim = _find_anim_player(_hands_root)
 _gun_anim = _find_anim_player(_gun_root)
 _skeleton = _find_skeleton(_hands_root, "tag_weapon")
 if _hands_anim == null or _gun_anim == null or _skeleton == null:
  push_error("BUKKBEEK_MP40_RED: source skeleton / original PSA players missing")
  return
 _bone_index = _skeleton.find_bone("tag_weapon")
 if _bone_index < 0:
  push_error("BUKKBEEK_MP40_RED: exact tag_weapon missing")
  return

 _idle_hands_clip = _clip(_hands_anim, "PSA_HandIdleMP40")
 _fire_hands_clip = _clip(_hands_anim, "PSA_viewmodel_mp40_fire")
 _reload_hands_clip = _clip(_hands_anim, "PSA_MP40ReloadHands")
 if _reload_hands_clip.is_empty():
  _reload_hands_clip = _clip(_hands_anim, "PSA_viewmodel_mp40_reload_empty")
 _gun_idle_clip = _clip(_gun_anim, "PSA_HandIdleMP40")
 _gun_fire_clip = _clip(_gun_anim, "PSA_viewmodel_mp40_fire")
 _gun_reload_clip = _clip(_gun_anim, "PSA_viewmodel_mp40_reload")
 if _gun_reload_clip.is_empty():
  _gun_reload_clip = _clip(_gun_anim, "PSA_MP40ReloadHands")
 if _fire_hands_clip.is_empty() or _reload_hands_clip.is_empty() or _gun_fire_clip.is_empty() or _gun_reload_clip.is_empty():
  push_error("BUKKBEEK_MP40_RED: missing source fire or reload PSA")
  return

 var textured_gun: int = _texture_source(_gun_root, GUN_ALBEDO, GUN_NORMAL, 0.40, 0.31)
 var textured_hands: int = _texture_source(_hands_root, HAND_ALBEDO, HAND_NORMAL, 0.0, 0.86)
 if textured_gun == 0 or textured_hands == 0:
  push_error("BUKKBEEK_MP40_RED: untextured source geometry")
  return

 # Source hand rig controls the actual grip: no free-floating gun placeholder.
 _socket = Node3D.new()
 _socket.name = "SourceMP40TagWeapon"
 _skeleton.add_child(_socket)
 _gun_root.reparent(_socket, false)
 _gun_root.transform = Transform3D.IDENTITY
 # MP40-specific original orientation; not applied to every weapon.
 _gun_root.rotation_degrees.x = 90.0
 _sync_grip()
 if not _skeleton.skeleton_updated.is_connected(_sync_grip):
  _skeleton.skeleton_updated.connect(_sync_grip)

 # Keep the source hands PSA as Bukkbeek's fire/reload authority.
 animation_player = _hands_anim
 animation_fire = _fire_hands_clip
 animation_reload = _reload_hands_clip
 if _hands_anim.has_animation(_reload_hands_clip):
  reload_time = maxf(0.2, _hands_anim.get_animation(_reload_hands_clip).length)
 _hands_anim.animation_finished.connect(_hands_anim_finished)
 _source_ok = true
 set_meta("source_mp40_ready", true)
 set_meta("source_mp40_textured_gun_meshes", textured_gun)
 set_meta("source_mp40_textured_hands_meshes", textured_hands)
 print("BUKKBEEK_MP40_SOURCE_READY gun=", textured_gun, " hands=", textured_hands,
  " source_hand_fire=", _fire_hands_clip, " source_hand_reload=", _reload_hands_clip,
  " original_gun_reload=", _gun_reload_clip)
 _play_idle()

func _texture_source(root: Node3D, albedo_path: String, normal_path: String, metallic: float, roughness: float) -> int:
 var albedo: Texture2D = load(albedo_path) as Texture2D
 var normal: Texture2D = load(normal_path) as Texture2D
 if albedo == null or normal == null:
  push_error("BUKKBEEK_MP40_RED missing textures: " + albedo_path)
  return 0
 var material := StandardMaterial3D.new()
 material.albedo_texture = albedo
 material.albedo_color = Color.WHITE
 material.normal_enabled = true
 material.normal_texture = normal
 material.metallic = metallic
 material.roughness = roughness
 var count := 0
 for child: Node in root.find_children("*", "MeshInstance3D", true, false):
  var mesh := child as MeshInstance3D
  mesh.layers = 2 # Source Bukkbeek weapon-only camera layer.
  if mesh.mesh == null:
   continue
  for surface_index: int in range(mesh.mesh.get_surface_count()):
   mesh.set_surface_override_material(surface_index, material)
  count += 1
 return count

func _find_anim_player(root: Node) -> AnimationPlayer:
 if root is AnimationPlayer:
  return root as AnimationPlayer
 for node: Node in root.find_children("*", "AnimationPlayer", true, false):
  return node as AnimationPlayer
 return null

func _find_skeleton(root: Node, exact_bone: String) -> Skeleton3D:
 for node: Node in root.find_children("*", "Skeleton3D", true, false):
  var sk := node as Skeleton3D
  if sk.find_bone(exact_bone) >= 0:
   return sk
 return null

func _clip(player: AnimationPlayer, exact_clip: String) -> String:
 if player == null:
  return ""
 for animation_name: StringName in player.get_animation_list():
  var full_name := str(animation_name)
  if full_name == exact_clip or full_name.ends_with("/" + exact_clip):
   return full_name
 return ""

func _sync_grip() -> void:
 if not is_instance_valid(_socket) or not is_instance_valid(_skeleton) or not is_instance_valid(_gun_root):
  return
 _socket.transform = _skeleton.get_bone_global_pose(_bone_index)
 # Critical source bug fix: imported hands are centimeter rig (0.01) but the
 # gun mesh was already exported in meters. Cancel inherited scale exactly once.
 var unit_scale := _socket.global_transform.basis.get_scale()
 if unit_scale.x > 0.000001 and unit_scale.y > 0.000001 and unit_scale.z > 0.000001:
  _gun_root.scale = Vector3(1.0 / unit_scale.x, 1.0 / unit_scale.y, 1.0 / unit_scale.z)

func _play_idle() -> void:
 if not _source_ok:
  return
 if not _idle_hands_clip.is_empty():
  _hands_anim.play(_idle_hands_clip, 0.06)
 if not _gun_idle_clip.is_empty():
  _gun_anim.play(_gun_idle_clip, 0.06)

func _hands_anim_finished(finished: StringName) -> void:
 if str(finished) != _idle_hands_clip and _source_ok and not is_reloading:
  _play_idle()

func activate(current_aim_mode: bool = false) -> void:
 super.activate(current_aim_mode)
 if _source_ok:
  _play_idle()

func fire_weapon() -> void:
 if not _source_ok:
  return
 super.fire_weapon()
 _gun_anim.play(_gun_fire_clip, 0.02)

func start_reload() -> void:
 if not _source_ok:
  return
 var was_reloading := is_reloading
 super.start_reload()
 if is_reloading and not was_reloading:
  _gun_anim.play(_gun_reload_clip, 0.04)
  print("BUKKBEEK_MP40_REAL_RELOAD hands=", _reload_hands_clip, " gun=", _gun_reload_clip)

func _on_reload_timer_timeout() -> void:
 super._on_reload_timer_timeout()
 if _source_ok:
  _play_idle()
