extends Node
class_name PlayerPartyMember1990

signal died

# Identidade
var nome: String = "Herói"
var classe_name: String = "Knight"
var level: int = 1
var xp: int = 0

# Atributos base
var STR: int = 0
var DEX: int = 0
var AGI: int = 0
var CON: int = 0
var MAG: int = 0
var INT: int = 0
var SPI: int = 0
var LCK: int = 0

# Atributos derivados
var max_hp: int = 0
var current_hp: int = 0
var max_mp: int = 0
var current_mp: int = 0
var defense: int = 0
var magic_defense: int = 0
var accuracy: int = 0
var evasion: int = 0
var speed: int = 0
var current_sp := 0
var max_sp := 0
var id: String = ""
var attack_type: String = "slash"
var atb_value := 0.0
var atb_max := 100.0

var special_charge := 0.0 # de 0 a 100
var special_ready := false
var position_line: String = "front"
var alcance_estendido: bool = false  # se pode atacar a traseira com ataque físico

var spells: Array[Spell] = []
var skills: Array[Skill] = []
var specials: Array[Special] = []
var spell_slots := {}  # Ex: {1: 3, 2: 1}
var obstruido = false
var max_spell_slots := {}  # Ex: {1: 5, 2: 2}
var sprite_ref: Sprite2D = null

# AP por habilidade (armazenado por nome da habilidade)

var spell_ap := {}
var skill_ap := {}

# Dicionário para upgrades (evoluções)

var spell_upgrades := {}
var skill_upgrades := {}

# Status
var is_defending: bool = false
var can_act: bool = true
var can_target: bool = true
var is_confused: bool = false
var is_charmed: bool = false
var is_petrified: bool = false
var is_invisible: bool = false
var doom_counter: int = -1
var status_effects: Array = []
var active_status_effects: Array = []

var element_resistances = {
	"fire": 1.0,
	"ice": 1.0,
	"lightning": 1.0,
	"earth": 1.0,
	"wind": 1.0,
	"holy": 1.0,
	"dark": 1.0,
	"poison": 1.0
}

var attack_type_resistances = {
	"slash": 1.0,
	"pierce": 1.0,
	"blunt": 1.0,
	"ranged": 1.0,
	"magic": 1.0
}

var xp_to_next_level: int = 100  # XP necessário para o próximo nível

const class_growth_curves = {
	"Knight":   {"STR": 2, "CON": 2, "DEX": 1, "AGI": 1},
	"Mage":     {"MAG": 2, "INT": 2, "SPI": 1},
	"Thief":    {"DEX": 2, "AGI": 2, "LCK": 1},
	"Cleric":   {"MAG": 1, "INT": 1, "SPI": 2},
	"Hunter":   {"DEX": 2, "AGI": 2, "LCK": 1},
	"Paladin":  {"STR": 1, "CON": 2, "SPI": 1},
	"Monk":     {"STR": 2, "CON": 1, "AGI": 1},
	"Summoner": {"MAG": 2, "INT": 1, "SPI": 1}
}

# === FUNÇÕES ===

func calculate_stats():
	max_hp = CON * 6 + STR * 2
	max_mp = MAG * 4 + INT * 4
	max_sp = STR * 2 + CON * 2 + AGI
	defense = CON * 2 + STR
	magic_defense = SPI * 2 + INT
	accuracy = DEX * 2 + LCK
	evasion = AGI * 2 + LCK
	speed = AGI + DEX
	current_sp = max_sp
	current_hp = max_hp
	current_mp = max_mp
	id = classe_name

func is_alive():
	return current_hp > 0

func take_damage(amount: int):
	var damage = amount
	var final_hit_chance_mod := 1.0

	if is_defending:
		damage = int(damage * 0.8)
		final_hit_chance_mod = 0.8  # Evasão aumentada em 20%
		is_defending = false

	current_hp = max(current_hp - damage, 0)

func heal(amount: int):
	current_hp = min(current_hp + amount, max_hp)

func apply_status_effect(effect: StatusEffect):
	for existing in active_status_effects:
		if existing.attribute == effect.attribute and existing.type == effect.type:
			existing.amount = effect.amount
			existing.duration = effect.duration
			return
	active_status_effects.append(effect)

func get_modified_stat(base: int, attribute: String) -> int:
	var result = base
	for effect in active_status_effects:
		if effect.attribute == attribute:
			result += effect.amount
	return result

func cast_spell(targets, spell_name := "fogo"):
	var spell_data: Spell = null
	for spell in spells:
		if spell.name.to_lower() == spell_name.to_lower():
			spell_data = spell
			break

	if spell_data == null:
		return []

	var spell_level = spell_data.level
	if not spell_slots.has(spell_level) or spell_slots[spell_level] <= 0:
		return []

	var base_cost = spell_data.cost
	var reduced_cost = int(base_cost * (1.0 - INT * 0.01))
	var final_cost = max(reduced_cost, 1)

	if current_mp < final_cost:
		return []

	current_mp -= final_cost
	spell_slots[spell_level] -= 1

	var result = []

	var alvo_lista = []
	if typeof(targets) == TYPE_ARRAY:
		alvo_lista = targets
	else:
		alvo_lista = [targets]

	for alvo in alvo_lista:
		var efeito = 0
		match spell_data.type:
			"damage":
				var power = spell_data.power
				var power_max = spell_data.power_max
				var base_random = power + randi() % (power_max - power + 1)

				var base_hit_chance = 100
				var total_hit = base_hit_chance + INT
				if randf() * 100 > total_hit:
					result.append({ "alvo": alvo, "efeito": 0, "miss": true })
					continue

				var normalized = float(base_random - power) / max(1, (power_max - power))
				var boosted_damage = base_random + int((1.0 - normalized) * MAG)

				var remaining_boost = max(0, MAG - alvo.magic_defense)
				var final_damage = boosted_damage + remaining_boost - MAG
				final_damage = max(final_damage, 0)

				alvo.take_damage(final_damage)
				efeito = final_damage

			"heal":
				efeito = abs(spell_data.power)
				alvo.heal(efeito)
				efeito = -efeito

			"buff", "debuff":
				var effect = StatusEffect.new()
				effect.attribute = spell_data.attribute
				effect.amount = spell_data.amount
				effect.duration = spell_data.duration
				effect.type = StatusEffect.Type.BUFF if spell_data.is_buff() else StatusEffect.Type.DEBUFF
				alvo.apply_status_effect(effect)
				efeito = 0

		result.append({ "alvo": alvo, "efeito": efeito })

	return result

func restore_spell_slots():
	for key in max_spell_slots.keys():
		spell_slots[key] = max_spell_slots[key]

func process_status_effects():
	var remaining: Array = []
	can_act = true
	can_target = true
	is_charmed = false
	is_confused = false
	is_petrified = false

	# Reset temporário das flags de proteção
	set_meta("protect_active", false)
	set_meta("shell_active", false)
	set_meta("reflect_active", false)

	for effect in active_status_effects:
		match effect.attribute:
			"poison":
				take_damage(5)
			"bleed":
				take_damage(5)
			"regen":
				heal(5 + SPI)
			"sleep", "paralysis", "stun", "stop", "knockout":
				can_act = false
			"confuse":
				is_confused = true
			"charm":
				is_charmed = true
			"petrify":
				is_petrified = true
				can_act = false
				can_target = false
			"doom":
				if doom_counter == -1:
					doom_counter = effect.duration
				doom_counter -= 1
				if doom_counter <= 0:
					take_damage(current_hp)  # Morte instantânea
			"haste":
				pass
			"protect":
				set_meta("protect_active", true)
			"shell":
				set_meta("shell_active", true)
			"reflect":
				set_meta("reflect_active", true)

		effect.duration -= 1
		if effect.duration > 0:
			remaining.append(effect)

	active_status_effects = remaining

	if not has_status("doom"):
		doom_counter = -1

func has_blink_active() -> bool:
	for effect in active_status_effects:
		if effect.attribute == "blink" and effect.blink_charges > 0:
			return true
	return false

func consume_blink_charge():
	for effect in active_status_effects:
		if effect.attribute == "blink" and effect.blink_charges > 0:
			effect.blink_charges -= 1
			return

func has_reraise_active() -> bool:
	return active_status_effects.any(func(e): return e.attribute == "reraise")

func get_available_spells() -> Dictionary:
	var result := {}
	for spell in spells:
		result[spell.name] = spell
	return result

func is_magic_user() -> bool:
	return classe_name in ["Mage", "Cleric", "Paladin", "Summoner"]

func is_skill_user() -> bool:
	return not is_magic_user()

func get_global_position() -> Vector2:
	if sprite_ref:
		return sprite_ref.global_position
	return Vector2.ZERO

func check_if_dead():
	if current_hp <= 0:
		if has_reraise_active():
			current_hp = int(max_hp * 0.25)
			# Remove o reraise
			active_status_effects = active_status_effects.filter(func(e): return e.attribute != "reraise")
		else:
			# Marca como morto normalmente
			special_charge = 0
			atb_value = 0
			emit_signal("died")
			can_act = false
			can_target = false

func has_status(attr: String) -> bool:
	return active_status_effects.any(func(e): return e.attribute == attr)

func increase_special_charge(amount: float) -> bool:
	if special_ready:
		return false

	special_charge += amount
	special_charge = clamp(special_charge, 0, 100)

	if special_charge >= 100:
		special_ready = true
		return true

	return true

func get_modified_derived_stat(attribute: String) -> int:
	var STR_mod = get_modified_stat(STR, "STR")
	var DEX_mod = get_modified_stat(DEX, "DEX")
	var AGI_mod = get_modified_stat(AGI, "AGI")
	var CON_mod = get_modified_stat(CON, "CON")
	var MAG_mod = get_modified_stat(MAG, "MAG")
	var INT_mod = get_modified_stat(INT, "INT")
	var SPI_mod = get_modified_stat(SPI, "SPI")
	var LCK_mod = get_modified_stat(LCK, "LCK")

	match attribute:
		"speed":
			return AGI_mod + DEX_mod
		"defense":
			return CON_mod * 2 + STR_mod
		"magic_defense":
			return SPI_mod * 2 + INT_mod
		"accuracy":
			return DEX_mod * 2 + LCK_mod
		"evasion":
			return AGI_mod * 2 + LCK_mod
		"max_hp":
			return CON_mod * 6 + STR_mod * 2
		"max_mp":
			return MAG_mod * 4 + INT_mod * 4
		"max_sp":
			return STR_mod * 2 + CON_mod * 2 + AGI_mod
		_:
			return 0

func gain_xp(amount: int):
	xp += amount
	while xp >= xp_to_next_level:
		xp -= xp_to_next_level
		level_up()

func level_up():
	level += 1
	var growth = class_growth_curves.get(classe_name, {})
	
	for stat_name in growth.keys():
		match stat_name:
			"STR":
				STR += growth[stat_name]
			"DEX":
				DEX += growth[stat_name]
			"AGI":
				AGI += growth[stat_name]
			"CON":
				CON += growth[stat_name]
			"MAG":
				MAG += growth[stat_name]
			"INT":
				INT += growth[stat_name]
			"SPI":
				SPI += growth[stat_name]
			"LCK":
				LCK += growth[stat_name]

	# Aumentar dificuldade progressivamente
	xp_to_next_level = int(xp_to_next_level + 100)

	# Recalcular stats derivados
	calculate_stats()

	print("%s subiu para o nível %d!" % [nome, level])

func gain_ap(ability_name: String, amount: int, is_spell: bool = true) -> void:
	var ap_dict
	if is_spell:
		ap_dict = spell_ap
	else:
		ap_dict = skill_ap
	
	if not ap_dict.has(ability_name):
		ap_dict[ability_name] = {"current": 0, "level": 1}

	ap_dict[ability_name]["current"] += amount

func apply_mastery_bonus(ability_name: String, new_level: int, is_spell: bool):
	
	var ability_list
	if is_spell:
		ability_list = spells 
	else:
		ability_list = skills

	for ab in ability_list:
		if ab.name == ability_name:
			# Reduz custo e aumenta poder
			ab.cost = int(ab.cost * 0.9)  # 10% de redução
			ab.power = int(ab.power * 1.1)  # 10% a mais de dano
			if new_level == 3:
				ab.name += " ★"  # Marca como dominado
			break

func remove_status_effect(attribute: String) -> void:
	for i in range(active_status_effects.size()):
		if active_status_effects[i].attribute == attribute:
			active_status_effects.remove_at(i)
			return
