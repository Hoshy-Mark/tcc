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

var spell_slots := {
	1: 3,
	2: 2,
	3: 1
}

var active_status_effects: Array[StatusEffect] = []

var spells := {}  # Agora será dicionário de dados, não Spell objects

var is_defending: bool = false

func _init():
	# Só inicialização básica aqui, para evitar sobrescrever spells que virão pelo setup
	pass

# Configura personagem com dados genéricos vindos de um dicionário
func setup(data: Dictionary) -> void:
	nome = data.get("nome", nome)
	max_hp = data.get("max_hp", max_hp)
	hp = data.get("hp", max_hp)
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

func attack(target):
	var base_damage = strength - target.get_modified_stat(target.defense, "defense")
	var damage = max(base_damage + randi() % 6 - 3, 1)
	target.take_damage(damage)
	return damage

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
		print("Sem slots de magia nível %d disponíveis!" % spell_level)
		return []

	var cost = spell_data.get("cost", 0)
	if mp < cost:
		print("Sem MP suficiente!")
		return []

	# Gasta só 1 slot e 1 custo de MP aqui, uma vez só
	spell_slots[spell_level] -= 1
	mp -= cost

	var is_area = spell_data.get("area", false)
	var result = []

	# Transforma 'targets' em lista se não for
	var alvo_lista = []
	if typeof(targets) == TYPE_ARRAY:
		alvo_lista = targets
	else:
		alvo_lista = [targets]

	for alvo in alvo_lista:
		var efeito = 0
		match spell_data.get("type", "damage"):
			"damage":
				efeito = spell_data.get("power", 0)
				var power_max = spell_data.get("power_max", efeito)
				if power_max > efeito:
					efeito += randi() % (power_max - efeito + 1)
				alvo.take_damage(efeito)
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
		damage_taken = int(amount / 2)
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
	xp_to_next_level = int(xp_to_next_level * 1.5)
	max_hp += 10
	max_mp += 5
	strength += 2
	defense += 1
	speed += 1
	hp = max_hp
	mp = max_mp
