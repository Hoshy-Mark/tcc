extends CombatCharacter

var random = RandomNumberGenerator.new()
var attack_range := 2.0
var reached_player_time := 0.0
var wait_after_reaching := 0.5 # Delay antes de perseguir de novo
var aggro_target: CombatCharacter = null
var aggro_range := 10.0  # Distância de visão
var priority := 1        # Prioridade da IA
var aggro_update_timer := 0.3

# PROCESSO PRINCIPAL

func _process(delta):
	if not health_bar or not model:
		return

	aggro_update_timer -= delta
	if aggro_update_timer <= 0:
		_update_aggro()
		aggro_update_timer = 0.3
	_update_health_bar_ui()

	if aggro_target and aggro_target.is_alive():
		update_ai_movement(delta)


# LÓGICA DE MOVIMENTO

func update_ai_movement(delta):
	if is_performing_action or not aggro_target:
		return
	
	var distance = global_position.distance_to(aggro_target.global_position)

	if distance > attack_range:
		if reached_player_time > 0.0:
			reached_player_time -= delta
			_stop_moving()
			return

		var manager = get_tree().get_root().get_node("Game2000/BattleManager")
		var slot_pos = aggro_target.global_position
		if manager:
			slot_pos = get_slot_position_around_target(self, aggro_target, manager.enemies, attack_range)

		_move_towards(slot_pos)
	else:
		reached_player_time = wait_after_reaching
		_stop_moving()

# LÓGICA DE ATAQUE (TURNO)

func update_ai_attack(_delta: float) -> void:
	var target = _choose_closest_player()
	if not target or not target.is_alive():
		return
	if global_position.distance_to(target.global_position) > attack_range:
		# Se não está no alcance, não ataca
		return
	
	_stop_moving()
	_face_target(target)
	var battle_manager = get_tree().get_root().get_node("Game2000/BattleManager")
	battle_manager._execute_attack(self, target)

# FUNÇÕES AUXILIARES

func _update_health_bar_ui():
	var head_pos = model.global_transform.origin + Vector3(0, 2.5, 0)

	if not camera:
		camera = get_viewport().get_camera_3d()

	if camera:
		var screen_pos = camera.unproject_position(head_pos)
		var camera_forward = -camera.global_transform.basis.z
		var to_char = (head_pos - camera.global_transform.origin).normalized()
		var dot = camera_forward.dot(to_char)
		health_bar.visible = dot > 0.0

		health_bar.position = screen_pos + Vector2(-50, -25)
		health_bar.set_health(hp, max_hp)
		health_bar.set_turn_charge(turn_charge, turn_threshold)

func _choose_random_player() -> CombatCharacter:
	var manager = get_tree().get_root().get_node("Game2000/BattleManager")
	if manager == null:
		return null
	
	var alive_party_members = []
	for member in manager.party_members:
		if member.is_alive():
			alive_party_members.append(member)
	
	if alive_party_members.size() == 0:
		return null
	
	return alive_party_members[random.randi_range(0, alive_party_members.size() - 1)]

func _choose_closest_player() -> CombatCharacter:
	var manager = get_tree().get_root().get_node("Game2000/BattleManager")
	if manager == null:
		return null

	var alive_players = []
	for player in manager.party_members:
		if player.is_alive():
			alive_players.append(player)
	if alive_players.size() == 0:
		return null
	
	var closest = alive_players[0]
	var min_dist = global_position.distance_to(closest.global_position)
	for p in alive_players:
		var dist = global_position.distance_to(p.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = p
	return closest

func _update_aggro():
	var manager = get_tree().get_root().get_node("Game2000/BattleManager")
	if manager == null:
		if aggro_target != null:
			release_slot_of_target(aggro_target)
		aggro_target = null
		return

	var alive_players = []
	for p in manager.party_members:
		if p.is_alive() and global_position.distance_to(p.global_position) <= aggro_range:
			alive_players.append(p)

	if alive_players.size() == 0:
		if aggro_target != null:
			release_slot_of_target(aggro_target)
		aggro_target = null
		return

	var closest = alive_players[0]
	var min_dist = global_position.distance_to(closest.global_position)
	for p in alive_players:
		var dist = global_position.distance_to(p.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = p

	if aggro_target != closest:
		release_slot_of_target(aggro_target)
		aggro_target = closest

func receive_damage(amount: int, attacker: CombatCharacter) -> void:
	hp = max(hp - amount, 0)
	print(name, " recebeu ", amount, " de dano! HP atual: ", hp)

	if attacker != null and attacker.is_alive() and has_method("add_threat"):
		add_threat(attacker, amount)

	is_performing_action = true

	if health_bar:
		health_bar.set_health(hp, max_hp)

	await get_tree().create_timer(1.0).timeout
	is_performing_action = false

	if hp <= 0:
		print(name, " está morrendo")
		await _die()

func _move_towards(target_pos: Vector3):
	nav_agent.target_position = target_pos
	is_moving = true
	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	velocity = direction * move_speed
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 0.2)
	anim.play("Walking_A")

func _stop_moving():
	velocity = Vector3.ZERO
	is_moving = false
	anim.play("Idle")

func _face_target(target: CombatCharacter):
	var direction = (target.global_position - global_position).normalized()
	rotation.y = atan2(direction.x, direction.z)
