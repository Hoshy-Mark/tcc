class_name EnemyAi2000
extends Node

static func get_target_and_action(attacker, battle_manager):
	var party = battle_manager.party_members
	
	# 1. TAUNT
	if attacker.has_status("taunted") and attacker.taunt_source and attacker.taunt_source.is_alive():
		# (Opcional: printar só uma vez quando muda o alvo)
		return { "target": attacker.taunt_source, "skill": "basic_attack" }

	var role = attacker.enemy_role
	
	# 2. LÓGICA POR PAPEL
	
	# --- ARQUEIRO ---
	if role == "Archer":
		var target = _find_target_with_status(party, "poison", attacker)
		if target: return { "target": target, "skill": "necrotic_shot" }
		
		target = _find_target_with_status(party, "bleed", attacker)
		if target: return { "target": target, "skill": "poison_arrow" }
		
		var closest = _find_closest_target(attacker, party)
		return { "target": closest, "skill": "poison_arrow" } 

	# --- BÁRBARO ---
	elif role == "Barbarian":
		var target = _find_target_with_status(party, "armor_break", attacker)
		if target: return { "target": target, "skill": "brutal_strike" }
		
		var closest = _find_closest_target(attacker, party)
		return { "target": closest, "skill": "brutal_strike" }

	# --- CAVALEIRO ---
	elif role == "Knight":
		var target = _find_target_without_status(party, "armor_break", attacker)
		if target: return { "target": target, "skill": "shield_bash" }
		
		var closest = _find_closest_target(attacker, party)
		return { "target": closest, "skill": "shield_bash" }

	# --- LADRÃO ---
	elif role == "Rogue":
		var target = _find_target_without_status(party, "poison", attacker)
		if target: return { "target": target, "skill": "poison_stab" }
		
		var closest = _find_closest_target(attacker, party)
		return { "target": closest, "skill": "poison_stab" }

	# --- MAGO ---
	elif role == "Mage":
		var cluster_center = _find_player_cluster(party, 6.0)
		if cluster_center: return { "target": cluster_center, "skill": "fireball" }
		
		var closest = _find_closest_target(attacker, party)
		return { "target": closest, "skill": "fireball" }

	# 3. FALLBACK
	var fallback_target = _find_closest_target(attacker, party)
	return { "target": fallback_target, "skill": "basic_attack" }

# --- Funções Auxiliares (Mantêm-se iguais, sem prints) ---
# ... (copie as funções auxiliares _find... do script anterior) ...
static func _find_target_with_status(party, status, attacker, max_range: float = 15.0):
	var best_target = null
	var min_dist = INF
	for p in party:
		if p.is_alive() and p.has_status(status):
			var dist = attacker.global_position.distance_to(p.global_position)
			if dist <= max_range and dist < min_dist:
				min_dist = dist
				best_target = p
	return best_target

static func _find_target_without_status(party, status, attacker, max_range: float = 15.0):
	var best_target = null
	var min_dist = INF
	for p in party:
		if p.is_alive() and not p.has_status(status):
			var dist = attacker.global_position.distance_to(p.global_position)
			if dist <= max_range and dist < min_dist:
				min_dist = dist
				best_target = p
	return best_target

static func _find_closest_target(attacker, party):
	var closest = null
	var min_dist = INF
	var my_vision = attacker.vision_range
	for p in party:
		if p.is_alive():
			var d = attacker.global_position.distance_to(p.global_position)
			if d <= my_vision and d < min_dist:
				min_dist = d
				closest = p
	return closest

static func _find_player_cluster(party, radius):
	for p1 in party:
		if not p1.is_alive(): continue
		var neighbors = 0
		for p2 in party:
			if p1 != p2 and p2.is_alive() and p1.global_position.distance_to(p2.global_position) < radius:
				neighbors += 1
		if neighbors >= 1: return p1
	return null
