extends RigidBody3D
## Functional grenade for template's already existing HAND_GRENADE ammo inventory.
## A temporary procedural body; never substitutes MP40 or original gun assets.
const BLAST_RADIUS := 4.0
const BLAST_DAMAGE := 170.0
var fuse_remaining: float = 3.2

func _ready() -> void:
 mass = 0.43
 continuous_cd = true
 contact_monitor = false
 var collider := CollisionShape3D.new()
 var sphere := SphereShape3D.new()
 sphere.radius = 0.095
 collider.shape = sphere
 add_child(collider)
 var visual := MeshInstance3D.new()
 var body_mesh := SphereMesh.new()
 body_mesh.radius = 0.095
 body_mesh.height = 0.19
 visual.mesh = body_mesh
 var mat := StandardMaterial3D.new()
 mat.albedo_color = Color(0.23, 0.27, 0.17)
 mat.roughness = 0.8
 visual.material_override = mat
 add_child(visual)
 get_tree().create_timer(maxf(0.05, fuse_remaining), false).timeout.connect(_explode)

func _explode() -> void:
 if not is_inside_tree(): return
 var blast := SphereShape3D.new()
 blast.radius = BLAST_RADIUS
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape = blast
 query.transform = Transform3D(Basis.IDENTITY, global_position)
 query.collide_with_bodies = true
 query.collision_mask = 0xffffffff
 query.exclude = [get_rid()]
 var hits := get_world_3d().direct_space_state.intersect_shape(query, 64)
 for hit in hits:
  var target: Object = hit.get("collider")
  if target == null or not target.has_method("get_damage"): continue
  if target == Global.player: continue
  var direction: Vector3 = (target.global_position - global_position).normalized()
  target.call("get_damage", BLAST_DAMAGE, direction)
 # Lightweight short-lived flash; do not ship counterfeit source SFX.
 var flash := OmniLight3D.new()
 flash.light_color = Color(1.0, 0.6, 0.26)
 flash.light_energy = 3.0
 flash.omni_range = BLAST_RADIUS
 get_tree().current_scene.add_child(flash)
 flash.global_position = global_position
 get_tree().create_timer(0.12, false).timeout.connect(func():
  if is_instance_valid(flash): flash.queue_free()
 )
 queue_free()
