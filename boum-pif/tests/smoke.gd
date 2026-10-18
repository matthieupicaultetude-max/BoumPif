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
	await frames(90)
	Input.action_release("jump")
	check(absf(game.car_speed) < 0.1, "Freinage")
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
	Input.action_press("forward")
	await frames(120)
	Input.action_release("forward")
	check(game.car.position.z > -69, "La limite de ville bloque la voiture")
	game._reset()
	check(not game.driving and game.player.position.is_equal_approx(game.spawn), "Réinitialisation")
	print("Résultat : %d échec(s)" % failures)
	quit(1 if failures else 0)
