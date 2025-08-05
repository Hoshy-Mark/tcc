extends Node

var party_paths := [
	preload("res://decades/2000s/Characters/Barbarian3D.tscn"),
	preload("res://decades/2000s/Characters/Mage3D.tscn"),
	preload("res://decades/2000s/Characters/Rogue3D.tscn"),
	preload("res://decades/2000s/Characters/Knight3D.tscn")
]

var enemy_paths := [
	preload("res://decades/2000s/Characters/Enemies/Skeleton_Minion.tscn")
]

var party_members: Array[CombatCharacter] = []
var enemies: Array[CombatCharacter] = []
var base_height = 0.5
var active_character: CombatCharacter = null
var camera: ThirdPersonCamera3D = null
var hud: CanvasLayer = null  # <-- nova variável para armazenar o HUD
var player_character: CombatCharacter = null

func _ready():
	_spawn_party()
	_spawn_enemies()

	var cam = get_node("Camera3D") # Ajuste o caminho real da câmera
	for char in party_members + enemies:
		char.set_camera(cam)
		
func _setup_ui_with_hud(ui_node: CanvasLayer):
	hud = ui_node
	if hud:
		hud.connect("action_selected", Callable(self, "_on_player_action_selected"))
		print("BattleManager: HUD conectado com sucesso")
	else:
		push_error("BattleManager: HUD GameUI não fornecido!")

func _spawn_party():
	var start_positions = [
		Vector3(2, 0, 1),
		Vector3(4, 0, 1),
		Vector3(6, 0, 1),
		Vector3(8, 0, 1)
	]

	for i in party_paths.size():
		var char: CombatCharacter = party_paths[i].instantiate()
		add_child(char)
		char.global_position = Vector3(start_positions[i % start_positions.size()].x, base_height, start_positions[i % start_positions.size()].z)
		party_members.append(char)

		# Knight será o último no array (index 3)
		if i == 3:
			char.manual_control = true
			player_character = char  # <-- armazenamos o Knight aqui
		else:
			char.manual_control = false  # serão IA no futuro

		print("BattleManager: Personagem da party instanciado: ", char.name)
		
func _spawn_enemies():
	var positions = [ Vector3(8, 0, 8) ]

	for i in enemy_paths.size():
		var enemy: CombatCharacter = enemy_paths[i].instantiate()
		add_child(enemy)
		enemy.global_position = Vector3(positions[i % positions.size()].x, base_height, positions[i % positions.size()].z)
		enemy.manual_control = false
		enemies.append(enemy)
		print("BattleManager: Inimigo instanciado: ", enemy.name)

func set_camera(cam: ThirdPersonCamera3D):
	camera = cam
	await get_tree().process_frame
	if player_character:
		camera.set_follow_target(player_character)
		camera.set_camera_to_combat(true)
		print("BattleManager: Câmera setada para seguir o Knight.")

func _set_active_character(character: CombatCharacter):
	active_character = character
	camera.set_follow_target(character)
	print("BattleManager: Personagem ativo agora é: ", character.name)
	for member in party_members:
		member.manual_control = false
	character.manual_control = true
	
func _process(delta):
	for enemy in enemies:
		if not enemy.manual_control and enemy.has_method("update_ai"):
			enemy.update_ai(delta)

	for member in party_members:
		member._update_turn_charge(delta)

	_check_turns()

func _check_turns():
	if get_tree().paused:
		return  # já está pausado, esperando ação

	if not active_character:
		for member in party_members:
			if member.is_turn_ready:
				_pause_game_for_action(member)
				return
	else:
		print("DEBUG _check_turns: Já existe personagem ativo: ", active_character.name)
				
func _pause_game_for_action(character: CombatCharacter):
	active_character = character
	camera.set_follow_target(character)

	# Modo de câmera depende se o personagem é controlado pelo jogador
	if character.manual_control:
		camera.set_camera_to_tactical()
	else:
		camera.set_camera_to_tactical()

	get_tree().paused = true

	if hud:
		hud.show_action_menu(character)
	else:
		push_error("HUD não está definido no BattleManager ao tentar mostrar menu de ações!")


func _on_player_action_selected(action_name: String):

	match action_name:
		"attack":
			_execute_attack(active_character)
		"defend":
			_execute_defend(active_character)
		"item":
			_execute_item(active_character)

	if hud:
		hud.hide_action_menu()
	get_tree().paused = false

	active_character.turn_charge = 0.0
	active_character.is_turn_ready = false
	active_character = null
	camera.set_follow_target(player_character)  # volta a seguir o Knight
	camera.set_camera_to_combat()

	call_deferred("_check_turns")

func _execute_attack(character: CombatCharacter):
	print(character.name + " atacou!")
	character.is_performing_action = true
	character.anim.play("1H_Melee_Attack_Slice_Diagonal")

	await character.anim.animation_finished
	character.is_performing_action = false

	var attack_range = 2.0

	var possible_targets = enemies if character in party_members else party_members

	for target in possible_targets:
		if character.global_position.distance_to(target.global_position) <= attack_range:
			target.receive_damage(20)  # ou outro valor
		
func _execute_defend(character: CombatCharacter):
	print(character.name + " defendeu!")
	character.is_performing_action = true
	character.anim.play("Block")
	await character.anim.animation_finished
	character.is_performing_action = false

func _execute_item(character: CombatCharacter):
	print(character.name + " usou um item!")
	character.is_performing_action = true
	character.anim.play("Use_Item")
	await character.anim.animation_finished
	character.is_performing_action = false
	character.hp = min(character.hp + 20, character.max_hp)

func on_character_ready(character: CombatCharacter):
	# Se o jogo já está pausado (alguém no meio da ação), não faz nada
	if get_tree().paused or active_character:
		return

	# Pausa o jogo e ativa o personagem imediatamente
	_pause_game_for_action(character)
