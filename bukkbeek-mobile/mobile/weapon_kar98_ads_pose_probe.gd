extends SceneTree
## Source-authored Kar98k first-person ADS arm pose investigation.
## Aether includes BOTH viewmodel_kar98_fire_ads (hand AND gun PSA) and idle.
## Can the FIRST real ADS fire pose solve the huge-sleeve issue without fakes?
func _init() -> void:
 call_deferred("_run")

func _shot(view:SubViewport,id:String) -> void:
 await process_frame
 await RenderingServer.frame_post_draw
 var image:Image=view.get_texture().get_image()
 var folder:="res://visual_probes/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 image.save_png(folder+id+".png")
 print("XZIEL_SOURCE_KAR98_ADS_PSA_CAPTURE name=",id," alpha_rect=",image.get_used_rect())

func _run()->void:
 var scene:PackedScene=load("res://main.tscn") as PackedScene
 var main:Node=scene.instantiate()
 root.add_child(main)
 await create_timer(0.82).timeout
 var player:Node=main.get_node("Player")
 var manager:Node=player.get_node("WeaponsManager")
 manager.call("switch_weapon",8)
 await create_timer(0.72).timeout
 var w:Node3D=manager.get("current_weapon") as Node3D
 if str(w.get("source_weapon_id"))!="kar98k":
  push_error("XZIEL_KAR_PSA_RED original Kar98k absent");quit(3);return
 var profile:Dictionary=w.get("_profile") as Dictionary
 var hand_clip:Dictionary=w.get("_hands_clips") as Dictionary
 var gun_clip:Dictionary=w.get("_gun_clips") as Dictionary
 var hand_anim:AnimationPlayer=w.get("_hand_anim") as AnimationPlayer
 var gun_anim:AnimationPlayer=w.get("_gun_anim") as AnimationPlayer
 var ik:SkeletonModifier3D=w.get("_source_ads_ik") as SkeletonModifier3D
 if ik!=null:ik.influence=0.0
 var view:SubViewport=player.get_node("WeaponSubViewport/SubViewport") as SubViewport
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 (player.get_node("WeaponSubViewport/SubViewport/Camera3D") as Camera3D).make_current()
 root.get_node("Global").emit_signal("aim_mode_changed",true)
 await create_timer(0.40).timeout
 if ik!=null:ik.influence=0.0
 await _shot(view,"kar98k_source_idle_ads_original")
 for sample_at in [0.0,0.06,0.12,0.20]:
  var hand_fire_ads:String=str(hand_clip.get("fire_ads",""))
  var gun_fire_ads:String=str(gun_clip.get("fire_ads",""))
  if hand_fire_ads.is_empty() or gun_fire_ads.is_empty():
   push_error("XZIEL_KAR_PSA_RED source authored ADS fire clip missing");quit(3);return
  hand_anim.play(hand_fire_ads)
  gun_anim.play(gun_fire_ads)
  hand_anim.seek(sample_at,true)
  gun_anim.seek(sample_at,true)
  hand_anim.pause()
  gun_anim.pause()
  await process_frame
  w.call("_sync_weapon_socket")
  await process_frame
  var clip_id:="kar98k_source_ADS_PSA_ms"+str(int(sample_at*1000))
  if ik!=null:ik.influence=0.0
  await _shot(view,clip_id+"_before")
  if bool(preload("res://mobile/source_weapon_fit.gd").calibrate(w,profile)):
   var rig:Node3D=w.get("fps_arms_root") as Node3D
   rig.transform=w.get("focused_aim_position").transform
   await process_frame
   if ik!=null:ik.influence=0.0
   await _shot(view,clip_id+"_recalibrated")
  else:
   print("XZIEL_KAR_PSA_CANDIDATE_REJECT id=",clip_id)
 print("XZIEL_KAR_SOURCE_PSA_SWEEP_DONE original_authored_ADS_pose=true")
 quit(0)
