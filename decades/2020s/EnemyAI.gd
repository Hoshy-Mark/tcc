extends Node
class_name EnemyAI

# --- LISTA DE PERSONALIDADES ---
enum BehaviorType {
	ZOMBIE, # Simples: Ataca quem estiver mais perto
	WOLF,   # Agressivo: Ataca quem tem menos vida (fome)
	ARCHER, # Tático: Prefere quem já está na mira, evita andar
	MAGE    # Inteligente: Foca no mais fraco, mas mantém distância
}

# No Inspector, vai aparecer uma lista para você escolher!
@export var ai_behavior: BehaviorType = BehaviorType.ZOMBIE
@export var debug_mode: bool = true

# --- FLUXO PRINCIPAL (CÉREBRO) ---
func execute_turn(actor: CombatCharacter2020, battle_manager: Node) -> void:
	if debug_mode: print("[%s] IA Iniciada. Tipo: %s" % [actor.name, BehaviorType.keys()[ai_behavior]])
	
	# Delay "humano"
	await actor.get_tree().create_timer(0.5).timeout
	if not actor.is_alive(): return

	# 1. Identificar Alvos
	var valid_targets = battle_manager.party_members.filter(
		func(p): return is_instance_valid(p) and p.is_alive()
	)
	
	if valid_targets.size() == 0:
		if debug_mode: print("Sem alvos.")
		return 
	
	# 2. Decisão: Escolher alvo baseado no Comportamento Atual
	var target = _choose_best_target(actor, valid_targets)
	if debug_mode: print("[%s] Alvo decidido: %s" % [actor.name, target.name])
	
	# 3. Ação: Atacar ou Mover
	if actor.can_attack(target):
		if debug_mode: print("No alcance. Atacando.")
		await actor.perform_attack(target)
	else:
		if debug_mode: print("Fora de alcance. Movendo...")
		var moved = await _move_to_engage(actor, target, battle_manager)
		
		# Tenta atacar de novo após mover (com tolerância aumentada)
		var dist = actor.global_position.distance_to(target.global_position)
		if moved and dist <= (actor.attack_range * 1.1):
			await actor.get_tree().create_timer(0.2).timeout
			await actor.perform_attack(target)
		else:
			# Se não deu pra atacar, defende
			if actor.has_action:
				actor.perform_defend()

# --- LÓGICA DE DECISÃO CENTRALIZADA ---
func _choose_best_target(actor: CombatCharacter2020, targets: Array) -> Node3D:
	var best_target = targets[0]
	var best_score = -99999.0 # Começa muito baixo
	
	for t in targets:
		var score = 0.0
		
		# Aqui a mágica acontece: trocamos a fórmula baseada na escolha do Editor
		match ai_behavior:
			
			BehaviorType.ZOMBIE:
				# ZUMBI: Só liga para distância. Burro e direto.
				var dist = actor.global_position.distance_to(t.global_position)
				score = -dist # Quanto menor a distância, maior o score (menos negativo)
				
			BehaviorType.WOLF:
				# LOBO: Oportunista. Quer sangue (vida baixa).
				var hp_percent = float(t.hp) / float(t.max_hp)
				# Muita prioridade para vida baixa (x100), pouca para distância
				score = (1.0 - hp_percent) * 100.0
				score -= actor.global_position.distance_to(t.global_position) * 0.5
				
			BehaviorType.ARCHER:
				# ARQUEIRO: Preguiçoso. Se já alcança, atira. Se não, pega o mais perto.
				var dist = actor.global_position.distance_to(t.global_position)
				if dist <= actor.attack_range:
					score = 1000.0 # Bônus massivo para não mover
				else:
					score = -dist # Se tiver que mover, vai no mais perto
				# Desempate: prefere alvos com menos vida
				score -= float(t.hp)
				
			BehaviorType.MAGE:
				# MAGO: Estratégico. Vida baixa é prioridade, mas não corre atrás de longe.
				var hp_percent = float(t.hp) / float(t.max_hp)
				score = (1.0 - hp_percent) * 60.0 # Prioridade Média/Alta em matar
				var dist = actor.global_position.distance_to(t.global_position)
				# Penalidade de distância menor que a do zumbi, ele se importa menos em andar
				score -= dist * 0.8 

		if score > best_score:
			best_score = score
			best_target = t
			
	return best_target

# --- MOVIMENTAÇÃO (A versão corrigida) ---
func _move_to_engage(actor: CombatCharacter2020, target: Node3D, manager: Node) -> bool:
	var diff_vector = target.global_position - actor.global_position
	diff_vector.y = 0 
	var dist_to_target = diff_vector.length()
	var direction = diff_vector.normalized()
	
	# Distância Alvo: 70% do range (tenta entrar bem na área)
	# Mínimo de 0.8m para não bugar colisão
	var desired_dist = max(actor.attack_range * 0.7, 0.8)
	
	var target_pos = target.global_position - (direction * desired_dist)
	
	# NavMesh
	if actor.nav_agent:
		var map = actor.nav_agent.get_navigation_map()
		var nav_pos = NavigationServer3D.map_get_closest_point(map, target_pos)
		# Se o NavMesh jogar muito longe (buraco), ignora NavMesh e tenta linha reta
		if nav_pos.distance_to(target_pos) < 1.5:
			target_pos = nav_pos
	
	# Cálculo final
	var vector_to_dest = target_pos - actor.global_position
	vector_to_dest.y = 0
	var dist_to_dest = vector_to_dest.length()
	
	if dist_to_dest < 0.1: return false
		
	var move_amount = min(actor.remaining_movement, dist_to_dest)
	var final_destination = actor.global_position + (direction * move_amount)
	
	if manager.can_move_character(actor, actor.global_position, final_destination, move_amount):
		await actor.move_towards(final_destination, manager)
		# Face target
		var look_pos = target.global_position
		look_pos.y = actor.global_position.y
		actor.look_at(look_pos, Vector3.UP)
		return true
	
	return false
