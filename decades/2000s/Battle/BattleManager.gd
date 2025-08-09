extends Node

var party_paths := [
	preload("res://decades/2000s/Characters/Barbarian3D.tscn"),
	preload("res://decades/2000s/Characters/Mage3D.tscn"),
	preload("res://decades/2000s/Characters/Rogue3D.tscn"),
	preload("res://decades/2000s/Characters/Knight3D.tscn")
]

var enemy_paths := [
	preload("res://decades/2000s/Characters/Enemies/Skeleton_Minion.tscn"),
]

var base_height = 0.5
var active_character: CombatCharacter = null
var camera: ThirdPersonCamera3D = null
var hud: CanvasLayer = null  # <-- nova variável para armazenar o HUD
var is_processing_turn = false
var enemies: Array[CombatCharacter] = []
var party_members: Array[CombatCharacter] = []
var player_character: CombatCharacter = null

# Sistema de XP e Nível do Grupo
var group_level: int = 1
var group_xp: int = 0
var xp_per_enemy: int = 20  # XP que cada inimigo derrotado dá
var hordes_defeated: int = 0
var max_hordes: int = 3
var enemies_per_horde: int = 6

# Controle do combate
var is_tactical_pause_active := false
var is_player_choosing_action := false
var player_auto_attacking := false

# Constantes
const ATTACK_RANGE := 2.0

func _ready():
	_spawn_party()
	_spawn_new_horde()

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
		# Não permite sair se o editor estiver aberto
		var editor = get_tree().get_root().find_child("GambitEditor", true, false)
		if editor and editor.visible:
			return
		_toggle_tactical_pause()
		return


	if is_tactical_pause_active:
		# Verifica se o editor está aberto
		var editor = get_tree().get_root().find_child("GambitEditor", true, false)
		if editor and editor.visible:
			return  # Não permite sair do modo tático com tecla enquanto editor estiver visível
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

		if not member.manual_control and not member.is_performing_action and member != player_character:
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
		
	# Atualizar turn charge de todo mundo
	for char in party_members + enemies:
		if char.is_alive():
			char._update_turn_charge(delta)

	# Loop de ataque automático do player
	if player_auto_attacking and player_character and player_character.current_target:
		
		var tgt = player_character.current_target

		if not tgt.is_alive():
			print("Alvo morto, parando auto ataque.")
			player_auto_attacking = false
			player_character.is_moving = false
			player_character.manual_control = true
			return

		if player_character.hp <= 0:
			player_auto_attacking = false
			player_character.is_moving = false
			return

		if player_character.is_performing_action:
			return # espera terminar ação

		var dist = player_character.global_position.distance_to(tgt.global_position)
		
		if dist > ATTACK_RANGE:
			player_character.manual_control = false  # garante movimento automático
			player_character.nav_agent.target_position = tgt.global_position
			player_character.is_moving = true
		else:
			player_character.is_moving = false
			player_character.manual_control = true
			if player_character.is_turn_ready:
				await _execute_attack(player_character)
				player_character.turn_charge = 50
				player_character.is_turn_ready = false


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
	var base_damage = attacker.attack_power
	var defense_factor = max(0.5, 1.0 - (target.defense / 200.0)) # Defesa reduz dano
	var damage = base_damage * defense_factor

	# Crítico
	if randi_range(1, 100) <= attacker.crit_chance:
		damage *= 1.5
		print("CRÍTICO!")

	# Ataque pelas costas bônus
	var attacker_dir = (target.global_position - attacker.global_position).normalized()
	var target_forward = -target.global_transform.basis.z.normalized()
	var dot = attacker_dir.dot(target_forward)

	if dot > 0.75:
		damage *= 1.5

	return int(max(1, damage))

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
			if player_character.current_target and player_character.current_target.is_alive():
				player_auto_attacking = true
				print("Auto ataque iniciado contra", player_character.current_target.name)
			else:
				print("Nenhum alvo válido.")
		"item":
			player_auto_attacking = false
			await _execute_item(player_character)
		"defend":
			player_auto_attacking = false
			await _execute_defend(player_character)

	if hud:
		hud.hide_action_menu()

	is_player_choosing_action = false

func _execute_attack(attacker: CombatCharacter) -> void:
	if not attacker.current_target or not attacker.current_target.is_alive():
		return

	attacker.is_performing_action = true

	# Rolagem de acerto simples
	var attack_roll = randi_range(1, 20)
	var target_roll = randi_range(1, 20)

	if attack_roll >= target_roll:
		print(attacker.name, "acertou", attacker.current_target.name)
		attacker.anim.play("1H_Melee_Attack_Slice_Diagonal", -1, 2.0)
		await get_tree().create_timer(1.0).timeout

		# Aplica o hit usando o sistema novo
		_apply_hit(attacker, attacker.current_target)
	else:
		attacker.anim.play("1H_Melee_Attack_Chop", -1, 2.0)
		await get_tree().create_timer(1.0).timeout
		print(attacker.name, "errou o ataque")

	attacker.is_performing_action = false

func _execute_item(user: CombatCharacter) -> void:
	print(user.name, "usou um item")
	await get_tree().create_timer(0.5).timeout

func _execute_defend(user: CombatCharacter) -> void:
	print(user.name, "defendeu")
	await get_tree().create_timer(0.5).timeout

func _auto_attack(character: CombatCharacter) -> void:
	if is_tactical_pause_active:
		return  # bloqueia ataque automático durante pausa tática
	if character.is_performing_action:
		return  # já está atacando
	if character.manual_control and character == player_character:
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
			if char == player_character:
				char.active = true
			char.manual_control = false
			char.is_performing_action = true
			char.velocity = Vector3.ZERO
			if char.anim:
				char.anim.pause()

		# Desativa botão Gambit
		if hud:
			hud.set_gambit_button_enabled(false)

	else:
		print("Modo estratégico desativado")
		if camera:
			camera.set_follow_target(player_character)
			camera.set_camera_to_combat()

		for char in party_members:
			if char == player_character:
				char.manual_control = true
			char.active = false
			char.is_performing_action = false
			if char.anim:
				char.anim.play("Idle")

		for enemy in enemies:
			enemy.is_performing_action = false
			if enemy.anim:
				enemy.anim.play("Idle")

		# Reativa botão Gambit
		if hud:
			hud.set_gambit_button_enabled(true)

func _handle_tactical_camera_movement(delta):
	if not camera:
		return

	var speed := 10.0
	var input_dir := Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x += 1
	if Input.is_action_pressed("move_right"):
		input_dir.x -= 1

	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()

		# Obtém a rotação atual da câmera (spring arm)
		var basis := camera.spring_arm.global_transform.basis

		# Pega apenas os vetores horizontalmente (ignora Y)
		var forward := -basis.z
		forward.y = 0
		forward = forward.normalized()

		var right := basis.x
		right.y = 0
		right = right.normalized()

		# Move baseado na direção da câmera
		var move_vector = (forward * input_dir.z + right * input_dir.x).normalized()

		camera.translate(move_vector * speed * delta)

func _anyone_is_acting() -> bool:
	for char in party_members + enemies:
		if char.is_performing_action:
			return true
	return false

func _unhandled_input(event):
	if is_tactical_pause_active:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_tactical_click(event.position)
	else:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_combat_click(event.position)

func _handle_combat_click(mouse_pos: Vector2):
	var camera = get_viewport().get_camera_3d()
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
		if clicked_node and clicked_node in enemies and clicked_node.is_alive():
			player_character.current_target = clicked_node
			print("Novo alvo:", clicked_node.name)

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
		player_character.active = false

	# Ativa o novo personagem
	player_character = new_char
	player_character.manual_control = true
	player_character.active = true

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

		# <<< Aqui reativa o botão de Gambit
		if hud:
			hud.set_gambit_button_enabled(true)

func get_party_members() -> Array:
	return party_members

func _apply_hit(attacker: CombatCharacter, target: CombatCharacter):
	var damage = _calculate_damage(attacker, target)
	target.apply_damage(damage, attacker) # Aqui entra defesa/esquiva

func add_group_xp(amount: int) -> void:
	group_xp += amount
	print("Grupo ganhou %d XP (Total: %d)" % [amount, group_xp])

	var xp_to_next_level = 100 * group_level
	if group_xp >= xp_to_next_level:
		group_xp -= xp_to_next_level
		group_level += 1
		print("🎉 Grupo subiu para o nível %d!" % group_level)
		
		for member in party_members:
			if not member.has_meta("points_to_spend"):
				member.level += 1
				member.set_meta("points_to_spend", 0)
			member.set_meta("points_to_spend", member.get_meta("points_to_spend") + 5)
		
func _check_enemies_defeated():
	if enemies.is_empty():
		hordes_defeated += 1
		print("Horda %d derrotada!" % hordes_defeated)

		if hordes_defeated >= max_hordes:
			print("🏆 Todas as hordas derrotadas! Vitória!")
			return

		print("Preparando próxima horda...")
		await get_tree().create_timer(2.0).timeout
		_spawn_new_horde()
		
func _spawn_new_horde():
	enemies.clear()
	for i in range(enemies_per_horde):
		var enemy_scene = enemy_paths[randi() % enemy_paths.size()]
		var enemy: CombatCharacter = enemy_scene.instantiate()
		add_child(enemy)
		enemy.global_position = Vector3(randf_range(2, 8), base_height, randf_range(6, 10))
		enemy.manual_control = false
		enemies.append(enemy)
		print("Novo inimigo spawnado:", enemy.name)
