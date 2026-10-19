extends SceneTree
## Measure the **actual original rifle receiver** with GPU j_gun skin transform,
## not a 2-point iron sight guess. Classify all source triangles by visibility
## at the REAL first-person Viewport lens, before/after source ADS.
func _init() -> void:
 call_deferred("_run")

func _inspect(w:Node3D,cam:Camera3D,stance:String) -> void:
 var id:String=str(w.get("source_weapon_id"))
 var gun:Node3D=w.get("_gun") as Node3D
 var sk:Skeleton3D=null
 for n:Node in gun.find_children("*","Skeleton3D",true,false):
  var b:=n as Skeleton3D
  if b.find_bone("j_gun")>=0:sk=b
 if sk==null:
  push_error("XZIEL_SOURCE_FRUSTUM_RED no GPU gun skeleton "+id)
  quit(6);return
 sk.force_update_all_bone_transforms()
 var bone_index:int=sk.find_bone("j_gun")
 var skin_pose:Transform3D=sk.get_bone_global_pose(bone_index)*sk.get_bone_global_rest(bone_index).affine_inverse()
 var viewport:Vector2=cam.get_viewport().get_visible_rect().size
 var lens_fov_rad:float=deg_to_rad(cam.fov)
 var tan_y:float=tan(lens_fov_rad*0.5)
 var aspect:float=viewport.x/maxf(1.0,viewport.y)
 for n:Node in gun.find_children("*","MeshInstance3D",true,false):
  var m:=n as MeshInstance3D
  if m.mesh==null:continue
  for surface in range(m.mesh.get_surface_count()):
   var material:Material=m.mesh.surface_get_material(surface)
   var mname:String=str(material.resource_name) if material!=null else "UNLABELED"
   var arrays:Array=m.mesh.surface_get_arrays(surface)
   var verts:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var report:Dictionary={"total":verts.size(),"behind_eye":0,"near_clipped":0,
    "x_offscreen":0,"y_offscreen":0,"in_frustum":0,
    "behind_camera_depth_min_m":INF,"depth_min_m":INF,
    "depth_max_m":-INF,"projected_receiver_lower_quarter":0}
   var xcenter:=Vector3.ZERO
   var source_xmin:=INF
   var source_xmax:=-INF
   for vertex:Vector3 in verts:
    source_xmin=minf(source_xmin,vertex.x)
    source_xmax=maxf(source_xmax,vertex.x)
    var raw:Vector3=m.to_global(vertex)
    var posed:Vector3=sk.to_global(skin_pose*sk.to_local(raw))
    var camera_p:Vector3=cam.to_local(posed)
    var d:float=-camera_p.z
    report["depth_min_m"]=minf(float(report["depth_min_m"]),d)
    report["depth_max_m"]=maxf(float(report["depth_max_m"]),d)
    if d<=0:
     report["behind_eye"]+=1
     report["behind_camera_depth_min_m"]=minf(float(report["behind_camera_depth_min_m"]),d)
     continue
    if d<cam.near:
     report["near_clipped"]+=1
     continue
    if absf(camera_p.x)>d*tan_y*aspect:
     report["x_offscreen"]+=1
     continue
    if absf(camera_p.y)>d*tan_y:
     report["y_offscreen"]+=1
     continue
    report["in_frustum"]+=1
    var pix:Vector2=cam.unproject_position(posed)
    if pix.y>viewport.y*0.75:report["projected_receiver_lower_quarter"]+=1
   report["source_xmin_m"]=source_xmin
   report["source_xmax_m"]=source_xmax
   report["original_material"]=mname
   print("XZIEL_SOURCE_FRUSTUM id=",id," stance=",stance,
    " source_surface=",surface," camera_near=",cam.near,
    " original_bounds=",Vector2(source_xmin,source_xmax),
    " projected=",JSON.stringify(report))
   
func _run()->void:
 var scene:PackedScene=load("res://main.tscn") as PackedScene
 if scene==null:push_error("XZIEL_SOURCE_FRUSTUM_RED main scene");quit(6);return
 var main:Node=scene.instantiate()
 root.add_child(main)
 await create_timer(0.80).timeout
 var player:Node=main.get_node("Player")
 var manager:Node=player.get_node("WeaponsManager")
 var cam:Camera3D=player.get_node("WeaponSubViewport/SubViewport/Camera3D") as Camera3D
 var view:SubViewport=player.get_node("WeaponSubViewport/SubViewport") as SubViewport
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 cam.make_current()
 for i in [6,7,8]:
  manager.call("switch_weapon",i)
  await create_timer(0.64).timeout
  var w:Node3D=manager.get("current_weapon") as Node3D
  _inspect(w,cam,"HIP")
  root.get_node("Global").emit_signal("aim_mode_changed",true)
  await create_timer(0.50).timeout
  _inspect(w,cam,"ADS")
  root.get_node("Global").emit_signal("aim_mode_changed",false)
 print("XZIEL_SOURCE_FRUSTUM_COMPLETE source_GPU_skin_verified=3")
 quit(0)
