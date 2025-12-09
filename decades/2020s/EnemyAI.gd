extends Node
class_name EnemyAI

# --- TIPOS DE PERSONALIDADE ---
enum BehaviorType {
	ZOMBIE, # Melee burro
	WOLF,   # Melee agressivo (foca vida baixa)
	ARCHER, # Ranged Combo (foca molhados)
	MAGE    # Ranged Support (cria poças)
}

@export var ai_behavior: BehaviorType = BehaviorType.ZOMBIE
@export var debug_mode: bool = true

# --- FLUXO PRINCIPAL DO TURNO ---
func execute_turn(actor: CombatCharacter2020, battle_manager: Node) -> void:
	if debug_mode: print("\n[%s] Iniciando IA (%s)..." % [actor.name, BehaviorType.keys()[ai_behavior]])
	
	await actor.get_tree().create_timer(0.5).timeout
	if not actor.is_alive(): return

	# 1. Identificar Alvos Vivos
	var valid_targets = battle_manager.party_members.filter(
		func(p): return is_instance_valid(p) and p.is_alive()
	)
	
	if valid_targets.size() == 0:
		print("IA: Sem alvos válidos.")
		return 
	
	# 2. Decisão: Escolher Melhor Alvo
	var target = _choose_best_target(actor, valid_targets)
	if debug_mode: print("[%s] Alvo escolhido: %s" % [actor.name, target.name])
	
	# 3. LÓGICA DE SKILLS ESPECIAIS (Prioridade sobre ataque normal)
	
	# Mago: Se o alvo não está molhado, prioriza criar a poça
	if ai_behavior == BehaviorType.MAGE:
		if target.current_status != "Wet":
			if debug_mode: print("IA Mago: Alvo seco. Usando Skill Poça!")
			await actor.cast_rain_skill(battle_manager, target)
			return # Fim do turno (gastou ação)

	# Arqueiro: Se o alvo está molhado e no alcance, usa Raio
	if ai_behavior == BehaviorType.ARCHER:
		if actor.can_attack(target) and target.current_status == "Wet":
			if debug_mode: print("IA Arqueiro: COMBO DETECTADO! Usando Flecha de Raio!")
			await actor.perform_lightning_arrow(target)
			return # Fim do turno
			
	# 4. LÓGICA PADRÃO (Mover e Atacar)
	if actor.can_attack(target):
		if debug_mode: print("IA: No alcance. Atacando normal.")
		await actor.perform_attack(target)
	else:
		if debug_mode: print("IA: Fora de alcance. Tentando aproximar...")
		var moved = await _move_to_engage(actor, target, battle_manager)
		
		# Tenta atacar de novo após mover (com tolerância de 10%)
		var dist = actor.global_position.distance_to(target.global_position)
		if moved and dist <= (actor.attack_range * 1.1):
			await actor.get_tree().create_timer(0.2).timeout
			await actor.perform_attack(target)
		else:
			if actor.has_action:
				actor.perform_defend()

# --- SISTEMA DE PONTUAÇÃO (Weight System) ---
func _choose_best_target(actor: CombatCharacter2020, targets: Array) -> Node3D:
	var best_target = targets[0]
	var best_score = -99999.0
	
	for t in targets:
		var score = 0.0
		var dist = actor.global_position.distance_to(t.global_position)
		var hp_percent = float(t.hp) / float(t.max_hp)
		
		match ai_behavior:
			BehaviorType.ZOMBIE:
				score = -dist # Só importa distância
				
			BehaviorType.WOLF:
				# 80% Fome (Vida baixa), 20% Preguiça (Distância)
				score = (1.0 - hp_percent) * 100.0 
				score -= dist * 0.5 
				
			BehaviorType.ARCHER:
				# Prioridade ABSOLUTA: Alvo molhado (Combo)
				if t.current_status == "Wet":
					score += 5000.0
				
				# Se já alcança, bônus para não mover
				if dist <= actor.attack_range:
					score += 1000.0
				else:
					score -= dist # Se tem que andar, pega o mais perto
				
			BehaviorType.MAGE:
				# Prioridade: Alvo que NÃO está molhado (para molhar)
				if t.current_status != "Wet":
					score += 200.0
				# Prefere alvos com mais vida (para preparar pro time bater)
				score += hp_percent * 50.0
				score -= dist * 0.8

		if score > best_score:
			best_score = score
			best_target = t
			
	return best_target

# --- NAVEGAÇÃO ---
func _move_to_engage(actor: CombatCharacter2020, target: Node3D, manager: Node) -> bool:
	var diff_vector = target.global_position - actor.global_position
	diff_vector.y = 0 
	var direction = diff_vector.normalized()
	
	# Mínimo de 0.8m para não bugar colisão física
	# Tenta chegar a 70% do range (segurança)
	var desired_dist = max(actor.attack_range * 0.7, 0.8)
	
	var target_pos = target.global_position - (direction * desired_dist)
	
	# NavMesh Adjust
	if actor.nav_agent:
		var map = actor.nav_agent.get_navigation_map()
		var nav_pos = NavigationServer3D.map_get_closest_point(map, target_pos)
		# Se o NavMesh devolver um ponto próximo o suficiente, usa ele
		if nav_pos.distance_to(target_pos) < 2.0:
			target_pos = nav_pos
	
	# Limita pelo movimento restante do turno
	var vector_to_dest = target_pos - actor.global_position
	vector_to_dest.y = 0
	var dist_to_dest = vector_to_dest.length()
	
	if dist_to_dest < 0.1: return false
		
	var move_amount = min(actor.remaining_movement, dist_to_dest)
	var final_destination = actor.global_position + (direction * move_amount)
	
	# Executa movimento se o BattleManager deixar
	if manager.can_move_character(actor, actor.global_position, final_destination, move_amount):
		await actor.move_towards(final_destination, manager)
		
		# Face target final
		var look_pos = target.global_position
		look_pos.y = actor.global_position.y
		actor.look_at(look_pos, Vector3.UP)
		return true
	
	return false
