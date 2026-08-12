extends CombatCharacter2000


var safe_distance := 1.5
var target_enemy: CombatCharacter2000 = null

var wait_after_enemy_move := 0.5
var wait_timer := 1.0
var party: Array = []
var random = RandomNumberGenerator.new()
var last_enemy_pos := Vector3.ZERO
var gambits: Array = []
var level: int = 1

# Avoidance tuning
var avoid_min_distance := 1.0
var avoid_max_distance := 2.2
var avoid_force := 1.2
var prediction_time := 0.35

var threat_radius := 10.0   # começar observando a 10 units
var danger_radius := 7.5    # reagir imediatamente dentro de 7.5 units
var threat_tolerance := 0.6 # secs de tolerância antes de reagir dentro da threat zone
var threat_timer := 0.0
var reposition_cooldown := 0.6 # evita reentradas rápidas
var reposition_timer := 0.0

func _ready():
	super._ready()
	random.randomize()
	move_speed = 2
	gambits = [null, null, null]

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
			return

	var distance = global_position.distance_to(target_enemy.global_position)
	var turn_ratio = turn_charge / turn_threshold

	if wait_timer > 0:
		wait_timer -= _delta
		_stop_moving()
		return

	# Movimento padrão da IA

	if distance > attack_range:
		var manager = get_tree().get_root().get_node("Game2000/BattleManager")
		if manager:
			# Usa slotting para evitar empilhamento
			var slot_pos = get_slot_position_around_target(self, target_enemy, manager.party_members, attack_range)
			nav_agent.target_position = slot_pos
			var next_pos = nav_agent.get_next_path_position()
			var avoid_pos = _avoid_allies(next_pos)
			_move_towards(avoid_pos)
		else:
			# Fallback: mover diretamente
			nav_agent.target_position = target_enemy.global_position
			_move_towards(target_enemy.global_position)
	else:
		_stop_moving()
		if _enemy_moved():
			wait_timer = wait_after_enemy_move

	# Executa ação apenas quando o turno estiver pronto
	if is_turn_ready and not is_performing_action:
		is_performing_action = true

		# BUG: current_target nunca era sincronizado aqui (só target_enemy
		# existia nesta classe base). Isso fazia a rotação de "olhar pro
		# alvo" logo abaixo nunca disparar para quem usa esta IA base
		# (o Bárbaro), e também impedia qualquer habilidade que dependa de
		# current_target (como as novas habilidades de classe) de disparar
		# de forma autônoma via IA — só funcionavam quando o jogador estava
		# controlando o personagem manualmente.
		current_target = target_enemy

		# Gambits ganham chance de substituir o ataque
		var acted := false
		for gambit in gambits:
			if gambit != null and gambit.is_condition_met(self):
				await gambit.execute_action(self)
				acted = true
				break

		# Se nenhum gambit agiu, tenta usar a habilidade 0 (se disponível),
		# igual ao padrão já usado pelo Mago/Ladino/Cavaleiro
		if not acted and can_use_ability(0):
			use_ability(0)
			acted = true

		# Se nada mais agiu, faz ataque padrão
		if not acted:
			if current_target != null:
				var target_pos = current_target.global_position
				target_pos.y = global_position.y  # mantem na mesma altura
				
				look_at(target_pos, Vector3.UP)
				
				# Ajusta para olhar de frente se o modelo estiver de costas
				rotation.y += PI  # gira 180 graus no eixo Y
			await _attack_target(target_enemy)

		turn_charge = 0.0
		is_turn_ready = false
		is_performing_action = false

# _move_towards() e _stop_moving() foram removidos daqui de propósito.
#
# BUG DE FÍSICA: esta classe tinha sua própria versão de _move_towards()/
# _stop_moving() que calculava velocity diretamente e chamava move_and_slide()
# "na mão", dentro de update_ai() — que é chamado a partir do _process() do
# BattleManager (framerate variável).
#
# Só que CombatCharacter2000._physics_process() (rodando a taxa fixa do motor
# de física) TAMBÉM roda sempre, para todo personagem, e recalculava a
# velocity a cada tick com base em nav_agent.get_next_path_position() e
# chamava move_and_slide() de novo — ou seja, move_and_slide() era chamado
# duas vezes por frame de física, com dois cálculos de velocity diferentes
# competindo entre si. Isso causava tremedeira, movimento "engasgado" e
# resposta de colisão inconsistente, principalmente perceptível no Bárbaro
# (que usa essa IA base sem sobrescrever update_ai()).
#
# A correção é deixar SÓ a classe base mover o personagem, sempre dentro de
# _physics_process(). _move_towards() da classe base já faz exatamente o que
# é preciso aqui: define nav_agent.target_position e is_moving = true; quem
# de fato aplica velocity + move_and_slide() é sempre _handle_movement(),
# uma única vez por tick físico.

func _enemy_moved() -> bool:
	if target_enemy == null:
		return false
	var moved = target_enemy.global_position.distance_to(last_enemy_pos) > 0.1
	if moved:
		last_enemy_pos = target_enemy.global_position
	return moved

func _choose_random_enemy() -> CombatCharacter2000:
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

func _attack_target(target: CombatCharacter2000) -> void:
	is_performing_action = true

	if anim:
		if global_position.distance_to(target.global_position) <= attack_range:
			anim.play("1H_Melee_Attack_Slice_Diagonal")
		else:
			anim.play("1H_Melee_Attack_Chop")  # Animação mesmo que não acerte
		await get_tree().create_timer(1.0).timeout
	else:
		await get_tree().create_timer(1.0).timeout

	# Aplica dano via BattleManager e adiciona threat
	if target and target.is_alive() and global_position.distance_to(target.global_position) <= attack_range:
		var manager = get_tree().get_root().get_node("Game2000/BattleManager")
		if manager:
			manager._apply_hit(self, target)
			# Aumenta threat no alvo para este atacante
			if target.has_method("add_threat"):
				target.add_threat(self, attack_power)

	is_performing_action = false

func _avoid_allies(position: Vector3) -> Vector3:
	# Versão melhorada: previsão de colisão, força proporcional à velocidade, e prioridade
	var separation_force := Vector3.ZERO
	var manager = get_tree().get_root().get_node("Game2000/BattleManager")
	if manager == null:
		return position
		
	var party = manager.party_members
	if typeof(party) != TYPE_ARRAY:
		return position
	
	for ally in party:
		if ally != self and ally.is_alive():
			# Pega velocidade do aliado (se existir)
			var ally_vel = Vector3.ZERO
			if "velocity" in ally:
				ally_vel = ally.velocity

			# Prever posição futura do aliado
			var future_pos = ally.global_position + ally_vel * prediction_time
			var my_future = global_position + velocity * prediction_time
			
			var dist = my_future.distance_to(future_pos)
			
			# Direção de empurrão no plano XZ
			var push_dir = (my_future - future_pos)
			push_dir.y = 0
			if push_dir.length() > 0:
				push_dir = push_dir.normalized()
			else:
				push_dir = Vector3.ZERO

			# prioridade simples (ex.: player > melee > ranged)
			var my_priority = 1
			var ally_priority = 1
			if "priority" in self:
				my_priority = self.priority
			if "priority" in ally:
				ally_priority = ally.priority

			var priority_factor = 1.0
			if my_priority < ally_priority:
				priority_factor = 1.6
			elif my_priority > ally_priority:
				priority_factor = 0.6

			if dist < avoid_min_distance:
				# Força alta para evitar colisão grave, proporcional à velocidade relativa
				var rel_speed = (velocity - ally_vel).length()
				var strength = clamp((avoid_min_distance - dist) / avoid_min_distance, 0.0, 1.0) * (1.0 + rel_speed)
				separation_force += push_dir * strength * avoid_force * priority_factor
			elif dist < avoid_max_distance:
				var strength = clamp((avoid_max_distance - dist) / (avoid_max_distance - avoid_min_distance), 0.0, 1.0)
				separation_force += push_dir * strength * (avoid_force * 0.6) * priority_factor

	if separation_force == Vector3.ZERO:
		return position
	else:
		separation_force.y = 0
		var adjusted = position + separation_force.normalized() * min(separation_force.length(), 1.8)
		return adjusted

func receive_damage(amount: int) -> void:
	print(name, " recebeu ", amount, " de dano! HP antes: ", hp)
	hp -= amount
	hp = max(hp, 0)
	print(name, " HP depois do dano: ", hp)

	is_performing_action = true  # BLOQUEIA movimento durante animação

	if health_bar:
		health_bar.set_health(hp, max_hp)

	await get_tree().create_timer(1.0).timeout  # Espera 1 segundo

	is_performing_action = false  # Libera o movimento, se ainda estiver vivo

	if hp <= 0:
		print(name, " está morrendo")
		await _die()
