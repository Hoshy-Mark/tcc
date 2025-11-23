extends CombatCharacter2020
class_name EnemyCharacter2020

func _ready() -> void:
	super._ready()
	is_player_controlled = false
	# Se quiser animação específica de inimigo:
	# anim = get_node("AnimationPlayer")

# A IA básica já está implementada em CombatCharacter2020.take_turn().
# Podemos só sobrepor se quisermos log ou comportamento diferente:
func take_turn(manager: Node) -> void:
	print("[Enemy] Iniciando turno do inimigo: %s" % name)
	await super.take_turn(manager)
	print("[Enemy] Turno finalizado: %s" % name)
