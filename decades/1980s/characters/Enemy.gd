extends Node
class_name Enemy

var nome: String = "Goblin"
var max_hp: int = 50
var current_hp: int = max_hp
var max_mp: int = 0
var current_mp: int = max_mp
var strength: int = 6
var defense: int = 2
var speed: int = 10
var xp_value = 50
var id: String = ""
var status_effects: Array = []
var active_status_effects: Array = []

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
	clear_status_effects()

func apply_status_effect(effect: StatusEffect) -> void:
	for e in status_effects:
		if e.name == effect.name:
			return
	status_effects.append(effect)

func process_status_effects() -> void:
	for effect in status_effects.duplicate():
		effect.apply(self)
		effect.duration -= 1
		if effect.duration <= 0:
			status_effects.erase(effect)

func clear_status_effects() -> void:
	status_effects.clear()

func get_modified_stat(base_value: int, stat_name: String) -> int:
	var modified = base_value
	for effect in active_status_effects:
		if effect.attribute == stat_name:
			modified += effect.amount
	return max(modified, 0)  # Evita valores negativos
