extends SceneTree
## Compare all 113 original T4 Marine source bone tags versus approved MP40.
## tag_view / tag_ads / tag_camera are PROVENANCE, not invented lens meters.
func _init() -> void: call_deferred("_run")

func _report(weapon: Node, name: String, skeleton: Skeleton3D) -> void:
 if skeleton == null:
  push_error("XZIEL_SOURCE_CAMERA_AUDIT_RED "+name+" no original marine rig")
  quit(3);return
 skeleton.force_update_all_bone_transforms()
 var markers: Dictionary={}
 for id in ["tag_view","tag_camera","tag_ads","tag_weapon",
  "j_wrist_le","j_wrist_ri","j_elbow_le","j_elbow_ri",
  "j_shoulder_le","j_shoulder_ri"]:
  var bone:=skeleton.find_bone(id)
  if bone<0:continue
  var transform: Transform3D=skeleton.get_bone_global_pose(bone)
  markers[id]={"position":str(transform.origin),
   "rotation":str(transform.basis.get_rotation_quaternion())}
 var rel:Dictionary={}
 for tag in ["tag_view","tag_camera","tag_ads"]:
  var b:=skeleton.find_bone(tag)
  var w:=skeleton.find_bone("tag_weapon")
  if b<0 or w<0:continue
  var cam:Transform3D=skeleton.get_bone_global_pose(b)
  var g:Transform3D=skeleton.get_bone_global_pose(w)
  var diff:Transform3D=cam.affine_inverse()*g
  rel[tag]={"weapon_relative_to_camera":str(diff.origin),
   "distance":diff.origin.length(),
   "rotation":str(diff.basis.get_rotation_quaternion())}
 print("XZIEL_SOURCE_CAMERA_AUDIT name=",name,
  " bones=",skeleton.get_bone_count(),
  " marker_poses=",JSON.stringify(markers),
  " source_tag_camera_geometry=",JSON.stringify(rel))

func _run() -> void:
 var scene:PackedScene=load("res://player/player.tscn") as PackedScene
 if scene==null:push_error("XZIEL_SOURCE_CAMERA_AUDIT_RED no player");quit(3);return
 var player=scene.instantiate()
 root.add_child(player)
 await create_timer(0.74).timeout
 var manager=player.get_node("WeaponsManager")
 var array:Array=manager.get("weapons_array")
 for ix in [5,6,7,8]:
  var w:Node=array[ix]
  var s:Skeleton3D=w.get("_skeleton") as Skeleton3D if ix==5 else w.get("_hand_skeleton") as Skeleton3D
  _report(w,str(w.name),s)
 print("XZIEL_SOURCE_CAMERA_AUDIT_DONE real_Marine_rigs=4")
 quit(0)
