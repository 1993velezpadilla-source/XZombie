extends Node3D
## Iglesia main-aisle V1: real-time Godot construction based on approved HIP/ADS
## composition, not a still screenshot masquerading as a working 3D church.
## All scenic nodes are collision-free; authoritative pew/altar/colliders live
## in iglesia.gd. Designed for Android Mobile renderer and headless gauntlet.

const FLOOR_Y := 0.018
var rock: StandardMaterial3D
var granite: StandardMaterial3D
var polished: StandardMaterial3D
var grout: StandardMaterial3D
var gilded: StandardMaterial3D
var aged_bronze: StandardMaterial3D
var black_iron: StandardMaterial3D
var wine: StandardMaterial3D
var wax: StandardMaterial3D
var flame: StandardMaterial3D
var glass_blue: StandardMaterial3D
var silver: StandardMaterial3D

func _material(base: Color, rough: float = 0.82, metallic: float = 0.0, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = base
	m.roughness = rough
	m.metallic = metallic
	if glow:
		m.emission_enabled = true
		m.emission = base
		m.emission_energy_multiplier = 2.5
	return m

func build(owner: Node3D) -> void:
	rock = _material(Color(0.083, 0.083, 0.103))
	granite = _material(Color(0.18, 0.167, 0.176))
	polished = _material(Color(0.093, 0.099, 0.131), 0.23, 0.29)
	grout = _material(Color(0.042, 0.043, 0.057))
	gilded = _material(Color(0.41, 0.27, 0.13), 0.33, 0.58)
	aged_bronze = _material(Color(0.22, 0.17, 0.13), 0.6, 0.51)
	black_iron = _material(Color(0.044, 0.051, 0.064), 0.65, 0.27)
	wine = _material(Color(0.22, 0.033, 0.050))
	wax = _material(Color(0.87, 0.75, 0.53), 0.72)
	flame = _material(Color(1.0, 0.53, 0.14), 0.28, 0.0, true)
	glass_blue = _material(Color(0.018, 0.10, 0.29), 0.18, 0.05, true)
	silver = _material(Color(0.53, 0.48, 0.44), 0.57, 0.17)
	_build_reflective_aisle()
	_build_ribbed_roof()
	_build_gothic_window_frames()
	_build_columns_and_side_shrines()
	_build_chandeliers()
	_build_altar_focal_point()
	_build_wall_sconces()
	set_meta("reference_goal", "IGLESIA gothic chapel target images HIP and ADS 2026-10-20")
	set_meta("only_main_aisle", true)
	print("IGLESIA_DRESSING_GREEN: nave, reflected stone tiling, roof ribs, windows, chandeliers, candles, altar retable, banners, crucifix")

func _block(label: String, pos: Vector3, dims: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := BoxMesh.new()
	mesh.size = dims
	item.mesh = mesh
	item.material_override = mat
	item.position = pos
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(item)
	return item

func _cylinder(label: String, pos: Vector3, radius: float, height: float, mat: Material, sides: int = 10) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	item.mesh = mesh
	item.material_override = mat
	item.position = pos
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)
	return item

func _beam(label: String, a: Vector3, b: Vector3, rad: float, mat: Material) -> MeshInstance3D:
	var v := b - a
	var item := _cylinder(label, (a + b) * 0.5, rad, v.length(), mat, 8)
	if v.length_squared() > 0.0001:
		item.quaternion = Quaternion(Vector3.UP, v.normalized())
	return item

func _lamp(label: String, position3d: Vector3, range3d: float, energy: float, tint: Color) -> void:
	var light := OmniLight3D.new()
	light.name = label
	light.position = position3d
	light.light_color = tint
	light.light_energy = energy
	light.omni_range = range3d
	light.shadow_enabled = false # mobile clustered-light budget
	add_child(light)

func _build_reflective_aisle() -> void:
	# Horizontal stone floor is a real 3D material, not a full-screen PNG.
	var plane := MeshInstance3D.new()
	plane.name = "StoneFloor_Satin_Wet"
	var surface := PlaneMesh.new()
	surface.size = Vector2(17.7, 34.6)
	plane.mesh = surface
	plane.material_override = polished
	plane.position.y = FLOOR_Y
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)
	# 1.45 m × 1.0 m coursed stone paving, elongated perspective down nave.
	# Collision stays on the solid static floor directly below these seams.
	for i in range(25):
		var z := -16.9 + float(i) * 1.37
		_block("FloorCourse_%02d" % i, Vector3(0, FLOOR_Y + 0.006, z), Vector3(17.5, 0.009, 0.028), grout)
	for row in range(12):
		var x := -8.3 + float(row) * 1.51
		_block("FloorJoint_%02d" % row, Vector3(x, FLOOR_Y + 0.006, 0), Vector3(0.026, 0.009, 34.3), grout)
	# Candle reflections run along the physical aisle; transparent overlay
	# rather than pretending unavailable mobile screen-space reflections.
	var pool := _material(Color(0.32, 0.16, 0.07, 0.25), 0.29, 0.08)
	pool.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for index in range(7):
		var rect := MeshInstance3D.new()
		rect.name = "WarmFloorGlow_%02d" % index
		var quad := PlaneMesh.new()
		quad.size = Vector2(0.24 + float(index % 3) * 0.12, 1.7)
		rect.mesh = quad
		rect.material_override = pool
		rect.position = Vector3(sin(float(index) * 1.93) * 0.74, FLOOR_Y + 0.023, -13.0 + float(index) * 2.75)
		rect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rect)

func _build_ribbed_roof() -> void:
	var roof := _material(Color(0.043, 0.044, 0.059))
	# Double-slope vaulted roof with actual interior surfaces and decorative ribs.
	for side in [-1.0, 1.0]:
		var slab := _block("VaultRoof_%s" % ("L" if side < 0.0 else "R"),
			Vector3(side * 4.37, 6.67, 0), Vector3(8.92, 0.22, 35), roof)
		slab.rotation_degrees.z = -side * 10.0
	for step in range(6):
		var z := -15.0 + float(step) * 6.05
		for side in [-1.0, 1.0]:
			_beam("GothicVaultRib_%d_%s" % [step, "L" if side < 0 else "R"],
				Vector3(side * 8.58, 5.84, z), Vector3(0, 7.42, z), 0.083, granite)
		_cylinder("VaultKeystone_%02d" % step, Vector3(0, 7.31, z), 0.16, 0.31, gilded, 10)
	# Crown beam also seals the black void visible in user's current APK.
	_block("VaultCrown", Vector3(0, 7.35, 0), Vector3(0.28, 0.23, 35), granite)

func _build_gothic_window_frames() -> void:
	for side in [-1.0, 1.0]:
		var face := "East" if side > 0 else "West"
		for index in range(4):
			var z := [-11.0, -4.0, 3.0, 10.0][index]
			var x := side * 8.58 # slightly in front of existing blue glass
			# Tracery outlines original emissive window panes instead of swapping them.
			for dz in [-0.72, 0.72]:
				_block("TraceryPost_%s_%d_%d" % [face, index, int(dz * 100)],
					Vector3(x, 3.48, z + dz), Vector3(0.13, 2.72, 0.10), black_iron)
			_block("TracerySill_%s_%d" % [face, index], Vector3(x, 2.1, z),
				Vector3(0.16, 0.12, 1.58), granite)
			_block("TraceryTransom_%s_%d" % [face, index], Vector3(x, 3.7, z),
				Vector3(0.12, 0.085, 1.48), aged_bronze)
			_beam("GothicWindowPeakL_%s_%d" % [face, index],
				Vector3(x, 4.87, z - 0.76), Vector3(x, 5.28, z), 0.06, aged_bronze)
			_beam("GothicWindowPeakR_%s_%d" % [face, index],
				Vector3(x, 5.28, z), Vector3(x, 4.87, z + 0.76), 0.06, aged_bronze)
			_block("WindowMullion_%s_%d" % [face, index], Vector3(x, 3.48, z),
				Vector3(0.13, 2.62, 0.043), aged_bronze)
	# Blue stained glass casts cold fill on opposing banks.
	_lamp("WestBlueStainedGlassGlow", Vector3(-7.4, 4.3, -3.8), 10.0, 0.48, Color(0.24, 0.38, 0.97))
	_lamp("EastBlueStainedGlassGlow", Vector3(7.4, 4.3, 4.0), 10.0, 0.48, Color(0.24, 0.38, 0.97))

func _build_columns_and_side_shrines() -> void:
	for side in [-1.0, 1.0]:
		for row in range(5):
			var z := [-13.0, -7.0, -1.0, 5.0, 11.0][row]
			var x := side * 8.25
			_block("ColumnGothicFoot_%d_%d" % [int(side), row],
				Vector3(x, 0.24, z), Vector3(1.06, 0.46, 1.13), granite)
			_block("ColumnCapital_%d_%d" % [int(side), row],
				Vector3(x, 5.32, z), Vector3(0.98, 0.30, 1.05), aged_bronze)
			for dx in [-0.29, 0.29]:
				_cylinder("ColumnFluting_%d_%d_%d" % [int(side), row, int(dx * 100)],
					Vector3(x + dx, 2.9, z - 0.47), 0.077, 4.6, granite, 8)
	# Small carved sanctuary niches outline the candle-lit altar reredos.
	for side in [-1.0, 1.0]:
		var x := side * 5.72
		_block("ShrineNicheBack_%d" % int(side), Vector3(x, 3.21, -17.17),
			Vector3(1.83, 3.5, 0.16), rock)
		_block("ShrinePedestal_%d" % int(side), Vector3(x, 1.43, -16.87),
			Vector3(1.45, 0.43, 0.94), granite)
		for dx in [-0.7, 0.7]:
			_cylinder("ShrinePier_%d_%d" % [int(side), int(dx * 10)],
				Vector3(x + dx, 3.2, -16.82), 0.16, 3.45, granite)
		_beam("ShrineArchA_%d" % int(side), Vector3(x - 0.75, 4.92, -16.84),
			Vector3(x, 5.60, -16.84), 0.12, granite)
		_beam("ShrineArchB_%d" % int(side), Vector3(x, 5.60, -16.84),
			Vector3(x + 0.75, 4.92, -16.84), 0.12, granite)
		# Abstract gothic saint silhouette until verified CC0 sculptures import.
		_cylinder("ShrineStatueBody_%d" % int(side), Vector3(x, 2.78, -16.69),
			0.24, 1.6, silver)
		var head := SphereMesh.new()
		head.radius = 0.21
		head.height = 0.42
		var statue := MeshInstance3D.new()
		statue.name = "ShrineStatueHead_%d" % int(side)
		statue.mesh = head
		statue.material_override = silver
		statue.position = Vector3(x, 3.79, -16.67)
		add_child(statue)

func _candle(label: String, p: Vector3, tall: float = 0.25) -> void:
	_cylinder(label + "_wax", p, 0.050, tall, wax, 8)
	_cylinder(label + "_wick", p + Vector3(0, tall * 0.5 + 0.035, 0), 0.012, 0.085, black_iron, 6)
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.058
	flame_mesh.height = 0.20
	flame_mesh.radial_segments = 8
	flame_mesh.rings = 4
	var f := MeshInstance3D.new()
	f.name = label + "_flame"
	f.mesh = flame_mesh
	f.material_override = flame
	f.position = p + Vector3(0, tall * 0.5 + 0.13, 0)
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(f)

func _build_chandeliers() -> void:
	for group in range(2):
		var z := -7.25 if group == 0 else 3.4
		_beam("ChandelierChain_%d" % group, Vector3(0, 7.32, z), Vector3(0, 4.88, z), 0.025, aged_bronze)
		_cylinder("ChandelierHub_%d" % group, Vector3(0, 4.81, z), 0.22, 0.23, gilded, 10)
		for index in range(10):
			var theta := float(index) * TAU / 10.0
			var x := cos(theta) * 1.52
			var dz := sin(theta) * 1.52
			_beam("ChandelierArm_%d_%02d" % [group, index],
				Vector3(0, 4.76, z), Vector3(x, 4.64, z + dz), 0.045, aged_bronze)
			_cylinder("ChandelierCandleCup_%d_%02d" % [group, index],
				Vector3(x, 4.70, z + dz), 0.10, 0.14, gilded, 8)
			_candle("ChandelierFlame_%d_%02d" % [group, index],
				Vector3(x, 4.90, z + dz), 0.26)
		_lamp("ChandelierWarmLight_%d" % group, Vector3(0, 5.2, z),
			11.0, 1.9, Color(1.0, 0.59, 0.29))

func _build_altar_focal_point() -> void:
	# Raised Tripo altar itself lives in iglesia.gd at y=0.45.
	# These elements are physically separate scenery, never a background image.
	_block("ChancelLipGold", Vector3(0, 0.45, -13.62), Vector3(6.42, 0.08, 0.11), gilded)
	_block("AltarReredosShadow", Vector3(0, 3.2, -17.10), Vector3(6.6, 4.55, 0.20), rock)
	for x in [-3.21, 3.21]:
		_cylinder("GothicRetablePier_%d" % int(x), Vector3(x, 3.50, -16.86),
			0.16, 4.1, granite, 8)
		_cylinder("GothicRetableFinial_%d" % int(x), Vector3(x, 5.65, -16.86),
			0.12, 0.43, gilded, 8)
	_beam("AltarGothicArchLeft", Vector3(-3.25, 5.55, -16.83),
		Vector3(0, 6.51, -16.83), 0.15, gilded)
	_beam("AltarGothicArchRight", Vector3(0, 6.51, -16.83),
		Vector3(3.25, 5.55, -16.83), 0.15, gilded)
	# Center crucifix as the aisle's primary focal point at player eye height.
	_block("CentralCrucifixVertical", Vector3(0, 4.43, -16.76),
		Vector3(0.16, 2.08, 0.14), gilded)
	_block("CentralCrucifixCrossbar", Vector3(0, 4.76, -16.74),
		Vector3(1.06, 0.14, 0.13), gilded)
	for side in [-1.0, 1.0]:
		var x := side * 4.25
		_block("AltarRedBanner_%d" % int(side), Vector3(x, 4.37, -17.10),
			Vector3(1.42, 2.64, 0.08), wine)
		_block("BannerCrossVertical_%d" % int(side), Vector3(x, 4.36, -17.035),
			Vector3(0.075, 1.08, 0.03), gilded)
		_block("BannerCrossHorizontal_%d" % int(side), Vector3(x, 4.48, -17.03),
			Vector3(0.48, 0.07, 0.03), gilded)
	# Place candleholders on and next to top of raised altar.
	for index in range(10):
		var x := -2.1 + float(index) * (4.2 / 9.0)
		_cylinder("AltarCandleStand_%02d" % index, Vector3(x, 2.22, -15.50), 0.075, 0.37, aged_bronze, 8)
		_candle("AltarCandle_%02d" % index, Vector3(x, 2.53, -15.50), 0.35)
	for side in [-1.0, 1.0]:
		var x := side * 2.87
		_cylinder("AltarSideCandelabra_%d" % int(side), Vector3(x, 1.48, -14.9),
			0.073, 1.5, aged_bronze)
		for branch in [-1.0, 0.0, 1.0]:
			var z := -14.9 + branch * 0.25
			_candle("Candelabra_%d_%d" % [int(side), int(branch)],
				Vector3(x, 2.38 - absf(branch) * 0.17, z), 0.22)
	_lamp("AltarAmberFocalBounce", Vector3(0, 3.4, -15.15), 8.4,
		1.2, Color(1.0, 0.51, 0.23))

func _build_wall_sconces() -> void:
	for side in [-1.0, 1.0]:
		for row in range(3):
			var z := -9.0 + float(row) * 8.2
			var x := side * 8.78
			_block("SconceBack_%d_%d" % [int(side), row],
				Vector3(x, 3.24, z), Vector3(0.24, 0.53, 0.36), aged_bronze)
			_beam("SconceBracket_%d_%d" % [int(side), row],
				Vector3(x, 3.2, z), Vector3(x - side * 0.51, 3.43, z),
				0.045, gilded)
			for dz in [-0.23, 0.23]:
				_candle("WallFlame_%d_%d_%d" % [int(side), row, int(dz * 100)],
					Vector3(x - side * 0.5, 3.61, z + dz), 0.25)
			if row == 1:
				_lamp("SconceOmni_%d" % int(side),
					Vector3(x - side * 1.0, 3.75, z),
					6.6, 0.85, Color(1.0, 0.53, 0.26))
