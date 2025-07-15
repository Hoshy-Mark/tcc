extends Node

class_name PlayerPartyMember

var nome: String = "Hero"
var hp: int = 100
var mp: int = 30
var strength: int = 10
var defense: int = 5
var speed: int = 8
var spell_slots = {
	1: 3,
	2: 2,
	3: 1
}

var spells = {
	"fire": {"level": 1, "cost": 5, "power": 15},
	"heal": {"level": 2, "cost": 7, "power": -20}
}


var is_defending: bool = false

func attack(target):
	var base_damage = strength - target.defense
	var damage = max(base_damage + randi() % 6 - 3, 1)
	target.take_damage(damage)
	return damage

func cast_spell(target, spell_name = "fire"):
	if not spells.has(spell_name):
		return 0
	var spell = spells[spell_name]
	var level = spell.level

	# Verifica slots
	if not spell_slots.has(level) or spell_slots[level] <= 0:
		print("Sem slots de magia nível %d disponíveis!" % level)
		return 0

	# Verifica MP
	if mp < spell.cost:
		print("Sem MP suficiente!")
		return 0

	# Usa slot e MP
	spell_slots[level] -= 1
	mp -= spell.cost

	var damage = spell.power + randi() % 6
	target.take_damage(damage)
	return damage


func try_escape():
	return randf() < 0.5

func defend():
	is_defending = true

func take_damage(amount):
	var damage_taken = amount
	if is_defending:
		damage_taken = amount / 2
		is_defending = false
	hp -= int(damage_taken)
	hp = max(hp, 0)

func is_alive():
	return hp > 0
