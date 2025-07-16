extends Node
class_name PlayerPartyMember

signal leveled_up(new_level, who)

var nome: String = "Hero"
var hp: int = 100
var mp: int = 30
var strength: int = 10
var defense: int = 5
var speed: int = 8
var max_hp: int = 100
var max_mp: int = 30
var level: int = 1
var xp: int = 0
var xp_to_next_level: int = 50

var spell_slots = {
	1: 3,
	2: 2,
	3: 1
}

var spells = {
	"fogo": {"level": 1, "cost": 5, "power": 15, "power_max": 25, "type": "damage"},
	"cura": {"level": 2, "cost": 7, "power": -20, "type": "heal"}
}

var is_defending: bool = false

func attack(target):
	var base_damage = strength - target.defense
	var damage = max(base_damage + randi() % 6 - 3, 1)
	target.take_damage(damage)
	return damage

func cast_spell(target, spell_name := "fogo"):
	if not spells.has(spell_name):
		return 0

	var spell = spells[spell_name]
	var level = spell.get("level", 1)
	var cost = spell.get("cost", 0)

	if not spell_slots.has(level) or spell_slots[level] <= 0:
		print("Sem slots de magia nível %d disponíveis!" % level)
		return 0

	if mp < cost:
		print("Sem MP suficiente!")
		return 0

	spell_slots[level] -= 1
	mp -= cost

	var effect = spell.get("power", 0)
	var power_max = spell.get("power_max", effect)
	if power_max > effect:
		effect += randi() % (power_max - effect + 1)

	var result = 0
	match spell.get("type", "damage"):
		"damage":
			target.take_damage(effect)
			result = effect
		"heal":
			target.heal(abs(effect))
			result = -abs(effect)
		_:
			target.take_damage(effect)
			result = effect

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
	hp -= int(damage_taken)
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
