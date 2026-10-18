extends SceneTree

var game: Node3D
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		push_error("FAIL: " + description)
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	check(not is_instance_valid(game.island), "L’île n’est pas construite au démarrage du quartier")
	await frames(90)
	test_arcade_handling()
	test_kart_drift()
	await test_drift_hop()
	await test_vehicle_terrain()
	await frames(90)
	check(game.player.is_on_floor(), "Le personnage repose sur le sol")
	var initial: Vector3 = game.player.position
	Input.action_press("forward")
	await frames(30)
	Input.action_release("forward")
	check(game.player.position.z < initial.z - 1, "Déplacement à pied")
	game.player.position = game.car.position + Vector3(2.5, 0.5, 0)
	await frames(2)
	game._interact()
	check(game.driving, "Entrée dans la voiture")
	initial = game.car.position
	Input.action_press("forward")
	await frames(60)
	Input.action_release("forward")
	check(game.car.position.z < initial.z - 2, "La voiture avance")
	Input.action_press("jump")
	await frames(180)
	Input.action_release("jump")
	check(absf(game.car_speed) < 0.1 and Vector2(game.car.velocity.x, game.car.velocity.z).length() < 0.1, "Freinage jusqu’à l’arrêt après glisse")
	game._interact()
	check(not game.driving and game.player.collision_layer == 1, "Sortie de voiture et collisions réactivées")
	game._reset()
	game.player.position = Vector3(17, 1.2, 10)
	game.yaw = PI
	Input.action_press("forward")
	await frames(120)
	Input.action_release("forward")
	check(game.player.position.z < 12, "Un bâtiment bloque le personnage")
	game._reset()
	game.car.position = Vector3(4, 0.8, -65)
	game.player.position = Vector3(6.5, 1.2, -65)
	await frames(10)
	game._interact()
	game.car_speed = 18
	game.car.velocity = Vector3(0, 0, -18)
	game.boost_time = 1.3
	Input.action_press("forward")
	await frames(30)
	Input.action_release("forward")
	check(game.car.position.z > -69, "La limite de ville bloque la voiture")
	check(not game.drifting and game.drift_charge == 0 and game.boost_time == 0, "Un choc annule le drift et le turbo")
	game._reset()
	game.car.position = Vector3(4, 0.8, -65)
	game.player.position = Vector3(6.5, 1.2, -65)
	await frames(10)
	game._interact()
	game.car_speed = 18
	game.car.velocity = Vector3(0, 0, -18)
	game.drifting = true
	game.drift_direction = 1
	game.drift_charge = game.SUPER_TURBO_CHARGE
	game.handbrake_was_pressed = true
	Input.action_press("jump")
	Input.action_press("forward")
	await frames(30)
	check(not game.drifting and game.drift_charge == 0, "Un choc pendant un drift chargé efface la charge")
	Input.action_release("jump")
	Input.action_release("forward")
	await frames(1)
	check(game.boost_time == 0, "Relâcher après un choc ne donne pas de turbo")
	game._reset()
	check(not game.driving and game.player.position.is_equal_approx(game.spawn), "Réinitialisation")
	await test_island_zone()
	await test_derby_arena()
	print("Résultat : %d échec(s)" % failures)
	quit(1 if failures else 0)

# Comparer les trajectoires avec les mêmes vitesse et durée, hors collisions.
func test_arcade_handling() -> void:
	game.car_speed = 14.0
	game.car.velocity = Vector3(0, 0, -14)
	Input.action_press("forward")
	Input.action_press("right")
	for i in 20:
		game._drive_car(1.0 / 60.0)
	var normal_slip: float = absf(game.car.velocity.dot(game.car.global_basis.x))
	check(absf(game.car.rotation.y) > 0.7, "Braquage arcade plus serré")
	game._reset()
	game.car_speed = 14.0
	game.car.velocity = Vector3(0, 0, -14)
	Input.action_press("jump")
	for i in 20:
		game._drive_car(1.0 / 60.0)
	var drift_slip: float = absf(game.car.velocity.dot(game.car.global_basis.x))
	check(game.drifting and drift_slip > normal_slip * 1.5 and drift_slip > 4, "Espace à vitesse élevée provoque une glisse latérale")
	check(Vector2(game.car.velocity.x, game.car.velocity.z).length() > 8, "Le drift conserve de la vitesse")
	game._update_drift_effects(0.016)
	check(game.tire_smoke.size() == 2 and game.tire_smoke[0].emitting and game.tire_smoke[1].emitting, "Les deux pneus arrière fument dès le drift avant la charge bleue")
	Input.action_release("jump")
	Input.action_release("right")
	for i in 60:
		game._drive_car(1.0 / 60.0)
	check(not game.drifting and absf(game.car.velocity.dot(game.car.global_basis.x)) < 0.1, "L'adhérence revient au relâchement")
	game._update_drift_effects(0.016)
	check(not game.tire_smoke[0].emitting and not game.boost_sparks[0].emitting, "Pas de fumée ni de traînée turbo en conduite normale")
	Input.action_release("forward")
	game._reset()
	game.car_speed = 4.0
	game.car.velocity = Vector3(0, 0, -4)
	Input.action_press("jump")
	for i in 60:
		game._drive_car(1.0 / 60.0)
	check(not game.drifting and game.car.velocity.length() < 0.1, "Espace freine à basse vitesse sans drift")
	Input.action_release("jump")
	game._reset()

func prepare_drift() -> void:
	for action in ["forward", "back", "left", "right", "jump"]:
		Input.action_release(action)
	game._reset()
	game.car_speed = 18.0
	game.car.velocity = Vector3(0, 0, -18)
	Input.action_press("forward")

func drive_steps(count: int) -> void:
	for i in count:
		game._drive_car(1.0 / 60.0)

func test_kart_drift() -> void:
	prepare_drift()
	Input.action_press("jump")
	drive_steps(60)
	check(not game.drifting and game.drift_charge == 0, "Espace en ligne droite ne charge pas de turbo")
	prepare_drift()
	Input.action_press("right")
	Input.action_press("jump")
	drive_steps(20)
	Input.action_release("jump")
	drive_steps(1)
	check(game.boost_time == 0, "Un drift trop court ne donne pas de turbo")
	prepare_drift()
	Input.action_press("right")
	Input.action_press("jump")
	drive_steps(45)
	check(game.drift_charge >= game.MINI_TURBO_CHARGE and game.drift_charge < game.SUPER_TURBO_CHARGE, "Premier niveau bleu chargé")
	game._update_drift_effects(0.016)
	check(game.sparks[0].emitting and game.sparks[0].color == Color("45bfff"), "Étincelles bleues au premier niveau")
	Input.action_release("jump")
	drive_steps(1)
	game._update_drift_effects(0.016)
	check(game.boost_sparks.size() == 2 and game.boost_sparks[0].emitting and game.boost_sparks[1].emitting, "Le mini-turbo émet deux gerbes d’étincelles arrière")
	check(not game.tire_smoke[0].emitting, "Le boost seul ne fait pas fumer les pneus")
	var blue_duration: float = game.boost_time
	drive_steps(20)
	check(blue_duration > 0 and game.car_speed > game.CAR_SPEED, "Relâcher un drift bleu donne un mini-turbo")
	drive_steps(120)
	check(game.boost_time == 0 and game.car_speed <= game.CAR_SPEED, "Le turbo expire et la vitesse redevient normale")
	game._update_drift_effects(0.016)
	check(not game.boost_sparks[0].emitting, "Les étincelles turbo s’arrêtent à expiration")
	prepare_drift()
	Input.action_press("right")
	Input.action_press("jump")
	drive_steps(100)
	check(game.drift_charge >= game.SUPER_TURBO_CHARGE, "Second niveau orange chargé")
	game._update_drift_effects(0.016)
	check(game.sparks[0].emitting and game.sparks[0].color == Color("ff9c32"), "Étincelles orange au second niveau")
	Input.action_release("right")
	Input.action_press("left")
	var before: float = game.car.rotation.y
	drive_steps(20)
	var turn: float = wrapf(game.car.rotation.y - before, -PI, PI)
	check(game.drifting and game.drift_direction == 1 and turn < 0 and absf(turn) < 0.2, "Contre-braquer élargit le virage sans inverser le drift")
	Input.action_release("jump")
	drive_steps(1)
	check(game.boost_time > blue_duration, "Le super mini-turbo dure plus longtemps")
	game._reset()
	check(game.boost_time == 0 and game.drift_charge == 0 and not game.drifting, "Réinitialiser efface charge et turbo")
	check(not game.tire_smoke[0].emitting and not game.boost_sparks[0].emitting, "Réinitialiser coupe les effets")
	prepare_drift()
	game.car_speed = -10
	game.car.velocity = Vector3(0, 0, 10)
	Input.action_release("forward")
	Input.action_press("back")
	Input.action_press("right")
	Input.action_press("jump")
	drive_steps(10)
	check(not game.drifting and game.boost_time == 0, "Pas de drift en marche arrière")
	prepare_drift()
	Input.action_release("forward")
	game._reset()

func test_drift_hop() -> void:
	game._reset()
	game.driving = true
	game.player.collision_layer = 0
	game.player.collision_mask = 0
	await frames(10)
	game.car_speed = 14
	game.car.velocity = Vector3(0, 0, -14)
	var ground_height: float = game.car.position.y
	Input.action_press("forward")
	Input.action_press("right", 0.2)
	Input.action_press("jump")
	await frames(10)
	check(game.drifting and game.car.position.y > ground_height + 0.15, "Le déclenchement fait réellement sauter la voiture")
	check(not game.tire_smoke[0].emitting, "Les pneus ne fument pas dans les airs")
	var air_charge: float = game.drift_charge
	await frames(4)
	check(is_equal_approx(game.drift_charge, air_charge), "Le turbo ne se charge pas dans les airs")
	await frames(20)
	check(game.car.is_on_floor(), "La voiture retombe après le saut")
	check(game.tire_smoke[0].emitting, "La fumée apparaît au retour au sol pendant le drift")
	for action in ["forward", "right", "jump"]:
		Input.action_release(action)
	game._reset()

func test_island_zone() -> void:
	game._travel_to(false)
	game.portal_cooldown = 0
	game.player.position = game.CITY_PORTAL + Vector3(0, 1, 0)
	await frames(2)
	check(game.loading_zone, "Le portail lance une préparation progressive")
	await wait_for_zone()
	check(game.on_island and not game.driving, "Le portail du quartier mène à l’île à pied")
	check(not game.city_zone.is_inside_tree() and game.island.is_inside_tree(), "Le quartier est retiré de l’affichage et de la physique sur l’île")
	var city_query := PhysicsRayQueryParameters3D.create(Vector3(0, 5, 0), Vector3(0, -2, 0))
	check(game.get_world_3d().direct_space_state.intersect_ray(city_query).is_empty(), "Les collisions du quartier sont absentes pendant la visite de l’île")
	var cached_island: Node3D = game.island
	await frames(60)
	check(game.player.is_on_floor(), "L’arrivée sur l’île possède un sol physique")
	check(game.island.house_count >= 30 and game.island.villages.size() == 2, "Deux villages denses avec au moins trente maisons")
	check(game.island.roads.size() >= 6, "Route principale et chemins secondaires présents")
	var route: PackedVector3Array = game.island.main_route
	check(route[-1].y > route[0].y + 70, "La route atteint le haut du volcan")
	var route_collision_ok := true
	for i in range(0, route.size(), 8):
		var point: Vector3 = game.ISLAND_OFFSET + route[i]
		var query := PhysicsRayQueryParameters3D.create(point + Vector3(0, 8, 0), point - Vector3(0, 8, 0))
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or absf(hit.position.y - point.y) > 1.0 or hit.normal.y < 0.7:
			route_collision_ok = false
			print("Collision route %d : hauteur %.2f, contact %s" % [i, point.y, hit])
	check(route_collision_ok, "Collisions continues sur toute la montée")
	game.portal_cooldown = 0
	game.player.position = game.ISLAND_OFFSET + game.island.portal_position + Vector3(0, 1.1, 0)
	await frames(2)
	check(not game.on_island, "Le portail de l’île ramène au quartier")
	check(not game.island.is_inside_tree() and game.city_zone.is_inside_tree(), "L’île n’est ni rendue ni simulée depuis le quartier")
	check(game.camera.far == 180, "La distance d’affichage du quartier est limitée")
	var island_point: Vector3 = game.ISLAND_OFFSET + game.island.arrival
	var island_query := PhysicsRayQueryParameters3D.create(island_point + Vector3(0, 10, 0), island_point - Vector3(0, 10, 0))
	check(game.get_world_3d().direct_space_state.intersect_ray(island_query).is_empty(), "Les collisions de l’île sont absentes depuis le quartier")
	game.driving = true
	game.player.collision_layer = 0
	game.player.collision_mask = 0
	game.portal_cooldown = 0
	game.car.position = game.CITY_PORTAL + Vector3(0, 0.9, 0)
	await frames(2)
	check(game.on_island and game.driving, "Le portail transporte aussi la voiture et son conducteur")
	check(game.island == cached_island and not game.loading_zone, "Revenir sur l’île réutilise la zone sans la reconstruire")
	# Conduire réellement jusqu'au cratère en suivant la ligne médiane.
	game.car.position = game.ISLAND_OFFSET + game.island.arrival + Vector3(0, 1, 0)
	game.car.rotation.y = 0
	Input.action_press("forward")
	var target_index := 0
	var steps := 0
	var stalled := 0
	while target_index < route.size() and steps < 9000 and stalled < 240:
		var target: Vector3 = game.ISLAND_OFFSET + route[target_index]
		var difference: Vector3 = target - game.car.position
		if Vector2(difference.x, difference.z).length() < 4:
			target_index += 1
			stalled = 0
			continue
		game.car.rotation.y = lerp_angle(game.car.rotation.y, atan2(-difference.x, -difference.z), 0.15)
		await frames(1)
		steps += 1
		stalled += 1
	Input.action_release("forward")
	check(target_index == route.size() and game.car.position.y > 75, "La voiture peut monter toute la route jusqu’au cratère")
	if target_index < route.size():
		print("Montée interrompue : point %d/%d ; position %s ; cible %s ; vitesse %s" % [target_index, route.size(), game.car.position, route[target_index], game.car.velocity])
		for i in game.car.get_slide_collision_count():
			var hit: KinematicCollision3D = game.car.get_slide_collision(i)
			print("Obstacle : ", hit.get_collider(), " normale ", hit.get_normal(), " contact ", hit.get_position())
	await test_wild_circuit()
	game.car.position.y = -4
	await frames(2)
	check(game.on_island and game.driving and game.car.position.y > 1, "L’eau ramène à l’arrivée sans perdre la voiture")
	game._reset()
	check(game.on_island and game.player.position.x > 1000, "R réinitialise dans la zone courante")
	game._travel_to(false)

func wait_for_zone() -> void:
	var render_frames := 0
	while game.loading_zone and render_frames < 1000:
		await process_frame
		render_frames += 1
	check(not game.loading_zone and render_frames > 20, "La préparation de l’île rend la main entre les lots de travail")
	await frames(2)

func test_wild_circuit() -> void:
	var route: PackedVector3Array = game.island.race_route
	check(route.size() > 500 and route[0].distance_to(route[-1]) < 0.01, "Le circuit sauvage forme une boucle fermée")
	check(game.island.tree_count >= 400, "Forêts denses regroupées par secteurs")
	print("Décor : %d arbres, %d maisons" % [game.island.tree_count, game.island.house_count])
	var high := -INF
	var low := INF
	var rising := false
	var falling := false
	for i in range(route.size() - 1):
		high = maxf(high, route[i].y)
		low = minf(low, route[i].y)
		rising = rising or route[i + 1].y > route[i].y + 0.1
		falling = falling or route[i + 1].y < route[i].y - 0.1
	check(high - low > 20 and rising and falling, "La boucle alterne montées et descentes avec un relief marqué")
	var terrain_tiles := 0
	var separate_road_meshes := 0
	var shared_material := true
	for child in game.island.get_children():
		if child is MeshInstance3D:
			if String(child.name).begins_with("GroundedRoad"):
				separate_road_meshes += 1
			if String(child.name).begins_with("Terrain_"):
				terrain_tiles += 1
				shared_material = shared_material and child.material_override == game.island.road_material
	check(terrain_tiles == 64 and separate_road_meshes == 0 and shared_material, "La route et le terrain partagent une seule surface : aucune chaussée superposée")
	var covered := true
	var junction_found := false
	for road: Dictionary in game.island.roads:
		var points: PackedVector3Array = road.points
		for i in range(0, points.size() - 1, 4):
			# Contrôler aussi les milieux des segments, pas seulement leurs sommets.
			for t in [0.0, 0.5]:
				var point := points[i].lerp(points[i + 1], t)
				var pixel: Color = road_mask_at(point)
				if (pixel.r < 0.95 and not road.dirt) or (maxf(pixel.r, pixel.g) < 0.95 and road.dirt):
					covered = false
				junction_found = junction_found or (pixel.r > 0.95 and pixel.g > 0.95)
	check(covered, "L’asphalte et les chemins couvrent les sommets et les milieux de tous les tracés")
	check(junction_found, "Les croisements asphalte et terre se composent dans le même matériau")
	check(road_mask_at(Vector3(300, 0, 300)).r == 0 and road_mask_at(Vector3(300, 0, 300)).g == 0, "Le terrain hors route conserve sa couleur")
	game.car.position = game.ISLAND_OFFSET + route[0] + Vector3(0, 1, 0)
	game.car.velocity = Vector3.ZERO
	game.car_speed = 0
	Input.action_press("forward")
	var target_index := 1
	var steps := 0
	var stalled := 0
	while target_index < route.size() and steps < 12000 and stalled < 240:
		var difference: Vector3 = game.ISLAND_OFFSET + route[target_index] - game.car.position
		if Vector2(difference.x, difference.z).length() < 3:
			target_index += 1
			stalled = 0
			continue
		game.car.rotation.y = lerp_angle(game.car.rotation.y, atan2(-difference.x, -difference.z), 0.15)
		await frames(1)
		steps += 1
		stalled += 1
	Input.action_release("forward")
	check(target_index == route.size(), "La voiture peut effectuer un tour complet du circuit sauvage")
	if target_index < route.size():
		print("Circuit interrompu : %d/%d à %s" % [target_index, route.size(), game.car.position])
		for i in game.car.get_slide_collision_count():
			var collision: KinematicCollision3D = game.car.get_slide_collision(i)
			print("Obstacle : ", collision.get_collider(), " normale ", collision.get_normal())

func road_mask_at(point: Vector3) -> Color:
	var size: int = game.island.ROAD_MASK_SIZE
	var x := clampi(int((point.x + game.island.RADIUS) / (2 * game.island.RADIUS) * size), 0, size - 1)
	var z := clampi(int((point.z + game.island.RADIUS) / (2 * game.island.RADIUS) * size), 0, size - 1)
	return game.island.road_mask.get_pixel(x, z)

func test_vehicle_terrain() -> void:
	game._reset()
	await frames(30)
	var visual: Node3D = game.car_visual
	check(visual.wheel_pivots.size() == 4 and visual.wheel_spinners[0].get_child(0).mesh is CylinderMesh, "Quatre roues rondes avec jantes et moyeux")
	var ramp := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 0.4, 16)
	shape.shape = box
	ramp.add_child(shape)
	ramp.position = Vector3(45, 2.2, 0)
	ramp.rotation.x = deg_to_rad(12)
	game.add_child(ramp)
	game.driving = true
	game.player.collision_layer = 0
	game.player.collision_mask = 0
	game.car.position = Vector3(45, 4, 0)
	await frames(90)
	check(game.car.is_on_floor() and visual.contact_count == 4, "Les quatre sondes détectent la rampe inclinée")
	check(visual.rotation.x > 0.12, "La caisse s’incline réellement selon la pente du sol")
	var front_height: float = visual.wheel_pivots[0].global_position.y
	var rear_height: float = visual.wheel_pivots[2].global_position.y
	check(front_height > rear_height + 0.3, "Les essieux suivent des hauteurs de sol différentes")
	var tires_touch := true
	for i in 4:
		if visual.contacts[i].is_empty():
			tires_touch = false
		else:
			var gap: float = (visual.wheel_pivots[i].global_position - visual.contacts[i].position).dot(visual.ground_normal) - visual.WHEEL_RADIUS
			tires_touch = tires_touch and absf(gap) < 0.08
	check(tires_touch, "Les quatre pneus restent au contact de la pente sans flotter")
	game.car_speed = 14
	game.car.velocity = Vector3(0, 0, -14)
	for i in 20:
		game._drive_car(1.0 / 60)
	var uphill_speed: float = game.car_speed
	game.car.rotation.y = PI
	game.car_speed = 14
	game.car.velocity = Vector3(0, 0, 14)
	for i in 20:
		game._drive_car(1.0 / 60)
	check(game.car_speed > uphill_speed + 0.5, "La pente ralentit la montée et favorise la descente")
	game.car.rotation.y = 0
	game.car_speed = 8
	game.car.position = Vector3(45, 13, 0)
	game.car.velocity = Vector3(0, 0, -8)
	await frames(2)
	var height_before: float = game.car.position.y
	Input.action_press("forward")
	Input.action_press("right")
	await frames(25)
	check(not game.car.is_on_floor() and game.car.position.y < height_before, "La voiture suit une trajectoire balistique dans les airs")
	check(absf(Vector2(game.car.velocity.x, game.car.velocity.z).length() - 8) < 0.2, "Accélérer et tourner en l’air ne crée pas d’adhérence")
	check(visual.spring_offsets[0] < -0.2, "Les roues se détendent quand elles quittent le sol")
	check(absf(visual.wheel_spinners[0].rotation.x) > 0.1 and absf(visual.wheel_pivots[0].rotation.y) > 0.1 and absf(visual.wheel_pivots[2].rotation.y) < 0.01, "Les pneus roulent et seules les roues avant braquent")
	Input.action_release("forward")
	Input.action_release("right")
	game.car.position = Vector3(45, 5, 0)
	game.car.velocity = Vector3.ZERO
	game.car.rotation = Vector3.ZERO
	game.car_speed = 0
	await frames(90)
	check(game.car.is_on_floor() and absf(visual.body_heave) < 0.12 and visual.spring_offsets[0] <= visual.WHEEL_TRAVEL, "Les ressorts amortis se stabilisent après l’atterrissage")
	game._reset()
	check(visual.rotation.is_zero_approx() and visual.spring_offsets[0] == 0, "Réinitialiser remet aussi la suspension à zéro")
	ramp.queue_free()
	await frames(2)

func test_derby_arena() -> void:
	check(not is_instance_valid(game.derby), "L’arène n’est pas construite avant sa première visite")
	game._travel_to(false)
	game.portal_cooldown = 0
	game.player.position = game.DERBY_PORTAL + Vector3(0, 1, 0)
	await frames(2)
	var ticks := 0
	while game.loading_zone and ticks < 1000:
		await process_frame
		ticks += 1
	await frames(30)
	check(game.on_derby and not game.on_island and game.derby.is_inside_tree(), "Le portail sud mène à La Fonderie")
	check(not game.city_zone.is_inside_tree() and not game.island.is_inside_tree(), "Les autres zones restent détachées pendant le derby")
	check(game.derby.spawn_points.size() == 4 and game.derby.SIZE >= 200, "L’arène de plus de deux cents mètres possède quatre départs")
	var arena: Node3D = game.derby
	var starts_clear := true
	for point: Vector3 in game.derby.spawn_points:
		var query := PhysicsShapeQueryParameters3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.2, 1.2, 4.1)
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, game.DERBY_OFFSET + point)
		query.exclude = [game.car.get_rid(), game.player.get_rid()]
		starts_clear = starts_clear and game.get_world_3d().direct_space_state.intersect_shape(query).is_empty()
	check(starts_clear, "Les quatre voitures disposent d’un volume de départ libre")
	check(game.derby.height_at(0, 0) > game.derby.height_at(40, 0) + 3, "Le plateau central domine la cuvette de combat")
	var ramps_solid: bool = game.derby.ramp_routes.size() == 4
	for route: PackedVector3Array in game.derby.ramp_routes:
		var point: Vector3 = game.DERBY_OFFSET + route[8]
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3(0, 2, 0), point - Vector3(0, 2, 0)))
		ramps_solid = ramps_solid and not hit.is_empty() and absf(hit.position.y - point.y) < 0.3 and hit.normal.y > 0.7
	check(ramps_solid, "Quatre rampes possèdent une surface physique praticable")
	game.driving = true
	game.player.collision_layer = 0
	game.player.collision_mask = 0
	game.car.position = game.DERBY_OFFSET + game.derby.arrival + Vector3(0, 1, 0)
	game.car.rotation.y = 0
	Input.action_press("forward")
	await frames(180)
	Input.action_release("forward")
	check(game.car.position.z < 40 and game.on_derby, "La voiture peut charger depuis le départ vers le centre")
	var ramp_route: PackedVector3Array = game.derby.ramp_routes[0]
	var outward: Vector3 = Vector3(ramp_route[0].x, 0, ramp_route[0].z).normalized()
	game.car.position = game.DERBY_OFFSET + ramp_route[0] + outward * 7 + Vector3(0, 1, 0)
	game.car.rotation.y = atan2(outward.x, outward.z)
	game.car.velocity = Vector3.ZERO
	game.car_speed = 0
	Input.action_press("forward")
	var jumped := false
	for i in 120:
		await frames(1)
		var local: Vector3 = game.car.position - game.DERBY_OFFSET
		jumped = jumped or (not game.car.is_on_floor() and local.y - game.derby.height_at(local.x, local.z) > 1.4)
	Input.action_release("forward")
	check(jumped, "La voiture franchit une rampe et décolle au-dessus de la cuvette")
	game.car.position = game.DERBY_OFFSET + Vector3(0, game.derby.height_at(0, -94) + 1, -94)
	game.car.rotation.y = 0
	game.car.velocity = Vector3.ZERO
	game.car_speed = 0
	Input.action_press("forward")
	await frames(100)
	Input.action_release("forward")
	check(game.car.position.z > -110 and game.car_speed < 2, "L’enceinte retient une voiture lancée contre le mur extérieur")
	# Charge physique sur une caisse, dans la diagonale nord-est.
	var prop: RigidBody3D = game.derby.props[0]
	var before: Vector3 = prop.global_position
	var direction: Vector3 = Vector3(before.x - game.DERBY_OFFSET.x, 0, before.z).normalized()
	game.car.position = before + direction * 9 + Vector3(0, 0.8, 0)
	game.car.rotation.y = atan2(direction.x, direction.z)
	game.car.velocity = -direction * 16
	game.car_speed = 16
	Input.action_press("forward")
	await frames(75)
	Input.action_release("forward")
	check(prop.global_position.distance_to(before) > 1.0, "Un impact de voiture déplace les caisses du derby")
	# Inclure un fût dans le contrôle de réinitialisation des objets physiques.
	var barrel: RigidBody3D = game.derby.props[-1]
	barrel.position += Vector3(2, 1, 0)
	barrel.linear_velocity = Vector3(4, 0, 0)
	game._reset()
	var reset_ok := true
	for i in game.derby.props.size():
		reset_ok = reset_ok and game.derby.props[i].position.distance_to(game.derby.prop_spawns[i].origin) < 0.01
	check(reset_ok, "R remet toutes les caisses et tous les fûts à leur position initiale")
	game.portal_cooldown = 0
	game.player.position = game.DERBY_OFFSET + game.derby.portal_position + Vector3(0, 1.1, 0)
	await frames(2)
	check(not game.on_derby and game.city_zone.is_inside_tree() and not game.derby.is_inside_tree(), "Le portail de sortie ramène au quartier et désactive l’arène")
	await game._travel_derby(true)
	check(game.derby == arena and game.on_derby, "Une nouvelle visite réutilise l’arène en cache")
	game.driving = true
	game.player.collision_layer = 0
	game.player.collision_mask = 0
	game.portal_cooldown = 0
	game.car.position = game.DERBY_OFFSET + game.derby.portal_position + Vector3(0, 0.9, 0)
	await frames(2)
	check(not game.on_derby and game.driving and game.car.position.x > -100, "Le portail de retour conserve la voiture et son conducteur")
