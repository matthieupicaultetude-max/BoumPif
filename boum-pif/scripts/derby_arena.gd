extends Node3D

# La Fonderie : quatre axes de charge, cuvette centrale et zones de cascades.
const SIZE := 224.0
const STEP := 4.0
var arrival := Vector3(0, 0, 82)
var portal_position := Vector3(0, 0, 98)
var spawn_points: Array[Vector3] = []
var props: Array[RigidBody3D] = []
var prop_spawns: Array[Transform3D] = []
var ramp_routes: Array[PackedVector3Array] = []
var floor_material: ShaderMaterial
var detail_batches: Dictionary = {}
var detail_count := 0
var barrel_count := 0
var wreck_count := 0
var ramp_material: ShaderMaterial

func build() -> void:
	await _terrain()
	await _walls_and_stands()
	var colors := [Color("e4a33a"), Color("5fb3d3"), Color("cb6766"), Color("76b18d")]
	for index in 4:
		var angle := index * PI / 2
		var direction := Vector3(sin(angle), 0, cos(angle))
		var point := direction * 80
		point.y = height_at(point.x, point.z)
		spawn_points.append(point + Vector3(0, 0.85, 0))
		for side in [-1.0, 1.0]:
			var marker: Vector3 = point + Vector3(cos(angle), 0, -sin(angle)) * side * 6
			marker.y = height_at(marker.x, marker.z)
			_box(Vector3(0.5, 1.2, 0.5), marker + Vector3(0, 0.6, 0), colors[index], false)
		_label(point + Vector3(0, 2, 0), "DÉPART %d" % (index + 1), colors[index], 34)
		_build_ramp(angle + PI / 4)
		_build_sector_obstacles(angle + PI / 4, colors[index])
		await get_tree().process_frame
	await _new_set_dressing()
	await _flush_details()
	_label(Vector3(0, 13, -116), "LA FONDERIE\nDESTRUCTION DERBY · 4 PLACES", Color("f3d3a0"), 64)
	_label(Vector3(20, 6, 87), "↓ PORTAIL DE RETOUR\nCentre : choc frontal\nDiagonales : rampes et débris", Color("f3d3a0"), 32)
	arrival.y = height_at(arrival.x, arrival.z)
	portal_position.y = height_at(portal_position.x, portal_position.z)

func height_at(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var bowl := -3.5 * (1 - smoothstep(24, 79, r))
	var platform := 5.5 * (1 - smoothstep(10, 32, r))
	var bank := 4.0 * smoothstep(84, 108, r)
	var waves := sin(x * 0.1) * sin(z * 0.1) * 0.6 * smoothstep(32, 50, r) * (1 - smoothstep(70, 84, r))
	return bowl + platform + bank + waves

func _terrain() -> void:
	floor_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
varying vec2 ground;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { ground = VERTEX.xz; }
void fragment() {
    float grain = hash(floor(ground * 9.0));
    float grain_fade = 1.0-smoothstep(0.4,1.2,length(fwidth(ground*9.0)));
    grain = mix(0.5,grain,grain_fade);
    float patches = hash(floor(ground * 0.4));
    vec3 base = COLOR.rgb * (0.82 + grain * 0.16 + patches * 0.12);
    float radius = length(ground);
    float arc = smoothstep(-0.4, 0.1, sin(atan(ground.y, ground.x) * 3.0));
    float tracks = (1.0-smoothstep(0.13, 0.4, abs(abs(radius-46.0)-0.8))) * arc;
    tracks = max(tracks, (1.0-smoothstep(0.1,0.3,abs(abs(radius-67.0)-0.8)))*(1.0-arc));
    tracks = max(tracks, (1.0-smoothstep(0.12,0.35,abs(abs(radius-9.0)-0.75))));
    float oil = 1.0-smoothstep(1.5,4.0,length((ground-vec2(28.0,18.0))*vec2(0.8,1.4)));
    oil = max(oil,1.0-smoothstep(1.0,3.0,length(ground-vec2(-18.0,-30.0))));
    ALBEDO = mix(base, base*0.28, max(tracks*0.75,oil*0.85));
    ROUGHNESS = mix(0.98,0.5,oil);
}
"""
	floor_material.shader = shader
	var cells := int(SIZE / STEP)
	for tx in range(0, cells, 14):
		for tz in range(0, cells, 14):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for x in range(tx, mini(tx + 14, cells)):
				for z in range(tz, mini(tz + 14, cells)):
					var a := Vector3(x * STEP - SIZE / 2, 0, z * STEP - SIZE / 2)
					var corners := [a, a + Vector3(STEP, 0, 0), a + Vector3(0, 0, STEP), a + Vector3(STEP, 0, STEP)]
					for i in [0, 1, 2, 1, 3, 2]:
						var point: Vector3 = corners[i]
						point.y = height_at(point.x, point.z)
						var radius := Vector2(point.x, point.z).length()
						var color := Color("665951") if radius > 80 else Color("967953")
						if radius < 13:
							color = Color("a34f37")
						elif absf(point.x) < 6 or absf(point.z) < 6:
							color = Color("736c63")
						surface.set_color(color)
						surface.add_vertex(point)
			surface.index()
			surface.generate_normals()
			var terrain := MeshInstance3D.new()
			terrain.name = "DerbyFloor_%d_%d" % [tx, tz]
			terrain.mesh = surface.commit()
			terrain.material_override = floor_material
			add_child(terrain)
			terrain.create_trimesh_collision()
			await get_tree().process_frame

func _walls_and_stands() -> void:
	for i in range(48):
		var angle := i * TAU / 48
		var point := Vector3(sin(angle) * 108, 0, cos(angle) * 108)
		point.y = height_at(point.x, point.z)
		var wall := _box(Vector3(14.3, 5, 2), point + Vector3(0, 2.4, 0), Color("424b50"))
		wall.rotation.y = angle
		_barrier_details(wall, i)
		var warning := _box(Vector3(13.9, 0.45, 2.05), point + Vector3(0, 4.5, 0), Color("dca442"), false)
		warning.rotation.y = angle
		if i % 3 == 0:
			for step in 3:
				var stand_point := point.normalized() * (120 + step * 4)
				stand_point.y = 6 + step * 2
				var stand := _box(Vector3(19, 2, 4), stand_point, Color("77838a"), false)
				stand.rotation.y = angle
		if i % 6 == 0:
			await get_tree().process_frame
	# Tours de projecteurs, sans lumières dynamiques coûteuses.
	for x in [-88, 88]:
		for z in [-88, 88]:
			_box(Vector3(1.6, 22, 1.6), Vector3(x, 14, z), Color("343f47"), false)
			_box(Vector3(9, 2.2, 1), Vector3(x, 25, z), Color("eadfbe"), false)

func _build_ramp(angle: float) -> void:
	var basis := Basis(Vector3.UP, angle)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var route := PackedVector3Array()
	for i in range(17):
		var distance := 78.0 - i
		var middle := basis * Vector3(0, 0, distance)
		middle.y = height_at(middle.x, middle.z) + float(i) / 16 * 4.5
		route.append(middle)
		if i == 16:
			break
		var corners: Array[Vector3] = []
		for uv: Vector2 in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)]:
			var point := basis * Vector3((uv.y - 0.5) * 10, 0, distance - uv.x)
			point.y = height_at(point.x, point.z) + (i + uv.x) / 16 * 4.5 + 0.02
			corners.append(point)
		for index in [0, 2, 1, 1, 2, 3]:
			var vertex: Vector3 = corners[index]
			var local := basis.inverse() * vertex
			surface.set_uv(Vector2((local.x + 5) / 10, (78 - local.z) / 16))
			surface.add_vertex(vertex)
	surface.generate_normals()
	var ramp := MeshInstance3D.new()
	ramp.mesh = surface.commit()
	if ramp_material == null:
		ramp_material = ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = """shader_type spatial;
void fragment() {
    vec2 p = UV*vec2(10.0,16.0);
    float plate = step(0.91,abs(sin((p.x+p.y)*22.0)))*step(0.55,abs(sin((p.x-p.y)*22.0)));
    float seam = 1.0-smoothstep(0.015,0.04,abs(fract(p.y/2.0)-0.5));
    vec3 base = mix(vec3(0.16,0.19,0.21),vec3(0.28,0.18,0.11),step(0.7,fract(sin(dot(floor(p*2.0),vec2(12.9,78.2)))*43758.5)));
    base += plate*0.065*(1.0-smoothstep(0.4,1.2,length(fwidth(p*7.0))));
    base *= 1.0-seam*0.45;
    float edge = max(1.0-step(0.065,UV.x),step(0.935,UV.x));
    vec3 warning = mix(vec3(0.035),vec3(0.72,0.43,0.055),step(0.5,fract((p.y+p.x)*0.8)));
    ALBEDO = mix(base,warning,edge);
    METALLIC = 0.5;
    ROUGHNESS = 0.75;
}
"""
		ramp_material.shader = shader
	ramp.material_override = ramp_material
	add_child(ramp)
	ramp.create_trimesh_collision()
	ramp_routes.append(route)
	_ramp_details(basis, route)
	_label(route[0] + Vector3(0, 2.5, 0), "RAMPE ↑", Color("f5cf75"), 24)

func _build_sector_obstacles(angle: float, color: Color) -> void:
	var basis := Basis(Vector3.UP, angle)
	# Conteneurs décalés : chicane, couvert et possibilité de contourner par les côtés.
	for i in 2:
		var point := basis * Vector3(-13 if i == 0 else 13, 0, 43)
		point.y = height_at(point.x, point.z)
		var container := _box(Vector3(7, 4.5, 12), point + Vector3(0, 2.25, 0), color)
		container.rotation.y = angle + (0.16 if i == 0 else -0.16)
		_container_details(container, color, int(round(angle / (PI / 2))) * 2 + i + 1)
	for i in 4:
		var point := basis * Vector3((i - 1.5) * 2.2, 0, 54)
		point.y = height_at(point.x, point.z) + 0.65
		var prop := RigidBody3D.new()
		prop.mass = 22
		prop.position = point
		prop.linear_damp = 0.8
		prop.angular_damp = 1.2
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.5, 1.2, 1.5)
		collider.shape = shape
		prop.add_child(collider)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = shape.size
		mesh.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("a85e3c")
		mesh.material_override = material
		prop.add_child(mesh)
		add_child(prop)
		props.append(prop)
		prop_spawns.append(prop.transform)

func reset_props() -> void:
	for i in props.size():
		props[i].transform = prop_spawns[i]
		props[i].linear_velocity = Vector3.ZERO
		props[i].angular_velocity = Vector3.ZERO
		props[i].sleeping = false

func _box(size: Vector3, point: Vector3, color: Color, solid := true) -> Node3D:
	# Le corps porte le maillage : leur rotation reste identique pour les collisions.
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.position = point
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	root.add_child(mesh)
	if solid:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		root.add_child(collider)
	add_child(root)
	return root

func _label(point: Vector3, title: String, color: Color, font_size: int) -> void:
	var label := Label3D.new()
	label.text = title
	label.position = point
	label.modulate = color
	label.font_size = font_size
	label.pixel_size = 0.025
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

# Détails statiques regroupés en MultiMesh : les rivets ne coûtent pas un draw chacun.
func _detail(size: Vector3, point: Vector3, color: Color, basis := Basis.IDENTITY, cylinder := false) -> void:
	var key := str(size) + str(color) + str(cylinder)
	if not detail_batches.has(key):
		detail_batches[key] = {"size": size, "color": color, "cylinder": cylinder, "transforms": []}
	detail_batches[key].transforms.append(Transform3D(basis, point))
	detail_count += 1

func _part(parent: Node3D, size: Vector3, point: Vector3, color: Color, rotation := Vector3.ZERO) -> void:
	_detail(size, parent.transform * point, color, parent.basis * Basis.from_euler(rotation))

func _beam(a: Vector3, b: Vector3, width: float, color: Color) -> void:
	if a.distance_to(b) < 0.02:
		return
	_detail(Vector3(width, width, a.distance_to(b)), (a + b) / 2, color, Basis.looking_at((a - b).normalized(), Vector3.RIGHT if absf((a-b).normalized().y) > 0.95 else Vector3.UP))

func _ramp_details(basis: Basis, route: PackedVector3Array) -> void:
	var steel := Color("39434a")
	for side in [-1.0, 1.0]:
		for i in range(0, 16, 2):
			var a: Vector3 = route[i] + basis * Vector3(side * 4.85, -0.18, 0)
			var b: Vector3 = route[mini(i + 2, 16)] + basis * Vector3(side * 4.85, -0.18, 0)
			_beam(a, b, 0.22, steel)
			# Boulons et plaques de fixation le long des longerons.
			_detail(Vector3(0.16, 0.07, 0.16), a + Vector3(0, 0.24, 0), Color("b6bdba"), Basis.IDENTITY, true)
		for i in [4, 8, 12, 16]:
			var top: Vector3 = route[i] + basis * Vector3(side * 4.4, -0.3, 0)
			var foot := Vector3(top.x, height_at(top.x, top.z), top.z)
			_beam(foot, top, 0.24, steel)
			_detail(Vector3(0.9, 0.12, 0.9), foot, Color("756c60"))
			if i > 4:
				var other: Vector3 = route[i - 4] + basis * Vector3(side * 4.4, -0.3, 0)
				_beam(other, foot, 0.13, Color("8c5c3d"))
	for i in range(2, 17, 2):
		_beam(route[i] + basis * Vector3(-4.8, -0.22, 0), route[i] + basis * Vector3(4.8, -0.22, 0), 0.18, steel)

func _container_details(root: Node3D, color: Color, number: int) -> void:
	var dark := color.darkened(0.38)
	var metal := Color("9a9e99")
	for side in [-1.0, 1.0]:
		for rib in 18:
			_part(root, Vector3(0.14, 3.9, 0.14), Vector3(side * 3.55, 0, -5.55 + rib * 0.65), dark)
		for y in [-2.1, 2.1]:
			_part(root, Vector3(0.2, 0.22, 12.1), Vector3(side * 3.5, y, 0), dark)
		for z in [-5.85, 5.85]:
			_part(root, Vector3(0.3, 4.4, 0.3), Vector3(side * 3.4, 0, z), dark)
			for y in [-2.0, 2.0]:
				_part(root, Vector3(0.38, 0.3, 0.4), Vector3(side * 3.4, y, z), metal)
	for rib in 17:
		_part(root, Vector3(6.6, 0.1, 0.12), Vector3(0, 2.29, -5.5 + rib * 0.66), dark)
	for side in [-1.0, 1.0]:
		_part(root, Vector3(3.25, 4.0, 0.06), Vector3(side * 1.68, 0, 6.04), color.lightened(0.07))
		for bar in [-1.0, 1.0]:
			_part(root, Vector3(0.075, 3.65, 0.1), Vector3(side * 1.68 + bar * 0.85, 0, 6.11), metal)
			_part(root, Vector3(0.5, 0.09, 0.12), Vector3(side * 1.68 + bar * 0.85, -0.35, 6.19), Color("343b40"))
		for y in [-1.5, 0.0, 1.5]:
			_part(root, Vector3(0.33, 0.2, 0.15), Vector3(side * 3.13, y, 6.12), metal)
	_part(root, Vector3(0.07, 4.3, 0.09), Vector3(0, 0, 6.08), dark)
	for i in 3:
		_part(root, Vector3(0.7 + i * 0.25, 0.16, 0.025), Vector3(-1.9 + i * 0.2, -1.3 + i * 0.2, 6.09), Color("79543b"))
	var label := Label3D.new()
	label.text = "FD-%02d\nMAX 30 T" % number
	label.font_size = 40
	label.pixel_size = 0.014
	label.position = Vector3(1.6, 1.25, 6.13)
	root.add_child(label)

func _barrier_details(root: Node3D, index: int) -> void:
	var concrete := Color("7a7b73")
	_part(root, Vector3(14, 1.6, 0.12), Vector3(0, -1.3, -1.07), concrete)
	for x in [-6.4, -3.2, 0.0, 3.2, 6.4]:
		_part(root, Vector3(0.065, 4.6, 0.06), Vector3(x, 0, -1.1), Color("343b3e"))
		_part(root, Vector3(0.18, 0.18, 0.09), Vector3(x + 0.25, 0.5, -1.13), Color("b1ada1"))
	for x in [-5.5, -3.3, -1.1, 1.1, 3.3, 5.5]:
		_part(root, Vector3(0.65, 0.9, 0.06), Vector3(x, 1.7, -1.05), Color("272e33"), Vector3(0, 0, -0.5))
	# Barreaudage de sécurité léger au-dessus du mur, hors de la piste.
	for x in [-6.5, 0.0, 6.5]:
		_part(root, Vector3(0.1, 2.2, 0.1), Vector3(x, 3.5, 0.8), Color("969e9d"))
	for y in [2.9, 3.7, 4.5]:
		_part(root, Vector3(14, 0.06, 0.06), Vector3(0, y, 0.8), Color("969e9d"))
	if index % 3 == 0:
		var point := root.position - root.basis.z * 3.0
		point.y = height_at(point.x, point.z)
		_tire_stack(point)

func _tire_stack(point: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = point
	var collider := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.75
	cylinder.height = 1.6
	collider.shape = cylinder
	collider.position.y = 0.8
	body.add_child(collider)
	add_child(body)
	for i in 4:
		_detail(Vector3(1.5, 0.36, 1.5), point + Vector3(0, 0.2 + i * 0.38, 0), Color("20282c"), Basis.IDENTITY, true)
		_detail(Vector3(0.8, 0.025, 0.8), point + Vector3(0, 0.39 + i * 0.38, 0), Color("414b4b"), Basis.IDENTITY, true)

func _new_set_dressing() -> void:
	for index in 4:
		var angle := PI / 8 + index * PI / 2
		var basis := Basis(Vector3.UP, angle)
		var point := basis * Vector3(0, 0, 91)
		point.y = height_at(point.x, point.z)
		# Épaves compactées, placées à l'écart des axes de départ et des rampes.
		var wreck := _box(Vector3(3.7, 1.1, 6.8), point + Vector3(0, 0.6, 0), Color("6d5b4d"))
		wreck.rotation.y = angle - 0.2
		_part(wreck, Vector3(3.2, 0.75, 2.8), Vector3(0, 0.9, 0.6), Color("424c50"), Vector3(0.05, 0, 0.08))
		_part(wreck, Vector3(3.3, 0.13, 2.0), Vector3(0, 0.65, -2), Color("9b6544"), Vector3(0.1, 0, 0))
		for side in [-1.0, 1.0]:
			for z in [-2.1, 2.1]:
				_detail(Vector3(1.3, 0.45, 1.3), wreck.transform * Vector3(side * 1.8, -0.1, z), Color("22292d"), wreck.basis * Basis(Vector3.FORWARD, PI / 2), true)
		wreck_count += 1
		for i in 2:
			var barrel_point := point + basis * Vector3(5 + i * 1.8, 0, -1)
			barrel_point.y = height_at(barrel_point.x, barrel_point.z) + 0.9
			_add_barrel(barrel_point)
		# Petit poste de réparation et drapeaux sur le pourtour extérieur.
		var shed := basis * Vector3(0, 0, 124)
		shed.y = 3.5
		var workshop := _box(Vector3(9, 5, 5), shed + Vector3(0, 2.5, 0), Color("46565c"), false)
		workshop.rotation.y = angle
		_part(workshop, Vector3(9.8, 0.3, 6), Vector3(0, 2.8, 0), Color("82664a"))
		_part(workshop, Vector3(5.5, 3.4, 0.1), Vector3(0, -0.7, -2.55), Color("202b32"))
		_label(shed + Vector3(0, 7, 0), "ATELIER %d" % (index + 1), Color("ecd092"), 30)
		await get_tree().process_frame

func _add_barrel(point: Vector3) -> void:
	var body := RigidBody3D.new()
	body.position = point
	body.mass = 15
	body.linear_damp = 0.5
	body.angular_damp = 0.5
	var shape := CylinderShape3D.new()
	shape.radius = 0.6
	shape.height = 1.7
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.6
	cylinder.bottom_radius = 0.6
	cylinder.height = 1.7
	cylinder.radial_segments = 16
	var mesh := MeshInstance3D.new()
	mesh.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("a65732")
	material.roughness = 0.8
	mesh.material_override = material
	body.add_child(mesh)
	var band_material := StandardMaterial3D.new()
	band_material.albedo_color = Color("484e4b")
	band_material.metallic = 0.4
	for y in [-0.6, 0.6]:
		var band := MeshInstance3D.new()
		var ring := CylinderMesh.new()
		ring.top_radius = 0.63
		ring.bottom_radius = 0.63
		ring.height = 0.1
		ring.radial_segments = 16
		band.mesh = ring
		band.material_override = band_material
		band.position.y = y
		body.add_child(band)
	var cap := MeshInstance3D.new()
	var bung := CylinderMesh.new()
	bung.top_radius = 0.09
	bung.bottom_radius = 0.09
	bung.height = 0.035
	cap.mesh = bung
	cap.position = Vector3(0.25, 0.86, 0)
	cap.material_override = band_material
	body.add_child(cap)
	add_child(body)
	props.append(body)
	prop_spawns.append(body.transform)
	barrel_count += 1

func _flush_details() -> void:
	var batch_index := 0
	for batch: Dictionary in detail_batches.values():
		var mesh: PrimitiveMesh
		if batch.cylinder:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = batch.size.x / 2
			cylinder.bottom_radius = batch.size.x / 2
			cylinder.height = batch.size.y
			cylinder.radial_segments = 16
			mesh = cylinder
		else:
			var box := BoxMesh.new()
			box.size = batch.size
			mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = batch.color
		material.roughness = 0.7
		mesh.material = material
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = mesh
		instances.instance_count = batch.transforms.size()
		for i in batch.transforms.size():
			instances.set_instance_transform(i, batch.transforms[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = instances
		add_child(node)
		batch_index += 1
		if batch_index % 8 == 0:
			await get_tree().process_frame
	detail_batches.clear()
