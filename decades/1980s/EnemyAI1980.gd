# EnemyAi1980.gd
extends Node
class_name EnemyAi1980

# -----------------------------------------------------------------
# FUNÇÃO QUE VOCÊ PEDIU: Ataque aleatório simples
# -----------------------------------------------------------------
# 'ator' é o inimigo que está agindo.
# 'party' é a lista de jogadores vivos.
# 'battle_manager' é a referência ao script principal da batalha,
# para podermos chamar o HUD e finalizar o turno.

func execute_simple_attack(ator: Enemy, party: Array, battle_manager):
	
	# 1. ESCOLHER ALVO ALEATÓRIO
	# (Esta é a lógica que estava no seu _escolher_alvo_aleatorio)
	var vivos = party.filter(func(p): return p.is_alive())
	
	if vivos.size() == 0:
		# Não há ninguém para atacar, apenas finaliza o turno
		battle_manager._finalizar_turno()
		return
		
	var target = vivos[randi() % vivos.size()]

	# 2. EXECUTAR AÇÃO
	# (Esta é a lógica que estava no seu _executar_acao_inimiga)
	if target:
		var resultado = ator.attack(target)
		var hud = battle_manager.hud # Pegamos o HUD

		if resultado.has("miss") and resultado["miss"]:
			hud.add_log_entry("%s tentou atacar %s, mas errou!" % [ator.nome, target.nome])
		else:
			var dano = resultado["damage"]
			var is_crit = resultado["crit"]

			if is_crit:
				hud.add_log_entry("%s acertou um **CRÍTICO** em %s causando %d de dano!" % [ator.nome, target.nome, dano])
			else:
				hud.add_log_entry("%s atacou %s e causou %d de dano." % [ator.nome, target.nome, dano])
	
	# 3. FINALIZAR O TURNO
	# A IA avisa ao BattleManager que terminou
	battle_manager._finalizar_turno()
