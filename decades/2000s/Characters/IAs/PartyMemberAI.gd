extends CombatCharacter

var attack_range := 2.0
var safe_distance := 5.0
var target_enemy: CombatCharacter = null

var wait_after_enemy_move := 0.5
var wait_timer := 0.0

var random = RandomNumberGenerator.new()
var last_enemy_pos := Vector3.ZERO

func _ready():
	super._ready()
	random.randomize()
	move_speed = 1

func update_ai(_delta: float) -> void:
	if is_performing_action:
		return

	# Escolhe alvo aleatório se não tiver ou alvo morreu
	if target_enemy == null or not target_enemy.is_alive():
		target_enemy = _choose_random_enemy()
		if target_enemy == null:
			_stop_moving()
			return

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
			var safe_pos = target_enemy.global_position + away_dir * (attack_range * 1.5)
			nav_agent.target_position = safe_pos
			_move_towards(nav_agent.get_next_path_position())
		else:
			_stop_moving()
	else:
		# Turno carregado > 50%, parte para o ataque
		if distance > attack_range:
			nav_agent.target_position = target_enemy.global_position
			_move_towards(nav_agent.get_next_path_position())
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
	var direction = (position - global_position).normalized()
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
