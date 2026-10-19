extends SceneTree
## Real Aether weapon/hand provenance diagnostics: hip projection, gun axes,
## source PSA static-root rotations, bone attachments. NO hard-coded offsets.
func _init() -> void:
 call_deferred("_run")

func _probe(w: Node3D) -> void:
 var id := str(w.get("source_weapon_id"))
 var hg: Node3D = w.get("_gun")
 var rig: Node3D = w.get("fps_arms_root")
 var ap: AnimationPlayer = w.get("_gun_anim")
 var hs: Skeleton3D = w.get("_hand_skeleton")
 var mesh: MeshInstance3D = null
 for n: Node in hg.find_children("*","MeshInstance3D",true,false):
  if (n as MeshInstance3D).mesh != null:
   mesh = n as MeshInstance3D
   break
 if mesh == null: push_error("V9_SOURCE_PROBE_RED no mesh "+id); return
 var bounds: AABB = AABB()
 var initial := true
 var count := 0
 for ix in range(mesh.mesh.get_surface_count()):
  var a: Array = mesh.mesh.surface_get_arrays(ix)
  var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
  for v: Vector3 in vertices:
   if initial:
    bounds=AABB(v,Vector3.ZERO);initial=false
   else:
    bounds=bounds.expand(v)
   count += 1
 var names: Array[String] = []
 var model_skeleton: Skeleton3D = null
 for n: Node in hg.find_children("*","Skeleton3D",true,false):
  if (n as Skeleton3D).find_bone("j_gun")>=0:
   model_skeleton=n as Skeleton3D
 var skin := Transform3D.IDENTITY
 if model_skeleton != null:
  var bone_id:=model_skeleton.find_bone("j_gun")
  skin=model_skeleton.get_bone_global_pose(bone_id) * model_skeleton.get_bone_global_rest(bone_id).affine_inverse()
 var vfront:=Vector3(bounds.end.x,bounds.position.y+bounds.size.y*0.55,bounds.position.z+bounds.size.z*0.5)
 var vrear:=Vector3(bounds.position.x,bounds.position.y+bounds.size.y*0.55,bounds.position.z+bounds.size.z*0.5)
 var rawf:=mesh.to_global(vfront)
 var rawr:=mesh.to_global(vrear)
 if model_skeleton != null:
  rawf=model_skeleton.to_global(skin*model_skeleton.to_local(rawf))
  rawr=model_skeleton.to_global(skin*model_skeleton.to_local(rawr))
 var local_front:=rig.to_local(rawf)
 var local_rear:=rig.to_local(rawr)
 var hip: Transform3D=w.get("standard_aim_position").transform
 var ads: Transform3D=w.get("focused_aim_position").transform
 var eyehip:Vector3=hip*local_front
 var eyeads:Vector3=ads*local_front
 print("XZIEL_V9_GEOM id=",id," vertices=",count," size_m=",bounds.size,
  " mesh_name=",mesh.name," model_skeleton=",model_skeleton != null,
  " axis_source=",vfront-vrear,
  " axis_in_rig=",local_front-local_rear,
  " hip_front_eye=",eyehip," ads_front_eye=",eyeads,
  " originalHIP=",hip," originalADS=",ads,
  " source_root=",hg.transform,
  " source_hands=",w.get("_hands").transform,
  " viewmodel_camera_fov=75")
 var clips: Array=[w.get("_gun_clips").get("idle"),w.get("_gun_clips").get("fire"),
  w.get("_gun_clips").get("reload"),w.get("_gun_clips").get("reload_empty")]
 for role in ["idle","fire","reload","reload_empty"]:
  var clip:=str(w.get("_gun_clips").get(role,""))
  if clip.is_empty() or not ap.has_animation(clip):continue
  var animation:=ap.get_animation(clip)
  var q: Array=[]
  for i in range(animation.get_track_count()):
   var path:=str(animation.track_get_path(i))
   if animation.track_get_type(i)==Animation.TYPE_ROTATION_3D and (
    "_skel" in path or "Skeleton3D" in path and "j_gun" in path):
    var n:=animation.track_get_key_count(i)
    q.append({"path":path,"key_count":n,"first":str(animation.track_get_key_value(i,0))})
  print("XZIEL_V9_ROOTS id=",id," role=",role," roots=",JSON.stringify(q))

func _run() -> void:
 var player=load("res://player/player.tscn").instantiate()
 root.add_child(player)
 await create_timer(0.65).timeout
 var mgr=player.get_node("WeaponsManager")
 for id in ["ColtSource","ThompsonSource","Kar98kSource"]:
  var w:Node3D=mgr.get_node(id)
  _probe(w)
 quit(0)
