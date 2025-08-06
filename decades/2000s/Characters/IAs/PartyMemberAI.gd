extends CombatCharacter

var attack_range := 2.0
var safe_distance := 1.5
var target_enemy: CombatCharacter = null

var wait_after_enemy_move := 0.5
var wait_timer := 0.0
var party: Array = []
var random = RandomNumberGenerator.new()
var last_enemy_pos := Vector3.ZERO

func _ready():
	super._ready()
	random.randomize()
	move_speed = 2

func update_ai(_delta: float) -> void:
	if is_performing_action:
		return

	if target_enemy == null or not target_enemy.is_alive():
		target_enemy = _choose_random_enemy()
		if target_enemy == null:
			var avoid_pos = _avoid_allies(global_position)
			if avoid_pos != global_position:
				_move_towards(avoid_pos)
			else:
				_stop_moving()
			return  # importante sair para evitar usar target_enemy nulo


	var distance = global_position.distance_to(target_enemy.global_position)
	var turn_ratio = turn_charge / turn_threshold

	# Se está esperando antes de perseguir o inimigo, decrementa timer
	if wait_timer > 0:
		wait_timer -= _delta
		_stop_moving()
		return

	# Decide comportamento baseado no turno carregado
	if turn_ratio < 0.5:
		# Fica fora do alcance, tentando se afastar se muito perto
		if distance < attack_range * 1.5:
			var away_dir = (global_position - target_enemy.global_position).normalized()
			var safe_pos = _avoid_allies(target_enemy.global_position + away_dir * (attack_range * 1.5))
			nav_agent.target_position = safe_pos
			var next_pos = nav_agent.get_next_path_position()
			var avoid_pos = _avoid_allies(next_pos)
			_move_towards(avoid_pos)
		else:
			_stop_moving()
	else:
		# Turno carregado > 50%, parte para o ataque
		if distance > attack_range:
			nav_agent.target_position = target_enemy.global_position
			var next_pos = nav_agent.get_next_path_position()
			var avoid_pos = _avoid_allies(next_pos)
			_move_towards(avoid_pos)
		else:
			# Está no alcance, para de andar e ataca
			_stop_moving()

			# Se inimigo se moveu, espera 0.5s antes de perseguir de novo
			if _enemy_moved():
				wait_timer = wait_after_enemy_move

	# Se o turno está cheio e não está atacando, inicia ataque automático
	if is_turn_ready and not is_performing_action:
		is_performing_action = true
		await _attack_target(target_enemy)
		turn_charge = 0.0
		is_turn_ready = false
		is_performing_action = false

func _move_towards(position: Vector3) -> void:
	position = _avoid_allies(position)
	var direction = (position - global_position)
	direction.y = 0  # Garantir que movimento fique no plano XZ
	if direction.length() == 0:
		_stop_moving()
		return

	direction = direction.normalized()
	velocity = direction * move_speed
	is_moving = true
	
	var target_yaw = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 0.2)
	
	move_and_slide()

	if anim and not anim.is_playing():
		anim.play("Walking_A")

func _stop_moving() -> void:
	velocity = Vector3.ZERO
	is_moving = false
	move_and_slide()
	if anim and anim.current_animation != "Idle":
		anim.play("Idle")

func _enemy_moved() -> bool:
	if target_enemy == null:
		return false
	
	var moved = target_enemy.global_position.distance_to(last_enemy_pos) > 0.1
	if moved:
		last_enemy_pos = target_enemy.global_position
	return moved

func _choose_random_enemy() -> CombatCharacter:
	var manager = get_tree().get_root().get_node("Game2000/BattleManager")
	if manager == null:
		return null
	
	var alive_enemies = []
	for enemy in manager.enemies:
		if enemy.is_alive():
			alive_enemies.append(enemy)
	if alive_enemies.size() == 0:
		return null
	
	return alive_enemies[random.randi_range(0, alive_enemies.size() - 1)]

func _attack_target(target: CombatCharacter) -> void:
	if anim:
		if global_position.distance_to(target.global_position) <= attack_range:
			anim.play("1H_Melee_Attack_Slice_Diagonal")
		else:
			anim.play("1H_Melee_Attack_Slice_Diagonal") # Animação mesmo que não acerte
		
		await get_tree().create_timer(1.0).timeout
	else:
		await get_tree().create_timer(1.0).timeout
	
	if target and target.is_alive() and global_position.distance_to(target.global_position) <= attack_range:
		var manager = get_tree().get_root().get_node("Game2000/BattleManager")
		if manager:
			var damage = manager._calculate_damage(self, target)
			target.receive_damage(damage)

func _avoid_allies(position: Vector3) -> Vector3:
	var separation_force := Vector3.ZERO
	var manager = get_tree().get_root().get_node("Game2000/BattleManager")
	if manager == null:
		return position
		
	var party = manager.party_members
	if typeof(party) != TYPE_ARRAY:
		return position
		
	for ally in party:
		if ally != self and ally.is_alive():
			var dist = global_position.distance_to(ally.global_position)
			
			# Vetor direção só no plano XZ
			var push_dir = (global_position - ally.global_position)
			push_dir.y = 0
			push_dir = push_dir.normalized()

			if dist < 1.0:
				# Evita colisão muito próxima com força alta
				var strength = (2.0 - dist) * 3.0  # Força extra para separação urgente
				separation_force += push_dir * strength
			elif dist < safe_distance:
				# Aplicar separação suave normal
				var strength = (safe_distance - dist) / safe_distance
				separation_force += push_dir * strength

	if separation_force == Vector3.ZERO:
		print("[Desvio] Nenhum desvio necessário.")
		return position
	else:
		# Aplique força normalizada e também zere Y para não subir
		separation_force.y = 0
		var adjusted = position + separation_force.normalized()
		print("[Desvio] Posição original: ", position)
		print("[Desvio] Ajustada para: ", adjusted)
		return adjusted
