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
var accuracy: int = 0
var evasion: int = 0
var intelligence: int = 0
var magic_power: int = 0
var magic_defense: int = 0
var luck: int = 0

func attack(target):
	var accuracy_atacante = accuracy + int(randf() * 10) *  1.5
	
	var evasion_alvo = target.evasion + int(randf() * 10)
	# Se o alvo está defendendo, recebe bônus de evasão (20%)
	if target.is_defending:
		evasion_alvo += int(target.evasion * 0.2)
		
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
		if e.attribute == effect.attribute and e.type == effect.type:
			e.duration = effect.duration 
			return
	status_effects.append(effect)
	active_status_effects.append(effect)

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
	return max(modified, 0)
	
func update_status_effects() -> void:
	active_status_effects.clear()
	for effect in status_effects:
		if effect.duration > 0:
			active_status_effects.append(effect)
