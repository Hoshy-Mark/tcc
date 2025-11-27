extends CharacterBody3D
class_name CombatCharacter2020

# --- Exports (tune no editor) ---
@export var max_hp := 100
@export var hp := 100
@export var attack_power := 10
@export var min_damage := 5
@export var max_damage := 12
@export var defense := 5
@export var crit_chance := 5 # %
@export var attack_range := 2.0
@export var is_player_controlled := false

var current_status: String = "" # Ex: "Wet"

# --- Movement / navigation ---
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
var remaining_movement := 0.0
var max_movement := 9.0
var is_performing_action := false
var is_defending := false

# --- Turn/animation ---
var turn_speed := 8.0 # quanto maior, mais rápido gira (ajuste conforme necessário)

# --- Initiative / turn flags ---
var initiative_value := 0
var has_action := true
var has_bonus_action := true
var reaction_available := true

# --- Signals ---
signal died(character)
signal turn_finished(character)

# --- Node refs (optionais) ---
var anim: AnimationPlayer = null

# ---------------------------
# _ready / setup
# ---------------------------
func _ready() -> void:
	randomize()   # <<< IMPORTANTE
	# procura NavigationAgent3D em children
	if nav_agent:
		if not nav_agent.is_target_reachable():
			print(name, " → NavMesh fora do alcance (OUTSIDE NAVMESH)")
	for child in get_children():
		if child.has_node("AnimationPlayer"):
			anim = child.get_node("AnimationPlayer")
			break

	if anim:
		anim.play("Idle")

func is_alive() -> bool:
	return hp > 0

# ---------------------------
# Initiative
# ---------------------------
func roll_initiative() -> int:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	# Exemplo simples: d20 + modifier (modificador poderia ser dex)
	var roll = rng.randi_range(1, 20)
	initiative_value = roll # + dex_mod (se tiver)
	return initiative_value

# ---------------------------
# Turn lifecycle (chamado pelo BattleManager)
# ---------------------------
func on_turn_start(movement_allowed):
	print(">> on_turn_start chamado para", name, " movement_allowed=", movement_allowed)
	remaining_movement = movement_allowed
	print("   remaining_movement AGORA =", remaining_movement)
	# remaining_movement = movement_allowed   <-- REMOVA ESTA
	has_action = true
	is_defending = false
	has_bonus_action = true
	reaction_available = true
	is_performing_action = false

func on_turn_end():
	if not is_defending:
		defense -= 5
		_set_anim_state(AnimState.IDLE)

func on_combat_end() -> void:
	# restaurar estados pós combate
	is_performing_action = false


# ---------------------------
# Movement API (para player e AI)
# ---------------------------

func move_towards(target_position: Vector3, manager: Node) -> bool:
	if nav_agent == null:
		push_error("No nav_agent on %s" % [name])
		return false
		
	var from = global_position
	var distance = from.distance_to(target_position)
	
	if not manager.can_move_character(self, from, target_position, distance):
		return false

	# 1. Configura destino
	nav_agent.target_position = target_position
	remaining_movement = max(0.0, remaining_movement - distance)
	is_performing_action = true

	# 2. Vira o boneco (Feedback visual instantâneo)
	var dir_look = (target_position - global_position)
	if dir_look.length() > 0.001:
		var look_target = global_position + Vector3(dir_look.x, 0, dir_look.z)
		look_at(look_target, Vector3.UP)

	
	var time_elapsed = 0.0
	var timeout_limit = 3.0 # SE FICAR ANDANDO POR MAIS DE 3 SEGUNDOS, ELE DESISTE
	
	# Espera o servidor de física calcular a rota inicial
	await get_tree().physics_frame

	# Loop: Enquanto não chegou ao destino...
	while not nav_agent.is_navigation_finished():
		
		# Move o boneco (Simples, sem detecção de travamento complexa)
		var next_pos = nav_agent.get_next_path_position()
		var move_dir = (next_pos - global_position).normalized()
		velocity = move_dir * 2.0 # Velocidade fixa 
		move_and_slide()
		
		time_elapsed += get_physics_process_delta_time()
		
		# O "IF" QUE VOCÊ PEDIU:
		if time_elapsed > timeout_limit:
			print("[%s] Timeout! Demorou demais (%ss), parando movimento." % [name, timeout_limit])
			break # Quebra o loop e segue a vida (passa o turno)
			
		await get_tree().physics_frame


	velocity = Vector3.ZERO # Garante que parou
	is_performing_action = false

	return true

func yield_to_arrival() -> void:
	# loop simples de espera até o nav_agent sinalizar que chegou
	if nav_agent == null:
		return
	while not nav_agent.is_navigation_finished():
		await get_tree().process_frame

# ---------------------------
# Attack API
# ---------------------------
func can_attack(target: CombatCharacter2020) -> bool:
	if not is_alive() or not target.is_alive():
		return false
	return global_position.distance_to(target.global_position) <= attack_range

func perform_attack(target: CombatCharacter2020) -> void:
	if not can_attack(target):
		return
	is_performing_action = true

	# Faz o atacante olhar para o alvo antes de tocar animação (bom para direção de ataque e backstab)
	var look_target = Vector3(target.global_position.x, global_position.y, target.global_position.z)
	look_at(look_target, Vector3.UP)
	rotate_y(deg_to_rad(180))
	_set_anim_state(AnimState.ATTACKING)

	var attack_time := 0.55

	await get_tree().create_timer(attack_time * 0.8).timeout

	# --- HIT CHECK ---
	var atk_roll = randi_range(1, 20)
	var def_roll = randi_range(1, 20)

	if atk_roll >= def_roll:
		var damage = randi_range(min_damage, max_damage)
		damage = _apply_crit_and_backstab(damage, target)
		target.apply_damage(damage, self)
	else:
		print("%s errou %s" % [name, target.name])

	# aguarda o restante da animação
	await get_tree().create_timer(attack_time * 0.2).timeout

	is_performing_action = false
	has_action = false

	_set_anim_state(AnimState.IDLE)


func _apply_crit_and_backstab(damage: int, target: CombatCharacter2020) -> int:
	# crítico simples
	if randi_range(1, 100) <= crit_chance:
		damage = int(damage * 1.5)
		print("CRÍTICO!")
	# backstab check (exemplo simples usando dot)
	var attacker_dir = (target.global_position - global_position).normalized()
	var target_forward = -target.global_transform.basis.z.normalized()
	var dot = attacker_dir.dot(target_forward)
	if dot > 0.75:
		damage = int(damage * 1.5)
	return damage

func apply_damage(amount: int, source: CombatCharacter2020) -> void:
	var mitigated = max(1, amount - int(defense / 2))
	hp = max(0, hp - mitigated)

	print("%s sofreu %d (HP=%d)" % [name, mitigated, hp])

	if hp <= 0:
		_on_death(source)
		return

	_set_anim_state(AnimState.HIT)

	# tempo de stagger
	await get_tree().create_timer(0.35).timeout

	if hp > 0:
		_set_anim_state(AnimState.IDLE)

func _on_death(killer: CombatCharacter2020) -> void:
	if anim_state == AnimState.DEAD:
		return

	print("%s morreu!" % name)
	anim_state = AnimState.DEAD
	_play_state_animation()

	emit_signal("died", self)

	await get_tree().create_timer(0.6).timeout
	queue_free()

# ---------------------------
# AI (por turno) - simples
# ---------------------------
func take_turn(manager: Node) -> void:
	# Versão básica: mover até alcance e atacar, então finalizar
	# Retorna quando terminou (async)
	if is_player_controlled:
		return # não deveria ser chamado para player

	if not is_alive():
		return

	# escolher alvo mais próximo vivo do party
	var possible_targets = manager.party_members.filter(func(p): return p.is_alive())
	if possible_targets.size() == 0:
		return

	var target: CombatCharacter2020 = possible_targets[0]
	var min_dist := INF
	for t in possible_targets:
		var d = global_position.distance_to(t.global_position)
		if d < min_dist:
			min_dist = d
			target = t

	# se já estiver em alcance, atacar
	if can_attack(target):
		perform_attack(target)
		await get_tree().create_timer(0.25).timeout
	else:
		# mover até o máximo possível em direção ao alvo, respeitando remaining_movement
		var dir = (target.global_position - global_position).normalized()
		var desired_pos = global_position + dir * min(remaining_movement,  target.global_position.distance_to(global_position) - attack_range)
		# garante que não vai dentro target
		if desired_pos.distance_to(global_position) > 0.1:
			if manager.can_move_character(self, global_position, desired_pos, global_position.distance_to(desired_pos)):
				# garante que comece olhando na direção do movimento
				var look_target = global_position + Vector3(dir.x, 0, dir.z)
				look_at(look_target, Vector3.UP)
				move_towards(desired_pos, manager)
				await get_tree().create_timer(0.1).timeout
		# se agora em alcance, atacar
		if can_attack(target):
			perform_attack(target)
			await get_tree().create_timer(0.25).timeout

	# finalizar o turno chamando manager.end_turn() ou retornando controle
	# manager.end_turn() é chamado pelo BattleManager automaticamente ao await completar no _begin_turn_for
	return

func _physics_process(delta):
	if nav_agent == null:
		return

	# Se ainda está navegando → está andando
	if anim_state != AnimState.ATTACKING and anim_state != AnimState.HIT and not nav_agent.is_navigation_finished():
		var next_pos = nav_agent.get_next_path_position()
		var direction = (next_pos - global_position)

		if direction.length() > 0.05:
			velocity = direction.normalized() * 4.0
			if not is_defending:
				_set_anim_state(AnimState.MOVING)

			# --- NOVO: girar suavemente para a direção do movimento ---
			# apenas no eixo Y (flatten)
			var flat_dir = Vector3(direction.x, 0, direction.z)
			if flat_dir.length() > 0.001:
				flat_dir = flat_dir.normalized()
				# constrói basis olhando para flat_dir para extrair yaw
				var desired_basis = Basis().looking_at(-flat_dir, Vector3.UP)
				var desired_euler = desired_basis.get_euler()
				var desired_yaw = desired_euler.y
				# suaviza rotação do personagem no eixo Y
				var current_yaw = rotation.y
				rotation.y = lerp_angle(current_yaw, desired_yaw, clamp(delta * turn_speed, 0.0, 1.0))

		else:
			velocity = Vector3.ZERO
			if not is_defending:
				_set_anim_state(AnimState.IDLE)

		move_and_slide()
	else:
		if anim_state not in [AnimState.ATTACKING, AnimState.HIT]:
			velocity = Vector3.ZERO
			if not is_defending:
				_set_anim_state(AnimState.IDLE)


# ---------------------------------------
# SISTEMA DE ESTADOS / ANIMAÇÕES
# ---------------------------------------

enum AnimState { IDLE, MOVING, ATTACKING, HIT, DEFENDING, DEAD }
var anim_state := AnimState.IDLE

# Força troca de estado
func _set_anim_state(new_state: int) -> void:
	if anim_state == AnimState.DEAD:
		return  # morto não anima mais

	if anim_state == new_state:
		return

	anim_state = new_state
	_play_state_animation()


func _play_state_animation() -> void:
	if anim == null:
		return

	match anim_state:
		AnimState.IDLE:
			if anim.current_animation != "Idle":
				anim.play("Idle")

		AnimState.MOVING:
			if anim.current_animation != "Walking_A":
				anim.play("Walking_A")

		AnimState.ATTACKING:
			anim.play("1H_Melee_Attack_Chop")
			anim.speed_scale = 1.0

		AnimState.HIT:
			anim.stop()
			anim.play("Hit_B")
			anim.speed_scale = 1.5

		AnimState.DEAD:
			anim.stop()
			anim.play("Death_A")
			
		AnimState.DEFENDING:
			anim.play("Blocking") 
			anim.speed_scale = 1.0

func perform_defend():
	is_defending = true
	_set_anim_state(AnimState.DEFENDING)
	defense += 5

func apply_status(new_status: String) -> void:
	if current_status == new_status:
		return
	
	current_status = new_status
	print(">>> %s recebeu status: %s <<<" % [name, new_status])
	
	# Feedback Visual Simples (Muda a cor para azulado se for molhado)
	# Se você tiver um MeshInstance3D, pode pintar ele aqui.
	# Exemplo genérico:
	var mesh = find_child("MeshInstance3D", true, false) # Tenta achar a malha
	if mesh and new_status == "Wet":
		# Isso é só um exemplo, se tiver material override
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.5, 1.0) # Azul
		mesh.material_override = mat

# Skill do MAGO (Chama a poça no BattleManager)
func cast_rain_skill(manager: Node, target_char: Node3D) -> void:
	print("%s conjura POÇA D'ÁGUA em %s!" % [name, target_char.name])
	
	is_performing_action = true
	
	# Vira para o alvo
	var look_target = Vector3(target_char.global_position.x, global_position.y, target_char.global_position.z)
	look_at(look_target, Vector3.UP)
	
	# Usa animação de ataque como "Cast"
	_set_anim_state(AnimState.ATTACKING)
	
	await get_tree().create_timer(1.0).timeout # Tempo da magia
	
	# Cria a poça visual e lógica via Manager
	if manager.has_method("spawn_water_puddle"):
		manager.spawn_water_puddle(target_char.global_position, 3.0)
	else:
		print("ERRO: BattleManager não tem spawn_water_puddle!")
		
	is_performing_action = false
	has_action = false
	_set_anim_state(AnimState.IDLE)

# Skill do ARQUEIRO (Dano extra em molhados)
func perform_lightning_arrow(target: CombatCharacter2020) -> void:
	print("%s dispara FLECHA DE RAIO em %s!" % [name, target.name])
	
	is_performing_action = true
	
	# Vira para o alvo
	var look_target = Vector3(target.global_position.x, global_position.y, target.global_position.z)
	look_at(look_target, Vector3.UP)
	
	_set_anim_state(AnimState.ATTACKING)
	
	await get_tree().create_timer(0.5).timeout
	
	var damage = attack_power * 1.5 # Dano base da skill maior
	
	# --- COMBO CHECK ---
	if target.current_status == "Wet":
		damage *= 2.0 # Dobro de dano!
		print(">>> COMBO! Eletrocutado (Dano: %d) <<<" % damage)
		# Se quiser, toque um som de trovão aqui
	else:
		print("Dano normal de raio: %d" % damage)
	
	target.apply_damage(int(damage), self)
	
	is_performing_action = false
	has_action = false
	_set_anim_state(AnimState.IDLE)
