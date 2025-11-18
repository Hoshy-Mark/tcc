extends "res://decades/2000s/Characters/IAs/PartyMemberAI.gd"

const SAFE_DISTANCE = 15.0
var current_safe_point: Vector3 = Vector3.ZERO
var safe_point_valid: bool = false

func _ready():
	super._ready()
	model = $Mage
	anim = model.get_node("AnimationPlayer")
	name = "Mago"
	strength = 4
	dexterity = 8
	constitution = 8
	intelligence = 14
	wisdom = 6
	_recalculate_stats()


func update_ai(delta):
	if is_performing_action:
		return
	
	var manager = get_tree().get_root().get_node("Game2000/BattleManager")
	if not manager:
		return
	
	if current_target == null or not current_target.is_alive():
		current_target = _choose_target_based_on_strategy()
		if current_target == null:
			_stop_moving()
			return
	
	# timers
	if reposition_timer > 0:
		reposition_timer -= delta
	if threat_timer > 0:
		threat_timer -= delta
	
	var dist = global_position.distance_to(current_target.global_position)
	
	# Checa se algum inimigo está "invadindo" o safe point atual
	var any_enemy_too_close = false
	for enemy in manager.enemies:
		if enemy.is_alive() and enemy.global_position.distance_to(current_safe_point) < SAFE_DISTANCE * 0.8:
			any_enemy_too_close = true
			break
	
	# Recalcula safe point apenas se atual inválido ou comprometido
	if not safe_point_valid or any_enemy_too_close:
		current_safe_point = _find_safe_point_away_from_all(manager.enemies, SAFE_DISTANCE)
		safe_point_valid = current_safe_point != Vector3.ZERO
		reposition_timer = 0  # libera movimentação imediata ao mudar safe point
	
	# Se estiver em zona de perigo, usa safe point guardado
	if dist <= danger_radius:
		if safe_point_valid and reposition_timer <= 0:
			nav_agent.target_position = current_safe_point
			_move_towards(current_safe_point)
			reposition_timer = reposition_cooldown
			threat_timer = 0

	elif dist <= threat_radius:
		if threat_timer <= 0:
			threat_timer = threat_tolerance
		elif threat_timer <= 0.001 and reposition_timer <= 0:
			var safe_point2 = _find_reposition_point_away_from(current_target, SAFE_DISTANCE)
			if safe_point2 != null and safe_point2 != Vector3.ZERO:
				nav_agent.target_position = safe_point2
				_move_towards(safe_point2)
				reposition_timer = reposition_cooldown
				threat_timer = 0
			else:
				_stop_moving()
	else:
		if dist > SAFE_DISTANCE + 0.2:
			var dir = (current_target.global_position - global_position).normalized()
			var desired_pos = current_target.global_position - dir * SAFE_DISTANCE
			nav_agent.target_position = desired_pos
			_move_towards(desired_pos)
		elif dist < SAFE_DISTANCE - 0.2:
			var dir = (global_position - current_target.global_position).normalized()
			var desired_pos = current_target.global_position + dir * SAFE_DISTANCE
			nav_agent.target_position = desired_pos
			_move_towards(desired_pos)
		else:
			_stop_moving()
	
	last_enemy_pos = current_target.global_position
	
	if is_turn_ready and not is_performing_action:
		current_target = _choose_target_based_on_strategy()
		if current_target == null:
			_stop_moving()
			return

		if can_use_ability(0):
			is_performing_action = true

			var acted := false
			for gambit in gambits:
				if gambit != null and gambit.is_condition_met(self):
					await gambit.execute_action(self)
					acted = true
					break

			if not acted:
				use_ability(0)
				if current_target != null:
					var target_pos = current_target.global_position
					target_pos.y = global_position.y
					look_at(target_pos, Vector3.UP)

			turn_charge = 0
			is_turn_ready = false
			is_performing_action = false


func _find_safe_point_away_from_all(enemies, desired_distance: float) -> Vector3:
	if enemies.size() == 0:
		return Vector3.ZERO

	var origin = global_position
	var space = get_world_3d().direct_space_state

	var sample_angles = [0, 0.33, -0.33, 0.66, -0.66, 1.0, -1.0]
	for a in sample_angles:
		var ang = a * PI
		var dir = Vector3(sin(ang), 0, cos(ang)).normalized()
		var candidate = origin + dir * desired_distance
		candidate.y = origin.y

		var too_close = false
		for enemy in enemies:
			if enemy.is_alive() and enemy.global_position.distance_to(candidate) < desired_distance * 0.7:
				too_close = true
				break
		if too_close:
			continue

		var fromp = origin + Vector3(0, 0.6, 0)
		var top = candidate + Vector3(0, 0.6, 0)
		var query = PhysicsRayQueryParameters3D.new()
		query.from = fromp
		query.to = top
		query.exclude = [self]
		query.collision_mask = 1
		var res = space.intersect_ray(query)
		if res:
			continue

		return candidate

	return Vector3.ZERO


func _cast_fireball(caster: CombatCharacter2000):
	if not caster.current_target:
		return
	caster.is_performing_action = true
	if caster.anim:
		caster.anim.play("Spellcast_Shoot", -1, 1.5)
	else:
		push_error("Caster não tem anim definido!")

	await get_tree().create_timer(0.5).timeout

	var projectile_scene = preload("res://decades/2000s/Characters/Projectile.tscn")
	var projectile = projectile_scene.instantiate()
	projectile.global_position = caster.global_position + Vector3(0, 1.5, 0)
	projectile.target = caster.current_target

	get_tree().current_scene.add_child(projectile)

	caster.turn_charge = 0
	caster.is_turn_ready = false
	caster.is_performing_action = false

	
func _cast_ability_0():
	_cast_fireball(self)

func _choose_target_based_on_strategy() -> CombatCharacter2000:
	var manager = get_tree().get_root().get_node("Game2000/BattleManager")
	if manager == null:
		return null

	var target = null
	var max_hp = -1
	for enemy in manager.enemies:
		if enemy.is_alive() and enemy.hp > max_hp:
			max_hp = enemy.hp
			target = enemy
	return target

func _find_reposition_point_away_from(target: CombatCharacter2000, desired_distance: float) -> Vector3:
	if target == null:
		return Vector3.ZERO  # Retorno consistente com Vector3

	var origin = global_position
	# direção oposta ao target
	var base_dir = (origin - target.global_position)
	base_dir.y = 0
	if base_dir.length() == 0:
		base_dir = Vector3(1, 0, 0)
	base_dir = base_dir.normalized()

	# amostrar ângulos próximos ao vetor oposto: primeiro tenta direto, depois +/- 30°, +/-60°, etc.
	var angles = [0, 0.33, -0.33, 0.66, -0.66, 1.0, -1.0] # em radianos multiplicadores do PI
	for a in angles:
		var ang = atan2(base_dir.x, base_dir.z) + a * 0.7 # espalha amostras
		var candidate = target.global_position + Vector3(sin(ang), 0, cos(ang)) * desired_distance
		# elevar o ponto um pouco para evitar colisões no chão
		candidate.y = global_position.y

		# checar se linha direta entre origin e candidate intersecta paredes
		var space = get_world_3d().direct_space_state
		var fromp = origin + Vector3(0, 0.6, 0)
		var top = candidate + Vector3(0, 0.6, 0)

		var query = PhysicsRayQueryParameters3D.new()
		query.from = fromp
		query.to = top
		query.exclude = [self]
		query.collision_mask = 1

		var res = space.intersect_ray(query)

		if not res:
			# sem colisão direta, ponto viável
			return candidate
	# se tudo falhar, retornar vetor zero
	return Vector3.ZERO

	
func _is_point_accessible(point: Vector3) -> bool:
	var space = get_world_3d().direct_space_state
	var fromp = global_position + Vector3(0, 0.6, 0)
	var top = point + Vector3(0, 0.6, 0)

	var query = PhysicsRayQueryParameters3D.new()
	query.from = fromp
	query.to = top
	query.exclude = [self]
	query.collision_mask = 1

	var res = space.intersect_ray(query)
	return not res
