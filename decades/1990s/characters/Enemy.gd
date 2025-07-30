extends Node

class_name Enemy1990

signal died

@export var enemy_type: String = "Beast"  # Pode ser Undead, Beast, Ghost, Flying, Demon, Dragon

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

var atb_value := 0.0
var atb_max := 100.0

# Outros dados
var nome: String = "Enemy"
var xp_value: int = 20
var id: String = ""
var is_defending: bool = false
var can_act: bool = true
var can_target: bool = true
var is_charmed: bool = false
var is_confused: bool = false
var is_petrified: bool = false
var is_invisible: bool = false
var doom_counter: int = -1
var sprite_ref: Sprite2D = null
var position_line: String = "front"  # ou "back"
var alcance_estendido: bool = false 
var obstruido := false

# Status
var status_effects: Array = []
var active_status_effects: Array = []
var attack_type: String = "slash"
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

func set_type_resistances():
	match enemy_type:
		"Undead":
			element_resistances = {
				"fire": 1.5,
				"ice": 1.0,
				"lightning": 1.0,
				"earth": 1.0,
				"wind": 1.0,
				"holy": 2.0,
				"dark": 0.5,
				"poison": 1.0
			}
			attack_type_resistances = {
				"slash": 1.0,
				"pierce": 1.0,
				"blunt": 1.2,
				"ranged": 1.0,
				"magic": 1.0
			}
		"Beast":
			element_resistances = {
				"fire": 1.0,
				"ice": 1.2,
				"lightning": 1.0,
				"earth": 1.0,
				"wind": 0.8,
				"holy": 1.0,
				"dark": 1.0,
				"poison": 1.5
			}
			attack_type_resistances = {
				"slash": 1.1,
				"pierce": 0.9,
				"blunt": 1.0,
				"ranged": 0.1,
				"magic": 1.0
			}
		"Ghost":
			element_resistances = {
				"fire": 1.0,
				"ice": 0.8,
				"lightning": 1.0,
				"earth": 0.5,
				"wind": 1.2,
				"holy": 2.0,
				"dark": 0.3,
				"poison": 0.0
			}
			attack_type_resistances = {
				"slash": 0.5,
				"pierce": 0.5,
				"blunt": 0.8,
				"ranged": 0.2,
				"magic": 1.5
			}
		"Flying":
			element_resistances = {
				"fire": 1.0,
				"ice": 1.0,
				"lightning": 1.5,
				"earth": 0.0,
				"wind": 0.7,
				"holy": 1.0,
				"dark": 1.0,
				"poison": 1.0
			}
			attack_type_resistances = {
				"slash": 1.0,
				"pierce": 1.2,
				"blunt": 0.9,
				"ranged": 1.3,
				"magic": 1.0
			}
		"Demon":
			element_resistances = {
				"fire": 0.5,
				"ice": 1.2,
				"lightning": 1.2,
				"earth": 1.0,
				"wind": 1.0,
				"holy": 2.5,
				"dark": 0.3,
				"poison": 1.0
			}
			attack_type_resistances = {
				"slash": 1.1,
				"pierce": 1.0,
				"blunt": 1.1,
				"ranged": 1.0,
				"magic": 0.8
			}
		"Dragon":
			element_resistances = {
				"fire": 0.7,
				"ice": 1.5,
				"lightning": 1.3,
				"earth": 1.0,
				"wind": 1.0,
				"holy": 1.5,
				"dark": 1.0,
				"poison": 0.5
			}
			attack_type_resistances = {
				"slash": 1.0,
				"pierce": 1.2,
				"blunt": 1.3,
				"ranged": 1.0,
				"magic": 0.9
			}
		_:
			# Default, tudo normal
			element_resistances = {
				"fire": 1.0,
				"ice": 1.0,
				"lightning": 1.0,
				"earth": 1.0,
				"wind": 1.0,
				"holy": 1.0,
				"dark": 1.0,
				"poison": 1.0
			}
			attack_type_resistances = {
				"slash": 1.0,
				"pierce": 1.0,
				"blunt": 1.0,
				"ranged": 1.0,
				"magic": 1.0
			}

# === FUNÇÕES ===

func calculate_stats():
	max_hp = CON * 10 + STR * 2
	max_mp = MAG * 5 + INT * 3
	defense = CON + floor(STR * 0.5)
	magic_defense = SPI + floor(INT * 0.5)
	accuracy = DEX * 2 + floor(LCK * 0.5)
	evasion = AGI * 2 + floor(LCK * 0.3)
	speed = AGI * 2
	current_hp = max_hp
	current_mp = max_mp

func is_alive():
	return current_hp > 0

func take_damage(amount):
	current_hp -= int(amount)
	current_hp = max(current_hp, 0)

func heal(amount: int):
	current_hp = min(current_hp + amount, max_hp)

func check_if_dead():
	if current_hp <= 0:
		if has_reraise_active():
			current_hp = int(max_hp * 0.25)
			# Remove o reraise
			active_status_effects = active_status_effects.filter(func(e): return e.attribute != "reraise")
		else:
			# Marca como morto normalmente
			atb_value = 0
			emit_signal("died")
			can_act = false
			can_target = false

func get_global_position() -> Vector2:
	if sprite_ref:
		return sprite_ref.global_position
	return Vector2.ZERO

func apply_status_effect(effect: StatusEffect):
	print("Esta senod aplicado o efeito: " + str(effect.type))
	print(effect.attribute)
	print(effect.amount)
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

func has_status(attr: String) -> bool:
	return active_status_effects.any(func(e): return e.attribute == attr)
	
