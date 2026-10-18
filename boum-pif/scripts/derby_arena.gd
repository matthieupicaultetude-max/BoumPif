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
var floor_material: StandardMaterial3D

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
	floor_material = StandardMaterial3D.new()
	floor_material.vertex_color_use_as_albedo = true
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
			surface.add_vertex(corners[index])
	surface.generate_normals()
	var ramp := MeshInstance3D.new()
	ramp.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("a7793f")
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ramp.material_override = material
	add_child(ramp)
	ramp.create_trimesh_collision()
	ramp_routes.append(route)
	_label(route[0] + Vector3(0, 2.5, 0), "RAMPE ↑", Color("f5cf75"), 24)

func _build_sector_obstacles(angle: float, color: Color) -> void:
	var basis := Basis(Vector3.UP, angle)
	# Conteneurs décalés : chicane, couvert et possibilité de contourner par les côtés.
	for i in 2:
		var point := basis * Vector3(-13 if i == 0 else 13, 0, 43)
		point.y = height_at(point.x, point.z)
		var container := _box(Vector3(7, 4.5, 12), point + Vector3(0, 2.25, 0), color)
		container.rotation.y = angle + (0.16 if i == 0 else -0.16)
		for stripe in 4:
			var detail := _box(Vector3(7.08, 0.13, 12.08), point + Vector3(0, 0.6 + stripe, 0), Color("434b4c"), false)
			detail.rotation.y = container.rotation.y
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
