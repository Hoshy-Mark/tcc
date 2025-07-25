extends Node

# Referências
var hud
@onready var characters_node = $Characters

# Dados do combate
var party := []
var enemies := []
var enemy_sprites = {}  # id -> EnemySprite
var current_actor = null
var ready_queue := []
var battle_active := false 

var inventory := {
	"Potion": 3,
	"Ether": 2,
	"Elixir": 1,
	"Spirit Water": 2
}

var item_database = {
	"Potion": {"type": "heal", "power": 50, "target": "ally"},
	"Ether": {"type": "restore_mp", "power": 30, "target": "ally"},
	"Spirit Water": {"type": "restore_sp", "power": 30, "target": "ally"},
	"Elixir": {"type": "full_restore", "target": "ally"},
}

const TEMPO_ESPERA_APOS_ACAO = 0.5

var enemy_base_stats = {
	"Goblin": {
		"STR": 10, "DEX": 6, "AGI": 20, "CON": 3, "MAG": 1, "INT": 2, "SPI": 2, "LCK": 4,
		"xp_value": 20, "sprite_path": "res://assets/Goblin.png", "enemy_type": "Beast", "attack_type":"blunt"
	},
	"Little Orc": {
		"STR": 10, "DEX": 4, "AGI": 20, "CON": 6, "MAG": 2, "INT": 3, "SPI": 3, "LCK": 3,
		"xp_value": 50, "sprite_path": "res://assets/Little Orc.png", "enemy_type": "Beast", "attack_type":"blunt"
	},
	"Zumbi": {
		"STR": 5, "DEX": 2, "AGI": 4, "CON": 3, "MAG": 1, "INT": 1, "SPI": 1, "LCK": 1,
		"xp_value": 15, "sprite_path": "res://assets/Zumbi.png", "enemy_type": "Undead", "attack_type":"blunt"
	},
	"Necromante": {
		"STR": 5, "DEX": 4, "AGI": 6, "CON": 6, "MAG": 6, "INT": 4, "SPI": 4, "LCK": 4,
		"xp_value": 50, "sprite_path": "res://assets/Necromante.png", "enemy_type": "Undead", "attack_type":"blunt"
	},
	"Lobo": {
		"STR": 8, "DEX": 6, "AGI": 8, "CON": 6, "MAG": 0, "INT": 0, "SPI": 4, "LCK": 6,
		"xp_value": 50, "sprite_path": "res://assets/Lobo.png", "enemy_type": "Beast", "attack_type":"slash"
	},
	"Passaro": {
		"STR": 6, "DEX": 7, "AGI": 10, "CON": 3, "MAG": 2, "INT": 2, "SPI": 2, "LCK": 4,
		"xp_value": 30, "sprite_path": "res://assets/Passaro.png", "enemy_type": "Flying", "attack_type":"ranged"
	},
}

var class_sprite_paths = {
	"Knight": "res://assets/classes/Knight.png",
	"Mage": "res://assets/classes/Mage.png",
	"Thief": "res://assets/classes/Thief.png",
	"Cleric": "res://assets/classes/Cleric.png",
	"Hunter": "res://assets/classes/Hunter.png",
	"Monk": "res://assets/classes/Monk.png",
	"Paladin": "res://assets/classes/Paladin.png",
	"Summoner": "res://assets/classes/Summoner.png",
}

var class_base_stats = {
	"Knight": {
		"STR": 10, "DEX": 7, "AGI": 4, "CON": 10, "MAG": 1, "INT": 3, "SPI": 5, "LCK": 5,
		"attack_type": "slash"
	},
	"Mage": {
		"STR": 1, "DEX": 4, "AGI": 7, "CON": 3, "MAG": 15, "INT": 13, "SPI": 10, "LCK": 7,
		"attack_type": "blunt"
	},
	"Thief": {
		"STR": 5, "DEX": 10, "AGI": 12, "CON": 4, "MAG": 1, "INT": 4, "SPI": 2, "LCK": 12,
		"attack_type": "pierce"
	},
	"Cleric": {
		"STR": 3, "DEX": 5, "AGI": 6, "CON": 6, "MAG": 10, "INT": 8, "SPI": 15, "LCK": 7,
		"attack_type": "blunt"
	},
	"Hunter": {
		"STR": 7, "DEX": 12, "AGI": 12, "CON": 5, "MAG": 1, "INT": 3, "SPI": 3, "LCK": 17,
		"attack_type": "ranged"
	},
	"Paladin": {
		"STR": 8, "DEX": 6, "AGI": 5, "CON": 9, "MAG": 6, "INT": 5, "SPI": 12, "LCK": 9,
		"attack_type": "slash"
	},
	"Monk": {
		"STR": 14, "DEX": 8, "AGI": 8, "CON": 9, "MAG": 2, "INT": 3, "SPI": 4, "LCK": 12,
		"attack_type": "blunt"
	},
	"Summoner": {
		"STR": 2, "DEX": 5, "AGI": 5, "CON": 4, "MAG": 14, "INT": 12, "SPI": 10, "LCK": 8,
		"attack_type": "blunt"
	},
}

var class_spell_slots = {
	"Mage": {1: 4, 2: 3, 3: 2},
	"Cleric": {1: 3, 2: 2, 3: 1},
	"Paladin": {1: 2},
	"Summoner": {1: 3, 2: 2},
	"Monk": {},
	"Hunter": {},
	"Thief": {},
	"Knight": {}
}

var spell_database = {
	# Magias ofensivas
	"Fire": {"type": "damage", "element": "fire", "attack_type": "magic", "power": 25, "power_max": 35, "cost": 5, "level": 1, "hit_chance": 95, "target_group": "single"},
	"Ice": {"type": "damage", "element": "ice", "attack_type": "magic", "power": 22, "power_max": 32, "cost": 5, "level": 1, "hit_chance": 95, "target_group": "single"},
	"Thunder": {"type": "damage", "element": "lightning", "attack_type": "magic", "power": 28, "power_max": 38, "cost": 6, "level": 1, "hit_chance": 90, "target_group": "single"},
	"Flare": {"type": "damage", "element": "fire", "attack_type": "magic", "power": 80, "power_max": 100, "cost": 20, "level": 3, "hit_chance": 85, "target_group": "single"},
	"Fire Rain": {"type": "damage", "element": "fire", "attack_type": "magic", "power": 30, "cost": 8, "level": 2,"target_group": "line"},
	"Mega Flare": {"type": "damage", "element": "fire", "attack_type": "magic", "power": 60, "cost": 10, "level": 4,"target_group": "area"},
	"Divine Blade": {"effect_type": "damage", "attack_type": "holy", "power": 45, "cost": 10, "target_type": "enemy", "status_inflicted": "blind", "level": 4,"status_chance": 0.3, "duration": 3},
	"Holy Smite": {"effect_type": "damage", "attack_type": "holy", "power": 60, "cost": 15, "level": 4, "target_type": "enemy"},
	
	# Cura
	"Cure": {"type": "heal", "attack_type": "magic", "power": 30, "cost": 5, "level": 1, "target_group": "single"},
	"Cura": {"type": "heal", "attack_type": "magic", "power": 60, "cost": 10, "level": 2, "target_group": "single"},
	"Heal All": {"type": "heal", "attack_type": "magic", "power": 40, "cost": 12, "level": 3, "target_group": "area"},

	# Buffs e debuffs
	"Protect": {"type": "buff", "attack_type": "magic", "attribute": "defense", "amount": 5, "duration": 3, "cost": 6, "level": 1, "target_group": "single"},
	"Shell": {"type": "buff", "attack_type": "magic", "attribute": "magic_defense", "amount": 5, "duration": 3, "cost": 6, "level": 1, "target_group": "single"},
	"Weaken": {"type": "debuff", "attack_type": "magic", "attribute": "strength", "amount": -5, "duration": 3, "cost": 8, "level": 2, "target_group": "single"},
	"Slow": {"type": "debuff", "attack_type": "magic", "attribute": "speed", "amount": -4, "duration": 3, "cost": 8, "level": 2, "target_group": "single"},

	# Especiais
	"Summon Ifrit": {"type": "damage","element": "fire", "attack_type": "magic", "power": 100, "power_max": 120, "cost": 25, "level": 4, "hit_chance": 100},
	"Dispel": {"type": "special", "attack_type": "magic","effect": "remove_buffs", "cost": 10, "level": 2, "target_group": "single"},
	"Eidolon Burst": {"effect_type": "damage", "attack_type": "magic", "power": 50, "cost": 20,"level": 4, "target_type": "area"},
	"Divine Light": {"type": "heal", "attack_type": "magic", "power": 75, "cost": 14, "level": 3, "target_group": "area"},
	"Summon Phoenix": {"type": "damage", "element": "fire", "attack_type": "magic", "power": 120, "power_max": 140, "cost": 30, "level": 5, "hit_chance": 100, "target_group": "area"},
}

var skill_database = {
	"Power Strike": {"effect_type": "damage",  "attack_type": "blunt", "power": 35, "cost": 4, "target_type": "enemy"},
	"Quick Shot": {"effect_type": "damage",  "attack_type": "pierce", "power": 25, "cost": 3, "target_type": "enemy"},
	"Focus": {"effect_type": "buff", "scaling_stat": "AGI", "amount": 5, "duration": 3, "cost": 2, "target_type": "self"},
	"Heal Self": {"effect_type": "heal", "power": 25, "cost": 5, "target_type": "self"},
	"Shield Breaker": {"effect_type": "damage", "attack_type": "pierce", "power": 30, "cost": 6, "target_type": "enemy", "status_inflicted": "defense_down", "status_chance": 0.6, "duration": 3},
	"Tracking Shot": {"effect_type": "damage", "attack_type": "pierce", "power": 35, "cost": 6, "target_type": "enemy", "status_inflicted": "accuracy_up", "status_chance": 0.7, "duration": 3},
	"Steal": {"effect_type": "special", "attack_type": "None", "effect": "steal_item", "cost": 4, "target_type": "enemy"},
	"Evade Boost": {"effect_type": "buff", "attribute": "evasion", "amount": 7, "duration": 3, "cost": 5, "target_type": "self"},
	"Fury Punch": {"effect_type": "damage", "attack_type": "blunt", "power": 45, "cost": 8, "target_type": "enemy"},
	"Holy Smite": {"effect_type": "damage", "attack_type": "holy", "power": 60, "cost": 15, "target_type": "enemy"},
	"Crushing Blow": {"effect_type": "damage", "attack_type": "blunt", "power": 55, "cost": 8, "target_type": "enemy", "status_inflicted": "stun", "status_chance": 0.4, "duration": 1},
	"Arrow Barrage": {"effect_type": "damage", "attack_type": "pierce", "power": 28, "cost": 6, "target_type": "line"},
	"Shadow Jab": {"effect_type": "damage", "attack_type": "pierce", "power": 40, "cost": 5, "target_type": "enemy", "status_inflicted": "bleed", "status_chance": 0.35, "duration": 3},
	"Chi Burst": {"effect_type": "hybrid", "attack_type": "magic", "power": 30, "heal": 30, "cost": 10, "target_type": "self"},
}

var class_spell_trees = {
	"Mage": {
		"spells": {
			"Fire": {"level": 1, "INT": 6},
			"Ice": {"level": 2, "INT": 7},
			"Thunder": {"level": 3, "INT": 8},
		},
		"skills": {},
		"specials": {
			"Arcane Surge": {"level": 1, "INT": 5}
		},
		"spell_upgrades": {
			"Fire": "Fire Rain",
			"Fire Rain": "Flare"
		},
		"skill_upgrades": {}
	},

	"Cleric": {
		"spells": {
			"Cure": {"level": 1, "SPI": 6},
			"Protect": {"level": 2, "SPI": 8},
			"Shell": {"level": 3, "SPI": 10},
		},
		"skills": {},
		"specials": {
			"Safe Guard": {"level": 1, "INT": 2}
		},
		"spell_upgrades": {
			"Cure": "Cura",
			"Cura": "Heal All"
		},
		"skill_upgrades": {}
	},

	"Knight": {
		"spells": {},
		"skills": {
			"Power Strike": {"level": 2, "STR": 10},
			"Focus": {"level": 3, "AGI": 11},
		},
		"specials": {
			"Shield Breaker": {"level": 1, "STR": 5}
		},
		"spell_upgrades": {},
		"skill_upgrades": {
			"Power Strike": "Crushing Blow"
		}
	},

	"Hunter": {
		"spells": {},
		"skills": {
			"Quick Shot": {"level": 1, "STR": 7},
			"Focus": {"level": 2, "AGI": 11},
		},
		"specials": {
			"Rain of Arrows": {"level": 1, "DEX": 2}
		},
		"spell_upgrades": {},
		"skill_upgrades": {
			"Quick Shot": "Arrow Barrage"
		}
	},

	"Thief": {
		"spells": {},
		"skills": {
			"Quick Shot": {"level": 1, "STR": 7},
		},
		"specials": {
			"Shadow Strike": {"level": 1, "AGI": 2}
		},
		"spell_upgrades": {},
		"skill_upgrades": {
			"Quick Shot": "Shadow Jab"
		}
	},

	"Monk": {
		"spells": {},
		"skills": {
			"Power Strike": {"level": 1, "STR": 8},
			"Heal Self": {"level": 2, "AGI": 11},
		},
		"specials": {
			"Inner Focus": {"level": 1, "SPI": 2}
		},
		"spell_upgrades": {},
		"skill_upgrades": {
			"Heal Self": "Chi Burst"
		}
	},

	"Paladin": {
		"spells": {
			"Cure": {"level": 1, "SPI": 6},
			"Protect": {"level": 2, "SPI": 8},
		},
		"skills": {},
		"specials": {
			"Divine Blade": {"level": 1, "STR": 2}
		},
		"spell_upgrades": {
			"Cure": "Divine Light"
		},
		"skill_upgrades": {}
	},

	"Summoner": {
		"spells": {
			"Summon Ifrit": {"level": 3, "SPI": 6},
			"Fire": {"level": 1, "SPI": 8},
			"Dispel": {"level": 2, "SPI": 8},
		},
		"skills": {},
		"specials": {
			"Eidolon Burst": {"level": 1, "SPI": 2}
		},
		"spell_upgrades": {
			"Summon Ifrit": "Summon Phoenix"
		},
		"skill_upgrades": {}
	}
}

var special_database = {
	"Break Thunder": {"effect_type": "damage", "attack_type": "Slash", "power": 35, "target_type": "enemy"},
	"Safe Guard": {"effect_type": "heal", "attack_type": "Magic", "power": 25, "target_type": "ally"},
	"Arcane Surge": {"effect_type": "damage", "attack_type": "Magic", "power": 40, "target_type": "enemy"},
	"Shield Breaker": {"effect_type": "damage", "attack_type": "Pierce", "power": 30, "target_type": "enemy", "status_inflicted": "defense_down", "status_chance": 0.6, "duration": 3},
	"Rain of Arrows": {"effect_type": "damage", "attack_type": "Pierce", "power": 20, "target_type": "all_enemies"},
	"Shadow Strike": {"effect_type": "damage", "attack_type": "Pierce", "power": 35, "target_type": "enemy", "status_inflicted": "stun", "status_chance": 0.4, "duration": 2},
	"Inner Focus": {"effect_type": "buff", "attack_type": "None", "power": 0, "target_type": "self", "attribute": "SPI", "amount": 5, "duration": 4},
	"Divine Blade": {"effect_type": "damage", "attack_type": "Holy", "power": 45, "target_type": "enemy", "status_inflicted": "blind", "status_chance": 0.3, "duration": 3},
	"Eidolon Burst": {"effect_type": "damage", "attack_type": "Magic", "power": 50, "target_type": "all_enemies", }
}

# Estado da batalha
var turn_order := []

var sp_values := {} 

var current_turn_index := 0



# FLUXO DO JOGO

func is_player(actor) -> bool:
	return party.has(actor)

func perform_enemy_action(enemy_actor) -> void:
	var alive_party = party.filter(func(p): return p.current_hp > 0)
	if alive_party.size() == 0:
		hud.show_top_message("Todos os jogadores foram derrotados!")
		return

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var target = alive_party[rng.randi_range(0, alive_party.size() - 1)]

	await perform_attack(enemy_actor, target)

	# 🔧 Zera ATB do inimigo
	atb_values[enemy_actor] = 0
	hud.update_atb_bars(atb_values)

	# 🔧 Espera e finaliza turno
	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	end_turn()

func get_player_position(index: int, is_front: bool) -> Vector2:
	var front_positions = [
		Vector2(1180, 400),  # Jogador 0 front
		Vector2(1100, 600),  # Jogador 1 back
	]
	var back_positions = [
		Vector2(1400, 400),  # Jogador 2 front
		Vector2(1350, 610),  # Jogador 3 back
	]

	# Usa a posição baseada na linha
	if is_front:
		if index < front_positions.size():
			return front_positions[index]
	else:
		if index < back_positions.size():
			return back_positions[index]

	# Fallback se algo der errado
	return Vector2(100, 500)

func get_enemy_position(index: int) -> Vector2:
	var base_x = 400
	var base_y = 400
	var offset_y = 110  # distância vertical entre inimigos na mesma linha
	var offset_x = 250  # distância horizontal entre as duas linhas

	if index < 3:
		# Linha da frente
		return Vector2(base_x, base_y + index * offset_y)
	else:
		# Linha de trás - mais atrás (X) e mais abaixo (Y)
		var tras_index = index - 3
		return Vector2(base_x + offset_x, base_y + tras_index * offset_y + 40)  # 40 a mais no Y

func check_battle_state() -> bool:
	# Verifica se todos os inimigos estão mortos
	
	var all_enemies_dead = enemies.all(func(e): return not e.is_alive())

	if all_enemies_dead:
		hud.show_top_message("Vitória! Todos os inimigos foram derrotados.")
		end_battle(true)
		return true

	# Verifica se todos os jogadores estão mortos
	var all_players_dead = party.all(func(p): return not p.is_alive())

	if all_players_dead:
		hud.show_top_message("Derrota! Todos os heróis caíram.")
		end_battle(false)
		return true

	return false  # A batalha continua

func end_battle(victory: bool) -> void:
	battle_active = false  # Para a batalha aqui
	hud.set_hud_buttons_enabled(false)

	if victory:
		print("Fim da batalha: Vitória")
		var total_xp = 0
		for enemy in enemies:
			total_xp += enemy.xp_value
		for member in party:
			member.gain_xp(total_xp)
			unlock_available_spells_and_skills(member)
		_save_party_status()
		await get_tree().create_timer(5.0).timeout
		start_battle()
	else:
		print("Fim da batalha: Derrota")
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://decades/1990s/battle/DefeatScreen.tscn")

func _save_party_status() -> void:
	var saved_data = []
	for member in party:
		var member_data = {
			"nome": member.nome,
			"classe_name": member.classe_name,
			"STR": member.STR,
			"DEX": member.DEX,
			"AGI": member.AGI,
			"CON": member.CON,
			"MAG": member.MAG,
			"INT": member.INT,
			"SPI": member.SPI,
			"LCK": member.LCK,
			"current_hp": member.current_hp,
			"max_hp": member.max_hp,
			"current_mp": member.current_mp,
			"max_mp": member.max_mp,
			"max_sp": member.max_sp,
			"current_sp": member.current_sp,
			"spells": member.spells,
			"spell_slots": member.spell_slots,
			"skills": member.skills,
			"level": member.level,
			"xp": member.xp,
			"xp_to_next_level": member.xp_to_next_level,
		}
		saved_data.append(member_data)
	
	GameManager.saved_party_data = saved_data
	print("DEBUG: Dados salvos para 1990.")

func _load_party() -> Array:
	var loaded_party := []
	for member_data in GameManager.saved_party_data:
		var member := PlayerPartyMember1990.new()
		member.nome = member_data["nome"]
		member.classe_name = member_data["classe_name"]
		member.STR = member_data["STR"]
		member.DEX = member_data["DEX"]
		member.AGI = member_data["AGI"]
		member.CON = member_data["CON"]
		member.MAG = member_data["MAG"]
		member.INT = member_data["INT"]
		member.SPI = member_data["SPI"]
		member.LCK = member_data["LCK"]
		member.current_hp = member_data["current_hp"]
		member.max_hp = member_data["max_hp"]
		member.current_mp = member_data["current_mp"]
		member.max_mp = member_data["max_mp"]
		member.current_sp = member_data["current_sp"]
		member.max_sp = member_data["max_sp"]
		member.spells = member_data.get("spells", [])
		member.spell_slots = member_data.get("spell_slots", {})
		member.skills = member_data.get("skills", [])
		member.level = member_data.get("level", 1)
		member.xp = member_data.get("xp", 0)
		member.xp_to_next_level = member_data.get("xp_to_next_level", 100)
		member.calculate_stats()
		loaded_party.append(member)
	return loaded_party

func ajustar_dano_por_posicao(dano: int, atacante, alvo, is_ataque_fisico: bool) -> int:
	if not is_ataque_fisico:
		return dano  # ataques mágicos ou à distância não são afetados

	# Reduzir dano causado se o atacante está na traseira
	if atacante.position_line == "back":
		dano *= 0.7
	
	# Reduzir dano recebido se o alvo está na traseira
	if alvo.position_line == "back":
		dano *= 0.5

	return int(dano)

func atualizar_obstrucao_inimigos() -> void:
	for i in range(enemies.size()):
		var enemy = enemies[i]
		if enemy.position_line == "back":
			var front_index = i - 3
			if front_index < 0 and enemies[front_index].is_alive():
				enemy.obstruido = true
			else:
				enemy.obstruido = false
		else:
			enemy.obstruido = false

func atualizar_obstrucao_party() -> void:
	for i in range(party.size()):
		var player = party[i]
		if player.position_line == "back":
			var front_index = i - 2
			if front_index >= 0 and party[front_index].is_alive():
				player.obstruido = true
			else:
				player.obstruido = false
		else:
			player.obstruido = false

func pode_atacar(alvo, atacante, is_ataque_fisico: bool) -> bool:
	if not is_ataque_fisico:
		return true  # Magias sempre podem atingir
		
	if not alvo.obstruido:
		return true  # Pode atacar se não estiver obstruído
	
	if alvo.obstruido and not atacante.alcance_estendido:
		return false  # Está atrás de alguém vivo e atacante não tem alcance
	
	if alvo.position_line == "front":
		return true

	return atacante.alcance_estendido

# CRIAÇÃO DE INIMIGOS E PLAYER


func spawn_party(party_data: Array) -> void:
	var has_paladin = "Paladin" in party_data
	var has_hunter = "Hunter" in party_data
	var front_index = 0
	var back_index = 0
	for i in range(party_data.size()):
		var classe_name = party_data[i]
		var player_node := PlayerPartyMember1990.new()
		player_node.classe_name = classe_name
		player_node.nome = classe_name

		var stats = class_base_stats.get(classe_name, {})
		player_node.STR = stats.get("STR", 0)
		player_node.DEX = stats.get("DEX", 0)
		player_node.AGI = stats.get("AGI", 0)
		player_node.CON = stats.get("CON", 0)
		player_node.MAG = stats.get("MAG", 0)
		player_node.INT = stats.get("INT", 0)
		player_node.SPI = stats.get("SPI", 0)
		player_node.LCK = stats.get("LCK", 0)
		player_node.attack_type = stats.get("attack_type", " ")

		player_node.calculate_stats()
		player_node.level = 1


		unlock_available_spells_and_skills(player_node)
		player_node.spell_upgrades = class_spell_trees.get(classe_name, {}).get("spell_upgrades", {})
		player_node.skill_upgrades = class_spell_trees.get(classe_name, {}).get("skill_upgrades", {})

		# Lógica de posição baseada na presença de Hunter e Paladin
		if classe_name == "Paladin":
			if has_hunter:
				player_node.position_line = "front"
			else:
				player_node.position_line = "back"
		elif classe_name == "Hunter":
			if has_paladin:
				player_node.position_line = "back"
			else:
				player_node.position_line = "front"
		elif classe_name in ["Monk", "Knight", "Thief"]:
			player_node.position_line = "front"
		else:
			player_node.position_line = "back"

		# Ajuste especial para Hunter
		if classe_name == "Hunter":
			player_node.alcance_estendido = true

		player_node.spell_slots = class_spell_slots.get(classe_name, {})
		party[i] = player_node


		#Define posição do sprite com base na linha
		var is_front = player_node.position_line == "front"
		var sprite_pos_index = 0
		if is_front:
			sprite_pos_index = front_index
		else:
			sprite_pos_index = back_index
		var player_sprite = preload("res://decades/1990s/Battle/PlayerSprite.tscn").instantiate()
		player_sprite.set_sprite(class_sprite_paths.get(classe_name, ""))
		player_sprite.position = get_player_position(sprite_pos_index, is_front)
		player_sprite.set_player(player_node)

		if is_front:
			front_index += 1
		else:
			back_index += 1

		if classe_name == "Monk":
			player_sprite.scale = Vector2(0.8, 0.8)

		player_node.sprite_ref = player_sprite
		characters_node.add_child(player_sprite)
		
	atualizar_obstrucao_party()

func spawn_loaded_party(loaded_party: Array) -> void:
	var front_index = 0
	var back_index = 2  # Começa do índice 2 para os de trás
	
	for i in range(loaded_party.size()):
		var player_node = loaded_party[i]

		# Sprite
		var player_sprite = preload("res://decades/1990s/Battle/PlayerSprite.tscn").instantiate()
		player_sprite.set_sprite(class_sprite_paths.get(player_node.classe_name, ""))
		
		var sprite_pos_index = 0
		if player_node.position_line == "front":
			sprite_pos_index = front_index
			front_index += 1
		else:
			sprite_pos_index = back_index
			back_index += 1

		player_sprite.position = get_player_position(sprite_pos_index, player_node.position_line == "front")
		player_sprite.set_player(player_node)

		if player_node.classe_name == "Monk":
			player_sprite.scale = Vector2(0.8, 0.8)

		player_node.sprite_ref = player_sprite

		# Adiciona ao array de party e à cena
		party[i] = player_node
		characters_node.add_child(player_sprite)
		
	atualizar_obstrucao_party()

func spawn_enemies(enemy_data: Array) -> void:
	for i in range(enemy_data.size()):
		var enemy_info = enemy_data[i]
		var enemy_sprite = preload("res://decades/1990s/Battle/EnemySprite.tscn").instantiate()
		enemy_sprite.set_sprite(enemy_info["sprite_path"])
		enemy_sprite.position = get_enemy_position(i)

		enemy_sprite.set_enemy(enemy_info["instance"])
		enemy_sprite.scale = Vector2(0.8, 0.8)
		enemy_info["instance"].sprite_ref = enemy_sprite

		enemies[i] = enemy_info["instance"]  # Substitui no array por instância
		characters_node.add_child(enemy_sprite)

func generate_enemies() -> Array:
	var enemies_array = []
	var enemy_types = ["Zumbi", "Necromante", "Lobo", "Passaro"]
	var enemy_count = 6

	for i in range(enemy_count):
		var rand_type = enemy_types[randi() % enemy_types.size()]
		var base = enemy_base_stats.get(rand_type)

		if base:
			
			var enemy_node := Enemy1990.new()
			var position_indicator = ""
			if i >= 3:
				enemy_node.position_line = "front"
				position_indicator = " [F]"
			else:
				enemy_node.position_line = "back"
				position_indicator = " [B]"

			enemy_node.nome = "%s%s" % [rand_type, position_indicator]
			enemy_node.STR = base["STR"]
			enemy_node.DEX = base["DEX"]
			enemy_node.AGI = base["AGI"]
			enemy_node.CON = base["CON"]
			enemy_node.MAG = base["MAG"]
			enemy_node.INT = base["INT"]
			enemy_node.SPI = base["SPI"]
			enemy_node.LCK = base["LCK"]
			enemy_node.xp_value = base["xp_value"]
			enemy_node.attack_type = base["attack_type"]
			enemy_node.enemy_type = base["enemy_type"]
			
			if enemy_node.enemy_type == "Flying":
				enemy_node.alcance_estendido = true
			
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			# Gerar ID aleatório em string
			enemy_node.id = "%s_%06d" % [name.to_lower().replace(" ", "_"), rng.randi_range(0, 999999)]
			
			enemy_node.calculate_stats()
			enemy_node.set_type_resistances()
			enemies_array.append({"instance": enemy_node, "sprite_path": base["sprite_path"]})
	
	return enemies_array

func find_enemy_by_id(id: String) -> Enemy1990:
	for enemy in enemies:
		if enemy.id == id:
			return enemy
	return null


# SISTEMA DE ATB

const ATB_MAX := 100
const ATB_INCREMENT_BASE := 10  # pode ajustar conforme a velocidade

var atb_values := {}  # dicionário: personagem -> valor atual do ATB
var ready_to_act := []  # fila de personagens com ATB cheio (100)
var is_executing_turn := false  # controla se alguém está executando/decidindo ação

func _ready():
	var hud_scene = preload("res://decades/1990s/Battle/CombatHUD1990.tscn")
	hud = hud_scene.instantiate()
	add_child(hud)

	# 🔧 Conecte o sinal aqui
	hud.action_selected.connect(_on_player_action_selected)
	hud.back_pressed.connect(_on_hud_back_pressed)

func start_battle(party_data: Array = []) -> void:
	if party_data.is_empty() and GameManager.saved_party_data.size() > 0:
		party_data = _load_party()
	elif party_data.is_empty():
		push_error("Nenhum dado de party fornecido e nenhum save encontrado.")
		return

	for child in characters_node.get_children():
		child.queue_free()
	enemy_sprites.clear()
	enemies.clear()
	

	if party_data[0] is PlayerPartyMember1990:
		party = party_data.duplicate()
		spawn_loaded_party(party)
	else:
		party.resize(party_data.size())
		spawn_party(party_data)

	for member in party:
		sp_values[member] = 0.0

	enemies = generate_enemies()
	spawn_enemies(enemies)
	atualizar_obstrucao_inimigos()
	
	hud.update_party_info(party)
	hud.update_enemy_info(enemies)
	
	battle_active = true
	turn_order = party + enemies
	current_turn_index = 0

	if not is_player(current_actor):
		current_actor = get_next_player_actor(current_turn_index)

	hud.show_top_message("Batalha Iniciada!")
	next_turn()

func get_next_player_actor(start_index: int):
	var size = turn_order.size()
	var idx = start_index
	for i in range(size):
		var actor = turn_order[idx]
		if is_player(actor):
			return actor
		idx = (idx + 1) % size
	return null

func update_atb(delta):
	for actor in turn_order:
		if actor.is_alive():
			var modified_speed = actor.get_modified_derived_stat("speed")
			actor.atb_value += modified_speed * delta
			actor.atb_value = min(actor.atb_value, actor.atb_max)

func check_ready_actors():
	for actor in turn_order:
		if actor.atb_value >= actor.atb_max and actor not in ready_queue and actor.is_alive():
			ready_queue.append(actor)

func _process(delta):
	if not battle_active:
		return

	if is_executing_turn or ready_to_act.size() > 0:
		return

	for actor in turn_order:
		if actor.is_alive():
			var modified_speed = actor.get_modified_derived_stat("speed")
			actor.atb_value += modified_speed * delta
			actor.atb_value = min(actor.atb_value, actor.atb_max)

	# Verifica quem está pronto
	var actors_filled = []
	for actor in turn_order:
		if actor.is_alive() and actor.atb_value >= actor.atb_max and not ready_to_act.has(actor):
			actors_filled.append(actor)

	if actors_filled.size() > 0:
		actors_filled.shuffle()
		for actor in actors_filled:
			ready_to_act.append(actor)

	var atb_values = {}
	for actor in turn_order:
		atb_values[actor] = actor.atb_value
	hud.update_atb_bars(atb_values)

	if not is_executing_turn and ready_to_act.size() > 0:
		next_turn()

func end_turn():
	is_executing_turn = false
	
	if is_player(current_actor):
		for spell_name in current_actor.spell_ap.keys():
			check_ability_mastery(current_actor, spell_name, true)
		for skill_name in current_actor.skill_ap.keys():
			check_ability_mastery(current_actor, skill_name, false)

	# Continua fluxo de batalha
	if not check_battle_state():
		if ready_to_act.size() > 0:
			next_turn()

func next_turn():
	if ready_to_act.is_empty():
		return
	current_actor = ready_to_act.pop_front()

	if not current_actor or not current_actor.is_alive():
		next_turn()
		return
		
	if current_actor is PlayerPartyMember and current_actor.is_defending:
		current_actor.is_defending = false
		
	is_executing_turn = true

	# Verifica se é jogador
	if is_player(current_actor):
		hud.set_hud_buttons_enabled(true, current_actor)
		hud.indicate_current_player(current_actor)
	else:
		await get_tree().create_timer(0.5).timeout
		perform_enemy_action(current_actor)
	
	current_actor.atb_value = 0

func reset_atb(actor):
	actor.atb_value = 0
	hud.update_atb_bars({actor: 0})


# CRIAÇÃO


func create_spell(name: String, data: Dictionary) -> Spell:
	var s = Spell.new()
	s.name = name
	s.cost = data.get("cost", 0)
	s.power = data.get("power", 0)
	s.power_max = data.get("power_max", s.power)
	s.level = data.get("level", 1)
	s.type = data.get("type", "")
	s.attribute = data.get("attribute", "")
	s.amount = data.get("amount", 0)
	s.duration = data.get("duration", 3)
	s.target_group = data.get("target_group", "single")
	s.target_all = data.get("target_all", s.target_group == "area")
	s.element = data.get("element", "")
	s.attack_type = data.get("attack_type", "")
	return s

func create_skill(name: String, data: Dictionary) -> Skill:
	var s = Skill.new()
	s.name = name
	s.cost = data.get("cost", 0)
	s.power = data.get("power", 0)
	s.scaling_stat = data.get("scaling_stat", "STR")
	s.hit_chance = data.get("hit_chance", 0.95)
	s.target_type = data.get("target_type", "enemy")
	s.effect_type = data.get("effect_type", "physical")
	s.status_inflicted = data.get("status_inflicted", "")
	s.status_chance = data.get("status_chance", 0.0)
	s.element = data.get("element", "")
	s.attack_type = data.get("attack_type", "")
	return s

func create_special(name: String, data: Dictionary) -> Special:
	var s = Special.new()
	s.name = name
	s.effect_type = data.get("effect_type", "")
	s.attack_type = data.get("attack_type", "")
	s.power = data.get("power", 0)
	s.target_type = data.get("target_type", "")
	s.scaling_stat = data.get("scaling_stat", "")
	s.amount = data.get("amount", 0)
	s.duration = data.get("duration", 0)
	return s

func get_spell_by_name(spells: Array, name: String) -> Spell:
	for spell in spells:
		if spell.name == name:
			return spell
	return null

func _create_menu() -> void:
	hud._hide_all_panels()
	hud.show_action_menu()
	hud.hide_arrow()

func unlock_available_spells_and_skills(player):
	var tree = class_spell_trees.get(player.classe_name, {"spells": {}, "skills": {}})

	player.spells.clear()
	player.skills.clear()
	player.specials.clear()

	# Desbloquear magias
	for spell_name in tree.spells.keys():
		var reqs = tree.spells[spell_name]
		# Confere level e atributos, default 0 caso não exista
		var level_req = reqs.get("level", 0)
		var int_req = reqs.get("INT", 0)
		var spi_req = reqs.get("SPI", 0)

		if player.level >= level_req and player.INT >= int_req and player.SPI >= spi_req:
			if spell_database.has(spell_name):
				var spell = create_spell(spell_name, spell_database[spell_name])
				player.spells.append(spell)

	# Desbloquear skills
	for skill_name in tree.skills.keys():
		var reqs = tree.skills[skill_name]
		var level_req = reqs.get("level", 0)

		var stat_req_pass = true
		for stat in reqs.keys():
			if stat == "level":
				continue
			# Verifica se o player tem stats mínimos (ex: STR, AGI, etc)
			if player.get(stat) < reqs[stat]:
				stat_req_pass = false
				break

		if player.level >= level_req and stat_req_pass:
			if skill_database.has(skill_name):
				var skill = create_skill(skill_name, skill_database[skill_name])
				player.skills.append(skill)
	
	# Desbloquear specials
	for special_name in tree.specials.keys():
		var reqs = tree.specials[special_name]
		var level_req = reqs.get("level", 0)

		var stat_req_pass = true
		for stat in reqs.keys():
			if stat == "level":
				continue
			if player.get(stat) < reqs[stat]:
				stat_req_pass = false
				break

		if player.level >= level_req and stat_req_pass:
			if special_database.has(special_name):
				var special = create_special(special_name, special_database[special_name])
				player.specials.append(special)

func check_ability_mastery(member, ability_name: String, is_spell: bool) -> void:
	var ap_dict
	if is_spell:
		ap_dict = member.spell_ap
	else:
		ap_dict = member.skill_ap
	var data = ap_dict[ability_name]
	var current_level = data.get("level", 1)
	var current_ap = data.get("current", 0)
	var ap_needed_per_level = {1: 50, 2: 100, 3: 200}

	if current_level >= 3:
		return

	var ap_needed = ap_needed_per_level[current_level]
	if current_ap >= ap_needed:
		data["level"] += 1
		data["current"] = 0
		member.apply_mastery_bonus(ability_name, data["level"], is_spell)
		if data["level"] == 3:
			if is_spell and ability_name in member.spell_upgrades:
				var evolved = member.spell_upgrades[ability_name]
				if evolved in spell_database:
					var evolved_spell = create_spell(evolved, spell_database[evolved])
					member.spells.append(evolved_spell)
					member.spell_ap[evolved] = {"current": 0, "level": 1}
					print("%s desbloqueou %s!" % [member.nome, evolved])
			elif not is_spell and ability_name in member.skill_upgrades:
				var evolved = member.skill_upgrades[ability_name]  # Corrigido aqui
				if evolved in skill_database:
					# Se tiver função create_skill, use ela. Se não, create_spell pode funcionar.
					var evolved_skill = create_skill(evolved, skill_database[evolved]) 
					member.skills.append(evolved_skill)
					member.skill_ap[evolved] = {"current": 0, "level": 1}
					print("%s desbloqueou %s!" % [member.nome, evolved])


# EXECUTA AÇÃO


func aplicar_dano(alvo, atacante, dano: int) -> void:
	alvo.current_hp -= dano
	if alvo.current_hp < 0:
		alvo.current_hp = 0
		alvo.check_if_dead()

	var updated := false

	if is_player(alvo):
		if alvo.increase_special_charge(dano * 0.75):
			sp_values[alvo] = alvo.special_charge
			updated = true

	if is_player(atacante):
		if atacante.increase_special_charge(dano * 0.5):
			sp_values[atacante] = atacante.special_charge
			updated = true

	if updated:
		hud.update_special_bar(sp_values)
		
	atualizar_obstrucao_inimigos()
	atualizar_obstrucao_party()
	
func _execute_skill(user, skill, alvo):
	
	if user.current_sp < skill.cost:
		hud.show_top_message("%s não tem SP suficiente para usar %s!" % [user.nome, skill.name])
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		end_turn()
		return
	user.current_sp -= skill.cost
	
	var is_fisico = skill.effect_type == "damage" and skill.effect_type != "magic"

	if not pode_atacar(alvo, user, is_fisico):
		hud.show_top_message("Alvo fora de alcance!")
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		end_turn()
		return
		
	var hit_roll = randf()
	if hit_roll > skill.hit_chance:
		hud.show_top_message("%s errou o uso de %s!" % [user.nome, skill.name])
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		reset_atb(user)
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		end_turn()
		return  # importante parar aqui

	if skill.effect_type == "damage":
		var base_dano = skill.power
		match skill.scaling_stat:
			"STR": base_dano += user.get_modified_stat(user.STR, "STR")
			"DEX": base_dano += user.get_modified_stat(user.DEX, "DEX")
			"INT": base_dano += user.get_modified_stat(user.INT, "INT")
			"SPI": base_dano += user.get_modified_stat(user.SPI, "SPI")
			_: base_dano += user.get_modified_stat(user.STR, "STR")

		var defesa_modificada = alvo.get_modified_stat(alvo.defense, "defense")
		var dano = base_dano - defesa_modificada
		dano = max(dano, 1)

		dano = ajustar_dano_por_posicao(dano, user, alvo, is_fisico)
		
		# Aplicar resistências
		var element_res = 1.0
		var attack_type_res = 1.0

		# Só aplicar se skill tiver element e attack_type preenchidos
		if skill.has_method("element") and skill.element != "":
			element_res = alvo.element_resistances.get(skill.element.to_lower(), 1.0)

		if skill.has_method("attack_type") and skill.attack_type != "":
			attack_type_res = alvo.attack_type_resistances.get(skill.attack_type.to_lower(), 1.0)
		
		dano = dano * element_res * attack_type_res
		
		# Crítico opcional baseado em LCK
		var crit_chance = user.LCK * 0.01
		if randf() < crit_chance:
			dano *= 2
			hud.show_top_message("CRÍTICO! %s usou %s e causou %d de dano em %s!" % [user.nome, skill.name, dano, alvo.nome])
		else:
			hud.show_top_message("%s usou %s e causou %d de dano em %s!" % [user.nome, skill.name, dano, alvo.nome])
		
		var ap_gain = int(10)  # Ganha mais AP se causar mais dano
		user.gain_ap(skill.name, ap_gain, false)
		aplicar_dano(alvo, user, dano)

		if alvo.current_hp <= 0:
			alvo.current_hp = 0
			if alvo.has_method("check_if_dead"):
				alvo.check_if_dead()
		hud.show_floating_number(dano, alvo, "damage")

	elif skill.effect_type == "heal":
		var cura = skill.power + user.SPI
		var ap_gain = int(100)  # Ganha mais AP se causar mais dano
		user.gain_ap(skill.name, ap_gain, false)
		alvo.current_hp = min(alvo.max_hp, alvo.current_hp + cura)
		hud.show_top_message("%s usou %s e curou %d HP em %s!" % [user.nome, skill.name, cura, alvo.nome])
		hud.show_floating_number(cura, alvo, "hp")

	elif skill.effect_type == "buff":
		var effect = StatusEffect.new()
		var ap_gain = int(100)  # Ganha mais AP se causar mais dano
		user.gain_ap(skill.name, ap_gain, false)
		effect.attribute = skill.scaling_stat
		effect.amount = skill.amount
		effect.duration = skill.duration if skill.duration > 0 else 3
		effect.type = StatusEffect.Type.BUFF
		alvo.apply_status_effect(effect)
		hud.show_top_message("%s aumentou %s de %s com %s!" % [user.nome, effect.attribute, alvo.nome, skill.name])

	if skill.status_inflicted != "":
		if randf() <= skill.status_chance:
			var status_effect = StatusEffect.new()
			status_effect.attribute = skill.status_inflicted
			status_effect.amount = 0  # para status como "stun", "poison", etc.
			status_effect.duration = skill.duration if skill.duration > 0 else 2
			status_effect.type = StatusEffect.Type.DEBUFF
			alvo.apply_status_effect(status_effect)
			hud.show_top_message("%s foi afetado por %s!" % [alvo.nome, skill.status_inflicted])

	reset_atb(user)
	hud.update_enemy_info(enemies)
	hud.update_party_info(party)
	_create_menu()
	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	end_turn()

func _execute_skill_area(user, skill, alvos):
	
	if user.current_sp < skill.cost:
		hud.show_top_message("%s não tem SP suficiente para usar %s!" % [user.nome, skill.name])
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		end_turn()
		return
		
	user.current_sp -= skill.cost
	
	var is_fisico = skill.effect_type == "damage" and skill.effect_type != "magic"

	for alvo in alvos:
		if alvo.current_hp <= 0:
			continue  # Ignora inimigos mortos

		if not pode_atacar(alvo, user, is_fisico):
			continue  # Pula alvos fora de alcance

		var hit_roll = randf()
		if hit_roll > skill.hit_chance:
			hud.show_top_message("%s errou %s em %s!" % [user.nome, skill.name, alvo.nome])
			continue  # Erro individual por alvo

		if skill.effect_type == "damage":
			var base_dano = skill.power
			match skill.scaling_stat:
				"STR": base_dano += user.get_modified_stat(user.STR, "STR")
				"DEX": base_dano += user.get_modified_stat(user.DEX, "DEX")
				"INT": base_dano += user.get_modified_stat(user.INT, "INT")
				"SPI": base_dano += user.get_modified_stat(user.SPI, "SPI")
				_: base_dano += user.get_modified_stat(user.STR, "STR")

			var defesa_modificada = alvo.get_modified_stat(alvo.defense, "defense")
			var dano = base_dano - defesa_modificada
			dano = max(dano, 1)

			dano = ajustar_dano_por_posicao(dano, user, alvo, is_fisico)

			var element_res = 1.0
			var attack_type_res = 1.0

			if skill.has_method("element") and skill.element != "":
				element_res = alvo.element_resistances.get(skill.element.to_lower(), 1.0)

			if skill.has_method("attack_type") and skill.attack_type != "":
				attack_type_res = alvo.attack_type_resistances.get(skill.attack_type.to_lower(), 1.0)

			dano *= element_res * attack_type_res

			var crit_chance = user.LCK * 0.01
			var crit = randf() < crit_chance
			if crit:
				dano *= 2
				hud.show_top_message("CRÍTICO! %s usou %s e causou %d de dano em %s!" % [user.nome, skill.name, dano, alvo.nome])
			else:
				hud.show_top_message("%s usou %s e causou %d de dano em %s!" % [user.nome, skill.name, dano, alvo.nome])

			user.gain_ap(skill.name, 100, false)
			aplicar_dano(alvo, user, dano)

			if alvo.current_hp <= 0:
				alvo.current_hp = 0
				if alvo.has_method("check_if_dead"):
					alvo.check_if_dead()

			hud.show_floating_number(dano, alvo, "damage")

		elif skill.effect_type == "heal":
			var cura = skill.power + user.get_modified_stat(user.SPI, "SPI")
			user.gain_ap(skill.name, 100, false)
			alvo.current_hp = min(alvo.max_hp, alvo.current_hp + cura)
			hud.show_top_message("%s usou %s e curou %d HP em %s!" % [user.nome, skill.name, cura, alvo.nome])
			hud.show_floating_number(cura, alvo, "hp")

		elif skill.effect_type == "buff":
			var effect = StatusEffect.new()
			user.gain_ap(skill.name, 100, false)
			effect.attribute = skill.scaling_stat
			effect.amount = skill.amount
			effect.duration = skill.duration if skill.duration > 0 else 3
			effect.type = StatusEffect.Type.BUFF
			alvo.apply_status_effect(effect)
			hud.show_top_message("%s aumentou %s de %s com %s!" % [user.nome, effect.attribute, alvo.nome, skill.name])

		# Aplica status secundário se existir
		if skill.status_inflicted != "":
			if randf() <= skill.status_chance:
				var status_effect = StatusEffect.new()
				status_effect.attribute = skill.status_inflicted
				status_effect.amount = 0
				status_effect.duration = skill.duration if skill.duration > 0 else 2
				status_effect.type = StatusEffect.Type.DEBUFF
				alvo.apply_status_effect(status_effect)
				hud.show_top_message("%s foi afetado por %s!" % [alvo.nome, skill.status_inflicted])

	reset_atb(user)
	hud.update_enemy_info(enemies)
	hud.update_party_info(party)
	await get_tree().create_timer(0).timeout
	_create_menu()
	end_turn()

func _execute_spell_area(caster, spell_name, alvos):
	var spell = get_spell_by_name(caster.spells, spell_name)
	if spell == null:
		hud.show_top_message("Magia não encontrada.")
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		end_turn()
		return

	if caster.current_mp < spell.cost:
		hud.show_top_message("%s não tem MP suficiente para usar %s!" % [caster.nome, spell.name])
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		end_turn()
		return

	if !caster.spell_slots.has(spell.level) or caster.spell_slots[spell.level] <= 0:
		hud.show_top_message("%s não tem slots de nível %d suficientes para usar %s!" % [caster.nome, spell.level, spell.name])
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		end_turn()
		return

	caster.current_mp -= spell.cost
	caster.spell_slots[spell.level] -= 1

	var tipo = spell.type

	for alvo in alvos:
		if alvo.current_hp <= 0:
			continue  # Pular inimigos mortos

		if tipo == "damage":
			var base_dano = spell.power + caster.get_modified_stat(caster.INT, "INT")
			var defesa_magica = alvo.get_modified_derived_stat("magic_defense")
			var dano = base_dano - defesa_magica
			dano = max(dano, 1)

			var element_res = alvo.element_resistances.get(spell.element.to_lower(), 1.0) if spell.element != "" else 1.0
			var attack_type_res = alvo.attack_type_resistances.get(spell.attack_type.to_lower(), 1.0) if spell.attack_type != "" else 1.0
			dano *= element_res * attack_type_res

			caster.gain_ap(spell.name, 100, true)
			aplicar_dano(alvo, caster, dano)

			if alvo.current_hp <= 0:
				alvo.current_hp = 0
				if alvo.has_method("check_if_dead"):
					alvo.check_if_dead()

			hud.show_top_message("%s atingido por %s: %d de dano!" % [alvo.nome, spell_name, dano])
			hud.show_floating_number(dano, alvo, "damage")

		elif tipo == "heal":
			var cura = spell.power + caster.get_modified_stat(caster.SPI, "SPI")
			caster.gain_ap(spell.name, 100, true)
			alvo.current_hp = min(alvo.max_hp, alvo.current_hp + cura)
			hud.show_top_message("%s curado por %s: %d de HP!" % [alvo.nome, spell_name, cura])
			hud.show_floating_number(cura, alvo, "hp")

		elif tipo == "buff" or tipo == "debuff":
			var effect = StatusEffect.new()
			caster.gain_ap(spell.name, 100, true)
			effect.attribute = spell.attribute
			effect.amount = spell.amount
			effect.duration = spell.duration
			effect.type = StatusEffect.Type.BUFF if tipo == "buff" else StatusEffect.Type.DEBUFF
			alvo.apply_status_effect(effect)
			var acao = "aumentado" if tipo == "buff" else "reduzido"
			hud.show_top_message("%s teve %s %s por %s!" % [alvo.nome, spell.attribute, acao, spell_name])

	reset_atb(caster)
	hud.update_enemy_info(enemies)
	hud.update_party_info(party)
	await get_tree().create_timer(0).timeout
	_create_menu()
	end_turn()

func _execute_spell_single(caster, spell_name, alvo):
	var spell = get_spell_by_name(caster.spells, spell_name)
	if spell == null:
		hud.show_top_message("Magia não encontrada.")
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		end_turn()
		return

	if caster.current_mp < spell.cost:
		hud.show_top_message("%s não tem MP suficiente para usar %s!" % [caster.nome, spell.name])
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		end_turn()
		return

	if !caster.spell_slots.has(spell.level) or caster.spell_slots[spell.level] <= 0:
		hud.show_top_message("%s não tem slots de nível %d suficientes para usar %s!" % [caster.nome, spell.level, spell.name])
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		end_turn()
		return

	caster.current_mp -= spell.cost
	caster.spell_slots[spell.level] -= 1

	var tipo = spell.type
	var efeito = 0

	if tipo == "damage":
		var base_dano = spell.power + caster.get_modified_stat(caster.INT, "INT")
		var defesa_magica = alvo.get_modified_derived_stat("magic_defense")
		var dano = base_dano - defesa_magica
		dano = max(dano, 1)

		var crit_chance = caster.get_modified_stat(caster.LCK, "LCK") * 0.01
		if randf() < crit_chance:
			dano *= 2
			hud.show_top_message("CRÍTICO MÁGICO! %s usou %s e causou %d de dano em %s!" % [caster.nome, spell.name, dano, alvo.nome])
		else:
			hud.show_top_message("%s usou %s em %s causando %d de dano!" % [caster.nome, spell.name, alvo.nome, dano])
		
					# Aplicar resistências
		var element_res = 1.0
		var attack_type_res = 1.0
		
		if spell.element != "":
			element_res = alvo.element_resistances.get(spell.element.to_lower(), 1.0)
		else:
			element_res = 1.0

		if spell.attack_type != "":
			attack_type_res = alvo.attack_type_resistances.get(spell.attack_type.to_lower(), 1.0)
		else:
			attack_type_res = 1.0
		dano *= element_res * attack_type_res
		var ap_gain = int(100)  # Ganha mais AP se causar mais dano
		caster.gain_ap(spell.name, ap_gain, true)
		aplicar_dano(alvo, caster, dano)
		
		if alvo.current_hp <= 0:
			alvo.current_hp = 0
			if alvo.has_method("check_if_dead"):
				alvo.check_if_dead()
				
		hud.show_floating_number(dano, alvo, "damage")

	elif tipo == "heal":
		var cura = spell.power + caster.get_modified_stat(caster.SPI, "SPI")
		var ap_gain = int(100)  # Ganha mais AP se causar mais dano
		caster.gain_ap(spell.name, ap_gain, true)
		alvo.current_hp = min(alvo.max_hp, alvo.current_hp + cura)
		hud.show_top_message("%s curou %s com %s em %d de HP!" % [caster.nome, alvo.nome, spell.name, cura])
		hud.show_floating_number(cura, alvo, "hp")

	elif tipo == "buff" or tipo == "debuff":
		var effect = StatusEffect.new()
		effect.attribute = spell.attribute
		effect.amount = spell.amount
		effect.duration = spell.duration
		effect.type = StatusEffect.Type.BUFF if spell.type == "buff" else StatusEffect.Type.DEBUFF
		var ap_gain = int(100)  # Ganha mais AP se causar mais dano
		caster.gain_ap(spell.name, ap_gain, true)
		alvo.apply_status_effect(effect)

		var acao = "aumentado" if spell.type == "buff" else "reduzido"
		hud.show_top_message("%s teve %s %s por %s!" % [alvo.nome, spell.attribute, acao, spell.name])
	
	reset_atb(caster)
	hud.update_enemy_info(enemies)
	hud.update_party_info(party)
	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	end_turn()

func perform_attack(attacker, target) -> void:
	# Verifica se pode atacar (regra de posição/alcance)
	var is_ataque_fisico = true  # aqui assumimos que este é um ataque físico normal
	if not pode_atacar(target, attacker, is_ataque_fisico):
		hud.show_top_message("Alvo fora de alcance!")
		reset_atb(attacker)
		hud.update_party_info(party)
		return

	# Obter stats modificados
	var attacker_accuracy = attacker.get_modified_stat(attacker.accuracy, "accuracy")
	var target_evasion = target.get_modified_stat(target.evasion, "evasion")
	var attacker_str = attacker.get_modified_stat(attacker.STR, "STR")
	var attacker_dex = attacker.get_modified_stat(attacker.DEX, "DEX")
	var target_def = target.get_modified_stat(target.defense, "defense")
	var attacker_lck = attacker.get_modified_stat(attacker.LCK, "LCK")
	
	# Calcular chance de acerto
	var hit_chance = attacker_accuracy / float(attacker_accuracy + target_evasion)
	var roll = randf()
	if roll > hit_chance:
		hud.show_top_message("%s errou o ataque!" % attacker.nome)
		reset_atb(attacker)
		hud.update_party_info(party)
		return

	# Calcular chance de crítico
	var crit_chance = attacker_lck * 0.01
	var is_crit = randf() < crit_chance
	
		# Tipo de ataque do atacante (deve estar definido no personagem)
	var attack_type = attacker.attack_type

	# Modificador de defesa baseado no tipo de ataque
	var defense_modifier = 1.0
	
	if attack_type in target.attack_type_resistances:
		defense_modifier = target.attack_type_resistances[attack_type]

	# Calcular dano base considerando o modificador
	var damage = attacker_str + int(attacker_dex / 2) - int(target_def * defense_modifier)
	damage = max(damage, 1)
	
	# Ajuste de dano por posição (frente/trás)
	damage = ajustar_dano_por_posicao(damage, attacker, target, is_ataque_fisico)

	if is_crit:
		damage *= 2
		hud.show_top_message("CRÍTICO! %s causou %d de dano!" % [attacker.nome, damage])
	else:
		hud.show_top_message("%s causou %d de dano!" % [attacker.nome, damage])

	# Aplicar dano
	aplicar_dano(target, attacker, damage)
	hud.show_floating_number(damage, target, "damage")

	# Verifica se morreu
	if target.current_hp <= 0:
		target.current_hp = 0
		if target.has_method("check_if_dead"):
			target.check_if_dead()
		hud.show_top_message("%s foi derrotado!" % target.nome)

	# Reset ATB
	reset_atb(attacker)
	hud.update_enemy_info(enemies)
	hud.update_party_info(party)

func _execute_special_area(caster, special: Special, alvos):
	for alvo in alvos:
		if alvo.current_hp <= 0:
			continue  # Ignorar inimigos mortos

		match special.effect_type:
			"damage":
				var dano = special.power + caster.get_modified_stat(caster.STR, "STR")
				dano = ajustar_dano_por_posicao(dano, caster, alvo, true)
				aplicar_dano(alvo, caster, dano)
				hud.show_floating_number(dano, alvo, "damage")

			"heal":
				var cura = special.power + caster.get_modified_stat(caster.SPI, "SPI")
				alvo.current_hp = min(alvo.max_hp, alvo.current_hp + cura)
				hud.show_floating_number(cura, alvo, "hp")

			"buff":
				var effect = StatusEffect.new()
				effect.attribute = special.attribute
				effect.amount = special.amount
				effect.duration = special.duration
				effect.type = StatusEffect.Type.BUFF
				alvo.apply_status_effect(effect)

	hud.show_top_message("%s usou %s!" % [caster.nome, special.name])
	reset_atb(caster)
	hud.update_enemy_info(enemies)
	hud.update_party_info(party)
	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout

	caster.special_charge = 0
	sp_values[caster] = 0
	caster.special_ready = false
	hud.update_special_bar(sp_values)

	_create_menu()
	end_turn()

func _execute_special_single(user, special, alvo):
	match special.effect_type:
		"damage":
			var dano = special.power + user.get_modified_stat(user.STR, "STR")
			dano = ajustar_dano_por_posicao(dano, user, alvo, true)
			aplicar_dano(alvo, user, dano)
			hud.show_top_message("%s usou %s e causou %d de dano!" % [user.nome, special.name, dano])
			hud.show_floating_number(dano, alvo, "damage")

		"heal":
			var cura = special.power + user.get_modified_stat(user.SPI, "SPI")
			alvo.current_hp = min(alvo.max_hp, alvo.current_hp + cura)
			hud.show_top_message("%s usou %s e curou %d HP!" % [user.nome, special.name, cura])
			hud.show_floating_number(cura, alvo, "hp")

		"buff":
			var effect = StatusEffect.new()
			effect.attribute = special.attribute
			effect.amount = special.amount
			effect.duration = special.duration
			effect.type = StatusEffect.Type.BUFF
			alvo.apply_status_effect(effect)
			hud.show_top_message("%s usou %s e aumentou %s!" % [user.nome, special.name, special.attribute])

	# Pós-ação
	reset_atb(user)
	hud.update_enemy_info(enemies)
	hud.update_party_info(party)
	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout

	# Reset de especial
	user.special_charge = 0
	sp_values[user] = 0
	user.special_ready = false
	hud.update_special_bar(sp_values)

	_create_menu()
	end_turn()

func usar_item_em_alvo(usuario, item_name: String, item_data: Dictionary, target_id) -> void:
	# Encontrar o personagem da party com o ID correspondente
	var alvo = null
	for membro in party:
		if membro.id == target_id:
			alvo = membro
			break
	
	if alvo == null:
		print("Erro: alvo com ID %s não encontrado na party!" % target_id)
		return
		
	match item_data.type:
		"heal":
			alvo.current_hp += item_data.power
			alvo.current_hp = min(alvo.current_hp, alvo.max_hp)
			hud.show_floating_number(item_data.power, alvo, "hp")
			hud.show_top_message("%s usou %s em %s!" % [usuario.nome, item_name, alvo.nome])

		"restore_mp":
			alvo.current_mp += item_data.power
			alvo.current_mp = min(alvo.current_mp, alvo.max_mp)
			hud.show_floating_number(item_data.power, alvo, "mp")
			hud.show_top_message("%s recuperou MP com %s!" % [alvo.nome, item_name])
			
		"restore_sp":
			alvo.current_sp += item_data.power
			alvo.current_sp = min(alvo.current_mp, alvo.max_sp)
			hud.show_floating_number(item_data.power, alvo, "sp")
			hud.show_top_message("%s recuperou MP com %s!" % [alvo.nome, item_name])

		"full_restore":
			alvo.current_hp = alvo.max_hp
			alvo.current_mp = alvo.max_mp
			alvo.current_sp = alvo.max_sp
			hud.show_floating_number(alvo.max_hp, alvo, "hp")
			await get_tree().create_timer(1.0).timeout
			hud.show_floating_number(alvo.max_mp, alvo, "mp")
			await get_tree().create_timer(1.0).timeout
			hud.show_floating_number(alvo.max_sp, alvo, "sp")
			hud.show_top_message("%s foi totalmente restaurado com %s!" % [alvo.nome, item_name])

		"cure_status":
			alvo.remove_status(item_data.status)
			hud.show_top_message("%s foi curado de %s!" % [alvo.nome, item_data.status])

	# Remover item do inventário
	if inventory.has(item_name):
		inventory[item_name] -= 1
		if inventory[item_name] <= 0:
			inventory.erase(item_name)

	# Encerrar turno
	reset_atb(usuario)
	hud.update_party_info(party)
	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	hud.hide_arrow()
	end_turn()

func tentar_fugir(actor) -> void:
	var vivos = party.filter(func(p): return p.is_alive()).size()
	if vivos == 0:
		hud.show_top_message("Ninguém pode fugir!")
		return

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var agi_total = 0
	var lck_total = 0
	for membro in party:
		if membro.is_alive():
			agi_total += membro.AGI
			lck_total += membro.LCK

	var media_agi = agi_total / vivos
	var media_lck = lck_total / vivos

	# Fórmula da chance de fuga
	var chance_fuga = clamp((media_agi * 2 + media_lck) / 3 + rng.randi_range(0, 20), 0, 100)

	var roll = rng.randi_range(0, 100)

	if roll < chance_fuga:
		hud.show_top_message("%s escapou com sucesso!" % actor.nome)
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		reset_atb(actor)
		end_battle(false)  # Finaliza a batalha sem vitória
	else:
		hud.show_top_message("%s tentou fugir, mas falhou!" % actor.nome)
		await get_tree().create_timer(0.2).timeout
	# 🔧 Oculta seta de seleção
		hud.hide_arrow()
		reset_atb(actor)
		hud.set_hud_buttons_enabled(false)
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		end_turn()


# SELECIONA AÇÃO


func _on_player_action_selected(action_name: String) -> void:
	match action_name:
		"Atacar":
			var alvos_validos = enemies.filter(func(e): return e.is_alive())
			var targets = []
			for enemy in enemies:
				if enemy.is_alive():
					targets.append({
						"id": enemy.id,
						"nome": enemy.nome,
						"node_ref": enemy
					})
			hud.target_selected.connect(_on_alvo_ataque_selecionado)
			hud.show_target_menu(targets, current_actor)

		"Magia", "Skills":
			if current_actor.is_magic_user():
				var magias = current_actor.get_available_spells()
				var mp = current_actor.current_mp
				var slots = current_actor.spell_slots
				if magias.is_empty():
					hud.show_top_message("%s não possui magias disponíveis." % current_actor.nome)
					await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
					next_turn()
					return
				hud.magic_selected.connect(_on_magic_selected)
				hud.show_magic_menu(magias, mp, slots)
			else:
				var skills = current_actor.skills
				if skills.is_empty():
					hud.show_top_message("%s não possui técnicas disponíveis." % current_actor.nome)
					await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
					next_turn()
					return
				hud.skill_selected.connect(_on_skill_selected)
				hud.show_skill_menu(skills, current_actor.current_sp)
		"Item":
			var items = inventory
			if items.is_empty():
				hud.show_top_message("%s não possui itens." % current_actor.nome)
				await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
				next_turn()
				return
			hud.item_selected.connect(_on_item_selected)
			hud.show_item_menu(items)
		"Defender":
			current_actor.is_defending = true
			hud.show_top_message("%s está em posição defensiva!" % current_actor.nome)
			reset_atb(current_actor)
			hud.update_party_info(party)
			hud.set_hud_buttons_enabled(false)
			await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
			hud.hide_arrow()
			end_turn()
			# Lógica de defesa
		"Fugir":
			print("Tentando fugir da batalha")
			await tentar_fugir(current_actor)
			# Lógica de fuga
		"Especial":
			var especiais = current_actor.specials

			if especiais.is_empty():
				await hud.show_top_message("%s não possui habilidades especiais disponíveis." % current_actor.nome)
				await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
				next_turn()
				return

			hud.special_selected.connect(_on_special_selected)
			hud.show_special_menu(especiais)

func _on_alvo_ataque_selecionado(alvo_id):
	if hud.target_selected.is_connected(_on_alvo_ataque_selecionado):
		hud.target_selected.disconnect(_on_alvo_ataque_selecionado)

	var jogador_atual = current_actor
	var target_enemy = find_enemy_by_id(alvo_id)
	if target_enemy:
		await perform_attack(jogador_atual, target_enemy)
	else:
		print("Alvo não encontrado:", alvo_id)

	# 🔧 Oculta seta de seleção
	hud.hide_arrow()
	
	# 🔧 Atualiza barras de ATB visualmente
	hud.update_atb_bars(atb_values)

	# 🔧 Desabilita HUD
	hud.set_hud_buttons_enabled(false)

	# 🔧 Espera e finaliza turno
	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	end_turn()

func _on_skill_selected(skill_name: String):
	if hud.skill_selected.is_connected(_on_skill_selected):
		hud.skill_selected.disconnect(_on_skill_selected)

	var user = current_actor
	var skill_matches = user.skills.filter(func(s): return s.name == skill_name)

	if skill_matches.is_empty():
		return

	var skill = skill_matches[0]
	hud.set_meta("skill_name", skill_name)

	var alvos = []
	match skill.target_type:
		"enemy":
			alvos = enemies.filter(func(e): return e.current_hp > 0)
		"self":
			alvos = [user]
		"ally":
			alvos = party.filter(func(p): return p.current_hp > 0)
		"all_enemies":
			alvos = enemies.filter(func(e): return e.current_hp > 0)
		"line":
			# Habilita seleção de linha (frente/trás)
			if hud.line_target_selected.is_connected(_on_skill_line_target_selected):
				hud.line_target_selected.disconnect(_on_skill_line_target_selected)
			hud.line_target_selected.connect(_on_skill_line_target_selected)
			hud.set_meta("spell_name", skill.name)
			hud.show_line_target_menu(["frente", "trás"])
			return  # Aguarda seleção do jogador
		_:
			alvos = enemies.filter(func(e): return e.current_hp > 0)

	if skill.target_type == "self":
		await _execute_skill(user, skill, user)
	elif skill.target_type == "all_enemies":
		await _execute_skill_area(user, skill, alvos)
	else:
		# Caso padrão: mostra seleção de alvos
		if hud.target_selected.is_connected(_on_skill_target_selected):
			hud.target_selected.disconnect(_on_skill_target_selected)
		hud.target_selected.connect(_on_skill_target_selected)

		var formatted_targets = []
		for target in alvos:
			formatted_targets.append({
				"id": target.id,
				"nome": target.nome,
				"node_ref": target
			})
		hud.show_target_menu(formatted_targets, current_actor)

func _on_magic_selected(spell_name: String):
	hud.magic_selected.disconnect(_on_magic_selected)

	var caster = current_actor

	# Buscar spell no array pelo nome
	var spell_data: Spell = null
	for spell in caster.spells:
		if spell.name.to_lower() == spell_name.to_lower():
			spell_data = spell
			break

	if not spell_data:
		hud.show_top_message("Magia não encontrada.")
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		next_turn()
		return

	var tipo = spell_data.type
	var alvos := []

	match tipo:
		"heal", "buff":
			alvos = party.filter(func(p): return p.current_hp > 0)
		"debuff", "damage":
			alvos = enemies.filter(func(e): return e.current_hp > 0)
		_:
			alvos = enemies.filter(func(e): return e.current_hp > 0)

	if alvos.is_empty():
		hud.show_top_message("Nenhum alvo válido.")
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		next_turn()
		return

	var target_group = spell_data.target_group

	match target_group:
		"area":
			await _execute_spell_area(caster, spell_name, alvos)

		"line":
			# Jogador escolhe "frente" ou "trás"
			hud.line_target_selected.connect(_on_magic_line_target_selected)
			hud.show_line_target_menu(["frente", "trás"])
			hud.set_meta("spell_name", spell_name)

		"single", _:
			hud.target_selected.connect(_on_magic_target_selected)
			var formatted_targets = []
			for target in alvos:
				formatted_targets.append({
					"id": target.id,
					"nome": target.nome,
					"node_ref": target
				})
			hud.show_target_menu(formatted_targets)
			hud.set_meta("spell_name", spell_name)

func _on_magic_line_target_selected(linha: String):
	hud.line_target_selected.disconnect(_on_magic_line_target_selected)

	var spell_name = hud.get_meta("spell_name")
	var caster = current_actor

	var linha_alvos = []
	
	if linha == "frente":
		linha_alvos = enemies.filter(func(e): return e.current_hp > 0 and e.position_line == "front")
	elif linha == "trás":
		linha_alvos = enemies.filter(func(e): return e.current_hp > 0 and e.position_line == "back")

	await _execute_spell_area(caster, spell_name, linha_alvos)

func _on_skill_line_target_selected(linha: String):
	hud.line_target_selected.disconnect(_on_skill_line_target_selected)

	var skill_name = hud.get_meta("skill_name")  # Corrigido de "spell_name" para "skill_name"
	var caster = current_actor

	var skill_matches = caster.skills.filter(func(s): return s.name == skill_name)
	if skill_matches.is_empty():
		print("Skill não encontrada:", skill_name)
		return

	var skill = skill_matches[0]

	var linha_alvos = []
	if linha == "frente":
		linha_alvos = enemies.filter(func(e): return e.current_hp > 0 and e.position_line == "front")
	elif linha == "trás":
		linha_alvos = enemies.filter(func(e): return e.current_hp > 0 and e.position_line == "back")

	await _execute_skill_area(caster, skill, linha_alvos)

func _on_magic_target_selected(alvo):
	hud.target_selected.disconnect(_on_magic_target_selected)

	var spell_name = hud.get_meta("spell_name")
	var caster = current_actor

	var target = find_enemy_by_id(alvo)
	
	if target == null:
		# Tenta encontrar nos aliados (party)
		for membro in party:
			if membro.id == alvo:
				target = membro
				break

	if target:
		await _execute_spell_single(caster, spell_name, target)
	else:
		print("Alvo não encontrado:", alvo)

func _on_skill_target_selected(target_id):
	if hud.target_selected.is_connected(_on_skill_target_selected):
		hud.target_selected.disconnect(_on_skill_target_selected)

	var user = current_actor
	var skill_name = hud.get_meta("skill_name")

	var skill_matches = user.skills.filter(func(s): return s.name == skill_name)
	if skill_matches.is_empty():
		print("Skill não encontrada:", skill_name)
		return

	var skill = skill_matches[0]
	var target = find_enemy_by_id(target_id)

	if target == null:
		for member in party:
			if member.id == target_id:
				target = member
				break

	if target:
		await _execute_skill(user, skill, target)
	else:
		hud.show_top_message("Alvo inválido.")
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		next_turn()

func _on_item_selected(item_name: String) -> void:
	var item_data = item_database.get(item_name, null)
	if item_data == null:
		hud.show_top_message("Item desconhecido!")
		return

	var target_list = []
	for membro in party:
		if membro.is_alive():
			target_list.append({
				"id": membro.id,
				"nome": membro.nome,
				"node_ref": membro
			})

	# Seleção de alvo
	hud.target_selected.connect(func(target):
		usar_item_em_alvo(current_actor, item_name, item_data, target)
	)
	hud.show_target_menu(target_list)

func _on_special_selected(especial):
	
	hud.hide_special_menu()

	if especial == null:
		hud.show_top_message("Especial não encontrado.")
		await get_tree().create_timer(1.0).timeout
		next_turn()
		return

	match especial.target_type:
		"all_enemies":
			_execute_special_area(current_actor, especial, enemies)

		"ally_party":
			_execute_special_area(current_actor, especial, party)

		"self":
			_execute_special_single(current_actor, especial, current_actor)

		"enemy":
			var alvos = []
			for enemy in enemies:
				if enemy.is_alive():
					alvos.append({
						"id": enemy.id,
						"nome": enemy.nome,
						"node_ref": enemy
					})
			hud.target_selected.connect(_on_special_target_selected.bind(especial))
			hud.show_target_menu(alvos)

		"ally":
			var alvos = []
			for ally in party:
				if ally.is_alive():
					alvos.append({
						"id": ally.id,
						"nome": ally.nome,
						"node_ref": ally
					})
			hud.target_selected.connect(_on_special_target_selected.bind(especial))
			hud.show_target_menu(alvos)

		_:
			hud.show_top_message("Tipo de alvo inválido.")
			await get_tree().create_timer(1.0).timeout
			next_turn()

func _on_special_target_selected(target_id, especial):
	if hud.target_selected.is_connected(_on_special_target_selected):
		hud.target_selected.disconnect(_on_special_target_selected)

	var alvo = null

	for enemy in enemies:
		if enemy.id == target_id:
			alvo = enemy
			break
	if alvo == null:
		for ally in party:
			if ally.id == target_id:
				alvo = ally
				break

	if alvo == null:
		hud.show_top_message("Alvo inválido.")
		await get_tree().create_timer(1.0).timeout
		next_turn()
		return

	await _execute_special_single(current_actor, especial, alvo)

func _on_hud_back_pressed():
	# Desconecta todos os sinais temporários
	if hud.magic_selected.is_connected(_on_magic_selected):
		hud.magic_selected.disconnect(_on_magic_selected)
	if hud.skill_selected.is_connected(_on_skill_selected):
		hud.skill_selected.disconnect(_on_skill_selected)
	if hud.special_selected.is_connected(_on_special_selected):
		hud.special_selected.disconnect(_on_special_selected)
	if hud.target_selected.is_connected(_on_skill_target_selected):
		hud.target_selected.disconnect(_on_skill_target_selected)
	if hud.target_selected.is_connected(_on_magic_target_selected):
		hud.target_selected.disconnect(_on_magic_target_selected)
	if hud.target_selected.is_connected(_on_special_target_selected):
		hud.target_selected.disconnect(_on_special_target_selected)
	if hud.line_target_selected.is_connected(_on_magic_line_target_selected):
		hud.line_target_selected.disconnect(_on_magic_line_target_selected)
	if hud.line_target_selected.is_connected(_on_skill_line_target_selected):
		hud.line_target_selected.disconnect(_on_skill_line_target_selected)

	# Limpa quaisquer metadados pendentes
	hud.set_meta("skill_name", null)
	hud.set_meta("spell_name", null)

	# Retorna ao menu de ações
	hud.show_action_menu()
	hud.set_hud_buttons_enabled(true, current_actor)
	hud.indicate_current_player(current_actor)
