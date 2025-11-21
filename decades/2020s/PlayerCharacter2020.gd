extends CombatCharacter2020
class_name PlayerCharacter2020

func _ready() -> void:
	super._ready()
	is_player_controlled = true
	print("agent:", nav_agent)
	if nav_agent:
		print("nav map:", nav_agent.get_navigation_map())
	# Se quiser animações específicas:
	# anim = get_node("AnimationPlayer")

func take_turn(manager: Node) -> void:
	# Jogador não usa IA.
	# O BattleManager2020 espera que o HUD chame perform_attack/move_towards/etc.
	print("[Player] Esperando ações do jogador...")
	return
