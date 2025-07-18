extends Resource
class_name StatusEffect

enum Type { BUFF, DEBUFF }

var attribute: String = ""      # "defense", "speed", etc.
var amount: int = 0             # Quanto altera
var duration: int = 3           # Duração em turnos
var type: Type = Type.BUFF
