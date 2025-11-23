# Database1990.gd
extends Node

# Este script deve ser configurado como um AutoLoad (Singleton)
# com o nome "Database1990".

# Ele guarda todos os dados estáticos do jogo para a década de 1990.

var status_cure_map = {
	"poison": {"items": ["Antídoto"], "spells": ["Esuna"]},
	"sleep": {"items": ["Despertar"], "spells": ["Esuna"]},
	"paralysis": {"items": ["Tônico Neural"], "spells": ["Esuna"]},
	"blind": {"items": ["Colírio"], "spells": ["Esuna"]},
	"confuse": {"items": ["Calmante"], "spells": ["Esuna"]},
	"curse": {"items": ["Água Benta"], "spells": ["Esuna"]},
	"petrify": {"items": ["Erva Suave"], "spells": ["Esuna"]},
	"charm": {"items": [], "spells": ["Dispel"]},
	"doom": {"items": [], "spells": ["Dispel"]},
	"stop": {"items": [], "spells": ["Dispel"]},
	"stun": {"items": [], "spells": ["Dispel"]},
	"slow": {"items": [], "spells": ["Dispel"]},
	"knockout": {"items": ["Spirit Water"], "spells": ["Revive"]}
}

var item_database = {
	"Potion": {"type": "heal", "power": 50, "target": "ally"},
	"Ether": {"type": "restore_mp", "power": 30, "target": "ally"},
	"Spirit Water": {"type": "restore_sp", "power": 30, "target": "ally"},
	"Elixir": {"type": "full_restore", "target": "ally"},
	
	"Antídoto": {"type": "cure_status", "status": "poison", "target": "ally"},
	"Despertar": {"type": "cure_status", "status": "sleep", "target": "ally"},
	"Tônico Neural": {"type": "cure_status", "status": "paralysis", "target": "ally"},
	"Colírio": {"type": "cure_status", "status": "blind", "target": "ally"},
	"Calmante": {"type": "cure_status", "status": "confuse", "target": "ally"},
	"Água Benta": {"type": "cure_status", "status": "curse", "target": "ally"},
	"Erva Suave": {"type": "cure_status", "status": "petrify", "target": "ally"},
}

var enemy_base_stats = {
	"Goblin": {
		"STR": 10, "DEX": 6, "AGI": 20, "CON": 3, "MAG": 1, "INT": 2, "SPI": 2, "LCK": 4,
		"xp_value": 20, "sprite_path": "res://assets/Goblin.png", "enemy_type": "Beast", "attack_type": "blunt",
		"ai_behavior": "goblin_oportunista",
		"alcance_estendido": false
	},
	"Orc": {
		"STR": 10, "DEX": 4, "AGI": 20, "CON": 6, "MAG": 2, "INT": 3, "SPI": 3, "LCK": 3,
		"xp_value": 50, "sprite_path": "res://assets/Little Orc.png", "enemy_type": "Beast", "attack_type": "blunt",
		"ai_behavior": "orc_brutamontes",
		"alcance_estendido": false
	},
	"Lobo": {
		"STR": 8, "DEX": 6, "AGI": 8, "CON": 6, "MAG": 0, "INT": 0, "SPI": 4, "LCK": 6,
		"xp_value": 50, "sprite_path": "res://assets/Lobo.png", "enemy_type": "Beast", "attack_type": "slash",
		"ai_behavior": "lobo_cacador",
		"alcance_estendido": false
	},
	"Dragão": {
		"STR": 32, "DEX": 7, "AGI": 8, "CON": 32, "MAG": 0, "INT": 2, "SPI": 2, "LCK": 5,
		"xp_value": 45, "sprite_path": "res://assets/Dragão.png", "enemy_type": "Beast", "attack_type": "slash",
		"ai_behavior": "dragao_tatico",
		"alcance_estendido": true,
		"base_cooldowns": { "fire_breath": 3 }
	}
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
		"STR": 40, "DEX": 8, "AGI": 4, "CON": 10, "MAG": 1, "INT": 3, "SPI": 5, "LCK": 5,
		"attack_type": "slash"
	},
	"Mage": {
		"STR": 1, "DEX": 4, "AGI": 7, "CON": 3, "MAG": 20, "INT": 13, "SPI": 10, "LCK": 7,
		"attack_type": "blunt"
	},
	"Thief": {
		"STR": 8, "DEX": 12, "AGI": 12, "CON": 4, "MAG": 1, "INT": 4, "SPI": 2, "LCK": 12,
		"attack_type": "pierce"
	},
	"Cleric": {
		"STR": 3, "DEX": 4, "AGI": 7, "CON": 10, "MAG": 10, "INT": 8, "SPI": 15, "LCK": 7,
		"attack_type": "blunt"
	},
	"Hunter": {
		"STR": 7, "DEX": 12, "AGI": 12, "CON": 5, "MAG": 1, "INT": 3, "SPI": 3, "LCK": 17,
		"attack_type": "ranged"
	},
	"Paladin": {
		"STR": 30, "DEX": 8, "AGI": 5, "CON": 9, "MAG": 6, "INT": 5, "SPI": 12, "LCK": 9,
		"attack_type": "slash"
	},
	"Monk": {
		"STR": 20, "DEX": 8, "AGI": 8, "CON": 9, "MAG": 2, "INT": 3, "SPI": 4, "LCK": 12,
		"attack_type": "blunt"
	},
	"Summoner": {
		"STR": 2, "DEX": 10, "AGI": 10, "CON": 4, "MAG": 20, "INT": 12, "SPI": 10, "LCK": 8,
		"attack_type": "blunt"
	},
}

var class_spell_slots = {
	"Mage": {1: 3, 2: 2, 3:5, 4:2, 5:1},
	"Cleric": {1: 3, 2: 2, 3:5, 4:2, 5:1},
	"Paladin":  {1: 3, 2: 2, 3:5, 4:2, 5:1},
	"Summoner": {1: 3, 2: 2, 3:5, 4:2, 5:1},
	"Monk":  {1: 3, 2: 2, 3:5, 4:2, 5:1},
	"Hunter":  {1: 3, 2: 2, 3:5, 4:2, 5:1},
	"Thief": {1: 3, 2: 2, 3:5, 4:2, 5:1},
	"Knight": {1: 3, 2: 2, 3:5, 4:2, 5:1},
}

var spell_database = {
	# Magias ofensivas
	"Fire": {"type": "damage", "element": "fire", "attack_type": "magic", "power": 25, "power_max": 35, "cost": 5, "level": 1, "hit_chance": 95, "target_group": "single"},
	"Ice": {"type": "damage", "element": "ice", "attack_type": "magic", "power": 22, "power_max": 32, "cost": 5, "level": 1, "hit_chance": 95, "target_group": "single"},
	"Thunder": {"type": "damage", "element": "lightning", "attack_type": "magic", "power": 28, "power_max": 38, "cost": 6, "level": 1, "hit_chance": 90, "target_group": "single"},
	"Flare": {"type": "damage", "element": "fire", "attack_type": "magic", "power": 80, "power_max": 100, "cost": 20, "level": 2, "hit_chance": 85, "target_group": "single"},
	"Fire Rain": {"type": "damage", "element": "fire", "attack_type": "magic", "power": 30, "cost": 8, "level": 3, "target_group": "line"},
	"Mega Flare": {"type": "damage", "element": "fire", "attack_type": "magic", "power": 60, "cost": 10, "level": 4, "target_group": "area"},
	"Divine Blade": {"type": "damage", "attack_type": "holy", "power": 45, "cost": 10, "level": 3, "target_group": "single", "status_effects": [{"attribute": "blind", "amount": -1, "duration": 3, "chance": 30}]},
	"Holy Smite": {"type": "damage", "attack_type": "holy", "power": 60, "cost": 15, "level": 3, "target_group": "single"},

	# Cura de Vida
	"Cure": {"type": "heal", "attack_type": "magic", "power": 30, "cost": 5, "level": 1, "target_group": "single"},
	"Cura": {"type": "heal", "attack_type": "magic", "power": 60, "cost": 10, "level": 2, "target_group": "single"},
	"Heal All": {"type": "heal", "attack_type": "magic", "power": 40, "cost": 12, "level": 3, "target_group": "area"},
	
	# Cura de Status
	"Esuna": { "type": "cure_status", "cost": 6, "level": 2, "target_group": "single", "status_effects": [ { "attribute": "poison" }, { "attribute": "sleep" }, { "attribute": "paralysis" }, { "attribute": "blind" }, { "attribute": "confuse" }, { "attribute": "curse" }, { "attribute": "petrify" } ] },
	"Dispel": { "type": "cure_status", "cost": 8, "level": 2, "target_group": "single", "status_effects": [ { "attribute": "charm" }, { "attribute": "doom" }, { "attribute": "stop" }, { "attribute": "stun" }, { "attribute": "slow" } ] },
	"Revive": { "type": "cure_status", "cost": 10, "level": 3, "target_group": "single", "status_effects": [ { "attribute": "knockout" } ] },
	
	# Buffs
	"Haste": {"type": "buff", "attack_type": "magic", "attribute": "haste", "amount": 0, "duration": 3, "cost": 8, "level": 3, "target_group": "single"},
	"Blink": {"type": "buff", "attack_type": "magic", "attribute": "blink", "amount": 2, "duration": 5, "cost": 10, "level": 3, "target_group": "single"},
	"Reflect": {"type": "buff", "attack_type": "magic", "attribute": "reflect", "amount": 1, "duration": 3, "cost": 10, "level": 4, "target_group": "single"},
	"Protect": {"type": "buff", "attack_type": "magic", "attribute": "protect", "amount": 5, "duration": 3, "cost": 6, "level": 1, "target_group": "single"},
	"Shell": {"type": "buff", "attack_type": "magic", "attribute": "shell", "amount": 5, "duration": 3, "cost": 6, "level": 1, "target_group": "single"},

	# Debuffs com efeitos negativos
	"Weaken": {"type": "debuff", "attack_type": "magic", "attribute": "strength", "amount": -5, "duration": 3, "cost": 8, "level": 2, "target_group": "single"},
	"Poison Cloud": {"type": "debuff", "attack_type": "magic", "cost": 6, "level": 1, "target_group": "single", "status_effects": [{"attribute": "poison", "amount": -1, "duration": 4, "chance": 80}]},
	"Dark Mist": {"type": "debuff", "attack_type": "magic", "cost": 5, "level": 1, "target_group": "single", "status_effects": [{"attribute": "blind", "amount": -1, "duration": 3, "chance": 70}]},
	"Sleep": {"type": "debuff", "attack_type": "magic", "cost": 6, "level": 2, "target_group": "single", "status_effects": [{"attribute": "sleep", "amount": -1, "duration": 3, "chance": 75}]},
	"Paralyze": {"type": "debuff", "attack_type": "magic", "cost": 7, "level": 2, "target_group": "single", "status_effects": [{"attribute": "paralysis", "amount": -1, "duration": 3, "chance": 60}]},
	"Confuse": {"type": "debuff", "attack_type": "magic", "cost": 10, "level": 3, "target_group": "single", "status_effects": [{"attribute": "confuse", "amount": -1, "duration": 3, "chance": 50}]},
	"Charm": {"type": "debuff", "attack_type": "magic", "cost": 5, "level": 1, "target_group": "single", "status_effects": [{"attribute": "charm", "amount": -1, "duration": 3, "chance": 100}]},
	"Stone Gaze": {"type": "debuff", "attack_type": "magic", "cost": 5, "level": 1, "target_group": "single", "status_effects": [{"attribute": "petrify", "amount": -1, "duration": 0, "chance": 100}]},
	"Curse": {"type": "debuff", "attack_type": "magic", "cost": 10, "level": 3, "target_group": "single", "status_effects": [{"attribute": "curse", "amount": -1, "duration": 5, "chance": 60}]},
	"Doom": {"type": "debuff", "attack_type": "magic", "cost": 18, "level": 4, "target_group": "single", "status_effects": [{"attribute": "doom", "amount": -1, "duration": 5, "chance": 50}]},
	"Stop Time": {"type": "debuff", "attack_type": "magic", "cost": 12, "level": 4, "target_group": "single", "status_effects": [{"attribute": "stop", "amount": -1, "duration": 2, "chance": 50}]},
	"Stun Bolt": {"type": "debuff", "attack_type": "magic", "cost": 8, "level": 2, "target_group": "single", "status_effects": [{"attribute": "stun", "amount": -1, "duration": 1, "chance": 60}]},
	"Knockout": {"type": "damage", "attack_type": "magic", "power": 9999, "cost": 5, "level": 1, "hit_chance": 100, "target_group": "single", "status_effects": [{"attribute": "knockout", "amount": -1, "duration": 0, "chance": 100}]},
	"Slow": {"type": "debuff", "attack_type": "magic", "attribute": "speed", "amount": -4, "duration": 3, "cost": 8, "level": 2, "target_group": "single"},
	
	# Especiais
	"Summon": {"type":"summon","cost":25,"level":4,"summon_data":{"nome":"Summon","STR":30,"DEX":15,"AGI":10,"CON":10,"MAG":35,"INT":30,"SPI":20,"LCK":10,"max_hp":100,"current_hp":100,"max_mp":100,"current_mp":100,"spells":["Fire Rain","Mega Flare"],"sprite_path":"res://assets/Invocação.png"}}
}


var skill_database = {
	"Power Strike": {"effect_type": "damage",  "attack_type": "blunt", "power": 35, "cost": 4, "target_type": "enemy", "level": 1},
	"Quick Shot": {"effect_type": "damage",  "attack_type": "pierce", "power": 25, "cost": 3, "target_type": "enemy", "level": 1},
	"Focus": {"effect_type": "buff", "scaling_stat": "AGI", "amount": 5, "duration": 3, "cost": 2, "target_type": "self", "level": 1},
	"Heal Self": {"effect_type": "heal", "power": 25, "cost": 5, "target_type": "self", "level": 1},
	"Shield Breaker": {"effect_type": "damage", "attack_type": "pierce", "power": 30, "cost": 6, "target_type": "enemy", "status_inflicted": "defense_down", "status_chance": 0.6, "duration": 3, "level": 2},
	"Tracking Shot": {"effect_type": "damage", "attack_type": "pierce", "power": 35, "cost": 6, "target_type": "enemy", "status_inflicted": "accuracy_up", "status_chance": 0.7, "duration": 3, "level": 2},
	"Evade Boost": {"effect_type": "buff", "attribute": "evasion", "amount": 7, "duration": 3, "cost": 5, "target_type": "self", "level": 1},
	"Fury Punch": {"effect_type": "damage", "attack_type": "blunt", "power": 45, "cost": 8, "target_type": "enemy", "level": 2},
	"Holy Smite": {"effect_type": "damage", "attack_type": "holy", "power": 60, "cost": 15, "target_type": "enemy", "level": 3},
	"Crushing Blow": {"effect_type": "damage", "attack_type": "blunt", "power": 55, "cost": 8, "target_type": "enemy", "status_inflicted": "stun", "status_chance": 0.4, "duration": 1, "level": 3},
	"Arrow Barrage": {"effect_type": "damage", "attack_type": "pierce", "power": 28, "cost": 6, "target_type": "line", "level": 2},
	"Shadow Jab": {"effect_type": "damage", "attack_type": "pierce", "power": 40, "cost": 5, "target_type": "enemy", "status_inflicted": "bleed", "status_chance": 0.35, "duration": 3, "level": 2},
	"Chi Burst": {"effect_type": "hybrid", "attack_type": "magic", "power": 30, "heal": 30, "cost": 10, "target_type": "self", "level": 2},
	"Steal": {"effect_type": "special", "attack_type": "None", "effect": "steal_item","cost": 4, "target_type": "enemy", "level": 1},
	"Scan": {"effect_type": "special", "attack_type": "None", "effect": "scan_info","cost": 2, "target_type": "enemy", "level": 1},
	"MP Drain": {"effect_type": "special", "attack_type": "None", "effect": "mp_drain","cost": 3, "target_type": "enemy", "level": 1}
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
			"Esuna": {"level": 1, "SPI": 6},
			"Dispel": {"level": 1, "SPI": 1},
			"Revive": {"level": 1, "SPI": 1},
			"Cure": {"level": 1, "SPI": 1},
			"Protect": {"level": 1, "SPI": 1},
			"Shell": {"level": 1, "SPI": 1},
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
			"Steal": {"level": 1, "STR": 1},
			"Scan": {"level": 1, "STR": 1},
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
			"Summon": {"level": 1, "SPI": 2},
			"Fire": {"level": 1, "SPI": 2},
			"Dispel": {"level": 1, "SPI": 2},
		},
		"skills": {},
		"specials": {
			"Eidolon Burst": {"level": 1, "SPI": 2}
		},
		"spell_upgrades": {},
		"skill_upgrades": {}
	}
}

var special_database = {
	"Break Thunder": {"effect_type": "damage", "attack_type": "Slash", "power": 35, "target_type": "enemy", "level": 1},
	"Safe Guard": {"effect_type": "heal", "attack_type": "Magic", "power": 25, "target_type": "ally", "level": 1},
	"Arcane Surge": {"effect_type": "damage", "attack_type": "Magic", "power": 40, "target_type": "enemy","level": 1},
	"Shield Breaker": {"effect_type": "damage", "attack_type": "Pierce", "power": 30, "target_type": "enemy", "status_inflicted": "defense_down", "status_chance": 0.6, "duration": 3,"level": 1},
	"Rain of Arrows": {"effect_type": "damage", "attack_type": "Pierce", "power": 20, "target_type": "all_enemies", "level": 1},
	"Shadow Strike": {"effect_type": "damage", "attack_type": "Pierce", "power": 35, "target_type": "enemy", "status_inflicted": "stun", "status_chance": 0.4, "duration": 2, "level": 1},
	"Inner Focus": {"effect_type": "buff", "attack_type": "None", "power": 0, "target_type": "self", "attribute": "SPI", "amount": 5, "duration": 4, "level": 1},
	"Divine Blade": {"effect_type": "damage", "attack_type": "Holy", "power": 45, "target_type": "enemy", "status_inflicted": "blind", "status_chance": 0.3, "duration": 3, "level": 1},
	"Eidolon Burst": {"effect_type": "damage", "attack_type": "Magic", "power": 50, "target_type": "all_enemies", "level": 1 }
}
