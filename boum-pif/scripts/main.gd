extends Node3D

const RallyCar = preload("res://scripts/rally_car.gd")
const IslandZone = preload("res://scripts/island.gd")
const ISLAND_OFFSET := Vector3(1200, 0, 0)
const CITY_PORTAL := Vector3(0, 0, -54)
var island: IslandZone
var city_zone: Node3D
var loading_zone := false
var on_island := false
var portal_cooldown := 0.0
var car_spawn := Vector3(4, 0.8, 4)
var spawn_yaw := 0.0

const WALK_SPEED := 6.0
const CAR_SPEED := 24.0
const CAR_ACCELERATION := 22.0
const CAR_GRIP := 12.0
const DRIFT_GRIP := 1.5
const DRIFT_MIN_SPEED := 8.0
const MINI_TURBO_CHARGE := 0.8
const SUPER_TURBO_CHARGE := 1.8
const BOOST_SPEED := 33.0
var drifting := false
var drift_direction := 0.0
var drift_charge := 0.0
var boost_time := 0.0
var handbrake_was_pressed := false
var car_visual: RallyCar
var sparks: Array[CPUParticles3D] = []
var tire_smoke: Array[CPUParticles3D] = []
var boost_sparks: Array[CPUParticles3D] = []
var player: CharacterBody3D
var car: CharacterBody3D
var camera: Camera3D
var hud: Label
var driving := false
var yaw := 0.0
var pitch := -0.2
var car_speed := 0.0
var spawn := Vector3(5, 1.2, 10)

func _ready() -> void:
	_setup_inputs()
	RenderingServer.set_default_clear_color(Color("91bcd2"))
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("91bcd2")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	city_zone = Node3D.new()
	city_zone.name = "CityZone"
	add_child(city_zone)
	_build_city()
	_build_portal(city_zone, CITY_PORTAL, "ÎLE DU VOLCAN", Color("66e4ef"))
	player = CharacterBody3D.new()
	player.name = "Player"
	player.floor_snap_length = 0.5
	add_child(player)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	player.add_child(collider)
	player.position = spawn
	_build_car()
	camera = Camera3D.new()
	camera.far = 180
	add_child(camera)
	camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 20)
	hud.add_theme_font_size_override("font_size", 20)
	hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(hud)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_inputs() -> void:
	var bindings := {
		"forward": [KEY_Z, KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN],
		"left": [KEY_Q, KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "interact": [KEY_E], "reset": [KEY_R]
	}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)

func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, solid := true) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var geometry := BoxShape3D.new()
		geometry.size = size
		shape.shape = geometry
		body.position = at
		body.add_child(shape)
		parent.add_child(body)

func _build_city() -> void:
	_box(city_zone, Vector3(140, 1, 140), Vector3(0, -0.5, 0), Color("739c67"))
	_box(city_zone, Vector3(16, 0.04, 130), Vector3(0, 0.02, 0), Color("374452"), false)
	_box(city_zone, Vector3(130, 0.04, 16), Vector3(0, 0.025, 0), Color("374452"), false)
	for i in range(-12, 13):
		if absi(i) > 1:
			_box(city_zone, Vector3(0.15, 0.02, 2), Vector3(0, 0.05, i * 5), Color("f0dd9a"), false)
			_box(city_zone, Vector3(2, 0.02, 0.15), Vector3(i * 5, 0.05, 0), Color("f0dd9a"), false)
	var colors := [Color("dcad82"), Color("8ca9bd"), Color("c28070"), Color("c5bd9c")]
	for x in [-1, 1]:
		for z in [-1, 1]:
			_box(city_zone, Vector3(45, 0.18, 45), Vector3(x * 32.5, 0.09, z * 32.5), Color("b5b6b3"))
			for row in range(3):
				for col in range(3):
					var height := float(5 + ((row * 3 + col * 5) % 4) * 3)
					var center := Vector3(x * (17 + row * 15), height / 2 + 0.18, z * (17 + col * 15))
					_box(city_zone, Vector3(10, height, 10), center, colors[(row + col) % 4])
					for floor_index in range(int(height / 3)):
						for window_x in [-2.5, 2.5]:
							_box(city_zone, Vector3(1.5, 1.4, 0.05), Vector3(center.x + window_x, 2 + floor_index * 3, center.z - 5.03), Color("425d70"), false)
	for axis in [0, 1]:
		for sign_value in [-1, 1]:
			var size := Vector3(1, 4, 140) if axis == 0 else Vector3(140, 4, 1)
			var at := Vector3(sign_value * 70, 2, 0) if axis == 0 else Vector3(0, 2, sign_value * 70)
			_box(city_zone, size, at, Color("687c7c"))

func _build_car() -> void:
	car = CharacterBody3D.new()
	car.name = "Car"
	car.floor_snap_length = 1.0
	car.floor_max_angle = deg_to_rad(50)
	add_child(car)
	car.position = Vector3(4, 0.8, 4)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.2, 4.1)
	shape.shape = box
	car.add_child(shape)
	var cabin_collision := CollisionShape3D.new()
	var cabin_box := BoxShape3D.new()
	cabin_box.size = Vector3(1.5, 0.65, 1.6)
	cabin_collision.shape = cabin_box
	cabin_collision.position = Vector3(0, 0.65, 0.1)
	car.add_child(cabin_collision)
	car_visual = RallyCar.new()
	car.add_child(car_visual)

	for side in [-1.0, 1.0]:
		var effect := CPUParticles3D.new()
		effect.position = Vector3(side, -0.3, 1.3)
		effect.local_coords = false
		effect.amount = 24
		effect.lifetime = 0.25
		effect.direction = Vector3(side, 0.3, 1)
		effect.spread = 35
		effect.initial_velocity_min = 2
		effect.initial_velocity_max = 5
		effect.gravity = Vector3(0, -5, 0)
		var spark_mesh := SphereMesh.new()
		spark_mesh.radius = 0.06
		spark_mesh.height = 0.12
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		spark_mesh.material = material
		effect.mesh = spark_mesh
		effect.emitting = false
		car_visual.add_child(effect)
		sparks.append(effect)
		_add_tire_smoke(side)
		_add_boost_sparks(side)

func _add_tire_smoke(side: float) -> void:
	var smoke := CPUParticles3D.new()
	smoke.position = Vector3(side, -0.45, 1.2)
	smoke.local_coords = false
	smoke.amount = 28
	smoke.lifetime = 0.9
	smoke.direction = Vector3(0, 1, 0.3)
	smoke.spread = 45
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 1.3
	smoke.gravity = Vector3(0, 0.7, 0)
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 1.0
	var growth := Curve.new()
	growth.add_point(Vector2(0, 0.3))
	growth.add_point(Vector2(1, 1.0))
	smoke.scale_amount_curve = growth
	var fade := Gradient.new()
	fade.set_color(0, Color(0.75, 0.77, 0.8, 0.6))
	fade.set_color(1, Color(0.75, 0.77, 0.8, 0))
	smoke.color_ramp = fade
	# Disque doux procédural : aucun fichier de texture externe nécessaire.
	var radial := GradientTexture2D.new()
	radial.width = 64
	radial.height = 64
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.5)
	radial.fill_to = Vector2(1, 0.5)
	var opacity := Gradient.new()
	opacity.set_color(0, Color.WHITE)
	opacity.set_color(1, Color(1, 1, 1, 0))
	radial.gradient = opacity
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = radial
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var puff := QuadMesh.new()
	puff.size = Vector2(1.8, 1.8)
	puff.material = material
	smoke.mesh = puff
	smoke.emitting = false
	car.add_child(smoke)
	tire_smoke.append(smoke)

func _add_boost_sparks(side: float) -> void:
	var effect := CPUParticles3D.new()
	effect.position = Vector3(side * 0.65, -0.1, 1.95)
	effect.local_coords = false
	effect.amount = 40
	effect.lifetime = 0.35
	effect.direction = Vector3(0, 0.15, 1)
	effect.spread = 20
	effect.initial_velocity_min = 6
	effect.initial_velocity_max = 12
	effect.gravity = Vector3(0, -2, 0)
	var fade := Gradient.new()
	fade.set_color(0, Color("fff1a8"))
	fade.set_color(1, Color(1, 0.35, 0.05, 0))
	effect.color_ramp = fade
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.24)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	effect.mesh = mesh
	effect.emitting = false
	car.add_child(effect)
	boost_sparks.append(effect)

func _unhandled_input(event: InputEvent) -> void:
	if loading_zone:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.003
		pitch = clampf(pitch - event.relative.y * 0.003, -1.1, 0.7)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if loading_zone:
		return
	portal_cooldown = maxf(0, portal_cooldown - delta)
	if Input.is_action_just_pressed("reset"):
		_reset()
	if Input.is_action_just_pressed("interact"):
		_interact()
	car_visual.sample_ground()
	if driving:
		_drive_car(delta)
	else:
		car.velocity.x = move_toward(car.velocity.x, 0, 10 * delta)
		car.velocity.z = move_toward(car.velocity.z, 0, 10 * delta)
	car.velocity.y -= 20 * delta
	car.move_and_slide()
	car_visual.update_motion(delta, Input.get_axis("left", "right") if driving else 0.0, drifting)
	if driving and car.get_slide_collision_count() > 0:
		for index in car.get_slide_collision_count():
			if absf(car.get_slide_collision(index).get_normal().y) < 0.5:
				car_speed = 0
				car.velocity.x = 0
				car.velocity.z = 0
				_cancel_drift()
	if not driving:
		var input := Input.get_vector("left", "right", "forward", "back")
		var direction := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
		player.velocity.x = direction.x * WALK_SPEED
		player.velocity.z = direction.z * WALK_SPEED
		player.velocity.y -= 20 * delta
		if player.is_on_floor() and Input.is_action_just_pressed("jump"):
			player.velocity.y = 7
		player.move_and_slide()
	_check_zone_transition()
	if loading_zone:
		return
	_update_drift_effects(delta)
	_update_camera()
	var near_car := player.position.distance_to(car.position) < 4
	hud.text = "BOUMPIF — %s\nZQSD / WASD / flèches : se déplacer · Souris : regarder\nEspace : %s · R : réinitialiser · Échap : libérer la souris\n%s" % ["Île du volcan" if on_island else "Quartier · portail de l’île au bout de la route nord", "direction + maintien : drift ; relâcher : mini-turbo" if driving else "sauter", "E : sortir à l’arrêt  |  %d km/h%s" % [int(Vector2(car.velocity.x, car.velocity.z).length() * 3.6), _drift_feedback()] if driving else ("E : entrer dans la voiture" if near_car else "Approche-toi de la voiture orange pour monter.")]

# Drift manuel : saut au déclenchement, côté verrouillé, contre-braquage
# pour élargir la courbe, puis mini-turbo au relâchement d'Espace.
func _drive_car(delta: float) -> void:
	var throttle := Input.get_axis("back", "forward")
	var steering := Input.get_axis("left", "right")
	var handbrake := Input.is_action_pressed("jump")
	var pressed := handbrake and not handbrake_was_pressed
	var released := not handbrake and handbrake_was_pressed
	handbrake_was_pressed = handbrake
	var ground_speed := Vector2(car.velocity.x, car.velocity.z).length()
	boost_time = maxf(0, boost_time - delta)
	if drifting and (ground_speed < 3.0 or car_speed <= 0):
		_cancel_drift()
	if drifting and released:
		if drift_charge >= SUPER_TURBO_CHARGE:
			boost_time = 1.3
		elif drift_charge >= MINI_TURBO_CHARGE:
			boost_time = 0.65
		drifting = false
		drift_charge = 0
		drift_direction = 0
	if pressed and car.is_on_floor() and ground_speed >= DRIFT_MIN_SPEED and car_speed > 0 and absf(steering) > 0.1:
		drifting = true
		drift_direction = signf(steering)
		drift_charge = 0
		boost_time = 0
		car.velocity.y = 3.8
	if drifting and car.is_on_floor() and ground_speed >= DRIFT_MIN_SPEED:
		# Braquer vers l'intérieur charge plus vite que contre-braquer.
		var charge_rate := 1.2 if steering * drift_direction > 0.1 else 0.5
		drift_charge = minf(SUPER_TURBO_CHARGE, drift_charge + charge_rate * delta)
	var target_speed := throttle * (CAR_SPEED if throttle >= 0 else 10.0)
	var acceleration := CAR_ACCELERATION if throttle else 8.0
	if boost_time > 0:
		target_speed = BOOST_SPEED
		acceleration = 55.0
	var grounded := car.is_on_floor()
	if grounded:
		var forward := -car.global_basis.z
		var motion_direction := forward * signf(target_speed)
		target_speed *= clampf(1.0 + motion_direction.dot(car_visual.ground_normal) * 0.65, 0.65, 1.12)
		var slope_acceleration := Vector3.DOWN.slide(car_visual.ground_normal).dot(forward) * 9.0
		car_speed = move_toward(car_speed, target_speed, acceleration * delta)
		if absf(car_speed) > 0.5 or throttle != 0:
			car_speed += slope_acceleration * delta

	if handbrake and not drifting:
		car_speed = move_toward(car_speed, 0, 34.0 * delta)
		boost_time = 0
	var steering_rate := 2.3 * clampf(absf(car_speed) / 7.0, 0.0, 1.0)
	var turn := steering * signf(car_speed) * steering_rate
	if drifting:
		# Le contre-braquage ne change pas le côté du dérapage.
		turn = drift_direction * (1.1 + 0.7 * steering * drift_direction)
	car.rotate_y(-turn * delta * (1.0 if grounded else 0.12))
	var desired_velocity := -car.global_basis.z * car_speed
	var grip := DRIFT_GRIP if drifting else CAR_GRIP
	# Moins d'appuis réduit le grip ; dans les airs, conserver l'élan balistique.
	var support := clampf(car_visual.contact_count / 4.0, 0.4, 1.0)
	var traction := 1.0 - exp(-grip * support * delta) if grounded else 0.0
	car.velocity.x = lerpf(car.velocity.x, desired_velocity.x, traction)
	car.velocity.z = lerpf(car.velocity.z, desired_velocity.z, traction)

func _cancel_drift() -> void:
	drifting = false
	drift_direction = 0
	drift_charge = 0
	boost_time = 0

func _drift_feedback() -> String:
	if boost_time > 0:
		return "  |  MINI-TURBO !"
	if drift_charge >= SUPER_TURBO_CHARGE:
		return "  |  ORANGE : super mini-turbo prêt !"
	if drift_charge >= MINI_TURBO_CHARGE:
		return "  |  BLEU : mini-turbo prêt !"
	return "  |  DRIFT : en charge…" if drifting else ""

func _update_drift_effects(delta: float) -> void:
	for effect in sparks:
		effect.emitting = (drifting and car.is_on_floor() and drift_charge >= MINI_TURBO_CHARGE) or boost_time > 0
		effect.color = Color("ff9c32") if drift_charge >= SUPER_TURBO_CHARGE or boost_time > 0 else Color("45bfff")

	var moving := Vector2(car.velocity.x, car.velocity.z).length() > 3.0
	for smoke in tire_smoke:
		smoke.emitting = drifting and car.is_on_floor() and moving
	for effect in boost_sparks:
		effect.emitting = boost_time > 0

func _update_camera() -> void:
	camera.rotation = Vector3(pitch, yaw, 0)
	if driving:
		var target := car.position + Vector3(0, 1.5, 0)
		var desired := target + Basis(Vector3.UP, yaw) * Vector3(0, 3, 7)
		var query := PhysicsRayQueryParameters3D.create(target, desired)
		query.exclude = [car.get_rid(), player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		camera.position = hit.position + hit.normal * 0.25 if hit else desired
		camera.look_at(target)
	else:
		camera.position = player.position + Vector3(0, 0.65, 0)

func _interact() -> void:
	if driving:
		if Vector2(car.velocity.x, car.velocity.z).length() > 1:
			return
		for side in [1.0, -1.0]:
			var exit_position: Vector3 = car.position + car.global_basis.x * side * 2.2 + Vector3(0, 0.5, 0)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = player.get_child(0).shape
			query.transform = Transform3D(Basis.IDENTITY, exit_position)
			query.exclude = [player.get_rid()]
			if get_world_3d().direct_space_state.intersect_shape(query).is_empty():
				player.position = exit_position
				player.velocity = Vector3.ZERO
				player.collision_layer = 1
				player.collision_mask = 1
				driving = false
				_cancel_drift()
				return
	elif player.position.distance_to(car.position) < 4:
		driving = true
		player.collision_layer = 0
		player.collision_mask = 0
		yaw = car.rotation.y

func _reset() -> void:
	driving = false
	_cancel_drift()
	handbrake_was_pressed = Input.is_action_pressed("jump")
	car_visual.reset_motion()
	for effects in [sparks, tire_smoke, boost_sparks]:
		for effect in effects:
			effect.emitting = false
	car_speed = 0
	player.collision_layer = 1
	player.collision_mask = 1
	player.position = spawn
	player.velocity = Vector3.ZERO
	car.position = car_spawn
	car.rotation = Vector3(0, spawn_yaw, 0)
	car.velocity = Vector3.ZERO
	yaw = spawn_yaw
	pitch = -0.2

func _build_portal(parent: Node3D, point: Vector3, title: String, color: Color) -> void:
	for side in [-1, 1]:
		_box(parent, Vector3(0.7, 6, 0.8), point + Vector3(side * 4, 3, 0), Color("535366"))
	_box(parent, Vector3(8.8, 0.6, 0.8), point + Vector3(0, 6, 0), color)
	var glow := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(7.3, 5.4, 0.08)
	glow.mesh = plane
	glow.position = point + Vector3(0, 2.8, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = material
	parent.add_child(glow)
	var label := Label3D.new()
	label.text = title + "\nTraverser à pied ou en voiture"
	label.position = point + Vector3(0, 7.6, 0)
	label.font_size = 42
	label.pixel_size = 0.025
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)

func _check_zone_transition() -> void:
	var actor: CharacterBody3D = car if driving else player
	var portal: Vector3 = ISLAND_OFFSET + island.portal_position if on_island else CITY_PORTAL
	if portal_cooldown <= 0 and absf(actor.position.y - portal.y) < 5 and Vector2(actor.position.x - portal.x, actor.position.z - portal.z).length() < 3.3:
		_travel_to(not on_island)
		return
	if on_island:
		var local := actor.position - ISLAND_OFFSET
		if local.y < 1.0 or (Vector2(local.x, local.z).length() < 17 and local.y < 62):
			_respawn_in_zone()
	elif actor.position.y < -10:
		_respawn_in_zone()

func _travel_to(to_island: bool) -> void:
	if loading_zone:
		return
	if to_island and not is_instance_valid(island):
		loading_zone = true
		hud.text = "Préparation de l’île…"
		# Laisser afficher l'indication avant de commencer les petits lots de travail.
		await get_tree().process_frame
		await get_tree().process_frame
		island = IslandZone.new()
		island.position = ISLAND_OFFSET
		island.visible = false
		add_child(island)
		await island.build()
		_build_portal(island, island.portal_position, "RETOUR AU QUARTIER", Color("c4a1ff"))
		remove_child(island)
		loading_zone = false
	# Une zone détachée n'affiche rien, ne simule aucune collision ni particule.
	if to_island:
		if city_zone.get_parent() == self:
			remove_child(city_zone)
		if island.get_parent() == null:
			add_child(island)
		island.visible = true
	else:
		if is_instance_valid(island) and island.get_parent() == self:
			remove_child(island)
		if city_zone.get_parent() == null:
			add_child(city_zone)
	camera.far = 750 if to_island else 180
	on_island = to_island
	if on_island:
		spawn = ISLAND_OFFSET + island.arrival + Vector3(0, 1.1, 0)
		car_spawn = ISLAND_OFFSET + island.arrival + Vector3(4, 0.9, 0)
		spawn_yaw = 0
	else:
		spawn = Vector3(0, 1.2, -43)
		car_spawn = Vector3(4, 0.8, -43)
		spawn_yaw = PI
	_respawn_in_zone()

func _respawn_in_zone() -> void:
	var was_driving := driving
	_reset()
	portal_cooldown = 2.0
	if was_driving:
		driving = true
		player.collision_layer = 0
		player.collision_mask = 0

func _exit_tree() -> void:
	# Libérer aussi les zones en cache, qui ne sont plus enfants de la scène.
	if is_instance_valid(island) and island.get_parent() == null:
		island.free()
	if is_instance_valid(city_zone) and city_zone.get_parent() == null:
		city_zone.free()
