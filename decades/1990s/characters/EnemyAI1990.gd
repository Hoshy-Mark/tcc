class_name EnemyAi1990
extends RefCounted


# ---------------------------------------------------------------------
# FUNÇÃO PRINCIPAL (DISPATCHER)
# ---------------------------------------------------------------------
func execute_turn(ator, party: Array, enemies: Array, battle_manager):
	
	if ator.has_method("update_cooldowns"):
		ator.update_cooldowns()

	match ator.ai_behavior: 
		"lobo_cacador":
			await _execute_wolf_ai(ator, party, enemies, battle_manager)
		"goblin_oportunista":
			await _execute_goblin_ai(ator, party, enemies, battle_manager)
		"orc_brutamontes":
			await _execute_orc_ai(ator, party, enemies, battle_manager)
		"dragao_tatico":
			await _execute_dragon_ai(ator, party, enemies, battle_manager)
		_:
			await _execute_simple_attack(ator, party, enemies, battle_manager)

# ---------------------------------------------------------------------
# LÓGICAS DE IA (AS "PERSONALIDADES")
# ---------------------------------------------------------------------

func _execute_wolf_ai(ator, party, enemies, battle_manager):
	var target = _find_weakest_target_perc(party, ator) 
	
	if target == null:
		_execute_simple_attack(ator, party, enemies, battle_manager)
		return

	# --- PRINT DE DEBUG ---
	print("IA 1990 (LOBO): Alvo com HP mais baixo encontrado: %s" % target.nome)
	
	battle_manager.hud.show_top_message("%s fareja o mais fraco!" % ator.nome)
	await battle_manager.action_executor.perform_attack(ator, target)
	
	await battle_manager.get_tree().create_timer(battle_manager.TEMPO_ESPERA_APOS_ACAO).timeout
	battle_manager.end_turn()


func _execute_goblin_ai(ator, party, enemies, battle_manager):
	var target = _find_lowest_defense_target(party, ator)
	
	if target == null:
		await _execute_simple_attack(ator, party, enemies, battle_manager)
		return

	# --- PRINT DE DEBUG ---
	print("IA 1990 (GOBLIN): Alvo com Defesa mais baixa encontrado: %s" % target.nome)

	battle_manager.hud.show_top_message("%s ataca o alvo mais vulnerável!" % ator.nome)
	await battle_manager.action_executor.perform_attack(ator, target)
	
	await battle_manager.get_tree().create_timer(battle_manager.TEMPO_ESPERA_APOS_ACAO).timeout
	battle_manager.end_turn()


func _execute_orc_ai(ator, party, enemies, battle_manager):
	var target = _find_highest_hp_target(party, ator)
	
	if target == null:
		await _execute_simple_attack(ator, party, enemies, battle_manager)
		return

	# --- PRINT DE DEBUG ---
	print("IA 1990 (ORC): Alvo com HP mais alto encontrado: %s" % target.nome)

	battle_manager.hud.show_top_message("%s tenta derrubar o mais resistente!" % ator.nome)
	await battle_manager.action_executor.perform_attack(ator, target)
	
	await battle_manager.get_tree().create_timer(battle_manager.TEMPO_ESPERA_APOS_ACAO).timeout
	battle_manager.end_turn()


func _execute_dragon_ai(ator, party, enemies, battle_manager):
	# PRIORIDADE 1: Sopro de Fogo
	if ator.has_method("is_skill_ready") and ator.is_skill_ready("fire_breath"):
		
		# --- PRINT DE DEBUG ---
		print("IA 1990 (DRAGÃO): Prioridade 1 -> Usando Sopro de Fogo (AoE)")
		
		battle_manager.hud.show_top_message("%s usa SOPRO DE FOGO!" % ator.nome)
		await battle_manager.action_executor.perform_dragon_fire_breath(ator, party)
		if ator.has_method("use_skill"):
			ator.use_skill("fire_breath")
		await battle_manager.get_tree().create_timer(battle_manager.TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()
		return

	# PRIORIDADE 2: Focar Healer
	var healer_target = _find_target_by_role(party, ator, "Healer")
	if healer_target != null:
		
		# --- PRINT DE DEBUG ---
		print("IA 1990 (DRAGÃO): Prioridade 2 -> Focando Healer: %s" % healer_target.nome)
		
		battle_manager.hud.show_top_message("%s foca no curandeiro!" % ator.nome)
		await battle_manager.action_executor.perform_attack(ator, healer_target)
		await battle_manager.get_tree().create_timer(battle_manager.TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()
		return

	await _execute_simple_attack(ator, party, enemies, battle_manager)

# ---------------------------------------------------------------------
# FUNÇÃO "INTELIGENTE" FILTRO DE ALCANCE
# ---------------------------------------------------------------------

# retorna uma lista de jogadores que o 'ator' PODE atacar.
func _get_valid_targets(party: Array, ator) -> Array:
	
	# 1. O inimigo tem 'alcance_estendido'?
	if not "alcance_estendido" in ator:
		push_warning("IA 1990: Inimigo %s não tem a prop 'alcance_estendido'! Assumindo melee." % ator.nome)
		ator.alcance_estendido = false # Fallback

	# 2. Se o atacante tem alcance, ele pode acertar QUALQUER UM vivo.
	if ator.alcance_estendido:
		return party.filter(func(p): return p.is_alive())

	# 3. Se o atacante é MELEE :
	# Ele só pode acertar quem está na "front" e vivo.
	var front_liners = party.filter(func(p): return p.is_alive() and p.position_line == "front")

	# 4. REGRA ESPECIAL: Se a linha "front" inteira estiver morta...
	if front_liners.is_empty():
		# ...então a linha "back" se torna o alvo válido.
		return party.filter(func(p): return p.is_alive() and p.position_line == "back")
	else:
		# ...senão, ele SÓ pode atacar a linha "front".
		return front_liners

# ---------------------------------------------------------------------
# FUNÇÕES AUXILIARES para as IAS
# ---------------------------------------------------------------------

func _find_weakest_target_perc(party: Array, ator):
	#  Pega SÓ os alvos que o ator pode acertar
	var valid_targets = _get_valid_targets(party, ator)
	
	if valid_targets.is_empty():
		return null

	# Faz a lógica APENAS na lista de alvos válidos
	var weakest_target = null
	var lowest_hp_perc = 1.0 
	
	for p in valid_targets: 
		var perc = p.current_hp / float(p.max_hp)
		if perc < lowest_hp_perc:
			lowest_hp_perc = perc
			weakest_target = p
			
	return weakest_target 

func _find_lowest_defense_target(party: Array, ator):
	var valid_targets = _get_valid_targets(party, ator)
	if valid_targets.is_empty():
		return null
		
	var target = null
	var lowest_stat = INF 
	
	for p in valid_targets:
		var defense_stat = p.get_modified_derived_stat("defense") 
		if defense_stat < lowest_stat:
			lowest_stat = defense_stat
			target = p
			
	return target

func _find_highest_hp_target(party: Array, ator):
	var valid_targets = _get_valid_targets(party, ator)
	if valid_targets.is_empty():
		return null

	var target = null
	var highest_stat = 0
	
	for p in valid_targets:
		if p.max_hp > highest_stat:
			highest_stat = p.max_hp
			target = p
			
	return target

func _find_target_by_role(party: Array, ator, role: String):
	var valid_targets = _get_valid_targets(party, ator)
	if valid_targets.is_empty():
		return null

 # classes q curam, se adiconar mais tenq colocar aqui
	var healer_classes = ["Cleric", "Paladin"]
	for p in valid_targets: 
		if p.classe_name in healer_classes:
			return p 
	return null 

# ---------------------------------------------------------------------
# FALLBACK (IA de 1980) 
# ---------------------------------------------------------------------
func _execute_simple_attack(ator, party: Array, enemies: Array, battle_manager):
	# O ataque simples também respeita o alcance
	var living_players = _get_valid_targets(party, ator)
	
	if living_players.size() > 0:
		var target = living_players[randi() % living_players.size()]
		
		battle_manager.hud.show_top_message("%s ataca %s!" % [ator.nome, target.nome])
		print("IA 1990 Atk simples %s" % target.nome)
		await battle_manager.action_executor.perform_attack(ator, target)
		battle_manager.end_turn()
	else:
		# Se não tiver alvos válidos, oq n é para acontecer
		battle_manager.hud.show_top_message("%s não consegue alcançar um alvo!" % ator.nome)
		
		# Se falahar por algum motivo
		await battle_manager.get_tree().create_timer(battle_manager.TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()
