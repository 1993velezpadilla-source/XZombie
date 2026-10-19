extends SceneTree
## Actual assembled Bukkbeek scene, not a simulated gun catalogue.
## Regression: MP40 V6 still remains index 5 and original 5 weapons stay.
func _init() -> void:
 call_deferred("_run")

func _red(reason: String) -> void:
 push_error("XZIEL_MULTIWEAPON_RUNTIME_RED " + reason)
 quit(3)

func _run() -> void:
 var scene: PackedScene = load("res://player/player.tscn") as PackedScene
 if scene == null:
  _red("original game player cannot load")
  return
 var player: Node3D = scene.instantiate() as Node3D
 root.add_child(player)
 await process_frame
 await process_frame
 # Like the original MP40, source sight calibration MUST wait for
 # authentic idle hand skeleton blending, never accept transient bind pose.
 await create_timer(0.55).timeout
 var manager = player.get_node_or_null("WeaponsManager")
 if manager == null: _red("manager missing"); return
 var arr: Array = manager.get("weapons_array")
 if arr.size() != 9:
  _red("expected 5 Bukkbeek + MP40 + Colt, Thompson, Kar98k: "+str(arr.size()))
  return
 if str(arr[5].name) != "MP40Source":
  _red("approved source MP40 index/weapon replaced")
  return
 var approved: Node3D = arr[5] as Node3D
 if not bool(approved.get_meta("source_mp40_ready", false)):
  _red("regression: approved MP40 rig not bound")
  return
 var expected := ["ColtSource", "ThompsonSource", "Kar98kSource"]
 var source_ids := ["colt", "thompson", "kar98k"]
 for i in range(3):
  var gun: Node3D = arr[6 + i] as Node3D
  if gun == null or str(gun.name) != expected[i]:
   _red("source weapon scene order changed "+expected[i]); return
  if not bool(gun.get_meta("source_optics_calibrated", false)):
   _red("source vertex-to-GPU-skinned optical ADS and hip solver RED "+source_ids[i]); return
  if not bool(gun.get_meta("source_root_import_repaired", false)):
   _red("original source weapon static root normalization RED "+source_ids[i]); return
  var rear_eye: Vector3=gun.get_meta("source_ads_rear_eye",Vector3(100,100,100)) as Vector3
  var front_eye: Vector3=gun.get_meta("source_ads_front_eye",Vector3(100,100,100)) as Vector3
  if Vector2(rear_eye.x,rear_eye.y).length()>0.0002 or Vector2(front_eye.x,front_eye.y).length()>0.0002:
   _red("real front/rear physical iron sights not on same source ray "+source_ids[i]);return
  if not bool(gun.get_meta("source_weapon_bound", false)):
   _red("original GLBs, compatible hands or authored PSAs did not bind for "+source_ids[i])
   return
  if str(gun.get_meta("source_weapon_id", "")) != source_ids[i]:
   _red("wrong asset bound to gun "+source_ids[i]); return
  var hand_anim: AnimationPlayer = gun.get("_hand_anim") as AnimationPlayer
  var gun_anim: AnimationPlayer = gun.get("_gun_anim") as AnimationPlayer
  var skel: Skeleton3D = gun.get("_hand_skeleton") as Skeleton3D
  var mesh_count := 0
  for n: Node in gun.get_node("FPSHandsRoot").find_children("*", "MeshInstance3D", true, false):
   var mesh := n as MeshInstance3D
   if mesh.mesh != null and mesh.mesh.get_surface_count() > 0: mesh_count += 1
  if mesh_count < 2 or skel == null or skel.find_bone("tag_weapon") < 0:
   _red("source geometry/hand bone missing "+source_ids[i]); return
  if hand_anim == null or gun_anim == null:
   _red("source PSA animation players missing "+source_ids[i]); return
  var roles: Dictionary = gun.get("_hands_clips") as Dictionary
  var guns: Dictionary = gun.get("_gun_clips") as Dictionary
  for role in ["idle", "fire", "reload"]:
   if not hand_anim.has_animation(str(roles.get(role, ""))) or not gun_anim.has_animation(str(guns.get(role, ""))):
    _red("source PSA pairing absent "+source_ids[i]+" "+role);return
  var sfx: AudioStreamPlayer3D = gun.get_node_or_null("SFX/FiringSFX") as AudioStreamPlayer3D
  if sfx == null or sfx.stream == null:
   _red("source original fire sample missing "+source_ids[i]);return
  if gun.get("reload_sfx") != null:
   _red("fake template reload sample incorrectly connected "+source_ids[i]);return
  print("XZIEL_MULTIWEAPON_BOUND_GREEN id=", source_ids[i],
   " realMeshes=", mesh_count,
   " handsPSA=", hand_anim.get_animation_list().size(),
   " gunPSA=", gun_anim.get_animation_list().size(),
   " fireAudio=true tag_weapon=true")
 # No mixing V7 touch state, and the player's original real hand/weapon
 # object lifetime must survive all weapon selection changes.
 for ix in [6,7,8,5]:
  manager.switch_weapon(ix)
  await create_timer(0.60).timeout
  if manager.current_weapon != arr[ix]:
   _red("real weapon swap failed for "+str(ix));return
 if manager.current_weapon != approved:
  _red("MP40 failed restoration after multiweapon swap");return
 print("XZIEL_MULTIWEAPON_RUNTIME_GREEN sourceWeaponCount=3 mp40Unchanged=true")
 quit(0)
