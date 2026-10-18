extends Node3D

# Île de ~600 m, relief continu et routes nivelées dans le même maillage physique.
const RADIUS := 310.0
const GRID_STEP := 2.5
const BUCKET_SIZE := 32.0
var roads: Array[Dictionary] = []
var road_buckets: Dictionary = {}
var main_route := PackedVector3Array()
var villages: Array[Vector3] = []
var arrival := Vector3(0, 0, 245)
var portal_position := Vector3(0, 0, 263)
var house_count := 0

func _ready() -> void:
	_plan_roads()
	_build_terrain()
	for road in roads:
		_build_road(road)
	_build_villages()
	_build_details()
	arrival.y = height_at(arrival.x, arrival.z)
	portal_position.y = height_at(portal_position.x, portal_position.z)

func base_height(x: float, z: float) -> float:
	var radius := Vector2(x, z).length()
	var angle := atan2(z, x)
	var coast := radius / (1.0 + 0.035 * sin(angle * 3) + 0.025 * cos(angle * 5))
	var beach := 5.0 - maxf(0, coast - 265) * 0.3
	var hills := (sin(x * 0.035) * cos(z * 0.028) + 1) * 2.5
	var cone := maxf(0, 1.0 - radius / 155.0) * 112.0
	if radius < 26:
		cone = lerpf(52.0, 93.2, smoothstep(8, 26, radius))
	return beach + hills * (1.0 - smoothstep(235, 295, coast)) + cone

func _plan_roads() -> void:
	var entrance := PackedVector3Array([Vector3(0, 0, 270), Vector3(0, 0, 245), Vector3(0, 0, 220)])
	_add_road(entrance, 11.0, false)
	for i in range(281):
		var t := float(i) / 280
		var angle := PI / 2 + t * TAU * 1.35
		var radius := lerpf(220, 33, t)
		main_route.append(Vector3(cos(angle) * radius, 0, sin(angle) * radius))
	_add_road(main_route, 11.0, false)
	# Deux villages accessibles depuis la route en spirale, à l'est et à l'ouest.
	for index in [48, 140]:
		var start := main_route[index]
		var outward := Vector3(start.x, 0, start.z).normalized()
		var village := start + outward * 52
		villages.append(village)
		var path := PackedVector3Array()
		for i in range(21):
			var t := float(i) / 20
			path.append(start.lerp(village + outward * 20, t))
		_add_road(path, 5.0, true)
	# Sentier panoramique sur la côte et chemin autour du cratère.
	var coast_path := PackedVector3Array()
	for i in range(101):
		var angle := PI / 2 + float(i) / 100 * TAU
		coast_path.append(Vector3(cos(angle) * 245, 0, sin(angle) * 245))
	_add_road(coast_path, 4.0, true)
	var rim := PackedVector3Array()
	var end_angle := atan2(main_route[-1].z, main_route[-1].x)
	for i in range(81):
		var angle := end_angle + float(i) / 80 * TAU
		rim.append(Vector3(cos(angle) * 33, 0, sin(angle) * 33))
	_add_road(rim, 5.0, true)

func _add_road(points: PackedVector3Array, width: float, dirt: bool) -> void:
	for i in points.size():
		points[i].y = base_height(points[i].x, points[i].z)
	var road := {"points": points, "width": width, "dirt": dirt}
	roads.append(road)
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var margin := width / 2 + 7
		for bx in range(int(floor((minf(a.x, b.x) - margin) / BUCKET_SIZE)), int(floor((maxf(a.x, b.x) + margin) / BUCKET_SIZE)) + 1):
			for bz in range(int(floor((minf(a.z, b.z) - margin) / BUCKET_SIZE)), int(floor((maxf(a.z, b.z) + margin) / BUCKET_SIZE)) + 1):
				var key := Vector2i(bx, bz)
				if not road_buckets.has(key):
					road_buckets[key] = []
				road_buckets[key].append({"a": a, "b": b, "width": width})

func height_at(x: float, z: float) -> float:
	var height := base_height(x, z)
	var total_weight := 0.0
	var weighted_height := 0.0
	var blend := 0.0
	var key := Vector2i(int(floor(x / BUCKET_SIZE)), int(floor(z / BUCKET_SIZE)))
	for segment: Dictionary in road_buckets.get(key, []):
		var a: Vector3 = segment.a
		var b: Vector3 = segment.b
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var t := clampf(Vector2(x - a.x, z - a.z).dot(ab) / maxf(ab.length_squared(), 0.001), 0, 1)
		var closest := a.lerp(b, t)
		var distance := Vector2(x - closest.x, z - closest.z).length()
		var influence := 1 - smoothstep(float(segment.width) / 2, float(segment.width) / 2 + 7, distance)
		if influence > 0:
			var weight := influence / maxf(1, distance * distance)
			total_weight += weight
			weighted_height += closest.y * weight
			blend = maxf(blend, influence)
	return lerpf(height, weighted_height / total_weight, blend) if total_weight > 0 else height

func _build_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells := int(RADIUS * 2 / GRID_STEP)
	var heights := PackedFloat32Array()
	heights.resize((cells + 1) * (cells + 1))
	for x in range(cells + 1):
		for z in range(cells + 1):
			heights[x * (cells + 1) + z] = height_at(-RADIUS + x * GRID_STEP, -RADIUS + z * GRID_STEP)
	for x in cells:
		for z in cells:
			var a := Vector3(-RADIUS + x * GRID_STEP, 0, -RADIUS + z * GRID_STEP)
			var corners := [a, a + Vector3(GRID_STEP, 0, 0), a + Vector3(0, 0, GRID_STEP), a + Vector3(GRID_STEP, 0, GRID_STEP)]
			var vertex_heights := [heights[x * (cells + 1) + z], heights[(x + 1) * (cells + 1) + z], heights[x * (cells + 1) + z + 1], heights[(x + 1) * (cells + 1) + z + 1]]
			for index in [0, 1, 2, 1, 3, 2]:
				var point: Vector3 = corners[index]
				point.y = vertex_heights[index]
				var color := Color("719658")
				if point.y < 6:
					color = Color("dbc28b")
				elif point.y > 48:
					color = Color("69646a") if point.y < 85 else Color("49444c")
				surface.set_color(color)
				surface.add_vertex(point)
	surface.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "IslandTerrain"
	terrain.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	terrain.material_override = material
	add_child(terrain)
	terrain.create_trimesh_collision()
	# L'océan est visuel : une chute dans l'eau ramène au point d'arrivée.
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1900, 1900)
	sea.mesh = plane
	sea.position.y = 0.8
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("368fbc")
	water.roughness = 0.25
	sea.material_override = water
	add_child(sea)

func _build_road(road: Dictionary) -> void:
	var points: PackedVector3Array = road.points
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var right := Vector3(b.z - a.z, 0, a.x - b.x).normalized() * float(road.width) / 2
		var corners := [a - right, a + right, b - right, b + right]
		for index in [0, 1, 2, 1, 3, 2]:
			var point: Vector3 = corners[index]
			point.y = height_at(point.x, point.z) + 0.15
			surface.add_vertex(point)
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b49b72") if road.dirt else Color("454951")
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	add_child(mesh)
	# Une seule surface physique continue évite les rebords entre tronçons.
	if not road.dirt:
		for i in range(0, points.size() - 1, 4):
			var point := points[i].lerp(points[i + 1], 0.5)
			point.y = height_at(point.x, point.z) + 0.22
			var dash := _box(Vector3(0.18, 0.03, 1.6), point, Color("f1dfaa"), false)
			dash.rotation.y = atan2(points[i + 1].x - points[i].x, points[i + 1].z - points[i].z)

func _build_villages() -> void:
	for v in villages.size():
		var center := villages[v]
		var radial := Vector3(center.x, 0, center.z).normalized()
		var side := Vector3(radial.z, 0, -radial.x)
		for i in range(6):
			var point := center + side * (-1 if i % 2 == 0 else 1) * 12 + radial * (int(i / 2) - 1) * 13
			point.y = height_at(point.x, point.z)
			var foundation_height := 2.5
			_box(Vector3(9, foundation_height, 8), point + Vector3(0, 0.5, 0), Color("817b70"))
			_box(Vector3(8, 4.5, 7), point + Vector3(0, 3.6, 0), Color("ecd1a2") if v == 0 else Color("d8aa8e"))
			var roof := MeshInstance3D.new()
			var pyramid := CylinderMesh.new()
			pyramid.top_radius = 0
			pyramid.bottom_radius = 6.4
			pyramid.height = 3
			pyramid.radial_segments = 4
			roof.mesh = pyramid
			roof.position = point + Vector3(0, 7.1, 0)
			roof.rotation.y = PI / 4
			var roof_material := StandardMaterial3D.new()
			roof_material.albedo_color = Color("a44e3a")
			roof.material_override = roof_material
			add_child(roof)
			roof.create_convex_collision()
			_box(Vector3(1.3, 2.5, 0.12), point + Vector3(0, 2.6, -3.55), Color("654d3c"), false)
			for window_x in [-2.3, 2.3]:
				_box(Vector3(1.3, 1.4, 0.12), point + Vector3(window_x, 4, -3.57), Color("577c8d"), false)
			house_count += 1
		_sign(center + side * 20, "HAMEAU DES PALMIERS" if v == 0 else "VILLAGE DES HAUTEURS")

func _build_details() -> void:
	var lava := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 16
	disk.bottom_radius = 16
	disk.height = 0.5
	lava.mesh = disk
	lava.position.y = 60
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f27537")
	material.emission_enabled = true
	material.emission = Color("eb4b16")
	lava.material_override = material
	add_child(lava)
	var plume := CPUParticles3D.new()
	plume.position = Vector3(0, 94, 0)
	plume.amount = 18
	plume.lifetime = 5
	plume.preprocess = 5
	plume.direction = Vector3(0.2, 1, 0)
	plume.spread = 18
	plume.initial_velocity_min = 3
	plume.initial_velocity_max = 6
	plume.gravity = Vector3(0.2, 0.4, 0)
	plume.scale_amount_min = 3
	plume.scale_amount_max = 6
	var cloud := SphereMesh.new()
	cloud.radial_segments = 8
	cloud.rings = 4
	var smoke_material := StandardMaterial3D.new()
	smoke_material.albedo_color = Color("77747c")
	cloud.material = smoke_material
	plume.mesh = cloud
	add_child(plume)
	for i in range(65):
		var angle := i * 2.39996
		var radius := 175.0 + fmod(i * 37.0, 85.0)
		var point := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		if _near_road(point, 13):
			continue
		point.y = height_at(point.x, point.z)
		_box(Vector3(0.7, 6, 0.7), point + Vector3(0, 3, 0), Color("8b704b"))
		var crown := MeshInstance3D.new()
		var foliage := CylinderMesh.new()
		foliage.top_radius = 0
		foliage.bottom_radius = 4
		foliage.height = 3
		foliage.radial_segments = 5
		crown.mesh = foliage
		crown.position = point + Vector3(0, 6.8, 0)
		var leaf := StandardMaterial3D.new()
		leaf.albedo_color = Color("427a50")
		crown.material_override = leaf
		add_child(crown)
	_sign(Vector3(12, 0, 238), "ÎLE DU VOLCAN\nRoute du cratère ↑\nVillages : chemins de terre")
	_sign(main_route[160] + Vector3(12, 0, 0), "SOMMET ↑")
	_sign(main_route[-1] + Vector3(0, 0, 8), "BELVÉDÈRE DU CRATÈRE")

func _near_road(point: Vector3, margin: float) -> bool:
	for road in roads:
		var points: PackedVector3Array = road.points
		for p in points:
			if Vector2(point.x - p.x, point.z - p.z).length() < margin:
				return true
	return false

func _sign(point: Vector3, text: String) -> void:
	point.y = height_at(point.x, point.z)
	_box(Vector3(0.3, 3, 0.3), point + Vector3(0, 1.5, 0), Color("786148"))
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.025
	label.position = point + Vector3(0, 3.2, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _box(size: Vector3, point: Vector3, color: Color, solid := true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = point
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	add_child(mesh)
	if solid:
		mesh.create_convex_collision()
	return mesh
