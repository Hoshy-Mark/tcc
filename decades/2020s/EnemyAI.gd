extends Node
class_name EnemyAI

# Configurações que você pode ajustar no editor para cada inimigo
@export var aggression: float = 1.0 # Peso para atacar quem tem pouca vida
@export var caution: float = 1.0    # Peso para se manter perto/longe (futuro)

# A função principal que o personagem chama
func execute_turn(actor: CombatCharacter2020, battle_manager: Node) -> void:
	print("[EnemyIA] Controlando: %s" % actor.name)
	
	# Delay "humano"
	await actor.get_tree().create_timer(0.5).timeout
	
	if not actor.is_alive():
		return

	# 1. Identificar Alvos
	var valid_targets = battle_manager.party_members.filter(
		func(p): return is_instance_valid(p) and p.is_alive()
	)
	
	if valid_targets.size() == 0:
		print("[EnemyIA] Sem alvos.")
		return 
	
	# 2. Decisão: Escolher alvo
	var target = _choose_best_target(actor, valid_targets)
	print("[EnemyIA] Alvo decidido: %s" % target.name)
	
	# 3. Decisão: Mover ou Atacar?
	if actor.can_attack(target):
		print("[EnemyIA] Já no alcance. Atacando.")
		await actor.perform_attack(target)
	else:
		print("[EnemyIA] Fora de alcance. Tentando aproximar...")
		var moved = await _move_to_engage(actor, target, battle_manager)
		
		# Tenta atacar de novo após mover
		if moved and actor.can_attack(target):
			# Pequeno delay para a animação de corrida terminar visualmente
			await actor.get_tree().create_timer(0.2).timeout
			await actor.perform_attack(target)
		else:
			# Se não deu pra atacar, defende (se sobrar ação)
			if actor.has_action:
				actor.perform_defend()

# --- Lógica Interna (Cérebro) ---

func _choose_best_target(actor: CombatCharacter2020, targets: Array) -> Node3D:
	var best_target = targets[0]
	var best_score = -9999.0
	
	for t in targets:
		var distance = actor.global_position.distance_to(t.global_position)
		var hp_percent = float(t.hp) / float(t.max_hp)
		
		# Fórmula de Pontuação:
		# - Prioriza distância curta (custo de movimento baixo)
		# - Prioriza inimigos com vida baixa (aggression)
		var dist_score = (20.0 - distance) * 2.0 
		var kill_score = (1.0 - hp_percent) * 50.0 * aggression
		
		var total_score = dist_score + kill_score
		
		if total_score > best_score:
			best_score = total_score
			best_target = t
			
	return best_target

func _move_to_engage(actor: CombatCharacter2020, target: Node3D, manager: Node) -> bool:
	# Calcular ponto ideal (na borda do ataque, não dentro do inimigo)
	var direction = (target.global_position - actor.global_position).normalized()
	var desired_dist = actor.attack_range * 0.85 # Fica a 85% do alcance máximo
	
	var target_pos = target.global_position - (direction * desired_dist)
	
	# Ajustar para NavMesh (evita ir para abismos)
	if actor.nav_agent:
		var map = actor.nav_agent.get_navigation_map()
		target_pos = NavigationServer3D.map_get_closest_point(map, target_pos)
		
	# Verificar quanto movimento o ator tem
	var dist_total = actor.global_position.distance_to(target_pos)
	var move_amount = min(actor.remaining_movement, dist_total)
	
	if move_amount < 0.1:
		return false # Muito perto ou sem movimento
		
	var final_destination = actor.global_position + (direction * move_amount)
	
	# Validar com o manager (regras do jogo)
	if manager.can_move_character(actor, actor.global_position, final_destination, move_amount):
		await actor.move_towards(final_destination, manager)
		return true
	
	return false
