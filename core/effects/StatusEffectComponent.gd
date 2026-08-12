extends RefCounted
class_name StatusEffectComponent

# Componente reutilizável de buffs/debuffs para qualquer combatente
# (jogador ou inimigo). Antes desta refatoração, Enemy e PlayerPartyMember
# (decadas/1980s) tinham cada um sua própria versão dessa lógica, com
# comportamentos sutilmente diferentes e bugs: efeitos podiam ser
# duplicados a cada turno processado (StatusEffect.apply() reinserindo o
# mesmo efeito na lista) e um dos dois zerava a lista inteira por engano
# a cada nova rodada.

var active: Array[StatusEffect] = []

# Aplica um novo efeito. Se já existir um efeito ativo com o mesmo
# atributo e tipo (buff/debuff), ele é substituído (nova duração e
# potência), em vez de empilhado.
func apply_effect(effect: StatusEffect) -> void:
	for i in range(active.size()):
		if active[i].attribute == effect.attribute and active[i].type == effect.type:
			active[i] = effect
			return
	active.append(effect)

func get_modifier(attribute: String) -> int:
	var total := 0
	for effect in active:
		if effect.attribute == attribute:
			total += effect.amount
	return total

# Deve ser chamado uma vez por turno do dono deste componente.
# Aplica o efeito por turno (ex: regen) de cada status ativo, reduz a
# duração e remove imediatamente os que expiraram.
func tick(target) -> void:
	for effect in active:
		effect.apply(target)
		effect.duration -= 1
	active = active.filter(func(e): return e.duration > 0)

func clear() -> void:
	active.clear()

func has(attribute: String) -> bool:
	return active.any(func(e): return e.attribute == attribute)
