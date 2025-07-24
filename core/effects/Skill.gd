extends Resource
class_name Skill

@export var name: String = "Nome da Skill"
@export_multiline var description: String = "Descrição da skill."
@export var cost: int = 5
@export var power: int = 10
@export var amount: int = 10 # valor upado oo buff ou debuff
@export var scaling_stat: String = "STR"  # STR, DEX, AGI, etc.
@export var hit_chance: float = 0.95  # de 0.0 a 1.0
@export var target_type: String = "enemy"  # enemy, ally, all_enemies, etc.
@export var effect_type: String = "physical"  # physical, debuff, buff, etc.
@export var duration: int = 3    # quantos turno dura o buff ou debuff

@export var status_inflicted: String = ""  # ex: "stun", "bleed", "" (nenhum)
@export var status_chance: float = 0.2  # chance de aplicar o status
@export var element: String = ""
@export var attack_type: String = ""
