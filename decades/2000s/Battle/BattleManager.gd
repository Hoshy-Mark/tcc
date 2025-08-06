extends Node

var party_paths := [
	preload("res://decades/2000s/Characters/Barbarian3D.tscn"),
	preload("res://decades/2000s/Characters/Mage3D.tscn"),
	preload("res://decades/2000s/Characters/Rogue3D.tscn"),
	preload("res://decades/2000s/Characters/Knight3D.tscn")
]

var enemy_paths := [
	preload("res://decades/2000s/Characters/Enemies/Skeleton_Minion.tscn"),
	preload("res://decades/2000s/Characters/Enemies/Skeleton_Minion.tscn"),
	preload("res://decades/2000s/Characters/Enemies/Skeleton_Minion.tscn"),
	preload("res://decades/2000s/Characters/Enemies/Skeleton_Minion.tscn")
]

var party_members: Array[CombatCharacter] = []
var enemies: Array[CombatCharacter] = []
var base_height = 0.5
var active_character: CombatCharacter = null
var camera: ThirdPersonCamera3D = null
var hud: CanvasLayer = null  # <-- nova variável para armazenar o HUD
var player_character: CombatCharacter = null
var is_processing_turn = false
var is_player_choosing_action: bool = false
var is_tactical_pause_active := false

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
			player_character = char
		else:
			char.manual_control = false  # serão IA no futuro

		print("BattleManager: Personagem da party instanciado: ", char.name)
		
func _spawn_enemies():
	var positions = [
		Vector3(8, 0, 8),
		Vector3(4, 0, 8),
		Vector3(2, 0, 8),
		Vector3(6, 0, 8)
	]

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

	for member in party_members:
		member.manual_control = (member == character and character == player_character)
	
func _process(delta):
	if Input.is_action_just_pressed("strategic_pause"):
		_toggle_tactical_pause()
		return  # Para evitar qualquer outro processamento no mesmo frame
		
	if is_tactical_pause_active:
		_handle_tactical_camera_movement(delta)
		return
	
	# Atualiza e processa inimigos
	for enemy in enemies:
		enemy._update_turn_charge(delta)
		enemy._update_vision_cone(player_character, 2.0)
		if enemy.is_turn_ready and not enemy.is_performing_action:
			enemy.is_performing_action = true  # Marca como ocupado
			await _handle_ai_turn(enemy)
			enemy.turn_charge = 0.0
			enemy.is_turn_ready = false
			enemy.is_performing_action = false  # Libera depois da ação

	# Atualiza e processa membros da party
	for member in party_members:
		member._update_turn_charge(delta)

		if not member.manual_control and not member.is_performing_action:
			await member.update_ai(delta)
			var attack_range = 2.0
			var closest_enemy: CombatCharacter = null
			var min_dist = INF
			for enemy in enemies:
				var dist = member.global_position.distance_to(enemy.global_position)
				if dist < min_dist:
					min_dist = dist
					closest_enemy = enemy
			if closest_enemy:
				member._update_vision_cone(closest_enemy, attack_range)

		# Atualiza o cone de visão para o player controlado manualmente
		if member == player_character:
			var attack_range = 2.0
			var closest_enemy: CombatCharacter = null
			var min_dist = INF
			for enemy in enemies:
				var dist = player_character.global_position.distance_to(enemy.global_position)
				if dist < min_dist:
					min_dist = dist
					closest_enemy = enemy
			if closest_enemy:
				player_character._update_vision_cone(closest_enemy, attack_range)

		# Se for o player manual e pronto, mostra menu de ação
		if member.is_turn_ready and member == player_character and not is_player_choosing_action:
			is_player_choosing_action = true
			if hud:
				hud.show_action_menu(member)


func _on_player_end_turn():
	if not active_character:
		return

	# Finaliza o turno do personagem manual
	active_character.turn_charge = 0.0
	active_character.is_turn_ready = false
	active_character = null

	get_tree().paused = false

	camera.set_follow_target(player_character)
	camera.set_camera_to_combat()

	call_deferred("_check_turns")



func on_character_ready(character: CombatCharacter):
	# Se o jogo já está pausado (alguém no meio da ação), não faz nada
	if get_tree().paused or active_character:
		return

func _calculate_damage(attacker: CombatCharacter, target: CombatCharacter) -> int:
	var base_damage = 20
	var attacker_dir = (target.global_position - attacker.global_position).normalized()
	var target_forward = -target.global_transform.basis.z.normalized()
	var dot = attacker_dir.dot(target_forward)

	if dot > 0.75:
		# ataque pelas costas
		return base_damage * 2
	elif dot > 0.3:
		# ataque lateral
		return base_damage * 1.5
	else:
		return base_damage

func _handle_ai_turn(character: CombatCharacter) -> void:
	if character.has_method("update_ai"):
		print("[AI TURN] Executando IA de ", character.name)
		await character.update_ai(get_process_delta_time())
	else:
		push_error("Character " + character.name + " não tem método update_ai()")


# O jogador escolhe a ação, então no handler:
func _on_player_action_selected(action_name: String):
	if is_tactical_pause_active:
		return

	match action_name:
		"attack":
			await _execute_attack(player_character)
		"defend":
			await _execute_defend(player_character)
		"item":
			await _execute_item(player_character)

	if hud:
		hud.hide_action_menu()

	player_character.turn_charge = 0.0
	player_character.is_turn_ready = false
	is_player_choosing_action = false

func _execute_attack(character: CombatCharacter):
	if character == null:
		return
	
	print(character.name + " atacou!")
	character.is_performing_action = true
	
	# Toca animação de ataque
	if character.anim:
		character.anim.play("1H_Melee_Attack_Slice_Diagonal")
		await character.anim.animation_finished
	
	character.is_performing_action = false

	var attack_range = 2.0
	var possible_targets = enemies if character in party_members else party_members
	
	# Verifica o alvo mais próximo dentro do alcance
	var closest_target: CombatCharacter = null
	var min_distance := INF

	for target in possible_targets:
		var dist = character.global_position.distance_to(target.global_position)
		if dist <= attack_range and dist < min_distance:
			min_distance = dist
			closest_target = target

	# Se encontrou um alvo válido, aplica o dano
	if closest_target:
		var damage = _calculate_damage(character, closest_target)
		print(closest_target.name, " recebeu ", damage, " de dano! HP antes: ", closest_target.hp)
		closest_target.receive_damage(damage)
		print(closest_target.name, " HP depois do dano: ", closest_target.hp)
	else:
		print("Nenhum alvo dentro do alcance para ", character.name)

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

func _auto_attack(character: CombatCharacter) -> void:
	if is_tactical_pause_active:
		return  # bloqueia ataque automático durante pausa tática
	if character.is_performing_action:
		return  # já está atacando
	if character.manual_control:
		push_warning("Player não deve atacar automaticamente")
		return
	await _execute_attack(character)

func _handle_party_member_ai_turn(member: CombatCharacter) -> void:
	var attack_range = 2.0
	var safe_distance = 5.0

	var possible_targets = enemies.filter(func(e): return e.is_alive())
	if possible_targets.size() == 0:
		return

	var target = possible_targets[randi() % possible_targets.size()]
	var dist = member.global_position.distance_to(target.global_position)

	if member.turn_charge < member.turn_threshold * 0.5:
		var direction_away = (member.global_position - target.global_position).normalized()
		var desired_pos = target.global_position + direction_away * safe_distance
		member.nav_agent.target_position = desired_pos
		member.is_moving = true
	elif dist <= attack_range:
		member.is_moving = false
		member.velocity = Vector3.ZERO
		var dir_to_target = (target.global_position - member.global_position).normalized()
		member.rotation.y = atan2(dir_to_target.x, dir_to_target.z)
		await member._attack_target(target)
	else:
		member.nav_agent.target_position = target.global_position
		member.is_moving = true

func _toggle_tactical_pause():
	is_tactical_pause_active = !is_tactical_pause_active

	if is_tactical_pause_active:
		print("Modo estratégico ativado")
		if camera:
			camera.set_follow_target(null)
			camera.set_camera_to_tactical()

		for char in party_members + enemies:
			char.manual_control = false
			char.is_performing_action = true
			char.velocity = Vector3.ZERO  # <- para qualquer movimento
			if char.anim:
				char.anim.pause()
	else:
		print("Modo estratégico desativado")
		if camera:
			camera.set_follow_target(player_character)
			camera.set_camera_to_combat()

		for char in party_members:
			if char == player_character:
				char.manual_control = true
			char.is_performing_action = false
			if char.anim:
				char.anim.play("Idle")  # volta a tocar animação

		for enemy in enemies:
			enemy.is_performing_action = false
			if enemy.anim:
				enemy.anim.play("Idle")

func _handle_tactical_camera_movement(delta):
	if not camera:
		return

	var speed := 10.0
	var dir := Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		dir.z -= 1
	if Input.is_action_pressed("move_backward"):
		dir.z += 1
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_right"):
		dir.x += 1

	if dir != Vector3.ZERO:
		dir = dir.normalized()
		camera.translate(dir * speed * delta)

func _anyone_is_acting() -> bool:
	for char in party_members + enemies:
		if char.is_performing_action:
			return true
	return false

func _unhandled_input(event):
	if not is_tactical_pause_active:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_tactical_click(event.position)
		
func _handle_tactical_click(mouse_pos: Vector2):
	var viewport = get_viewport()
	var camera = viewport.get_camera_3d()
	if not camera:
		return

	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0

	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)

	if result:
		var clicked_node = result["collider"]
		if clicked_node and clicked_node is CombatCharacter:
			if clicked_node in party_members:
				_set_new_player_character(clicked_node)
				
func _set_new_player_character(new_char: CombatCharacter):
	if new_char == player_character:
		return  # Já é o personagem ativo

	print("Novo personagem ativo:", new_char.name)

	# Desativa o anterior
	if player_character:
		player_character.manual_control = false

	# Ativa o novo personagem
	player_character = new_char
	player_character.manual_control = true

	# Atualiza a câmera
	if camera:
		camera.set_follow_target(player_character)
		camera.set_camera_to_combat()

	# Se estava em modo tático, desativa
	if is_tactical_pause_active:
		is_tactical_pause_active = false
		print("Saindo do modo tático por seleção de personagem")

		# Restaura animações e estados dos personagens
		for char in party_members:
			char.is_performing_action = false
			if char.anim:
				char.anim.play("Idle")
		
		for enemy in enemies:
			enemy.is_performing_action = false
			if enemy.anim:
				enemy.anim.play("Idle")
