extends Node
class_name PlayerPartyMember

signal leveled_up(new_level, who)

var nome: String = "Hero"
var hp: int = 100
var mp: int = 30
var strength: int = 60
var defense: int = 5
var speed: int = 8
var max_hp: int = 100
var max_mp: int = 30
var level: int = 1
var xp: int = 0
var xp_to_next_level: int = 50
var vitality: int = 0
var accuracy: int = 0
var evasion: int = 0
var intelligence: int = 0
var magic_power: int = 0
var magic_defense: int = 0
var luck: int = 0

var spell_slots := {
	1: 3,
	2: 2,
	3: 1
}

var active_status_effects: Array[StatusEffect] = []

var spells := {}

var is_defending: bool = false

func _init():

	pass

func setup(data: Dictionary) -> void:
	nome = data.get("nome", nome)
	max_mp = data.get("max_mp", max_mp)
	mp = data.get("mp", max_mp)
	strength = data.get("strength", strength)
	defense = data.get("defense", defense)
	speed = data.get("speed", speed)
	level = data.get("level", level)
	xp = data.get("xp", xp)
	xp_to_next_level = data.get("xp_to_next_level", xp_to_next_level)
	spell_slots = data.get("spell_slots", spell_slots)
	spells = data.get("spells", {})
	strength = data.get("strength", strength)
	defense = data.get("defense", defense)
	speed = data.get("speed", speed)
	vitality = data.get("vitality", 10)
	accuracy = data.get("accuracy", 10)
	evasion = data.get("evasion", 5)
	intelligence = data.get("intelligence", 5)
	magic_power = data.get("magic_power", 5)
	magic_defense = data.get("magic_defense", 5)
	luck = data.get("luck", 5)
	max_hp = vitality * 10
	hp = data.get("hp", max_hp)

func attack(target):
	var accuracy_atacante = accuracy + int(randf() * 10) *  1.5
	var evasion_alvo = target.evasion + int(randf() * 10)
	var accuracy_check = accuracy_atacante > evasion_alvo
	if not accuracy_check:
		return {"miss": true}

	var base_damage = max(1, strength - target.get_modified_stat(target.defense, "defense"))
	var damage_variation = randi() % 6 - 2
	var damage = max(base_damage + damage_variation, 1)

	# Crítico
	var is_crit = randf() < (luck * 0.01)
	if is_crit:
		damage = int(damage * 1.5)

	target.take_damage(damage)
	return {"damage": damage, "crit": is_crit}

func apply_status_effect(effect: StatusEffect):
	for i in range(active_status_effects.size()):
		if active_status_effects[i].attribute == effect.attribute:
			active_status_effects[i] = effect
			return
	active_status_effects.append(effect)

func process_status_effects():
	for effect in active_status_effects:
		match effect.attribute:
			"regen":
				heal(5)  # Pode modificar para algo baseado em level
	
	var remaining: Array[StatusEffect] = []
	for effect in active_status_effects:
		effect.duration -= 1
		if effect.duration > 0:
			remaining.append(effect)
	active_status_effects = remaining

func get_modified_stat(base: int, attribute: String) -> int:
	var result = base
	for effect in active_status_effects:
		if effect.attribute == attribute:
			result += effect.amount
	return result

func cast_spell(targets, spell_name := "fogo"):
	if not spells.has(spell_name):
		return []

	var spell_data = spells[spell_name]
	var spell_level = spell_data.get("level", 1)
	if not spell_slots.has(spell_level) or spell_slots[spell_level] <= 0:
		return []

	var base_cost = spell_data.get("cost", 0)
	var reduced_cost = int(base_cost * (1.0 - intelligence * 0.01))
	var final_cost = max(reduced_cost, 1)

	if mp < final_cost:
		return []

	mp -= final_cost
	spell_slots[spell_level] -= 1

	var result = []

	var alvo_lista = []
	if typeof(targets) == TYPE_ARRAY:
		alvo_lista = targets
	else:
		alvo_lista = [targets]

	for alvo in alvo_lista:
		var efeito = 0
		match spell_data.get("type", "damage"):
			"damage":
				var power = spell_data.get("power", 0)
				var power_max = spell_data.get("power_max", power)
				var base_random = power + randi() % (power_max - power + 1)


				var base_hit_chance = spell_data.get("hit_chance", 100) 
				var total_hit = base_hit_chance + intelligence
				if randf() * 100 > total_hit:

					result.append({ "alvo": alvo, "efeito": 0, "miss": true })
					continue

				var normalized = float(base_random - power) / max(1, (power_max - power))
				var boosted_damage = power + int((1.0 - normalized) * magic_power)

				var remaining_boost = max(0, magic_power - alvo.magic_defense)
				var final_damage = boosted_damage + remaining_boost - magic_power
				final_damage = max(final_damage, 0)

				alvo.take_damage(final_damage)
				efeito = final_damage

			"heal":
				efeito = abs(spell_data.get("power", 0))
				alvo.heal(efeito)
				efeito = -efeito

			"buff", "debuff":
				var effect = StatusEffect.new()
				effect.attribute = spell_data.get("attribute", "")
				effect.amount = spell_data.get("amount", 0)
				effect.duration = spell_data.get("duration", 3)
				effect.type = StatusEffect.Type.BUFF if spell_data.get("type") == "buff" else StatusEffect.Type.DEBUFF
				alvo.apply_status_effect(effect)
				efeito = 0

		result.append({ "alvo": alvo, "efeito": efeito })

	return result

func try_escape():
	return randf() < 0.5

func defend():
	is_defending = true

func take_damage(amount):
	var damage_taken = amount
	if is_defending:
		damage_taken = int(amount * 0.8)  # Reduz 20%
		is_defending = false
	hp -= damage_taken
	hp = max(hp, 0)

func is_alive():
	return hp > 0

func heal(amount):
	hp = min(hp + amount, max_hp)

func gain_xp(amount: int):
	if not is_alive():
		return
	
	xp += amount
	while xp >= xp_to_next_level:
		xp -= xp_to_next_level
		level_up()
		emit_signal("leveled_up", level, self)

func level_up():
	level += 1
	xp_to_next_level += 100

	match nome:
		"Mago Negro":
			vitality += 1
			intelligence += 2
			magic_power += 2
			magic_defense += 1
			max_mp += 10
		"Guerreiro":
			vitality += 2
			strength += 3
			defense += 2
			speed += 1
		"Maga Branca":
			intelligence += 1
			magic_power += 1
			magic_defense += 2
			vitality += 1
			max_mp += 10
		"Ladrao":
			speed += 2
			evasion += 2
			accuracy += 1
			luck += 2
			vitality += 1
		_:
			# genérico
			vitality += 1
			strength += 1
			defense += 1
			speed += 1
			max_mp += 5

	max_hp = vitality * 10
	hp = max_hp
	mp = max_mp

func update_status_effects() -> void:
	active_status_effects.clear()
	for effect in active_status_effects:
		if effect.duration > 0:
			active_status_effects.append(effect)
