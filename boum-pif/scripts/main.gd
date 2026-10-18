extends Node3D

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
var car_visual: Node3D
var sparks: Array[CPUParticles3D] = []
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
	_build_city()
	player = CharacterBody3D.new()
	player.name = "Player"
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
	camera.far = 250
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
	_box(self, Vector3(140, 1, 140), Vector3(0, -0.5, 0), Color("739c67"))
	_box(self, Vector3(16, 0.04, 130), Vector3(0, 0.02, 0), Color("374452"), false)
	_box(self, Vector3(130, 0.04, 16), Vector3(0, 0.025, 0), Color("374452"), false)
	for i in range(-12, 13):
		if absi(i) > 1:
			_box(self, Vector3(0.15, 0.02, 2), Vector3(0, 0.05, i * 5), Color("f0dd9a"), false)
			_box(self, Vector3(2, 0.02, 0.15), Vector3(i * 5, 0.05, 0), Color("f0dd9a"), false)
	var colors := [Color("dcad82"), Color("8ca9bd"), Color("c28070"), Color("c5bd9c")]
	for x in [-1, 1]:
		for z in [-1, 1]:
			_box(self, Vector3(45, 0.18, 45), Vector3(x * 32.5, 0.09, z * 32.5), Color("b5b6b3"))
			for row in range(3):
				for col in range(3):
					var height := float(5 + ((row * 3 + col * 5) % 4) * 3)
					var center := Vector3(x * (17 + row * 15), height / 2 + 0.18, z * (17 + col * 15))
					_box(self, Vector3(10, height, 10), center, colors[(row + col) % 4])
					for floor_index in range(int(height / 3)):
						for window_x in [-2.5, 2.5]:
							_box(self, Vector3(1.5, 1.4, 0.05), Vector3(center.x + window_x, 2 + floor_index * 3, center.z - 5.03), Color("425d70"), false)
	for axis in [0, 1]:
		for sign_value in [-1, 1]:
			var size := Vector3(1, 4, 140) if axis == 0 else Vector3(140, 4, 1)
			var at := Vector3(sign_value * 70, 2, 0) if axis == 0 else Vector3(0, 2, sign_value * 70)
			_box(self, size, at, Color("687c7c"))

func _build_car() -> void:
	car = CharacterBody3D.new()
	car.name = "Car"
	add_child(car)
	car.position = Vector3(4, 0.8, 4)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.2, 3.8)
	shape.shape = box
	car.add_child(shape)
	car_visual = Node3D.new()
	car.add_child(car_visual)
	_box(car_visual, Vector3(1.9, 0.7, 3.8), Vector3.ZERO, Color("e99936"), false)
	_box(car_visual, Vector3(1.6, 0.65, 1.8), Vector3(0, 0.6, 0.2), Color("344f65"), false)
	for x in [-0.97, 0.97]:
		for z in [-1.2, 1.2]:
			_box(car_visual, Vector3(0.3, 0.65, 0.65), Vector3(x, -0.25, z), Color("242b32"), false)
	for x in [-0.6, 0.6]:
		_box(car_visual, Vector3(0.4, 0.2, 0.05), Vector3(x, 0.1, -1.92), Color("fff1b7"), false)

	for side in [-1.0, 1.0]:
		var effect := CPUParticles3D.new()
		effect.position = Vector3(side, -0.3, 1.3)
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.003
		pitch = clampf(pitch - event.relative.y * 0.003, -1.1, 0.7)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("reset"):
		_reset()
	if Input.is_action_just_pressed("interact"):
		_interact()
	if driving:
		_drive_car(delta)
	else:
		car.velocity.x = move_toward(car.velocity.x, 0, 10 * delta)
		car.velocity.z = move_toward(car.velocity.z, 0, 10 * delta)
	car.velocity.y -= 20 * delta
	car.move_and_slide()
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
	_update_drift_effects(delta)
	_update_camera()
	var near_car := player.position.distance_to(car.position) < 4
	hud.text = "BOUMPIF — Premier quartier\nZQSD / WASD / flèches : se déplacer · Souris : regarder\nEspace : %s · R : réinitialiser · Échap : libérer la souris\n%s" % ["direction + maintien : drift ; relâcher : mini-turbo" if driving else "sauter", "E : sortir à l’arrêt  |  %d km/h%s" % [int(Vector2(car.velocity.x, car.velocity.z).length() * 3.6), _drift_feedback()] if driving else ("E : entrer dans la voiture" if near_car else "Approche-toi de la voiture orange pour monter.")]

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
	car_speed = move_toward(car_speed, target_speed, acceleration * delta)
	if handbrake and not drifting:
		car_speed = move_toward(car_speed, 0, 34.0 * delta)
		boost_time = 0
	var steering_rate := 2.3 * clampf(absf(car_speed) / 7.0, 0.0, 1.0)
	var turn := steering * signf(car_speed) * steering_rate
	if drifting:
		# Le contre-braquage ne change pas le côté du dérapage.
		turn = drift_direction * (1.1 + 0.7 * steering * drift_direction)
	car.rotate_y(-turn * delta)
	var desired_velocity := -car.global_basis.z * car_speed
	var grip := DRIFT_GRIP if drifting else CAR_GRIP
	var traction := 1.0 - exp(-grip * delta)
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
	var lean := drift_direction * 0.12 if drifting else 0.0
	car_visual.rotation.z = lerpf(car_visual.rotation.z, lean, 1.0 - exp(-10 * delta))
	for effect in sparks:
		effect.emitting = (drifting and car.is_on_floor() and drift_charge >= MINI_TURBO_CHARGE) or boost_time > 0
		effect.color = Color("ff9c32") if drift_charge >= SUPER_TURBO_CHARGE or boost_time > 0 else Color("45bfff")

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
	car_visual.rotation = Vector3.ZERO
	for effect in sparks:
		effect.emitting = false
	car_speed = 0
	player.collision_layer = 1
	player.collision_mask = 1
	player.position = spawn
	player.velocity = Vector3.ZERO
	car.position = Vector3(4, 0.8, 4)
	car.rotation = Vector3.ZERO
	car.velocity = Vector3.ZERO
	yaw = 0
	pitch = -0.2
