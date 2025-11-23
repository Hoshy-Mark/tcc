extends Node3D

# -----------------------
# Exports & Paths
# -----------------------
@export_node_path var hud_path: NodePath
var camera_rig: Node3D
var camera: Camera3D
@export_range(0.1, 10.0, 0.1) var default_movement_per_turn := 9.0
@export var attack_range_default := 2.0

# -----------------------
# Signals
# -----------------------
signal combat_started()
signal combat_ended()
signal turn_started(character)
signal turn_ended(character)

# -----------------------
# Estado (preenchidos em initialize / start_combat)
# -----------------------
var hud: CanvasLayer = null
var camera_follow_target: Node3D = null
var camera_follow_speed := 8.0   # velocidade de acompanhamento

var party_members: Array = []
var enemies: Array = []
var turn_order: Array = []
var current_turn_index: int = 0
var combat_active: bool = false

# seleção / pending
var pending_action: String = ""          # ex: "attack", "move", ""
var pending_actor = null                  # personagem que iniciou a ação
var awaiting_world_click: bool = false

# rng
var initiative_rng_seeded := false

# UI extras
var attack_range_indicator: Node3D = null

# -----------------------
# _ready / initialize
# -----------------------
func _ready() -> void:
	print("BattleManager READY (aguardando initialize)")
	if not initiative_rng_seeded:
		RandomNumberGenerator.new().randomize()
		initiative_rng_seeded = true
	set_process_unhandled_input(true)

func _process(delta):
	if camera_rig and camera_follow_target and is_instance_valid(camera_follow_target):
		
		# Mantém a altura fixa da câmera
		var fixed_y = camera_rig.global_position.y
		
		# Alvo desejado (X/Z do personagem)
		var target = camera_follow_target.global_position
		var target_pos = Vector3(
			target.x,
			fixed_y,
			target.z
		)

		# Movimento suave (lerp)
		camera_rig.global_position = camera_rig.global_position.lerp(
			target_pos,
			delta * camera_follow_speed
		)

func initialize(h, cam_rig):
	hud = h
	camera_rig = cam_rig               # <- RIG (ThirdPersonCamera3D.tscn)
	camera = cam_rig.cam               # <- Camera real
	print("BattleManager recebeu HUD e Câmera:", hud, camera)

	# conectar sinais do HUD (se existirem)
	if hud:
		if hud.has_signal("action_selected"):
			hud.action_selected.connect(_on_hud_action_selected)
		if hud.has_signal("end_turn_pressed"):
			hud.end_turn_pressed.connect(_on_hud_end_turn_pressed)
		if hud.has_signal("move_requested"):
			hud.move_requested.connect(_on_hud_move_requested)
	else:
		print("⚠️ AVISO: HUD não recebido no BattleManager")

# -----------------------
# Iniciar / Encerrar combate
# -----------------------
func start_combat(party: Array, foes: Array) -> void:
	party_members = party
	enemies = foes
	_prepare_characters_for_combat()
	_build_initiative_order()
	combat_active = true
	current_turn_index = 0
	emit_signal("combat_started")
	_start_next_turn()

func end_combat() -> void:
	combat_active = false
	emit_signal("combat_ended")
	for c in party_members + enemies:
		if is_instance_valid(c) and c.has_method("on_combat_end"):
			c.on_combat_end()
	turn_order.clear()
	pending_action = ""
	pending_actor = null
	awaiting_world_click = false

# -----------------------
# Preparação / Iniciativa
# -----------------------
func _prepare_characters_for_combat() -> void:
	for c in party_members + enemies:
		if is_instance_valid(c) and c.has_method("on_combat_start"):
			c.on_combat_start()

func _build_initiative_order() -> void:
	turn_order.clear()
	for c in party_members + enemies:
		if is_instance_valid(c) and c.is_alive():
			var init_val = c.roll_initiative() if c.has_method("roll_initiative") else 0
			turn_order.append({"char": c, "ini": init_val})
	turn_order.sort_custom(Callable(self, "_sort_initiative_desc"))
	turn_order = turn_order.map(func(x): return x["char"])

	# DEBUG
	print("=== INITIATIVE ORDER ===")
	for i in range(turn_order.size()):
		var ch = turn_order[i]
		print("%d: %s | player:%s | alive:%s" %
			[i, ch.name if ch.has_method("name") else str(ch), str(ch.is_player_controlled), str(ch.is_alive())])
	
	# Atualiza HUD
	if hud:
		hud.call_deferred("show_turn_order", turn_order)

func _sort_initiative_desc(a, b) -> int:
	if a["ini"] > b["ini"]:
		return -1
	elif a["ini"] < b["ini"]:
		return 1
	return 0

# -----------------------
# Fluxo de turnos
# -----------------------
func _start_next_turn() -> void:
	_clean_dead()
	if _is_encounter_over():
		end_combat()
		return
	if turn_order.size() == 0:
		end_combat()
		return

	current_turn_index = current_turn_index % turn_order.size()
	var current_char = turn_order[current_turn_index]
	if not is_instance_valid(current_char) or not current_char.is_alive():
		_remove_from_turn_order(current_char)
		_start_next_turn()
		return
	if hud:
		hud.call_deferred("highlight_turn_index", current_turn_index)
		hud.call_deferred("update_turn_hp", turn_order)
	camera_follow_target = current_char
	_begin_turn_for(current_char)

func _begin_turn_for(character) -> void:
	print("[DEBUG] Begin turn for:", character.name, " remaining_movement BEFORE:", character.remaining_movement)
	emit_signal("turn_started", character)
	if character.has_method("on_turn_start"):
		character.on_turn_start(default_movement_per_turn)
		
	if hud and hud.has_method("update_turn_info"):
		hud.update_turn_info(character)
		
	_show_hud_for_player(character)

	pending_action = ""
	pending_actor = null
	awaiting_world_click = false

	if not character.is_player_controlled:
		if hud and hud.has_method("disable_all_buttons"):
			hud.disable_all_buttons()
		await character.take_turn(self)
		_end_turn_for(character)
	else:
		if hud and hud.has_method("enable_buttons_for"):
			hud.enable_buttons_for(character)

func end_turn() -> void:
	if not combat_active:
		return
	if turn_order.size() == 0:
		return
	var character = turn_order[current_turn_index]
	_end_turn_for(character)

func _end_turn_for(character) -> void:
	if not is_instance_valid(character):
		return
	if character.has_method("on_turn_end"):
		character.on_turn_end()
	emit_signal("turn_ended", character)
	# avançar índice
	if character in turn_order:
		current_turn_index = turn_order.find(character) + 1
	_start_next_turn()

# -----------------------
# Helpers: limpeza / remoção
# -----------------------
func _remove_from_turn_order(character) -> void:
	if character in turn_order:
		var idx = turn_order.find(character)
		turn_order.remove_at(idx)
		if idx <= current_turn_index and current_turn_index > 0:
			current_turn_index -= 1

func _clean_dead() -> void:
	for c in (party_members + enemies):
		if is_instance_valid(c) and not c.is_alive():
			_remove_from_turn_order(c)

func _is_encounter_over() -> bool:
	var any_enemy_alive := false
	for e in enemies:
		if is_instance_valid(e) and e.is_alive():
			any_enemy_alive = true
			break
	var any_party_alive := false
	for p in party_members:
		if is_instance_valid(p) and p.is_alive():
			any_party_alive = true
			break
	return (not any_enemy_alive) or (not any_party_alive)

# -----------------------
# HUD interaction
# -----------------------
func _show_hud_for_player(character) -> void:
	if hud and hud.has_method("show_action_menu"):
		hud.call_deferred("show_action_menu", character)

func _on_hud_action_selected(action_name: String) -> void:
	if not combat_active:
		return
	var actor = turn_order[current_turn_index]
	if actor == null or not is_instance_valid(actor) or not actor.is_player_controlled:
		return

	match action_name:
		"attack":
			_enter_target_selection_mode(actor)
		"move":
			_enter_movement_mode(actor)
		"defend":
			_perform_defend(actor)
		_:
			print("Ação do HUD não tratada:", action_name)

func _on_hud_end_turn_pressed() -> void:
	end_turn()

func _on_hud_move_requested():
	var actor = turn_order[current_turn_index]
	_enter_movement_mode(actor)

# -----------------------
# Seleção de alvo / clique no mundo
# -----------------------
func _enter_target_selection_mode(actor) -> void:
	pending_action = "attack"
	pending_actor = actor
	var targets := enemies.filter(func(e): return is_instance_valid(e) and e.is_alive())
	if targets.size() == 0:
		print("Nenhum alvo disponível")
		return
	if hud and hud.has_method("show_target_selector"):
		hud.call_deferred("show_target_selector", targets, Callable(self, "_on_target_selected"))
	awaiting_world_click = true

func _on_target_selected(target) -> void:
	awaiting_world_click = false
	if pending_action != "attack":
		return
	if not is_instance_valid(target) or not target.is_alive():
		return
	if pending_actor and is_instance_valid(pending_actor):
		var success := await request_attack(pending_actor, target)
		if pending_actor.has_action == false:
			end_turn()
	pending_action = ""
	pending_actor = null

# -----------------------
# Modo movimento (click-to-move)
# -----------------------
func _enter_movement_mode(actor) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	pending_action = "move"
	pending_actor = actor
	awaiting_world_click = true
	if hud and hud.has_method("show_move_cursor_hint"):
		hud.call_deferred("show_move_cursor_hint")

func _on_world_click(global_pos: Vector3, clicked_obj) -> void:
	print("CLICK: awaiting=", awaiting_world_click, " actor=", pending_actor)
	if not combat_active:
		return

	if not awaiting_world_click:
		var current_actor = _get_current_actor()
		if current_actor and is_instance_valid(current_actor) and current_actor.is_player_controlled:
			pending_action = "move"
			pending_actor = current_actor
			awaiting_world_click = true
			if hud and hud.has_method("show_move_cursor_hint"):
				hud.call_deferred("show_move_cursor_hint")
		else:
			return

	if pending_action == "move":
		if pending_actor and is_instance_valid(pending_actor):
			var from = pending_actor.global_position
			var distance = from.distance_to(global_pos)
			if can_move_character(pending_actor, from, global_pos, distance):
				awaiting_world_click = false
				var actor = pending_actor
				pending_actor = null
				pending_action = ""
				# Inicia animação de caminhada (não await para loop)
				var moved = await actor.move_towards(global_pos, self)
				if hud and hud.has_method("update_turn_info"):
					hud.update_turn_info(actor)
				# Parar walk -> voltar para idle
				if hud and hud.has_method("show_action_menu"):
					hud.call_deferred("show_action_menu", turn_order[current_turn_index])
			else:
				print("Movimento inválido: distancia muito grande ou sem nav_agent")

	elif pending_action == "attack":
		if clicked_obj and clicked_obj is Object and clicked_obj.has_method("is_alive"):
			var target = clicked_obj
			if is_instance_valid(target) and target.is_alive():
				awaiting_world_click = false
				if pending_actor and is_instance_valid(pending_actor):
					var ok = await request_attack(pending_actor, target)
					if pending_actor.has_action == false:
						end_turn()
				pending_action = ""
				pending_actor = null

# -----------------------
# Input (raycast mouse)
# -----------------------
func _unhandled_input(event) -> void:
	if not combat_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if camera == null:
			return
		var mp = get_viewport().get_mouse_position()
		var from = camera.project_ray_origin(mp)
		var dir = camera.project_ray_normal(mp)
		var to = from + dir * 2000.0
		var space_state = get_world_3d().direct_space_state
		var params := PhysicsRayQueryParameters3D.new()
		params.from = from
		params.to = to
		var res = space_state.intersect_ray(params)
		if res:
			var pos = res.position
			var collider = res.collider
			_on_world_click(pos, collider)

# -----------------------
# Validações / pedidos (move / attack)
# -----------------------
func can_move_character(character, from: Vector3, to: Vector3, distance: float) -> bool:
	if not combat_active:
		print("[can_move] Rejeitado: combate inativo")
		return false
	if turn_order.size() == 0:
		print("[can_move] Rejeitado: turn_order vazio")
		return false

	var current = turn_order[current_turn_index] if current_turn_index >= 0 and current_turn_index < turn_order.size() else null
	if current != character:
		print("[can_move] Rejeitado: actor diferente do turno atual")
		return false

	if distance <= 0:
		print("[can_move] Rejeitado: distance <= 0")
		return false

	var rm = character.remaining_movement
	if distance > rm:
		print("[can_move] Rejeitado: distance maior que remaining_movement")
		return false

	# checar nav_agent simples
	if character.has_node("NavigationAgent3D"):
		var a = character.get_node("NavigationAgent3D")
		if a == null:
			print("[can_move] Rejeitado: nav_agent == null")
			return false
	else:
		# fallback: se personagem expõe nav_agent property
		if not (character.has_method("nav_agent")):
			# não temos como garantir, mas permitimos se personagem fornecer move_towards
			if not character.has_method("move_towards"):
				print("[can_move] Rejeitado: sem nav_agent nem move_towards")
				return false

	print("[can_move] Permitido: distance=", distance, " remaining=", rm)
	return true

func request_move():
	var actor = _get_current_actor()
	if actor == null or not is_instance_valid(actor):
		return
	_enter_movement_mode(actor)

func request_attack(attacker, target) -> bool:
	if not combat_active:
		return false
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return false
	if not attacker.is_alive() or not target.is_alive():
		return false
	if turn_order.size() == 0:
		return false
	if turn_order[current_turn_index] != attacker:
		return false
		
	var range = attacker.attack_range
	print(attacker.global_position.distance_to(target.global_position))
	print(range)
	if attacker.global_position.distance_to(target.global_position) > range:
		print("Alvo fora de alcance")
		return false

	# tudo OK -> executa (await)
	await _execute_attack(attacker, target)

	return true

# -----------------------
# Execução de ações com animações
# -----------------------
func _execute_attack(attacker, target) -> void:
	# 1) iniciar animação de ataque do attacker (aguarda se possível)

	# 2) aplicar efeito (usar método do personagem, para lógica/HP/estado)
	await attacker.perform_attack(target)
	
	if hud and hud.has_method("update_turn_info"):
		hud.update_turn_info(attacker)
	# 3) tocar reação do alvo (hit) se houver

	# 4) atualizar HUD e flags de ação
	attacker.has_action = false
	hud.call_deferred("show_action_menu", attacker)

func _perform_defend(actor) -> void:
	# tocar animação de defender e aplicar efeito
	actor.perform_defend()
	if hud and hud.has_method("update_turn_info"):
		hud.update_turn_info(actor)
	actor.has_action = false
	hud.call_deferred("show_action_menu", actor)

# -----------------------
# Utilitários: câmera, indicador, debug
# -----------------------
func _focus_camera_on(character):
	if not camera_rig: return
	camera_rig.global_position.x = character.global_position.x
	camera_rig.global_position.z = character.global_position.z

func _update_attack_range_indicator(character):
	if attack_range_indicator and is_instance_valid(character):
		attack_range_indicator.global_transform.origin = character.global_transform.origin
		attack_range_indicator.scale = Vector3(character.attack_range, 0.1, character.attack_range)
		attack_range_indicator.visible = true

func debug_print_turn_order():
	print("Turn Order:")
	for i in range(turn_order.size()):
		var c = turn_order[i]
		print("%d: %s (HP: %d)" % [i, c.name, c.hp])

func _get_current_actor():
	if turn_order.size() == 0:
		return null
	var idx = current_turn_index % turn_order.size()
	return turn_order[idx] if idx >= 0 and idx < turn_order.size() else null
