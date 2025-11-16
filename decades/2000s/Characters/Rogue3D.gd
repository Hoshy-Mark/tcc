extends "res://decades/2000s/Characters/IAs/PartyMemberAI.gd"

func _ready():
	super._ready()
	model = $Rogue
	anim = model.get_node("AnimationPlayer")
	name = "Ladrão"
	strength = 8
	dexterity = 14
	constitution = 8
	intelligence = 6
	wisdom = 4
	_recalculate_stats()

func update_ai(delta):
	if is_performing_action:
		return

	var manager = get_tree().get_root().get_node("Game2000/BattleManager")
	if not manager:
		return

	if current_target == null or not current_target.is_alive():
		current_target = _choose_lowest_hp_enemy()
		if current_target == null:
			_stop_moving()
			return

	var dist = global_position.distance_to(current_target.global_position)

	if wait_timer > 0:
		wait_timer -= delta
		_stop_moving()
		return

	if _enemy_moved():
		wait_timer = wait_after_enemy_move
		_stop_moving()
		return

	if dist > attack_range:
		nav_agent.target_position = current_target.global_position
		_move_towards(current_target.global_position)
	else:
		_stop_moving()

	last_enemy_pos = current_target.global_position

	if is_turn_ready and not is_performing_action:
		is_performing_action = true

		current_target = _choose_lowest_hp_enemy()

		if current_target != null:
			var target_pos = current_target.global_position
			target_pos.y = global_position.y
			look_at(target_pos, Vector3.UP)
			rotation.y += PI

		var acted := false
		for gambit in gambits:
			if gambit != null and gambit.is_condition_met(self):
				await gambit.execute_action(self)
				acted = true
				break

		if not acted:
			await _attack_target(current_target)

		turn_charge = 0
		is_turn_ready = false
		is_performing_action = false

func _choose_lowest_hp_enemy() -> CombatCharacter2000:
	var manager = get_tree().get_root().get_node("Game2000/BattleManager")
	if manager == null:
		return null

	var target = null
	var min_hp = 999999
	for enemy in manager.enemies:
		if enemy.is_alive() and enemy.hp < min_hp:
			min_hp = enemy.hp
			target = enemy
	return target
