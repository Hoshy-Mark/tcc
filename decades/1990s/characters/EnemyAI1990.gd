
extends Node
class_name EnemyAi1990

# --- IA Padrão: Ataque Aleatório ---
# Esta é a lógica que copiamos e limpamos do seu BattleManager
func execute_simple_attack(ator: Enemy1990, party: Array, enemies: Array, battle_manager):
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# Comportamento padrão: ataca jogadores não invisíveis
	var alive_party = party.filter(func(p): return p.is_alive() and not p.is_invisible)
	
	if alive_party.is_empty():
		battle_manager.hud.show_top_message("Todos os jogadores estão invisíveis ou mortos!")
		# Pula o turno se não houver alvo
		await battle_manager.get_tree().create_timer(battle_manager.TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()
		return

	var target = alive_party[rng.randi_range(0, alive_party.size() - 1)]
	
	# Chama a função de ataque do BattleManager
	await battle_manager.action_executor.perform_attack(ator, target)
	
	# A IA agora é responsável por finalizar o turno
	# (Esta lógica estava no fim do seu 'perform_enemy_action' antigo)
	await battle_manager.get_tree().create_timer(battle_manager.TEMPO_ESPERA_APOS_ACAO).timeout
	battle_manager.end_turn()
