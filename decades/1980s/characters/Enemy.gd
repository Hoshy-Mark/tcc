extends Node
class_name Enemy

var nome: String = "Goblin"
var max_hp: int = 50
var current_hp: int = max_hp
var max_mp: int = 0
var current_mp: int = max_mp
var strength: int = 6
var defense: int = 2
var speed: int = 4
var xp_value = 50
var id: String = ""


func attack(target):
	var base_damage = strength - target.defense
	var damage = max(base_damage + randi() % 6 - 2, 1)
	target.take_damage(damage)
	return damage

func take_damage(amount):
	current_hp -= int(amount)
	current_hp = max(current_hp, 0)

func is_alive():
	return current_hp > 0

func reset():
	current_hp = max_hp
	current_mp = max_mp
