extends "res://decades/2000s/Characters/IAs/PartyMemberAI.gd"

const LOW_HP_THRESHOLD = 60  # ou algum percentual do max_hp

func _ready():
	super._ready()
	model = $Knight
	anim = model.get_node("AnimationPlayer")
	name = "Cavaleiro"
	strength = 12
	dexterity = 8
	constitution = 14
	intelligence = 2
	wisdom = 4
	has_shield = true
	_recalculate_stats()

func update_ai(delta):
	if is_performing_action:
		return
	
	var manager = get_tree().get_root().get_node("Game2000/BattleManager")
	if not manager:
		return

	var ally_in_danger = null
	for ally in manager.party_members:
		if ally != self and ally.is_alive() and ally.hp <= LOW_HP_THRESHOLD:
			ally_in_danger = ally
			break

	var target = null
	if ally_in_danger != null:
		for enemy in manager.enemies:
			if enemy.is_alive() and enemy.current_target == ally_in_danger:
				target = enemy
				break

	if target == null:
		target = _choose_closest_enemy()

	if target == null:
		_stop_moving()
		return

	current_target = target
	var dist = global_position.distance_to(target.global_position)

	# Se o inimigo se mexeu e está longe o suficiente, resetar o timer e parar movimento
	if _enemy_moved() and dist > attack_range + 0.5:
		wait_timer = wait_after_enemy_move
		_stop_moving()
		return

	# Se estiver perto do inimigo, libera o timer para mover sem atraso
	if dist <= attack_range + 0.1:
		wait_timer = 0.0

	if wait_timer > 0:
		wait_timer -= delta
		_stop_moving()
		return

	if dist > attack_range:
		nav_agent.target_position = target.global_position
		_move_towards(target.global_position)
	else:
		_stop_moving()

	last_enemy_pos = target.global_position

	if is_turn_ready and not is_performing_action:
		is_performing_action = true

		# Gambits primeiro
		var acted := false
		for gambit in gambits:
			if gambit != null and gambit.is_condition_met(self):
				await gambit.execute_action(self)
				acted = true
				break

		if not acted:
			if current_target != null:
				var target_pos = current_target.global_position
				target_pos.y = global_position.y  # mantem na mesma altura
				
				look_at(target_pos, Vector3.UP)
				
				# Ajusta para olhar de frente se o modelo estiver de costas
				rotation.y += PI  # gira 180 graus no eixo Y
			await _attack_target(target)

		turn_charge = 0
		is_turn_ready = false
		is_performing_action = false


func _choose_closest_enemy() -> CombatCharacter2000:
	var manager = get_tree().get_root().get_node("Game2000/BattleManager")
	var min_dist = 99999
	var closest_enemy = null
	for enemy in manager.enemies:
		if enemy.is_alive():
			var d = global_position.distance_to(enemy.global_position)
			if d < min_dist:
				min_dist = d
				closest_enemy = enemy
	return closest_enemy
