extends CharacterBody3D
class_name CombatCharacter

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var vision_cone: MeshInstance3D = $VisionCone
var model: Node3D = null
var anim: AnimationPlayer = null
var health_bar_scene := preload("res://decades/2000s/UI/HealthBar.tscn")
var health_bar: Control = null
var progress_bar: ProgressBar = null
var vision_cone_material: StandardMaterial3D = null
# Atributos
var move_speed := 4.0
var hp := 100
var max_hp := 100
var camera: Camera3D = null

# Controle
var is_moving := false
var manual_control := false
var target_position := Vector3.ZERO
var is_performing_action := false
var active := false
var turn_charge := 0.0
var turn_threshold := 100.0
var charge_speed := 20.0
var is_turn_ready := false
var current_target: CombatCharacter = null
var has_shield: bool = false
var is_attacking: bool = false
var is_defending: bool = false

var dodge_chance: float = 5.0  # %
var block_chance: float = 20.0 # %
# Cooldowns das habilidades (valores atuais)
var ability_cooldowns := [0.0, 0.0, 0.0, 0.0]
# Tempo total de cooldown para cada habilidade (em segundos)
var ability_cooldown_times := [5.0, 8.0, 12.0, 15.0]

var strength := 10        # Força
var dexterity := 10       # Destreza
var constitution := 10    # Constituição
var intelligence := 10    # Inteligência
var wisdom := 10          # Sabedoria

# Stats derivados que serão recalculados:
var attack_power := 0
var defense := 0
var current_hp := 100
var attack_speed := 1.0
var mana := 0
var crit_chance := 0
var magic_resist := 0
var physical_resist := 0
var min_damage: int = 5
var max_damage: int = 10

# Threat table (aggro)
var threat_table := {} # {CombatCharacter -> float}
var threat_decay_rate := 5.0 # pontos de threat por segundo
const DEFAULT_SLOTS_PER_TARGET := 12
var reserved_slot_idx := -1
var reserved_target_id := 0
var slot_renew_timer := 0.0
const SLOT_RENEW_INTERVAL := 0.4

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if vision_cone:
		# Fixar rotação local para frente do personagem
		vision_cone.rotation_degrees = Vector3(90, 0, 0)  # apenas X

		# Escala e posição relativa
		vision_cone.scale = Vector3(0.3, 0.5, 0.3)
		vision_cone.position = Vector3(0, 3.0, 0)  # na frente e acima

		# Copiar material
		var original_material = vision_cone.get_active_material(0)
		if original_material:
			vision_cone_material = original_material.duplicate()
			vision_cone.set_surface_override_material(0, vision_cone_material)

	# Localizar modelo/anim
	for child in get_children():
		if child.has_node("AnimationPlayer"):
			model = child
			anim = model.get_node("AnimationPlayer")
			break

	if anim:
		anim.process_mode = Node.PROCESS_MODE_ALWAYS if Engine.has_singleton("Engine") == false else Node.PROCESS_MODE_ALWAYS
		anim.play("Idle")
	else:
		push_error("AnimationPlayer não encontrado no personagem: " + str(self))

	# Instanciar barra de vida
	health_bar = health_bar_scene.instantiate()

	# Corrigir local de adição — buscar CanvasLayer "UI" no topo
	var ui_layer = get_tree().get_root().get_node("Game2000/UI")
	if ui_layer:
		ui_layer.add_child(health_bar)
	else:
		push_error("UI Layer (CanvasLayer) não encontrado!")

	if health_bar:
		health_bar.set_health(hp, max_hp)

func _recalculate_stats():
	# Dano físico base
	attack_power = (strength * 2) + (dexterity * 0.5)
	# Dano mínimo e máximo baseado no attack_power
	min_damage = int(attack_power * 0.8)  # 80% do attack_power
	max_damage = int(attack_power * 1.2)  # 120% do attack_power
	# Defesa física
	defense = (constitution * 2) + (dexterity * 0.5)

	# Pontos de vida
	max_hp = 50 + (constitution * 10)
	hp = clamp(hp, 0, max_hp)

	# Mana / recurso mágico
	mana = 20 + (intelligence * 5) + (wisdom * 3)

	# Velocidade de ataque (turn charge)
	charge_speed = 15 + (dexterity * 0.5) + (wisdom * 0.2)

	# Velocidade de movimento
	move_speed = 1.5 + (dexterity * 0.1) + (strength * 0.05)

	# Chance de crítico físico
	crit_chance = min(25, dexterity * 0.5) # Máx 25%

	# Resistência mágica
	magic_resist = wisdom * 1.5

	# Resistência física
	physical_resist = constitution * 1.0

	# Chances baseadas nos atributos
	dodge_chance = dexterity * 0.5  # Ex: DEX 10 = 5% esquiva
	block_chance = 10.0  # Base

	if has_shield:
		print("tenho escudo")
		block_chance += 15.0  # Escudo aumenta chance de defesa

# ------------------ Threat / Aggro helpers ------------------
func add_threat(by: CombatCharacter, amount: float) -> void:
	if by == null:
		return
	if not threat_table.has(by):
		threat_table[by] = 0.0
	threat_table[by] += amount

func get_top_threat() -> CombatCharacter:

	if threat_table.size() == 0:
		return null

	var best: CombatCharacter = null
	var best_val := -INF
	for attacker in threat_table.keys():
		var v = threat_table[attacker]
		if v > best_val and attacker and attacker.is_alive():
			best_val = v
			best = attacker
	return best

func decay_threat(delta: float):
	var to_remove = []
	for attacker in threat_table.keys():
		threat_table[attacker] -= threat_decay_rate * delta
		if threat_table[attacker] <= 0:
			to_remove.append(attacker)
	for k in to_remove:
		threat_table.erase(k)

func clear_threats():
	threat_table.clear()

# ------------------ Slotting / engagement point ------------------
# Calcula uma posição (slot) ao redor do target para evitar empilhamento

func get_slot_position_around_target(self_char: CombatCharacter, target: CombatCharacter, allies: Array, slot_distance: float = 1.8) -> Vector3:
	if target == null:
		return global_position

	# tenta usar o BattleManager para reservar um slot
	var manager = get_tree().get_root().get_node("Game2000/BattleManager")
	var slots_count := DEFAULT_SLOTS_PER_TARGET
	var slot_idx := -1
	if manager and manager.has_method("reserve_slot_for"):
		slot_idx = manager.reserve_slot_for(target, self_char, slots_count)
		if slot_idx != -1:
			# guarda reserva
			reserved_slot_idx = slot_idx
			reserved_target_id = target.get_instance_id()
			slot_renew_timer = SLOT_RENEW_INTERVAL

	# fallback: se não conseguiu reservar
	if slot_idx == -1:
		var same_target_allies := []
		for ally in allies:
			if ally != null and ally.is_alive() and ally.current_target == target:
				same_target_allies.append(ally)
		if not same_target_allies.has(self_char):
			same_target_allies.append(self_char)

		same_target_allies.sort_custom(func(a,b):
			if a == null or b == null:
				return 0
			return int(a.get_instance_id()) - int(b.get_instance_id())
		)

		var slot_index = same_target_allies.find(self_char)
		if slot_index == -1:
			slot_index = 0

		var count = same_target_allies.size()
		var angle = (float(slot_index) / max(1, float(count))) * TAU
		var offset = Vector3(sin(angle), 0, cos(angle)) * slot_distance
		return target.global_position + offset
	else:
		# slot reservado: calcula posição com base no índice
		var count = slots_count
		var radius = slot_distance + int(slot_idx / 6) * 0.6
		var angle = (float(slot_idx) / float(count)) * TAU
		var offset = Vector3(sin(angle), 0, cos(angle)) * radius
		return target.global_position + offset

func release_slot_of_target(target: CombatCharacter) -> void:
	if target == null:
		return
	var manager = get_tree().get_root().get_node("Game2000/BattleManager")
	if manager and manager.has_method("release_slot_for"):
		manager.release_slot_for(target, self)

# ------------------ Process / movement helpers ------------------

func _process(delta):
	# Renovar reserva de slot
	if reserved_slot_idx != -1 and reserved_target_id != 0:
		slot_renew_timer -= delta
		if slot_renew_timer <= 0:
			var bm = get_tree().get_root().get_node("Game2000/BattleManager")
			if bm and bm.has_method("reserve_slot_for"):
				var target_node = instance_from_id(reserved_target_id)
				if target_node:
					bm.reserve_slot_for(target_node, self, DEFAULT_SLOTS_PER_TARGET)
			slot_renew_timer = SLOT_RENEW_INTERVAL

	decay_threat(delta)

	if not health_bar or not model:
		return

	_update_turn_charge(delta)

	for i in range(ability_cooldowns.size()):
		if ability_cooldowns[i] > 0:
			ability_cooldowns[i] = max(ability_cooldowns[i] - delta, 0)

	var head_pos = model.global_transform.origin + Vector3(0, 2.5, 0)

	if not camera:
		camera = get_viewport().get_camera_3d()

	if camera:
		var screen_pos = camera.unproject_position(head_pos)
		var camera_forward = -camera.global_transform.basis.z
		var to_char = (head_pos - camera.global_transform.origin).normalized()
		var dot = camera_forward.dot(to_char)
		health_bar.visible = dot > 0.0

		var offset_x = -50
		var offset_y = -25
		health_bar.position = screen_pos + Vector2(offset_x, offset_y)

		health_bar.set_health(hp, max_hp)
		health_bar.set_turn_charge(turn_charge, turn_threshold)

func _physics_process(delta: float) -> void:
	_handle_movement(delta)

func _handle_movement(delta):
	
	if manual_control and Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_backward") or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
		var bm = get_tree().get_root().get_node("Game2000/BattleManager")
		if bm:
			bm.player_auto_attacking = false
	
	if is_performing_action:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if manual_control:
		var input_dir = Vector2(
			Input.get_action_strength("move_left") - Input.get_action_strength("move_right"),
			Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
		).normalized()

		if input_dir.length() > 0.01:
			var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
			velocity = direction * move_speed
			move_and_slide()

			var target_yaw = atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 0.1)

			anim.play("Walking_A")
		else:
			velocity = Vector3.ZERO
			move_and_slide()
			anim.play("Idle")
	else:
		if is_moving:
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_position).normalized()
			velocity = direction * move_speed
			rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 0.1)
			move_and_slide()
			if anim and anim.current_animation != "Walking_A":
				anim.play("Walking_A")
		else:
			velocity = Vector3.ZERO
			move_and_slide()
			if anim and anim.current_animation != "Idle":
				anim.play("Idle")

func take_turn():
	if current_target and current_target.is_alive():
		var battle_manager = get_tree().get_root().get_node("Game2000/BattleManager")
		battle_manager._execute_attack(self, current_target)

func apply_damage(amount: int, attacker: CombatCharacter):
	# Se tentar esquivar
	if randi_range(1, 100) <= dodge_chance:
		print("%s esquivou do ataque!" % name)
		is_defending = true
		_play_dodge_animation()
		await get_tree().create_timer(1.0).timeout
		is_defending = false
	
	# Se tiver escudo e não estiver atacando → tentar defender
	if has_shield and not is_attacking:
		print("pode defender")
		if randi_range(1, 100) <= block_chance:
			print("%s bloqueou o ataque!" % name)
			amount = int(amount * 0.5)  # Reduz dano pela metade
			is_defending = true
			_play_block_animation()
			await get_tree().create_timer(0.5).timeout
			is_defending = false

	# Aplica o dano final
	hp -= amount
	print("%s recebeu %d de dano (HP: %d/%d)" % [name, amount, hp, max_hp])

	if hp <= 0:
		_die()

func _update_turn_charge(delta: float) -> void:
	if is_turn_ready:
		return
	
	turn_charge += charge_speed * delta
	
	if turn_charge >= turn_threshold:
		turn_charge = turn_threshold
		is_turn_ready = true

		var manager = get_tree().get_root().get_node("Game2000/BattleManager")  # corrigido o caminho
		if manager and manager.has_method("on_character_ready"):
			manager.on_character_ready(self)

func _die() -> void:

	print(name, " morreu!")

	is_performing_action = true  # Evita se mover durante a morte

	if anim:
		anim.play("Death_A") 
	
	if health_bar:
		health_bar.queue_free()

	await get_tree().create_timer(1.0).timeout  # Espera 1 segundo antes de remover

	# Remover da lista do BattleManager
	var manager = get_tree().get_root().get_node("Game2000/BattleManager")
	if manager:
		if self in manager.enemies:
			manager.enemies.erase(self)
			manager.add_group_xp(manager.xp_per_enemy)
			manager._check_enemies_defeated()
		elif self in manager.party_members:
			manager.party_members.erase(self)

	if manager and self == manager.player_character:
		manager.player_auto_attacking = false
	await get_tree().create_timer(1.0).timeout  # Espera mais 1 segundo para "sumir"

	queue_free()

func set_camera(cam: Camera3D):
	if cam:
		camera = cam

func update_ai(_delta: float) -> void:
	# IA desativada, ataques automáticos serão tratados no BattleManager
	pass

func _update_vision_cone(target: CombatCharacter, attack_range: float):
	if not vision_cone_material or not target:
		return

	# Atualiza a cor do cone com base na distância
	var distance := global_position.distance_to(target.global_position)
	var is_in_range := distance <= attack_range
	var color := Color(1, 0, 0, 0.4) if is_in_range else Color(0, 0, 1, 0.4)
	vision_cone_material.albedo_color = color

	# Faz o cone mirar no inimigo (rotaciona localmente em Y)
	var local_direction = (to_local(target.global_position)).normalized()
	var angle = atan2(local_direction.x, local_direction.z)
	vision_cone.rotation.y = angle

func is_alive() -> bool:
	return hp > 0

func _play_block_animation():
	anim.play("Block_Hit", -1, 2)
	
func _play_dodge_animation():
	anim.play("Dodge_Backward")

func can_use_ability(index: int) -> bool:
	if index < 0 or index >= ability_cooldowns.size():
		return false
	return ability_cooldowns[index] <= 0

func use_ability(index: int):
	if can_use_ability(index):
		ability_cooldowns[index] = ability_cooldown_times[index]
		# Aqui você chama a função que executa a habilidade específica
		match index:
			0:
				_cast_ability_0()
			1:
				_cast_ability_1()
			2:
				_cast_ability_2()
			3:
				_cast_ability_3()
		print("%s usou a habilidade %d" % [name, index])
	else:
		print("Habilidade %d em cooldown (%.2f segundos restantes)" % [index, ability_cooldowns[index]])

# Funções placeholders para as habilidades
func _cast_ability_0():
	# Código da habilidade 0 aqui
	pass

func _cast_ability_1():
	# Código da habilidade 1 aqui
	pass

func _cast_ability_2():
	# Código da habilidade 2 aqui
	pass

func _cast_ability_3():
	# Código da habilidade 3 aqui
	pass
