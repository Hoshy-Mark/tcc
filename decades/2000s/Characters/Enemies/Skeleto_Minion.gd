extends CombatCharacter

var player_character: CombatCharacter = null
var attack_range := 2.0
var reached_player_time := 0.0
var wait_after_reaching := 0.5 # 1 segundo de delay antes de perseguir de novo

func _ready():
	super._ready()
	model = $Skeleton_Minion
	anim = model.get_node("AnimationPlayer")
	move_speed = 2.0 

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
		
	if player_character == null:
		var manager := get_tree().get_root().get_node("Game2000/BattleManager")
		if manager:
			player_character = manager.player_character

	if player_character:
		_follow_player(delta)

func _follow_player(delta):
	if is_performing_action:
		return

	var distance = global_position.distance_to(player_character.global_position)

	if distance > attack_range:
		# Checa se o tempo de espera passou
		if reached_player_time > 0.0:
			reached_player_time -= delta
			velocity = Vector3.ZERO
			is_moving = false
			anim.play("Idle")
			return

		nav_agent.target_position = player_character.global_position
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
	if player_character == null:
		return

	var distance_to_target = global_position.distance_to(player_character.global_position)

	velocity = Vector3.ZERO
	is_moving = false

	var direction = (player_character.global_position - global_position).normalized()
	var target_yaw = atan2(direction.x, direction.z)
	rotation.y = target_yaw

	# Sempre toca a animação de ataque, mesmo sem atingir
	await _attack_target(player_character)

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
