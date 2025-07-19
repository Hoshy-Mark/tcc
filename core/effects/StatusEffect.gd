extends Resource
class_name StatusEffect

enum Type { BUFF, DEBUFF }

var attribute: String = ""      # "defense", "speed", etc.
var amount: int = 0             # Quanto altera
var duration: int = 3           # Duração em turnos
var type: Type = Type.BUFF

func apply(target):
	# Aqui, o efeito aplica a alteração de atributo no alvo
	if type == Type.BUFF:
		target.active_status_effects.append(self)
	elif type == Type.DEBUFF:
		target.active_status_effects.append(self)
