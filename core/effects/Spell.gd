extends Resource
class_name Spell

@export var name: String = "Fogo"
@export var cost: int = 5
@export var power: int = 10
@export var power_max: int = 10
@export var level: int = 1
@export var type: String = "damage"  
@export var attribute: String = ""  
@export var amount: int = 0         
@export var duration: int = 3     
@export var target_all: bool = false
@export var target_group: String = "single"  # Valores: "single", "line", "area"
@export var element: String = ""
@export var attack_type: String = ""

func is_buff() -> bool:
	return type == "buff"

func is_debuff() -> bool:
	return type == "debuff"

func is_heal() -> bool:
	return type == "heal"

func is_damage() -> bool:
	return type == "damage"
