extends Resource
class_name Special

@export var name: String = "Nome da Special"
@export_multiline var description: String = "Descrição da habilidade especial."
@export var cost_mp: int = 20  # Custo de MP (ou outro recurso especial)
@export var power: int = 25
@export var scaling_stat: String = "INT"  # Pode escalar com INT, FTH, etc.
@export var target_type: String = "enemy"  # enemy, ally, all_allies, etc.
@export var effect_type: String = "magical"  # magical, heal, buff, debuff, etc.
@export var duration: int = 2  # Duração de efeito como buff/debuff
@export var level: int = 1

@export var amount: int = 15  # Intensidade do efeito (cura, buff, etc.)
@export var hit_chance: float = 1.0  # Magias geralmente não erram, mas pode variar
@export var status_inflicted: String = ""  # ex: "burn", "sleep", ""
@export var status_chance: float = 0.3  # Chance de aplicar o status
@export var element: String = "fire"  # Elemento associado
@export var attack_type: String = "magic"  # magic, divine, dark, etc.
@export var cooldown: int = 3  # Turnos até poder usar novamente
@export var is_ultimate: bool = false  # Marcar se é um golpe especial único
