extends Node

# --- Paths para instanciar personagens e inimigos ---

# --- Referências para HUD, câmera e altura base ---
var ability_hud: AbilityHUD = null
var camera: ThirdPersonCamera3D = null
var hud: CanvasLayer = null
var base_height := 0.5  

# --- Paths para instanciar personagens e inimigos ---
var party_paths := [
	preload("res://decades/2000s/Characters/Barbarian3D.tscn"),
	preload("res://decades/2000s/Characters/Mage3D.tscn"),
	preload("res://decades/2000s/Characters/Rogue3D.tscn"),
	preload("res://decades/2000s/Characters/Knight3D.tscn")
]

var enemy_paths := [
	preload("res://decades/2000s/Characters/Enemies/EnemyKnight.tscn"),
	preload("res://decades/2000s/Characters/Enemies/EnemyMage.tscn"),
	preload("res://decades/2000s/Characters/Enemies/EnemyRogue.tscn"),
	preload("res://decades/2000s/Characters/Enemies/EnemyArcher.tscn"),
	preload("res://decades/2000s/Characters/Enemies/EnemyBarbarian.tscn")
]

var fixed_positions = [
	Vector3(6, base_height, 6),
	Vector3(-6, base_height, 0),
	Vector3(6, base_height, -12),
	Vector3(0, base_height, -22),
	Vector3(-36, base_height, 6),
	Vector3(-22, base_height, -22),
	Vector3(-22, base_height, -6),
	Vector3(-22, base_height, -59),
	Vector3(-32, base_height, -71),
	Vector3(-22, base_height, -83),
	Vector3(-6, base_height, -79),
	Vector3(-40, base_height, -79),
	Vector3(24, base_height, -71),
	Vector3(12, base_height, -75),
	Vector3(16, base_height, -119),
	Vector3(24, base_height, -115),
	Vector3(6, base_height, -111),
	Vector3(24, base_height, -103),
	Vector3(6, base_height, -95),
	Vector3(20, base_height, -127),
]

# --- Estado do combate ---
var party_members: Array[CombatCharacter2000] = []
var enemies: Array[CombatCharacter2000] = []
var player_character: CombatCharacter2000 = null

var is_processing_turn := false
var is_tactical_pause_active := false
var is_player_choosing_action := false
var player_auto_attacking := false

# --- XP e nível do grupo ---
var group_level: int = 1
var group_xp: int = 0
var xp_per_enemy: int = 20
var hordes_defeated: int = 0
var max_hordes: int = 2
var battle_ended := false

# mudei para teste pode mudar de volta se quiser
var enemies_per_horde: int = 4

# --- Controle de slots de posicionamento ---
var slot_occupancy := {}
const DEFAULT_SLOTS_PER_TARGET := 12
const SLOT_LEASE_MS := 1200  # tempo até expirar se não renovado

# --- Constantes de jogo ---
const ATTACK_RANGE := 2.2

# --- Inventário / loja ---
# Antes disso, o botão de item recriava um único "Poção de Cura" do zero a
# cada clique (nunca gasta, sem custo). Agora é uma contagem de verdade,
# que se esgota com o uso e só se repõe na loja entre hordas.
var inventory := {
	"Poção de Cura": 3
}
const ITEM_DATABASE := {
	"Poção de Cura": {"heal": 20, "type": "healing"}
}
const SHOP_PRICES := {
	"Poção de Cura": 15
}
var ShopMenuScene: PackedScene = preload("res://decades/2000s/UI/ShopMenu.tscn")
var shop_menu: Node = null

# --- Funções de inicialização e setup ---

func _ready():
	_spawn_new_horde()
	_spawn_party()
	# A câmera 3D ainda não existe neste ponto (é criada depois por
	# Game2000._ready()), então tentar buscá-la aqui sempre falhava
	# ("Node not found: Camera3D") e não fazia nada. Cada personagem já
	# resolve sua própria câmera automaticamente em CombatCharacter2000._process()
	# via get_viewport().get_camera_3d(), então essa chamada foi removida.

func _setup_ui_with_hud(ui_node: CanvasLayer):
	hud = ui_node
	if hud:
		hud.connect("action_selected", Callable(self, "_on_player_action_selected"))
		print("BattleManager: HUD conectado com sucesso")
	else:
		push_error("BattleManager: HUD GameUI não fornecido!")

func _spawn_party():
	var start_positions = [
		Vector3(2, 0, 1),
		Vector3(4, 0, 1),
		Vector3(6, 0, 1),
		Vector3(8, 0, 1)
	]

	for i in party_paths.size():
		var char: CombatCharacter2000 = party_paths[i].instantiate()
		add_child(char)
		char.global_position = Vector3(
			start_positions[i % start_positions.size()].x,
			base_height,
			start_positions[i % start_positions.size()].z
		)
		party_members.append(char)

		# Definir controle manual somente para o Knight (índice 3)
		if i == 3:
			char.manual_control = true
			player_character = char
				# --- MODO IMORTAL (GOD MODE para teste) ---
				#char.constitution = 5000 # Aumenta defesa e HP base
				#char.max_hp = 99999
				#char.hp = 99999
				#char._recalculate_stats() # Aplica os status absurdos
				#print("🛡️ MODO IMORTAL ATIVADO PARA O CAVALEIRO")
				# -------------------------------
		else:
			char.manual_control = false  # IA futura

		print("BattleManager: Personagem da party instanciado: ", char.name)

func _spawn_new_horde():
	enemies.clear()
	var roles_pool = ["Knight", "Barbarian", "Rogue", "Archer", "Mage"]
	
	for i in range(enemies_per_horde):
		# Instancia o inimigo genérico
		# (Certifique-se que enemy_paths tem a cena do seu inimigo base)
		var enemy_scene = enemy_paths[0] 
		var enemy: CombatCharacter2000 = enemy_scene.instantiate()
		
		add_child(enemy)
		
		# Sorteia um papel e configura o inimigo
		var random_role = roles_pool.pick_random()
		
		# Verifica se o script é o EnemyUnit2000 antes de chamar
		if enemy.has_method("setup_enemy"):
			enemy.setup_enemy(random_role)
		
		# Usa a posição fixa correspondente
		if i < fixed_positions.size():
			enemy.global_position = fixed_positions[i]
		else:
			# fallback se tiver mais inimigos que posições fixas
			enemy.global_position = Vector3(
				randf_range(2, 6),
				base_height,
				randf_range(6, 10)
			)
		
		enemy.manual_control = false
		enemies.append(enemy)
		print("Novo inimigo spawnado:", enemy.name)


func set_camera(cam: ThirdPersonCamera3D):
	camera = cam
	await get_tree().process_frame
	if player_character:
		camera.set_follow_target(player_character)
		camera.set_camera_to_combat(true)
		print("BattleManager: Câmera setada para seguir o Knight.")

# --- Loop principal e controle do fluxo ---

func _process(delta: float) -> void:
	if battle_ended:
		return

	if _handle_pause_input():
		return

	if is_tactical_pause_active:
		_handle_tactical_mode(delta)
		return

	_update_enemies(delta)
	_update_party_members(delta)
	_handle_player_auto_attack()

	_cleanup_slot_occupancy()

func _handle_pause_input() -> bool:
	if Input.is_action_just_pressed("strategic_pause"):
		var editor = get_tree().get_root().find_child("GambitEditor", true, false)
		if editor and editor.visible:
			return true
		_toggle_tactical_pause()
		return true
	return false

func _handle_tactical_mode(delta: float) -> void:
	var editor = get_tree().get_root().find_child("GambitEditor", true, false)
	if editor and editor.visible:
		return
	_handle_tactical_camera_movement(delta)

func _update_enemies(delta: float) -> void:
	for enemy in enemies:
		enemy._update_turn_charge(delta)
		if enemy.has_method("update_ai_movement"):
			enemy.update_ai_movement(delta)
		# Só atualiza o cone se o player existir E estiver vivo na memória
		if player_character and is_instance_valid(player_character) and player_character.is_alive():
			enemy._update_vision_cone(player_character, ATTACK_RANGE)
		if enemy.is_turn_ready and not enemy.is_performing_action:
			await _handle_ai_turn(enemy)

func _update_party_members(delta: float) -> void:
	for member in party_members:
		member._update_turn_charge(delta)
		
		if not member.manual_control and not member.is_performing_action and member != player_character:
			
			# Atualiza ataque de forma assíncrona
			await member.update_ai(delta)
			
			# Atualiza visão depois do movimento/ataque
			_update_member_vision(member)

		if member == player_character:
			_update_member_vision(player_character)

		# Gerenciamento da vez do jogador
		if member.is_turn_ready and member == player_character and not is_player_choosing_action:
			is_player_choosing_action = true
			if hud:
				hud.show_action_menu(member)

func _update_member_vision(member: CombatCharacter2000) -> void:
	var closest_enemy = _find_closest_enemy(member)
	if closest_enemy:
		member._update_vision_cone(closest_enemy, ATTACK_RANGE)

func _find_closest_enemy(member: CombatCharacter2000) -> CombatCharacter2000:
	var closest_enemy = null
	var min_dist := INF
	for enemy in enemies:
		var dist = member.global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			closest_enemy = enemy
	return closest_enemy

func _handle_player_auto_attack() -> void:
	if not player_auto_attacking or player_character == null or player_character.current_target == null:
		return

	var tgt = player_character.current_target

	if not tgt.is_alive():
		print("Alvo morto, parando auto ataque.")
		_stop_player_auto_attack()
		return

	if player_character.hp <= 0:
		_stop_player_auto_attack()
		return

	if player_character.is_performing_action:
		return # espera terminar ação

	var dist = player_character.global_position.distance_to(tgt.global_position)

	if dist > ATTACK_RANGE:
		player_character.manual_control = false
		player_character.nav_agent.target_position = tgt.global_position
		player_character.is_moving = true
	else:
		player_character.is_moving = false
		player_character.manual_control = true
		if player_character.is_turn_ready:
			await _execute_attack(player_character, player_character.current_target)

func _stop_player_auto_attack() -> void:
	player_auto_attacking = false
	if player_character:
		player_character.is_moving = false
		player_character.manual_control = true

# --- Funções de combate e ataque ---

func _execute_attack(attacker: CombatCharacter2000, target: CombatCharacter2000) -> void:
	
	if target:
		if attacker.global_position.distance_to(target.global_position) > attacker.attack_range:
			print(attacker.name, " está fora do alcance para atacar ", target.name)
			return
	
	if not target or not target.is_alive():
		return

	attacker.is_performing_action = true

	# Rolar acerto
	var attack_roll = randi_range(1, 20)
	var target_roll = randi_range(1, 20)

	if attack_roll >= target_roll:
		print(attacker.name, "acertou", target.name)
		await _play_attack_animation(attacker)

		var damage = randi_range(attacker.min_damage, attacker.max_damage)
		target.apply_damage(damage, attacker)
		if target.has_method("add_threat"):
			target.add_threat(attacker, damage)
	else:
		print(attacker.name, "errou o ataque.")
		await _play_attack_animation(attacker)

	attacker.is_performing_action = false
	attacker.turn_charge = 0
	attacker.is_turn_ready = false

# Função auxiliar só para animação
func _play_attack_animation(character: CombatCharacter2000) -> void:
	if character.anim:
		character.anim.play("1H_Melee_Attack_Slice_Diagonal")
		await get_tree().create_timer(1.0).timeout

func _apply_hit(attacker: CombatCharacter2000, target: CombatCharacter2000) -> int:
	var damage = _calculate_damage(attacker, target)
	target.apply_damage(damage, attacker) # Aqui entra defesa/esquiva
	return damage

# --- Funções de morte, recompensas e evolução  ---
# OBS: a morte real dos personagens é tratada em CombatCharacter2000._die(),
# que chama _check_enemies_defeated() abaixo. As funções antigas
# _on_character_death/_spawn_new_horde_if_needed foram removidas por serem
# código morto (nunca eram chamadas) e por contarem "hordas derrotadas" a
# cada inimigo morto em vez de a cada horda inteira eliminada, o que fazia
# uma nova horda de 4 inimigos ser spawnada a cada kill individual.

func add_group_xp(amount: int) -> void:
	group_xp += amount
	print("Grupo ganhou %d XP (Total: %d)" % [amount, group_xp])

	var xp_to_next_level = 100 * group_level
	if group_xp >= xp_to_next_level:
		group_xp -= xp_to_next_level
		group_level += 1
		print("🎉 Grupo subiu para o nível %d!" % group_level)
		
		for member in party_members:
			# BUG: "level += 1" estava dentro do "if not has_meta", que só é
			# verdadeiro na PRIMEIRA vez (antes do meta existir) — então o
			# grupo só subia de nível uma única vez, pra sempre, mesmo
			# ganhando XP suficiente pra subir várias vezes depois. O "if"
			# deveria só inicializar o contador de pontos, não travar o level up.
			if not member.has_meta("points_to_spend"):
				member.set_meta("points_to_spend", 0)
			member.level += 1
			member.set_meta("points_to_spend", member.get_meta("points_to_spend") + 5)

func add_group_gold(amount: int) -> void:
	GameManager.saved_gold += amount
	print("Grupo ganhou %d de ouro (Total: %d)" % [amount, GameManager.saved_gold])

# --- Callbacks de UI e interação  ---

func _on_player_action_selected(action_name: String):
	match action_name:
		"attack":
			player_auto_attacking = true
		"defend":
			# Implementar defesa
			pass
		_:
			print("Ação desconhecida selecionada:", action_name)
	is_player_choosing_action = false

# --- Cálculos e lógica de combate ---

func _calculate_damage(attacker: CombatCharacter2000, target: CombatCharacter2000) -> int:
	var base_damage = attacker.attack_power
	var defense_factor = max(0.5, 1.0 - (target.defense / 200.0)) # Defesa reduz dano
	var damage = base_damage * defense_factor

	# Crítico
	if randi_range(1, 100) <= attacker.crit_chance:
		damage *= 1.5
		print("CRÍTICO!")

	# Ataque pelas costas bônus
	var attacker_dir = (target.global_position - attacker.global_position).normalized()
	var target_forward = -target.global_transform.basis.z.normalized()
	var dot = attacker_dir.dot(target_forward)

	if dot > 0.75:
		damage *= 1.5

	return int(max(1, damage))

func execute_item_use(user: CombatCharacter2000, target: CombatCharacter2000, item: Dictionary):
	user.is_performing_action = true
	if target == user:
		user.anim.play("Use_Item")
	else:
		user.look_at(target.global_position)
		user.anim.play("Throw")

	await get_tree().create_timer(1.0).timeout

	if item.type == "healing":
		target.hp = clamp(target.hp + item.heal, 0, target.max_hp)

	if inventory.has(item.name):
		inventory[item.name] -= 1
		if inventory[item.name] <= 0:
			inventory.erase(item.name)

	user.turn_charge = 0
	user.is_turn_ready = false
	user.is_performing_action = false
	is_player_choosing_action = false

# --- IA e comportamento dos personagens ---

func _handle_ai_turn(character: CombatCharacter2000) -> void:
	if character.has_method("update_ai_attack"):
		await character.update_ai_attack(get_process_delta_time())
	else:
		push_error("Character " + character.name + " não tem método update_ai()")


func _ensure_slots_for_target(target: CombatCharacter2000, slots_count: int = DEFAULT_SLOTS_PER_TARGET) -> void:
	if target == null:
		return
	var id = target.get_instance_id()
	if not slot_occupancy.has(id):
		slot_occupancy[id] = []
		for i in range(slots_count):
			slot_occupancy[id].append({ "agent": null, "reserved_at": 0, "priority": 0 })

func reserve_slot_for(target: CombatCharacter2000, agent: CombatCharacter2000, slots_count: int = DEFAULT_SLOTS_PER_TARGET, desired_role: String = "any") -> int:
	if target == null or agent == null:
		return -1
	_ensure_slots_for_target(target, slots_count)
	var id = target.get_instance_id()
	var slots = slot_occupancy[id]

	# limpar slots expirados
	var now = Time.get_unix_time_from_system() * 1000
	for i in range(slots.size()):
		var s = slots[i]
		if s["agent"] != null and (not is_instance_valid(s["agent"]) or not s["agent"].is_alive() or now - s["reserved_at"] > SLOT_LEASE_MS):
			slots[i] = { "agent": null, "reserved_at": 0, "priority": 0 }

	# base_angle do agent em relação ao target (convenção: atan2(z,x))
	var dir = (agent.global_position - target.global_position)
	dir.y = 0
	if dir.length() == 0:
		dir = Vector3(1,0,0)
	var base_angle = atan2(dir.z, dir.x)

	# preferir slots por role (ex: front 0..2, side 3..8, back 9..11) - ajustável
	var preferred_ranges = []
	if desired_role == "tank":
		preferred_ranges = [0,1,2]
	elif desired_role == "melee":
		preferred_ranges = [0,1,2,3,4]
	elif desired_role == "ranged":
		preferred_ranges = [5,6,7,8,9,10,11]
	else:
		for i in range(slots.size()):
			preferred_ranges.append(i)

	var best_idx := -1
	var best_ang_diff := 99999.0
	for i in preferred_ranges:
		if i < 0 or i >= slots.size():
			continue
		var s = slots[i]
		if s["agent"] == null:
			var angle = (float(i) / float(slots.size())) * TAU
			var diff = abs(wrapf(angle - base_angle, -PI, PI))
			if diff < best_ang_diff:
				best_ang_diff = diff
				best_idx = i

	# se não encontrou em preferred, tenta qualquer slot livre
	if best_idx == -1:
		for i in range(slots.size()):
			var s = slots[i]
			if s["agent"] == null:
				var angle = (float(i) / float(slots.size())) * TAU
				var diff = abs(wrapf(angle - base_angle, -PI, PI))
				if diff < best_ang_diff:
					best_ang_diff = diff
					best_idx = i

	if best_idx != -1:
		slots[best_idx] = {
			"agent": agent,
			"reserved_at": now,
			"priority": 1
		}
		slot_occupancy[id] = slots
		return best_idx

	return -1

func release_slot_for(target: CombatCharacter2000, agent: CombatCharacter2000) -> void:
	if target == null or agent == null:
		return
	var id = target.get_instance_id()
	if not slot_occupancy.has(id):
		return
	var slots = slot_occupancy[id]
	for i in range(slots.size()):
		var s = slots[i]
		if s["agent"] == agent:
			slots[i] = { "agent": null, "reserved_at": 0, "priority": 0 }
	slot_occupancy[id] = slots

func _cleanup_slot_occupancy() -> void:
	var to_delete = []
	for key in slot_occupancy.keys():
		var slots = slot_occupancy[key]
		for i in range(slots.size()):
			if slots[i] != null and (not is_instance_valid(slots[i]) or not slots[i].is_alive()):
				slots[i] = null
		slot_occupancy[key] = slots
		# opcional: se todos nulos, remover entrada
		var all_null = true
		for s in slots:
			if s != null:
				all_null = false; break
		if all_null:
			to_delete.append(key)
	for k in to_delete:
		slot_occupancy.erase(k)

# --- Modo tático e controle da pausa estratégica ---

func _toggle_tactical_pause():
	is_tactical_pause_active = !is_tactical_pause_active

	if is_tactical_pause_active:
		print("Modo estratégico ativado")
		if camera:
			camera.set_follow_target(null)
			camera.set_camera_to_tactical()

		for char in party_members + enemies:
			if char == player_character:
				char.active = true
			char.manual_control = false
			char.is_performing_action = true
			char.velocity = Vector3.ZERO
			if char.anim:
				char.anim.pause()

		# Desativa botão Gambit
		if hud:
			hud.set_gambit_button_enabled(false)

	else:
		print("Modo estratégico desativado")
		if camera:
			camera.set_follow_target(player_character)
			camera.set_camera_to_combat()

		for char in party_members:
			if char == player_character:
				char.manual_control = true
			char.active = false
			char.is_performing_action = false
			if char.anim:
				char.anim.play("Idle")

		for enemy in enemies:
			enemy.is_performing_action = false
			if enemy.anim:
				enemy.anim.play("Idle")

		# Reativa botão Gambit
		if hud:
			hud.set_gambit_button_enabled(true)

func _handle_tactical_camera_movement(delta):
	if not camera:
		return

	var speed := 10.0
	var input_dir := Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x += 1
	if Input.is_action_pressed("move_right"):
		input_dir.x -= 1

	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()

		# Obtém a rotação atual da câmera (spring arm)
		var basis := camera.spring_arm.global_transform.basis

		# Pega apenas os vetores horizontalmente (ignora Y)
		var forward := -basis.z
		forward.y = 0
		forward = forward.normalized()

		var right := basis.x
		right.y = 0
		right = right.normalized()

		# Move baseado na direção da câmera
		var move_vector = (forward * input_dir.z + right * input_dir.x).normalized()

		camera.translate(move_vector * speed * delta)

func _anyone_is_acting() -> bool:
	for char in party_members + enemies:
		if char.is_performing_action:
			return true
	return false

# --- Input e seleção de personagem / controle de câmera ---

func _unhandled_input(event):
	if is_tactical_pause_active:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_tactical_click(event.position)
	else:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_combat_click(event.position)

func _handle_combat_click(mouse_pos: Vector2):
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0

	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)
	if result:
		var clicked_node = result["collider"]
		if clicked_node and clicked_node in enemies and clicked_node.is_alive():
			player_character.current_target = clicked_node
			print("Novo alvo:", clicked_node.name)

func _handle_tactical_click(mouse_pos: Vector2):
	var viewport = get_viewport()
	var camera = viewport.get_camera_3d()
	if not camera:
		return

	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0

	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)

	if result:
		var clicked_node = result["collider"]
		if clicked_node and clicked_node is CombatCharacter2000:
			if clicked_node in party_members:
				_set_new_player_character(clicked_node)

func _set_new_player_character(new_char: CombatCharacter2000):
	if new_char == player_character:
		return  # Já é o personagem ativo

	print("Novo personagem ativo:", new_char.name)

	# Desativa o anterior
	if player_character:
		player_character.manual_control = false
		player_character.active = false

	# Ativa o novo personagem
	player_character = new_char
	player_character.manual_control = true
	player_character.active = true
	if ability_hud:
		ability_hud.show_abilities_for(player_character)
	# Atualiza a câmera
	if camera:
		camera.set_follow_target(player_character)
		camera.set_camera_to_combat()

	# Se estava em modo tático, desativa
	if is_tactical_pause_active:
		is_tactical_pause_active = false
		print("Saindo do modo tático por seleção de personagem")

		# Restaura animações e estados dos personagens
		for char in party_members:
			char.is_performing_action = false
			if char.anim:
				char.anim.play("Idle")
		
		for enemy in enemies:
			enemy.is_performing_action = false
			if enemy.anim:
				enemy.anim.play("Idle")

		# <<< Aqui reativa o botão de Gambit
		if hud:
			hud.set_gambit_button_enabled(true)

# --- Gerenciamento de batalha e evento de inimigos ---

func get_party_members() -> Array:
	return party_members

func _check_enemies_defeated():
	if enemies.is_empty():
		hordes_defeated += 1
		print("Horda %d derrotada!" % hordes_defeated)

		if hordes_defeated >= max_hordes:
			_end_battle(true)
			return

		print("Preparando próxima horda...")
		await get_tree().create_timer(2.0).timeout
		await _open_shop()
		_spawn_new_horde()

# --- Loja (entre uma horda e outra) ---
func _open_shop() -> void:
	if shop_menu == null:
		shop_menu = ShopMenuScene.instantiate()
		get_tree().get_root().add_child(shop_menu)

	# Congela todo mundo, igual à pausa tática, enquanto a loja está aberta
	for char in party_members + enemies:
		if is_instance_valid(char):
			char.is_performing_action = true
			char.velocity = Vector3.ZERO
			if char.anim:
				char.anim.pause()
	if hud:
		hud.hide()

	shop_menu.open_shop(self)
	await shop_menu.shop_closed

	if hud:
		hud.show()
	for char in party_members:
		if is_instance_valid(char):
			char.is_performing_action = false
			if char.anim:
				char.anim.play("Idle")

func _check_party_defeated():
	if party_members.is_empty():
		_end_battle(false)

# --- Fim de batalha (vitória/derrota) ---
# Antes disso a "vitória" era só um print no console e não existia nenhuma
# checagem de derrota: se o grupo inteiro morresse, nada acontecia — a
# batalha simplesmente ficava parada, sem feedback nenhum pro jogador.

func _end_battle(victory: bool) -> void:
	if battle_ended:
		return
	battle_ended = true

	# Congela todo mundo que ainda estiver de pé (mesmo padrão usado na pausa tática)
	for char in party_members + enemies:
		if is_instance_valid(char):
			char.is_performing_action = true
			char.velocity = Vector3.ZERO
			if char.anim:
				char.anim.pause()

	if hud:
		hud.hide()
	if ability_hud:
		ability_hud.hide()

	var ui_layer = get_tree().get_root().get_node_or_null("Game2000/UI")
	var screen_scene = preload("res://decades/2000s/UI/VictoryScreen2000.tscn") if victory else preload("res://decades/2000s/UI/DefeatScreen2000.tscn")
	var screen = screen_scene.instantiate()

	if ui_layer:
		ui_layer.add_child(screen)
	else:
		get_tree().get_root().add_child(screen)

	if victory:
		print("🏆 Todas as hordas derrotadas! Vitória!")
	else:
		print("💀 O grupo foi derrotado.")

# --- HUD e interface de habilidades ---

func _on_ability_selected(index: int):
	if not player_character:
		return
	
	if player_character.can_use_ability(index):
		player_character.use_ability(index)
	else:
		print("Cooldown ainda ativo!")

func set_ability_hud(hud: AbilityHUD):
	ability_hud = hud
	ability_hud.ability_selected.connect(_on_ability_selected)
