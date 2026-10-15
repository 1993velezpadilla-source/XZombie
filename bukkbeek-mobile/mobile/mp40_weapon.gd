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
var _hands_reload_empty_clip: String = ""
var _gun_reload_empty_clip: String = ""
var _active_reload_hands_clip: String = ""
var _active_reload_gun_clip: String = ""
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
 # Explicitly pair the two COMPLETE source reloads; do not borrow the short
 # gun-side 0.04s MP40ReloadHands stub in place of a full reload animation.
 _hands_reload_empty_clip = _clip(_hands_anim, "PSA_viewmodel_mp40_reload_empty")
 _gun_reload_empty_clip = _clip(_gun_anim, "PSA_viewmodel_mp40_reload_empty")
 if (_hands_reload_empty_clip.is_empty() != _gun_reload_empty_clip.is_empty()):
  push_error("BUKKBEEK_MP40_RED: only one empty reload source PSA is present")
  return
 if _fire_hands_clip.is_empty() or _reload_hands_clip.is_empty() or _gun_fire_clip.is_empty() or _gun_reload_clip.is_empty():
  push_error("BUKKBEEK_MP40_RED: missing source fire or reload PSA")
  return

 # Source evidence: the imported root quaternion is IDENTITY in idle, but
 # (-0.707107, 0, 0, 0.707107) in BOTH firing and reloading. This is a static
 # -90-degree frame mismatch, not intentional recoil. The original hand
 # tag_weapon pose already owns the grip; applying that key flips the *entire*
 # gun sideways on FIRE and sends the reload toward the wrong screen side.
 # Fix ONLY the single static root track. Do not touch animated j_clip/j_bolt
 # tracks (59 rotation/56 position magazine keys from the source GLB).
 if not _normalize_source_gun_root_basis():
  push_error("BUKKBEEK_MP40_RED: cannot safely neutralize source -90-degree animation root")
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
 # Source gun reload runs one 24fps frame longer than the hands (3.291667
 # vs 3.25s). Waiting for the LONGER real track prevents the bolt snap caused
 # by switching to the idle key one frame too early.
 reload_time = _synchronized_reload_seconds(_reload_hands_clip, _gun_reload_clip)
 _hands_anim.animation_finished.connect(_hands_anim_finished)
 _source_ok = true
 set_meta("source_mp40_ready", true)
 set_meta("source_mp40_textured_gun_meshes", textured_gun)
 set_meta("source_mp40_textured_hands_meshes", textured_hands)
 set_meta("source_mp40_normal_reload_pair", [_reload_hands_clip, _gun_reload_clip])
 set_meta("source_mp40_empty_reload_pair", [_hands_reload_empty_clip, _gun_reload_empty_clip])
 set_meta("source_mp40_reload_normal_duration", reload_time)
 set_meta("source_mp40_reload_empty_duration",
  _synchronized_reload_seconds(_hands_reload_empty_clip, _gun_reload_empty_clip))
 print("BUKKBEEK_MP40_SOURCE_READY gun=", textured_gun, " hands=", textured_hands,
  " source_hand_fire=", _fire_hands_clip, " source_hand_reload=", _reload_hands_clip,
  " original_gun_reload=", _gun_reload_clip)
 _play_idle()

const SOURCE_GUN_ROOT_TRACK := "MP40_SM_ao/Skeleton3D:viewmodel_ger_mp40_smg_LOD0_skel"

func _normalize_source_gun_root_basis() -> bool:
 # Preserve the idle-root source basis, which the user verified appears upright.
 # The imported firing/reload PSA both contain a SINGLE static -90 degree
 # root key; applying that key produces the observed sideways flip. Modify the
 # in-memory Animation only; downloaded authoring GLBs remain untouched.
 if _gun_anim == null or _gun_idle_clip.is_empty():
  return false
 if not _gun_anim.has_animation(_gun_idle_clip):
  return false
 var idle: Animation = _gun_anim.get_animation(_gun_idle_clip)
 var neutral_quat := Quaternion.IDENTITY
 var idle_found := false
 for track_idx: int in range(idle.get_track_count()):
  if (str(idle.track_get_path(track_idx)) == SOURCE_GUN_ROOT_TRACK
   and idle.track_get_type(track_idx) == Animation.TYPE_ROTATION_3D
   and idle.track_get_key_count(track_idx) == 1):
   neutral_quat = idle.track_get_key_value(track_idx, 0) as Quaternion
   idle_found = true
 if not idle_found:
  return false

 var source_animated_clips: Array[String] = [_gun_fire_clip, _gun_reload_clip]
 if not _gun_reload_empty_clip.is_empty():
  source_animated_clips.append(_gun_reload_empty_clip)
 for clip: String in source_animated_clips:
  if not _gun_anim.has_animation(clip):
   return false
  var animation: Animation = _gun_anim.get_animation(clip)
  var root_found := false
  for track_idx: int in range(animation.get_track_count()):
   if str(animation.track_get_path(track_idx)) != SOURCE_GUN_ROOT_TRACK:
    continue
   if (animation.track_get_type(track_idx) != Animation.TYPE_ROTATION_3D
    or animation.track_get_key_count(track_idx) != 1):
    return false  # Never strip legitimate animated multi-key weapon rotations.
   var source_quat: Quaternion = animation.track_get_key_value(track_idx, 0) as Quaternion
   var mismatch_degrees := rad_to_deg(neutral_quat.angle_to(source_quat))
   # Imported PSA sometimes already uses idle orientation, but the observed
   # original MP40 fire/normal reload root carries exactly -90 degrees.
   if mismatch_degrees > 1.0 and (mismatch_degrees < 70.0 or mismatch_degrees > 110.0):
    return false  # Fail closed if source/axis contract changed.
   animation.track_set_key_value(track_idx, 0, neutral_quat)
   root_found = true
   print("BUKKBEEK_MP40_SOURCE_ROOT_FIXED clip=", clip,
    " original_rotation_deg=", mismatch_degrees,
    " new_root_key=", animation.track_get_key_value(track_idx, 0),
    " preserved_magazine_and_bolt_tracks=", animation.get_track_count() - 1)
  if not root_found:
   return false
 set_meta("source_mp40_root_rotation_fixed", true)
 return true

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

func _synchronized_reload_seconds(hands_clip: String, gun_clip: String) -> float:
 if (hands_clip.is_empty() or gun_clip.is_empty()
  or not _hands_anim.has_animation(hands_clip)
  or not _gun_anim.has_animation(gun_clip)):
  return 0.0
 return maxf(_hands_anim.get_animation(hands_clip).length,
  _gun_anim.get_animation(gun_clip).length)


func _play_idle() -> void:
 if not _source_ok:
  return
 if not _idle_hands_clip.is_empty():
  _hands_anim.play(_idle_hands_clip, 0.12)
 if not _gun_idle_clip.is_empty():
  # This blends the j_bolt end pose back to source idle, rather than popping
  # instantly to a different static bolt pose at the end of the reload.
  _gun_anim.play(_gun_idle_clip, 0.12)

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
 if not _source_ok or is_reloading:
  return
 # The gun's original *EMPTY* clip has eight charging-handle keys and a
 # matching 4.2083s hands PSA. The normal 3.29s reload has just one static
 # j_bolt key, so NEVER fake a left-hand handle pull for a tactical reload.
 var empty_mag := current_mag == 0
 var selected_hands := _reload_hands_clip
 var selected_gun := _gun_reload_clip
 if empty_mag and not _hands_reload_empty_clip.is_empty():
  selected_hands = _hands_reload_empty_clip
  selected_gun = _gun_reload_empty_clip
 var required_seconds := _synchronized_reload_seconds(selected_hands, selected_gun)
 if required_seconds < 0.2:
  push_error("BUKKBEEK_MP40_RED: selected source reload pair is invalid")
  return
 # Source strings are reassigned BEFORE Bukkbeek starts its AnimationPlayer
 # and timer, so both hands and gun run their corresponding original variant.
 animation_reload = selected_hands
 reload_time = required_seconds
 var was_reloading := is_reloading
 super.start_reload()
 if is_reloading and not was_reloading:
  _active_reload_hands_clip = selected_hands
  _active_reload_gun_clip = selected_gun
  _gun_anim.play(selected_gun, 0.04)
  _gun_anim.seek(0.0, true)
  _hands_anim.seek(0.0, true)
  set_meta("source_mp40_reload_active_variant", "empty" if empty_mag else "normal")
  set_meta("source_mp40_reload_active_duration", required_seconds)
  print("BUKKBEEK_MP40_REAL_RELOAD variant=", "EMPTY" if empty_mag else "NORMAL",
   " hands=", selected_hands, " gun=", selected_gun, " duration=", required_seconds)


func _on_reload_timer_timeout() -> void:
 super._on_reload_timer_timeout()
 _active_reload_hands_clip = ""
 _active_reload_gun_clip = ""
 if _source_ok:
  _play_idle()
