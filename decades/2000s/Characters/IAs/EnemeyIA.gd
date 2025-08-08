extends CombatCharacter


var random = RandomNumberGenerator.new()
var attack_range := 2.0
var reached_player_time := 0.0
var wait_after_reaching := 0.5 # 1 segundo de delay antes de perseguir de novo
var aggro_target: CombatCharacter = null


func _process(delta):
	
	if not health_bar or not model:
		return

	var head_pos = model.global_transform.origin + Vector3(0, 2.5, 0)

	if not camera:
		camera = get_viewport().get_camera_3d()

	if camera:
		var screen_pos = camera.unproject_position(head_pos)
		var camera_forward = -camera.global_transform.basis.z
		var to_char = (head_pos - camera.global_transform.origin).normalized()
		var dot = camera_forward.dot(to_char)
		health_bar.visible = dot > 0.0

		# Aplica o deslocamento na posição da barra
		var offset_x = -50  # ajustar para o lado que quiser
		var offset_y = -25  # ajustar para cima/baixo

		health_bar.position = screen_pos + Vector2(offset_x, offset_y)

		# Atualiza a barra de vida
		health_bar.set_health(hp, max_hp)

		# Atualiza a barra de turno (turn_charge)
		health_bar.set_turn_charge(turn_charge, turn_threshold)
		
	if aggro_target == null or not aggro_target.is_alive():
		_update_aggro()
	
	if aggro_target != null:
		_follow_aggro_target(delta)

func _follow_aggro_target(delta):
	if is_performing_action or aggro_target == null:
		return
	
	var distance = global_position.distance_to(aggro_target.global_position)

	if distance > attack_range:
		# Checa se o tempo de espera passou
		if reached_player_time > 0.0:
			reached_player_time -= delta
			velocity = Vector3.ZERO
			is_moving = false
			anim.play("Idle")
			return

		nav_agent.target_position = aggro_target.global_position
		is_moving = true
		var next_pos = nav_agent.get_next_path_position()
		var direction = (next_pos - global_position).normalized()
		velocity = direction * move_speed
		var target_yaw = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 0.2)
		move_and_slide()
		anim.play("Walking_A")
	else:
		# Quando alcança o player, começa o delay
		reached_player_time = wait_after_reaching
		velocity = Vector3.ZERO
		is_moving = false
		anim.play("Idle")

# update_ai é chamado APENAS no turno do inimigo, para atacar
func update_ai(_delta: float) -> void:
	if aggro_target == null:
		return

	var distance_to_target = global_position.distance_to(aggro_target.global_position)

	velocity = Vector3.ZERO
	is_moving = false

	var direction = (aggro_target.global_position - global_position).normalized()
	var target_yaw = atan2(direction.x, direction.z)
	rotation.y = target_yaw

	# Sempre toca a animação de ataque, mesmo sem atingir
	await _attack_target(aggro_target)

func _attack_target(target: CombatCharacter) -> void:
	is_performing_action = true

	if anim:
		if global_position.distance_to(target.global_position) <= attack_range:
			anim.play("1H_Melee_Attack_Slice_Diagonal")
		else:
			anim.play("1H_Melee_Attack_Slice_Diagonal")  # ou uma animação "errou"
		
		await get_tree().create_timer(1.0).timeout
	else:
		await get_tree().create_timer(1.0).timeout

	if target and target.is_alive() and global_position.distance_to(target.global_position) <= attack_range:
		var manager = get_tree().get_root().get_node("Game2000/BattleManager")
		if manager:
			var damage = manager._calculate_damage(self, target)
			target.receive_damage(damage)

	is_performing_action = false


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


func _update_aggro():
	# Se não tem alvo ou alvo está morto, escolhe um novo
	if aggro_target == null or not aggro_target.is_alive():
		aggro_target = _choose_closest_player()

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
	
	# Pega o mais próximo
	var closest = alive_players[0]
	var min_dist = global_position.distance_to(closest.global_position)
	for p in alive_players:
		var dist = global_position.distance_to(p.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = p
	return closest

func receive_damage(amount: int, attacker: CombatCharacter) -> void:
	hp -= amount
	hp = max(hp, 0)
	if attacker != null and attacker.is_alive():
		aggro_target = attacker
		print(name, " recebeu ", amount, " de dano! HP antes: ", hp)

	is_performing_action = true  # BLOQUEIA movimento durante animação

	if anim:
		anim.play("Hit_B")

	if health_bar:
		health_bar.set_health(hp, max_hp)

	await get_tree().create_timer(1.0).timeout  # Espera 1 segundo

	is_performing_action = false  # Libera o movimento, se ainda estiver vivo

	if hp <= 0:
		print(name, " está morrendo")
		await _die()
