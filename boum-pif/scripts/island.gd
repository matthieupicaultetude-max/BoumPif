extends Node3D

# Île de ~600 m, relief continu et routes nivelées dans le même maillage physique.
const RADIUS := 310.0
const GRID_STEP := 2.5
const BUCKET_SIZE := 32.0
const ROAD_MASK_SIZE := 1024
var road_mask: Image
var road_material: ShaderMaterial
var roads: Array[Dictionary] = []
var road_buckets: Dictionary = {}
var race_route := PackedVector3Array()
var tree_count := 0
var marking_batches: Dictionary = {}
var house_positions: Array[Vector3] = []
var terrain_heights := PackedFloat32Array()
var main_route := PackedVector3Array()
var villages: Array[Vector3] = []
var arrival := Vector3(0, 0, 245)
var portal_position := Vector3(0, 0, 263)
var house_count := 0

func build() -> void:
	_plan_roads()
	await _build_road_material()
	await _build_terrain()
	for road in roads:
		await _build_road(road)
		await get_tree().process_frame
	await _build_villages()
	await get_tree().process_frame
	_build_details()
	await _build_forests()
	await _build_race_markers()
	arrival.y = height_at(arrival.x, arrival.z)
	portal_position.y = height_at(portal_position.x, portal_position.z)

func base_height(x: float, z: float) -> float:
	var radius := Vector2(x, z).length()
	var angle := atan2(z, x)
	var coast := radius / (1.0 + 0.035 * sin(angle * 3) + 0.025 * cos(angle * 5))
	var beach := 5.0 - maxf(0, coast - 265) * 0.3
	var hills := 14.0 + 8.0 * sin(x * 0.026 + z * 0.012) * cos(z * 0.021)
	hills += 5.0 * sin(x * 0.048 - z * 0.025) + 2.5 * sin(z * 0.082 + x * 0.034)
	hills *= smoothstep(35, 100, radius)
	var cone := maxf(0, 1.0 - radius / 155.0) * 112.0
	if radius < 26:
		cone = lerpf(52.0, 93.2, smoothstep(8, 26, radius))
	return beach + hills * (1.0 - smoothstep(235, 295, coast)) + cone

func _plan_roads() -> void:
	var entrance := PackedVector3Array([Vector3(0, 0, 270), Vector3(0, 0, 245), Vector3(0, 0, 220), Vector3(0, 0, 195)])
	_add_road(entrance, 11.0, false)
	for i in range(281):
		var t := float(i) / 280
		var angle := PI / 2 + t * TAU * 1.35
		var radius := lerpf(220, 33, t)
		main_route.append(Vector3(cos(angle) * radius, 0, sin(angle) * radius))
	_add_road(main_route, 11.0, false)
	# Boucle de course irrégulière : trois secteurs sinueux, compressions et crêtes.
	for i in range(721):
		var angle := PI / 2 + float(i) / 720 * TAU
		var radius := 175.0 + 45.0 * sin(3 * angle + PI / 2) + 20.0 * sin(5 * angle)
		race_route.append(Vector3(cos(angle) * radius, 0, sin(angle) * radius))
	_add_road(race_route, 12.5, false)
	for index in [80, 430]:
		var start := race_route[index]
		var outward := Vector3(start.x, 0, start.z).normalized()
		var village := start + outward * 55
		villages.append(village)
		var path := PackedVector3Array()
		for i in range(41):
			path.append(start.lerp(village + outward * 45, float(i) / 40))
		_add_road(path, 6.0, true)
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
	var cells := int(RADIUS * 2 / GRID_STEP)
	var heights := PackedFloat32Array()
	heights.resize((cells + 1) * (cells + 1))
	for x in range(cells + 1):
		for z in range(cells + 1):
			heights[x * (cells + 1) + z] = height_at(-RADIUS + x * GRID_STEP, -RADIUS + z * GRID_STEP)
		if x % 8 == 0:
			await get_tree().process_frame
	terrain_heights = heights
	# Petites tuiles : pas de gros envoi de maillage/collision en une seule image.
	const TILE_CELLS := 31
	for tx in range(0, cells, TILE_CELLS):
		for tz in range(0, cells, TILE_CELLS):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for x in range(tx, mini(tx + TILE_CELLS, cells)):
				for z in range(tz, mini(tz + TILE_CELLS, cells)):
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
			surface.index()
			surface.generate_normals()
			var terrain := MeshInstance3D.new()
			terrain.name = "Terrain_%d_%d" % [tx, tz]
			terrain.mesh = surface.commit()
			terrain.material_override = road_material
			add_child(terrain)
			terrain.create_trimesh_collision()
			await get_tree().process_frame
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

# La route est une couleur du terrain, jamais un second maillage superposé.
# Les bandes restent de petits détails ; elles ne forment pas la chaussée.
func _build_road(road: Dictionary) -> void:
	var points: PackedVector3Array = road.points
	if not road.dirt:
		for i in range(0, points.size() - 1, 4):
			var point := points[i].lerp(points[i + 1], 0.5)
			point.y = ground_height(point.x, point.z) + 0.07
			_add_marking(Vector3(0.18, 0.03, 1.6), point, Color("f1dfaa"), atan2(points[i + 1].x - points[i].x, points[i + 1].z - points[i].z))
			if i % 128 == 0:
				await get_tree().process_frame

func _build_road_material() -> void:
	road_mask = Image.create(ROAD_MASK_SIZE, ROAD_MASK_SIZE, false, Image.FORMAT_RG8)
	var pixel_size := 2.0 * RADIUS / ROAD_MASK_SIZE
	for road in roads:
		var points: PackedVector3Array = road.points
		var half_width: float = road.width / 2
		for i in range(points.size() - 1):
			var a := Vector2(points[i].x, points[i].z)
			var b := Vector2(points[i + 1].x, points[i + 1].z)
			var ab := b - a
			var margin := half_width + pixel_size
			var min_x := maxi(0, int(floor((minf(a.x, b.x) - margin + RADIUS) / pixel_size)))
			var max_x := mini(ROAD_MASK_SIZE - 1, int(ceil((maxf(a.x, b.x) + margin + RADIUS) / pixel_size)))
			var min_z := maxi(0, int(floor((minf(a.y, b.y) - margin + RADIUS) / pixel_size)))
			var max_z := mini(ROAD_MASK_SIZE - 1, int(ceil((maxf(a.y, b.y) + margin + RADIUS) / pixel_size)))
			for px in range(min_x, max_x + 1):
				for pz in range(min_z, max_z + 1):
					var point := Vector2((px + 0.5) * pixel_size - RADIUS, (pz + 0.5) * pixel_size - RADIUS)
					var t := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0, 1)
					var distance := point.distance_to(a + ab * t)
					var coverage := 1.0 - smoothstep(half_width - pixel_size * 0.5, half_width + pixel_size * 0.5, distance)
					if coverage <= 0:
						continue
					var pixel := road_mask.get_pixel(px, pz)
					if road.dirt:
						pixel.g = maxf(pixel.g, coverage)
					else:
						pixel.r = maxf(pixel.r, coverage)
					road_mask.set_pixel(px, pz, pixel)
			if i % 16 == 0:
				await get_tree().process_frame
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D road_mask : filter_linear, repeat_disable;
uniform float terrain_span = 620.0;
varying vec2 road_uv;
void vertex() {
    road_uv = (VERTEX.xz + vec2(terrain_span * 0.5)) / terrain_span;
}
void fragment() {
    vec2 coverage = texture(road_mask, road_uv).rg;
    vec3 dirt = vec3(0.4564, 0.3278, 0.1683);
    vec3 asphalt = vec3(0.0595, 0.0666, 0.0823);
    ALBEDO = mix(mix(COLOR.rgb, dirt, coverage.g), asphalt, coverage.r);
    ROUGHNESS = 0.95;
}
"""
	road_material = ShaderMaterial.new()
	road_material.shader = shader
	road_material.set_shader_parameter("road_mask", ImageTexture.create_from_image(road_mask))
	road_material.set_shader_parameter("terrain_span", RADIUS * 2)

func _build_villages() -> void:
	for v in villages.size():
		var center := villages[v]
		var radial := Vector3(center.x, 0, center.z).normalized()
		var side := Vector3(radial.z, 0, -radial.x)
		for i in range(24):
			var offsets := [-28.0, -14.0, 14.0, 28.0]
			var point: Vector3 = center + side * offsets[i % 4] + radial * (int(i / 4) - 2) * 13
			if _near_road(point, 13):
				continue
			house_positions.append(point)
			point.y = height_at(point.x, point.z)
			var foundation_height := 4.0
			_box(Vector3(9, foundation_height, 8), point + Vector3(0, 0.5, 0), Color("817b70"))
			_box(Vector3(8, 4.5, 7), point + Vector3(0, 3.6, 0), Color("ecd1a2") if v == 0 else Color("d8aa8e"))
			var roof := MeshInstance3D.new()
			var pyramid := CylinderMesh.new()
			pyramid.top_radius = 0
			pyramid.bottom_radius = 6.4
			pyramid.height = 3
			pyramid.radial_segments = 4
			roof.visibility_range_end = 220
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
			if i % 4 == 0:
				await get_tree().process_frame
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
	_sign(Vector3(13, 0, 237), "CIRCUIT SAUVAGE ↑\nBoucle : forêt et villages\nMontée du cratère : embranchement")
	_sign(main_route[-1] + Vector3(0, 0, 9), "BELVÉDÈRE DU CRATÈRE")

func _near_road(point: Vector3, margin: float) -> bool:
	var key := Vector2i(int(floor(point.x / BUCKET_SIZE)), int(floor(point.z / BUCKET_SIZE)))
	for segment: Dictionary in road_buckets.get(key, []):
		var a: Vector3 = segment.a
		var b: Vector3 = segment.b
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var t := clampf(Vector2(point.x - a.x, point.z - a.z).dot(ab) / maxf(ab.length_squared(), 0.001), 0, 1)
		var nearest := a.lerp(b, t)
		if Vector2(point.x - nearest.x, point.z - nearest.z).length() < maxf(margin, float(segment.width) / 2 + 3):
			return true
	return false

# Même interpolation triangulaire que le terrain physique, plutôt qu'une hauteur
# analytique approximative : la chaussée reste au contact des bosses et des creux.
func ground_height(x: float, z: float) -> float:
	var cells := int(RADIUS * 2 / GRID_STEP)
	var gx := clampf((x + RADIUS) / GRID_STEP, 0, cells - 0.001)
	var gz := clampf((z + RADIUS) / GRID_STEP, 0, cells - 0.001)
	var ix := int(floor(gx))
	var iz := int(floor(gz))
	var fx := gx - ix
	var fz := gz - iz
	var a := terrain_heights[ix * (cells + 1) + iz]
	var b := terrain_heights[(ix + 1) * (cells + 1) + iz]
	var c := terrain_heights[ix * (cells + 1) + iz + 1]
	var d := terrain_heights[(ix + 1) * (cells + 1) + iz + 1]
	return a + (b - a) * fx + (c - a) * fz if fx + fz <= 1 else d + (c - d) * (1 - fx) + (b - d) * (1 - fz)

func _build_forests() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 84021
	var groups: Dictionary = {}
	for index in [170, 340, 620]:
		var center := race_route[index]
		for x in range(-11, 12):
			for z in range(-11, 12):
				var point := center + Vector3(x * 7 + rng.randf_range(-2, 2), 0, z * 7 + rng.randf_range(-2, 2))
				if Vector2(point.x, point.z).length() > 270 or _near_road(point, 11):
					continue
				var near_house := false
				for house in house_positions:
					if Vector2(point.x - house.x, point.z - house.z).length() < 13:
						near_house = true
						break
				if near_house:
					continue
				point.y = ground_height(point.x, point.z)
				var key := Vector2i(int(floor(point.x / 48)), int(floor(point.z / 48)))
				if not groups.has(key):
					groups[key] = []
				groups[key].append(point)
				tree_count += 1
			await get_tree().process_frame
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.3
	trunk_mesh.bottom_radius = 0.55
	trunk_mesh.height = 7
	trunk_mesh.radial_segments = 5
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color("72583e")
	trunk_mesh.material = bark
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.3
	crown_mesh.bottom_radius = 3.8
	crown_mesh.height = 7
	crown_mesh.radial_segments = 6
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color("315e43")
	crown_mesh.material = leaf
	var tree_shape := CylinderShape3D.new()
	tree_shape.radius = 0.55
	tree_shape.height = 7
	for key: Vector2i in groups:
		var points: Array = groups[key]
		var cluster := Node3D.new()
		cluster.position = Vector3(key.x * 48, 0, key.y * 48)
		add_child(cluster)
		var body := StaticBody3D.new()
		cluster.add_child(body)
		for layer in 2:
			var instances := MultiMesh.new()
			instances.transform_format = MultiMesh.TRANSFORM_3D
			instances.mesh = trunk_mesh if layer == 0 else crown_mesh
			instances.instance_count = points.size()
			for i in points.size():
				var at: Vector3 = points[i] - cluster.position + Vector3(0, 3.5 if layer == 0 else 8.5, 0)
				instances.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
			var mesh := MultiMeshInstance3D.new()
			mesh.multimesh = instances
			mesh.visibility_range_end = 240
			mesh.visibility_range_end_margin = 25
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cluster.add_child(mesh)
		for point: Vector3 in points:
			var collider := CollisionShape3D.new()
			collider.shape = tree_shape
			collider.position = point - cluster.position + Vector3(0, 3.5, 0)
			body.add_child(collider)
		await get_tree().process_frame

func _build_race_markers() -> void:
	for i in range(0, race_route.size() - 1, 12):
		var point := race_route[i]
		var forward := (race_route[i + 1] - point).normalized()
		var side := Vector3(forward.z, 0, -forward.x)
		for sign_value in [-1, 1]:
			var marker: Vector3 = point + side * sign_value * 7
			marker.y = ground_height(marker.x, marker.z)
			_add_marking(Vector3(0.5, 1, 0.5), marker + Vector3(0, 0.5, 0), Color("e7d8b7") if i % 24 == 0 else Color("b6553d"))
		if i % 48 == 0:
			await get_tree().process_frame
	var start := race_route[0]
	var forward := (race_route[1] - start).normalized()
	forward.y = 0
	forward = forward.normalized()
	var side := Vector3(forward.z, 0, -forward.x)
	for row in 2:
		for i in 12:
			var point := start + side * (i - 5.5) + forward * (row - 0.5)
			point.y = ground_height(point.x, point.z) + 0.08
			_add_marking(Vector3(0.95, 0.04, 0.95), point, Color.WHITE if (i + row) % 2 == 0 else Color("262d35"), atan2(forward.x, forward.z))
	_sign(start + Vector3(15, 0, -8), "CIRCUIT SAUVAGE\nDépart / Arrivée ←")
	_flush_markings()

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
	mesh.visibility_range_end = 220
	mesh.position = point
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	add_child(mesh)
	if solid:
		mesh.create_convex_collision()
	return mesh

# Les petites balises et bandes sont regroupées pour éviter des centaines de draws.
func _add_marking(size: Vector3, point: Vector3, color: Color, yaw := 0.0) -> void:
	var key := str(size) + str(color)
	if not marking_batches.has(key):
		marking_batches[key] = {"size": size, "color": color, "transforms": []}
	marking_batches[key].transforms.append(Transform3D(Basis(Vector3.UP, yaw), point))

func _flush_markings() -> void:
	for batch: Dictionary in marking_batches.values():
		var mesh := BoxMesh.new()
		mesh.size = batch.size
		var material := StandardMaterial3D.new()
		material.albedo_color = batch.color
		mesh.material = material
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = mesh
		instances.instance_count = batch.transforms.size()
		for i in batch.transforms.size():
			instances.set_instance_transform(i, batch.transforms[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = instances
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	marking_batches.clear()
