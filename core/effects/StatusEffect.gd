extends Resource
class_name StatusEffect

# Tipo geral de efeito que a magia aplica
enum EffectType { DAMAGE, HEAL, STAT, STATUS, SPECIAL }

# Tipo específico de status (buff ou debuff)
enum Type { BUFF, DEBUFF }

# Lista global de status reconhecidos
const STATUS_EFFECTS = [
	"haste", "slow", "protect", "shell", "poison", "blind",
	"sleep", "paralysis", "confuse", "charm", "petrify",
	"doom", "stop", "stun", "reflect", "blink"
]

# Atributos do efeito
@export var attribute: String = ""      # "defense", "speed", etc.
@export var amount: int = 0             # Quanto altera
@export var duration: int = 3           # Duração em turnos
@export var type: Type = Type.BUFF      # Se é buff ou debuff
@export var status_type: String = ""    # ex: "poison", "sleep", etc.
@export var blink_charges: int = 0      # Para efeito Blink
@export var chance: int = 100           # 👈 Aqui está a propriedade que faltava

func is_valid_status(status_name: String) -> bool:
	return status_name in STATUS_EFFECTS

# Efeito colateral aplicado a cada "tick" (uma vez por turno do alvo).
# Registro/remoção do efeito na lista do alvo é responsabilidade de quem
# gerencia essa lista (ver StatusEffectComponent), não deste método —
# chamá-lo várias vezes não deve duplicar o efeito.
func apply(target):
	match attribute:
		"regen":
			target.heal(5)
		"blink":
			blink_charges = amount
