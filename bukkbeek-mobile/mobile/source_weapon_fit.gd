extends RefCounted
## Repeatable MP40 physical-viewmodel method for ORIGINAL Aether GLBs:
## exact witness vertices -> real GPU j_gun skin -> real hand tag_weapon ->
## camera-space iron-sight line -> roll/camera framing -> pixel validation.
## No "universal 12cm": independent original geometry per gun.
static func _point(a: Array) -> Vector3:
 return Vector3(float(a[0]), float(a[1]), float(a[2]))

static func _material_mesh(root: Node3D, samples: Array) -> MeshInstance3D:
 for n: Node in root.find_children("*", "MeshInstance3D", true, false):
  var m:=n as MeshInstance3D
  if m.mesh == null: continue
  var matches:=true
  for sample in samples:
   var found:=false
   for si in range(m.mesh.get_surface_count()):
    var arrays: Array=m.mesh.surface_get_arrays(si)
    var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var anchor:=_point(sample)
    for v: Vector3 in verts:
     if v.distance_to(anchor) < 0.000025:
      found=true
      break
    if found: break
   if not found:
    matches=false
    break
  if matches: return m
 return null

static func _posed_vertex(m: MeshInstance3D, sk: Skeleton3D, bone_id: int, v: Vector3) -> Vector3:
 var raw:=m.to_global(v)
 var skin:=sk.get_bone_global_pose(bone_id) * sk.get_bone_global_rest(bone_id).affine_inverse()
 return sk.to_global(skin * sk.to_local(raw))

static func calibrate(w: Node3D, profile: Dictionary) -> bool:
 var id:=str(profile.get("id",""))
 var sight: Dictionary=profile.get("source_sights",{})
 var rears: Array=sight.get("rear_witness_vertices",[])
 var fronts: Array=sight.get("front_witness_vertices",[])
 if rears.is_empty() or fronts.is_empty(): push_error("XZIEL_FIT_RED no original metal sight witnesses "+id);return false
 var gun:Node3D=w.get("_gun")
 var rig:Node3D=w.get("fps_arms_root")
 var gun_sk:Skeleton3D=null
 for node: Node in gun.find_children("*","Skeleton3D",true,false):
  var s:=node as Skeleton3D
  if s.find_bone("j_gun") >= 0:
   gun_sk=s
   break
 if gun_sk==null or rig==null: push_error("XZIEL_FIT_RED no original j_gun skin "+id);return false
 var m:=_material_mesh(gun,rears+fronts)
 if m==null:push_error("XZIEL_FIT_RED witness vertices NOT present in source GLB "+id);return false
 var bone:=gun_sk.find_bone("j_gun")
 var real_rear:=Vector3.ZERO
 var real_front:=Vector3.ZERO
 for v in rears:
  real_rear+=_posed_vertex(m,gun_sk,bone,_point(v))
 real_rear/=float(rears.size())
 for v in fronts:
  real_front+=_posed_vertex(m,gun_sk,bone,_point(v))
 real_front/=float(fronts.size())
 var rear:Vector3=rig.to_local(real_rear)
 var front:Vector3=rig.to_local(real_front)
 var sightline:Vector3=front-rear
 var expected_length:=float(sight.get("source_witness_sep_m",0.0))
 if sightline.length() < 0.13 or sightline.length() > 1.3 or absf(sightline.length()-expected_length)>0.08:
  push_error("XZIEL_FIT_RED source authentic 3D sightline length mismatch id="+id+" actual="+str(sightline.length())+" expected="+str(expected_length))
  return false
 var authored_hip:Transform3D=w.get("standard_aim_position").transform
 var authored_ads:Transform3D=w.get("focused_aim_position").transform
 var delta:=Quaternion((authored_ads.basis*sightline).normalized(),Vector3.FORWARD)
 var aligned_basis:Basis=(Basis(delta)*authored_ads.basis).orthonormalized()
 # DO NOT force imported GLB +Y onto the screen's up axis: in the
 # Aether/ActorX skeleton, source mesh Y is not an authored COD camera roll.
 # That previous -90° correction rotated real shoulders THROUGH the screen.
 # Like our working MP40, solve the remaining roll from genuine wrist/elbow
 # locations, while preserving source-authored HIP arm screen projections.
 var original_arm: Skeleton3D=w.get("_hand_skeleton") as Skeleton3D
 if original_arm==null:push_error("XZIEL_FIT_RED original hand skeleton missing "+id);return false
 var reference_pose:Transform3D=authored_hip
 var joint_rig: Array[Vector3]=[]
 var joint_screen: Array[Vector2]=[]
 var joint_weights: Array[float]=[]
 for label in ["j_wrist_le","j_wrist_ri","j_elbow_le","j_elbow_ri","j_shoulder_le","j_shoulder_ri"]:
  var j:=original_arm.find_bone(label)
  if j<0:continue
  var pose_world:Vector3=original_arm.to_global(original_arm.get_bone_global_pose(j).origin)
  var bone_rig:Vector3=rig.to_local(pose_world)
  var view_ref:Vector3=reference_pose*bone_rig
  if view_ref.z >= -0.06:continue
  joint_rig.append(bone_rig)
  joint_screen.append(Vector2(view_ref.x,view_ref.y)/(-view_ref.z))
  joint_weights.append(3.0 if "wrist" in label else (1.0 if "elbow" in label else 0.25))
 var roll:=0.0
 var best_score:=INF
 # Preserve the user's source authoring instead of letting a 90-degree
 # screenshot-only model-up guess flip arms into the camera.
 for i in range(41):
  var angle_deg:float=(float(i)-20.0)*0.5 # ±10° physical camera-axis roll
  var candidate:Basis=(Basis(Quaternion(Vector3.FORWARD,deg_to_rad(angle_deg)))*aligned_basis).orthonormalized()
  var r:Vector3=candidate*rear
  var origin:=Vector3(-r.x,-r.y,-float(sight.get("eye_relief_m",0.2))-r.z)
  var score:float=angle_deg*angle_deg*0.003
  for index in range(joint_rig.size()):
   var frame:Vector3=candidate*joint_rig[index]+origin
   if frame.z>=-0.04:
    score+=joint_weights[index]*(60.0+absf(frame.z)*20.0)
   else:
    var point:=Vector2(frame.x,frame.y)/-frame.z
    score+=joint_weights[index]*point.distance_squared_to(joint_screen[index])
  if score<best_score:
   best_score=score
   roll=deg_to_rad(angle_deg)
 var upright_basis:Basis=(Basis(Quaternion(Vector3.FORWARD,roll))*aligned_basis).orthonormalized()
 w.set_meta("source_original_hand_joint_count",joint_rig.size())
 w.set_meta("source_original_arms_fit_error",best_score)
 var aligned_rear:=upright_basis*rear
 var eye_relief:=float(sight.get("eye_relief_m",0.0))
 if eye_relief<0.11 or eye_relief>0.37:
  push_error("XZIEL_FIT_RED eye relief outside mobile FPS guard "+id);return false
 var target_ads:=Transform3D(upright_basis,Vector3(-aligned_rear.x,-aligned_rear.y,-eye_relief-aligned_rear.z))
 # Independent, source-image-verified rendering correction. Camera-ray
 # X/Y sight alignment remains authoritative. NEVER assign MP40 numbers to
 # a pistol: real per-gun sweeps measured skin + receiver visibility.
 var ads_screen_shift_z:float=float(sight.get("ads_render_offset_z_m",0.0))
 if absf(ads_screen_shift_z)>0.30:return false
 target_ads.origin.z+=ads_screen_shift_z
 var effective_eye_relief:float=eye_relief-ads_screen_shift_z
 if effective_eye_relief<0.11 or effective_eye_relief>0.75:return false
 var test_rear:=target_ads*rear
 var test_front:=target_ads*front
 if Vector2(test_rear.x,test_rear.y).length()>0.00006 or Vector2(test_front.x,test_front.y).length()>0.00006:
  push_error("XZIEL_FIT_RED real front/rear sights not centered "+id);return false
 if test_front.z>=test_rear.z-0.11:
  push_error("XZIEL_FIT_RED real barrel points wrong way "+id);return false
 # Template HIP yaw and pitch stay source-authored; only remove the incorrect
 # extra gun roll. Use ORIGINAL source measured body length to position the
 # geometry inside the mobile safe frame, never use screenshot PNG sprites.
 var hip_delta:Basis=authored_hip.basis*authored_ads.basis.inverse()
 var hip_basis:Basis=(hip_delta*upright_basis).orthonormalized()
 var body_length:=float(sight.get("source_body_length_m",0.0))
 if body_length<0.2 or body_length>1.2:push_error("XZIEL_FIT_RED body source extents "+id);return false
 var clearance:float=float(sight.get("hip_camera_clearance_m",0.44))
 if clearance<0.35 or clearance>0.95:return false
 var hip_front:=Vector3(0.13,-0.15,-(body_length+clearance))
 var hip_shift_y:float=float(sight.get("hip_render_offset_y_m",0.0))
 var hip_shift_z:float=float(sight.get("hip_render_offset_z_m",0.0))
 if absf(hip_shift_y)>0.15 or absf(hip_shift_z)>0.30:return false
 hip_front.y+=hip_shift_y
 hip_front.z+=hip_shift_z
 var framed:=Transform3D(hip_basis,hip_front-hip_basis*front)
 # Actual source gun front must be within the visible instrumented 75° FOV.
 var sample_fr:=framed*front
 var fov_tan:=tan(deg_to_rad(75.0)*0.5)
 if (sample_fr.z>=-0.2 or absf(sample_fr.x/sample_fr.z)>=fov_tan or absf(sample_fr.y/sample_fr.z)>=fov_tan):
  push_error("XZIEL_FIT_RED source front projected outside 75deg lens "+id);return false
 var hip_marker: Marker3D=w.get("standard_aim_position") as Marker3D
 var ads_marker: Marker3D=w.get("focused_aim_position") as Marker3D
 if hip_marker==null or ads_marker==null:return false
 hip_marker.transform=framed
 ads_marker.transform=target_ads
 w.set_meta("source_optics_calibrated",true)
 w.set_meta("source_measured_sight_separation_m",sightline.length())
 w.set_meta("source_sight_rear_rig",rear)
 w.set_meta("source_sight_front_rig",front)
 w.set_meta("source_hip_front_eye",sample_fr)
 w.set_meta("source_ads_rear_eye",test_rear)
 w.set_meta("source_ads_actual_eye_relief_m",effective_eye_relief)
 w.set_meta("source_ads_cinematic_render_offset_z_m",ads_screen_shift_z)
 w.set_meta("source_hip_cinematic_render_offset_y_m",hip_shift_y)
 w.set_meta("source_hip_cinematic_render_offset_z_m",hip_shift_z)
 w.set_meta("source_ads_front_eye",test_front)
 w.set_meta("source_optical_upright_roll_deg",rad_to_deg(roll))
 w.set_meta("source_hip_source_body_length_m",body_length)
 print("XZIEL_SOURCE_OPTICS_GREEN id=",id," sight_sep_m=",sightline.length(),
  " eye_relief_m=",eye_relief," arm_preserving_roll_deg=",rad_to_deg(roll),
  " hip_front_eye=",sample_fr," ADS_rear_eye=",test_rear," ADS_front_eye=",test_front)
 return true
