extends Node3D

# Habillage et suspension à quatre points du contrôleur arcade CharacterBody3D.
const WHEEL_RADIUS := 0.43
const WHEEL_TRAVEL := 0.28
const MOUNTS := [Vector3(-1.01, -0.18, -1.3), Vector3(1.01, -0.18, -1.3), Vector3(-1.01, -0.18, 1.25), Vector3(1.01, -0.18, 1.25)]
var shell: Node3D
var wheel_pivots: Array[Node3D] = []
var wheel_spinners: Array[Node3D] = []
var contacts: Array[Dictionary] = []
var ground_normal := Vector3.UP
var contact_count := 0
var spring_offsets := PackedFloat32Array([0, 0, 0, 0])
var spring_velocities := PackedFloat32Array([0, 0, 0, 0])
var body_heave := 0.0
var body_heave_velocity := 0.0
var previous_velocity := Vector3.ZERO
var wheel_spin := 0.0
var paint := _material(Color("e9a62f"), 0.3, 0.3)
var trim := _material(Color("252c34"), 0.08, 0.55)
var rubber := _material(Color("171d22"), 0.0, 0.9)
var glass := _material(Color("25495e"), 0.45, 0.15)
var metal := _material(Color("aab4bc"), 0.75, 0.25)
var white := _material(Color("fff0b5"), 0.0, 0.25)
var red := _material(Color("d63126"), 0.05, 0.3)

func _ready() -> void:
	name = "RallyCarVisual"
	shell = Node3D.new()
	add_child(shell)
	# Profil biseauté, capot, habitacle incliné et toit contrasté.
	_prism(shell, PackedVector2Array([Vector2(-2.04, -0.2), Vector2(-2.04, 0.16), Vector2(-1.55, 0.37), Vector2(1.45, 0.37), Vector2(1.98, 0.18), Vector2(1.98, -0.2)]), 0.91, paint)
	_prism(shell, PackedVector2Array([Vector2(-1.05, 0.38), Vector2(-0.48, 1.0), Vector2(0.7, 1.0), Vector2(1.22, 0.38)]), 0.73, glass)
	_box(shell, Vector3(1.52, 0.1, 1.27), Vector3(0, 1.02, 0.11), trim)
	_box(shell, Vector3(0.14, 0.025, 1.0), Vector3(-0.25, 0.39, -1.4), trim)
	_box(shell, Vector3(0.14, 0.025, 1.0), Vector3(0.25, 0.39, -1.4), trim)
	_box(shell, Vector3(1.85, 0.2, 0.14), Vector3(0, -0.16, -2.06), trim)
	_box(shell, Vector3(1.85, 0.2, 0.14), Vector3(0, -0.16, 2.01), trim)
	_box(shell, Vector3(0.8, 0.19, 0.05), Vector3(0, 0.08, -2.08), trim)
	for i in range(5):
		_box(shell, Vector3(0.55, 0.015, 0.015), Vector3(0, 0.02 + i * 0.03, -2.115), metal)
	for side in [-1.0, 1.0]:
		_box(shell, Vector3(0.4, 0.19, 0.08), Vector3(side * 0.66, 0.14, -2.04), white)
		_box(shell, Vector3(0.4, 0.17, 0.08), Vector3(side * 0.66, 0.16, 1.98), red)
		_box(shell, Vector3(0.08, 0.08, 0.11), Vector3(side * 0.88, 0.1, -1.92), red)
		_rod(shell, Vector3(side * 0.74, 0.4, -1.05), Vector3(side * 0.74, 1.0, -0.48), 0.065, paint)
		_rod(shell, Vector3(side * 0.74, 0.4, 1.21), Vector3(side * 0.74, 1.0, 0.7), 0.075, paint)
		_box(shell, Vector3(0.07, 0.6, 0.075), Vector3(side * 0.74, 0.7, 0.16), trim)
		_box(shell, Vector3(0.025, 0.38, 1.45), Vector3(side * 0.92, 0.05, 0.08), trim)
		_box(shell, Vector3(0.03, 0.33, 1.39), Vector3(side * 0.935, 0.05, 0.08), paint)
		_box(shell, Vector3(0.05, 0.055, 0.22), Vector3(side * 0.96, 0.23, 0.55), metal)
		_box(shell, Vector3(0.25, 0.16, 0.28), Vector3(side * 0.95, 0.61, -0.63), trim)
		_box(shell, Vector3(0.035, 0.12, 0.22), Vector3(side * 1.085, 0.61, -0.63), metal)
		_box(shell, Vector3(0.1, 0.29, 0.1), Vector3(side * 0.65, 0.47, 1.7), trim)
	_box(shell, Vector3(1.9, 0.09, 0.32), Vector3(0, 0.63, 1.75), trim)
	_box(shell, Vector3(0.52, 0.17, 0.04), Vector3(0, -0.02, 2.1), white)
	_box(shell, Vector3(0.45, 0.13, 0.01), Vector3(0, -0.02, 2.125), trim)
	for side in [-1.0, 1.0]:
		_cylinder(shell, 0.09, 0.25, Vector3(side * 0.55, -0.24, 2.05), metal, Vector3(PI / 2, 0, 0))
	for i in MOUNTS.size():
		_build_wheel(i)

func _build_wheel(index: int) -> void:
	var mount: Vector3 = MOUNTS[index]
	var side := signf(mount.x)
	var pivot := Node3D.new()
	pivot.position = mount
	add_child(pivot)
	wheel_pivots.append(pivot)
	var spinner := Node3D.new()
	pivot.add_child(spinner)
	wheel_spinners.append(spinner)
	_cylinder(spinner, WHEEL_RADIUS, 0.34, Vector3.ZERO, rubber)
	_cylinder(spinner, 0.29, 0.36, Vector3.ZERO, trim)
	_cylinder(spinner, 0.095, 0.39, Vector3.ZERO, metal)
	var spokes: Array[Transform3D] = []
	for spoke in range(5):
		spokes.append(Transform3D(Basis(Vector3.RIGHT, spoke * TAU / 5), Vector3(side * 0.19, 0, 0)))
	_box_instances(spinner, Vector3(0.035, 0.055, 0.48), metal, spokes)
	var treads: Array[Transform3D] = []
	for tread in range(20):
		var angle := tread * TAU / 20
		treads.append(Transform3D(Basis(Vector3.RIGHT, -angle), Vector3(0, sin(angle) * WHEEL_RADIUS, cos(angle) * WHEEL_RADIUS)))
	_box_instances(spinner, Vector3(0.28, 0.035, 0.055), trim, treads)
	# Les garde-boue restent sur la caisse ; les roues bougent indépendamment.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in 16:
		var corners: Array[Vector3] = []
		for uv: Vector2 in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)]:
			var angle := (step + uv.x) / 16 * PI
			var radius := 0.53 + uv.y * 0.12
			corners.append(Vector3(side * 0.98, mount.y + sin(angle) * radius, mount.z + cos(angle) * radius))
		for vertex in [0, 1, 2, 1, 3, 2]:
			surface.add_vertex(corners[vertex])
	surface.generate_normals()
	var arch := MeshInstance3D.new()
	arch.mesh = surface.commit()
	var arch_material := trim.duplicate() as StandardMaterial3D
	arch_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	arch.material_override = arch_material
	shell.add_child(arch)

func sample_ground() -> void:
	var body := get_parent() as CharacterBody3D
	contacts.clear()
	contact_count = 0
	var normal_sum := Vector3.ZERO
	for mount: Vector3 in MOUNTS:
		var start := body.to_global(Vector3(mount.x, 0.75, mount.z))
		var end := body.to_global(Vector3(mount.x, -2.2, mount.z))
		var query := PhysicsRayQueryParameters3D.create(start, end)
		query.exclude = [body.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.normal.y < 0.55:
			hit = {}
		contacts.append(hit)
		if not hit.is_empty():
			contact_count += 1
			normal_sum += hit.normal
	if contact_count > 0:
		ground_normal = normal_sum.normalized()

func update_motion(delta: float, steering: float, drifting: bool) -> void:
	var body := get_parent() as CharacterBody3D
	sample_ground()
	var grounded := body.is_on_floor()
	var local_normal := body.global_basis.inverse() * ground_normal
	var pitch := atan2(local_normal.z, local_normal.y)
	var roll := atan2(-local_normal.x, local_normal.y)
	if contact_count > 0 and grounded:
		rotation.x = lerp_angle(rotation.x, clampf(pitch, -0.65, 0.65), 1 - exp(-12 * delta))
		rotation.z = lerp_angle(rotation.z, clampf(roll, -0.5, 0.5), 1 - exp(-12 * delta))
	# Le collider arcade reste stable ; compenser sa garde au sol sur une pente
	# pour que les pneus et la caisse visuelle ne flottent pas au-dessus du sol.
	var target_ride := 0.0
	if grounded and contact_count > 0:
		var ground_at_center := 0.0
		for contact: Dictionary in contacts:
			if not contact.is_empty():
				var point: Vector3 = contact.position
				var normal: Vector3 = contact.normal
				ground_at_center += point.y - (normal.x * (body.global_position.x - point.x) + normal.z * (body.global_position.z - point.z)) / maxf(normal.y, 0.55)
		target_ride = clampf(ground_at_center / contact_count + 0.61 - body.global_position.y, -0.9, 0.3)
	position.y = lerpf(position.y, target_ride, 1 - exp(-14 * delta))
	var local_velocity := body.global_basis.inverse() * body.velocity
	var acceleration := (local_velocity - previous_velocity) / maxf(delta, 0.001)
	previous_velocity = local_velocity
	var squat := clampf(-acceleration.z * 0.003, -0.09, 0.09) if grounded else 0.0
	var lateral_lean := clampf(-acceleration.x * 0.002, -0.09, 0.09) if grounded else 0.0
	if drifting:
		lateral_lean += steering * 0.045
	shell.rotation.x = lerpf(shell.rotation.x, squat, 1 - exp(-8 * delta))
	shell.rotation.z = lerpf(shell.rotation.z, lateral_lean, 1 - exp(-8 * delta))
	wheel_spin = wrapf(wheel_spin - local_velocity.z / WHEEL_RADIUS * delta, -PI, PI)
	var compression_sum := 0.0
	for i in wheel_pivots.size():
		var target := -WHEEL_TRAVEL
		if not contacts[i].is_empty():
			var local_point: Vector3 = to_local(contacts[i].position)
			target = clampf(local_point.y + WHEEL_RADIUS - MOUNTS[i].y, -WHEEL_TRAVEL, WHEEL_TRAVEL)
		# Ressort amorti, intégré en petits pas pour rester stable si l'image ralentit.
		var remaining := minf(delta, 0.1)
		while remaining > 0:
			var step := minf(remaining, 1.0 / 120)
			spring_velocities[i] += ((target - spring_offsets[i]) * 100 - spring_velocities[i] * 16) * step
			spring_offsets[i] = clampf(spring_offsets[i] + spring_velocities[i] * step, -WHEEL_TRAVEL, WHEEL_TRAVEL)
			remaining -= step
		wheel_pivots[i].position.y = MOUNTS[i].y + spring_offsets[i]
		wheel_pivots[i].rotation.y = lerpf(wheel_pivots[i].rotation.y, -steering * 0.48 if i < 2 else 0.0, 1 - exp(-12 * delta))
		wheel_spinners[i].rotation.x = wheel_spin
		compression_sum += spring_offsets[i]
	var target_heave := clampf(compression_sum / 4 * 0.35, -0.09, 0.09)
	body_heave_velocity += ((target_heave - body_heave) * 70 - body_heave_velocity * 12) * minf(delta, 0.033)
	body_heave += body_heave_velocity * minf(delta, 0.033)
	shell.position.y = body_heave

func reset_motion() -> void:
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	shell.rotation = Vector3.ZERO
	shell.position = Vector3.ZERO
	previous_velocity = Vector3.ZERO
	ground_normal = Vector3.UP
	body_heave = 0
	body_heave_velocity = 0
	wheel_spin = 0
	for i in wheel_pivots.size():
		spring_offsets[i] = 0
		spring_velocities[i] = 0
		wheel_pivots[i].position = MOUNTS[i]
		wheel_pivots[i].rotation = Vector3.ZERO
		wheel_spinners[i].rotation = Vector3.ZERO

func _material(color: Color, metallic := 0.0, roughness := 0.5) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _box(parent: Node3D, size: Vector3, point: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = point
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

func _cylinder(parent: Node3D, radius: float, width: float, point: Vector3, material: Material, rotation_value := Vector3(0, 0, PI / 2)) -> void:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = width
	cylinder.radial_segments = 24
	mesh.mesh = cylinder
	mesh.position = point
	mesh.rotation = rotation_value
	mesh.material_override = material
	parent.add_child(mesh)

func _rod(parent: Node3D, a: Vector3, b: Vector3, width: float, material: Material) -> void:
	var mesh := _box(parent, Vector3(width, a.distance_to(b), width), (a + b) / 2, material)
	var up := (b - a).normalized()
	var right := Vector3.FORWARD.cross(up).normalized()
	mesh.basis = Basis(right, up, right.cross(up)).orthonormalized()

func _prism(parent: Node3D, profile: PackedVector2Array, half_width: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size():
		var j := (i + 1) % profile.size()
		var corners := [Vector3(-half_width, profile[i].y, profile[i].x), Vector3(half_width, profile[i].y, profile[i].x), Vector3(-half_width, profile[j].y, profile[j].x), Vector3(half_width, profile[j].y, profile[j].x)]
		for index in [0, 1, 2, 1, 3, 2]:
			surface.add_vertex(corners[index])
	for side in [-1.0, 1.0]:
		for i in range(1, profile.size() - 1):
			var indices := [0, i, i + 1] if side < 0 else [0, i + 1, i]
			for index in indices:
				surface.add_vertex(Vector3(side * half_width, profile[index].y, profile[index].x))
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var two_sided := material.duplicate() as StandardMaterial3D
	two_sided.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = two_sided
	parent.add_child(mesh)

func _box_instances(parent: Node3D, size: Vector3, material: Material, transforms: Array[Transform3D]) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for i in transforms.size():
		instances.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = instances
	parent.add_child(node)
