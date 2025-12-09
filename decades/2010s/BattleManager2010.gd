extends Node

signal player_spawned(player)
signal enemy_spawned(enemy)
var camera: ThirdPersonCamera3D
var player_hud: Control = null

var player_path := preload("res://decades/2010s/Knight3D.tscn")
var enemy_paths := [preload("res://decades/2010s/Skeleton_Minion.tscn")]

var player_character: CombatCharacter = null
var enemies: Array = []
var spawn_positions := [Vector3(6, 0.5, 6), Vector3(-6, 0.5, 0), Vector3(6, 0.5, -12)]

func _ready() -> void:
	_spawn_player()
	_spawn_enemies(3)
	set_process_input(true)
	print("BattleManager (simples) pronto")

func set_camera(cam: ThirdPersonCamera3D):
	camera = cam
	await get_tree().process_frame
	if player_character:
		camera.set_follow_target(player_character)
		camera.set_camera_to_combat(true)
		print("BattleManager: Câmera setada para seguir o Knight.")

func set_player_hud(hud):
	player_hud = hud
	if player_character and player_hud:
		player_hud.set_player(player_character)

func _spawn_player() -> void:
	player_character = player_path.instantiate()
	add_child(player_character)
	player_character.global_position = Vector3(2, 0.5, 1)
	player_character.manual_control = true
	player_character.name = "Player"

	if camera:
		player_character.set_camera(camera)
		camera.set_follow_target(player_character)

	if player_hud:
		player_hud.set_player(player_character)

	player_character.connect("died", Callable(self, "_on_character_death"))
	emit_signal("player_spawned", player_character)

func _spawn_enemies(count: int) -> void:
	# Definição fixa do esquadrão para demonstrar a IA
	var squad_roles = ["Tank", "Healer", "DPS"]
	
	# Limpa lista anterior
	enemies.clear()
	
	for i in range(min(count, squad_roles.size())):

		var scene = enemy_paths[0] 
		var enemy = scene.instantiate()
		
		add_child(enemy)
		enemy.global_position = spawn_positions[i % spawn_positions.size()]
		enemy.manual_control = false
		
		# CONFIGURA O ROLE
		if enemy is EnemyAI2010:
			enemy.role = squad_roles[i]
			enemy.name = "Enemy_" + squad_roles[i] # Ex: Enemy_Tank
			print("Spawnando Inimigo: " + enemy.role)
		
		enemies.append(enemy)
		enemy.connect("died", Callable(self, "_on_character_death"))
		emit_signal("enemy_spawned", enemy)
		
	# Atualiza a lista dpara o Healer saber quem curar
	for enemy in enemies:
		if enemy is EnemyAI2010:
			enemy.squad_mates = enemies

func _input(event) -> void:
	if not player_character:
		return
	if event.is_action_pressed("attack_light"):
		player_character.perform_attack(false)
	if event.is_action_pressed("attack_heavy"):
		player_character.perform_attack(true)
	if event.is_action_pressed("dodge"):
		player_character.perform_dodge()
	if event.is_action_pressed("defend"):
		player_character.start_blocking()
	elif event.is_action_released("defend"):
		player_character.stop_blocking()


func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_combat_click(event.position)

func _handle_combat_click(mouse_pos: Vector2) -> void:
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return
	var from = cam.project_ray_origin(mouse_pos)
	var to = from + cam.project_ray_normal(mouse_pos) * 1000.0
	var space_state = cam.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result = space_state.intersect_ray(query)
	if result:
		var clicked = result["collider"]
		if clicked and clicked in enemies and clicked.is_alive():
			player_character.current_target = clicked
			print("Alvo selecionado:", clicked.name)

func _on_character_death(character):
	print(character.name, "morreu")
	if enemies.has(character):
		enemies.erase(character)
	if character == player_character:
		print("Player morreu - Game Over")
