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

# Habilidade 0: Golpe Envenenado — ataque rápido que aplica veneno no alvo,
# espelhando o "poison_stab" que os Ladinos inimigos já usam.
func _cast_ability_0():
	_cast_poison_strike(self)

func _cast_poison_strike(caster: CombatCharacter2000):
	if not caster.current_target or not caster.current_target.is_alive():
		return

	caster.is_performing_action = true
	if caster.anim and caster.anim.has_animation("Dualwield_Melee_Attack_Stab"):
		caster.anim.play("Dualwield_Melee_Attack_Stab")
	elif caster.anim:
		caster.anim.play("1H_Melee_Attack_Stab")

	await get_tree().create_timer(0.4).timeout

	var target = caster.current_target
	if target and is_instance_valid(target) and target.is_alive():
		var dmg = int(caster.attack_power * 1.1) # rápido, não tão forte quanto o do Bárbaro
		target.apply_damage(dmg, caster)
		target.apply_status("poison", 10.0, caster)
		if target.has_method("add_threat"):
			target.add_threat(caster, dmg)

	caster.turn_charge = 0
	caster.is_turn_ready = false
	caster.is_performing_action = false

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

		if not acted and can_use_ability(0):
			use_ability(0)
			acted = true

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
