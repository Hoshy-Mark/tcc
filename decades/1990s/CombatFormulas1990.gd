extends Node

func ajustar_dano_por_posicao(dano: int, atacante, alvo, is_ataque_fisico: bool) -> int:
	if not is_ataque_fisico:
		return dano  # ataques mágicos ou à distância não são afetados

	# Reduzir dano causado se o atacante está na traseira
	if atacante.position_line == "back":
		dano *= 0.7
	
	# Reduzir dano recebido se o alvo está na traseira
	if alvo.position_line == "back":
		dano *= 0.5

	return int(dano)

func atualizar_obstrucao_inimigos(enemies: Array) -> void:
	var inimigos_vivos = enemies.filter(func(e): return e.is_alive())
	
	for i in range(enemies.size()):
		var enemy = enemies[i]
		
		# Se houver 3 ou menos inimigos VIVOS no total, ninguém está obstruído
		if inimigos_vivos.size() <= 3:
			enemy.obstruido = false
			continue
		
		if enemy.position_line == "back":
			# O protetor do inimigo 0 é o 3. O do 1 é o 4. O do 2 é o 5.
			var front_index = i + 3 # <-- Lógica corrigida
			
			# Checa se esse protetor existe no array E se está vivo
			if front_index < enemies.size() and enemies[front_index].is_alive():
				enemy.obstruido = true
			else:
				enemy.obstruido = false
		else:
			# Inimigos da linha de frente (índices 3, 4, 5) nunca estão obstruídos
			enemy.obstruido = false

func atualizar_obstrucao_party(party: Array) -> void:
	for i in range(party.size()):
		var player = party[i]
		if player.position_line == "back":
			var front_index = i - 2
			if front_index >= 0 and party[front_index].is_alive():
				player.obstruido = true
			else:
				player.obstruido = false
		else:
			player.obstruido = false

func pode_atacar(alvo, atacante, is_ataque_fisico: bool) -> bool:
	# 1. Magia e ataques à distância (Hunter) sempre acertam
	if not is_ataque_fisico:
		return true
	
	# 2. Sempre pode atacar a linha da frente
	if alvo.position_line == "front":
		return true
		
	# 3. Se chegamos aqui, o alvo está na linha de TRÁS.
	
	if alvo.obstruido:
		# Alvo está na linha de trás E seu protetor da frente está VIVO.
		# Só pode acertar se o atacante tiver alcance.
		return atacante.alcance_estendido
	else:
		# Alvo está na linha de trás MAS seu protetor da frente está MORTO.
		return true
