extends RefCounted
class_name EnemyAi1980

# Faz o sprite do atacante avançar e voltar, simulando o golpe.
func _play_attacker_lunge(ator: Enemy, battle_manager) -> void:
	var sprite = battle_manager._get_sprite_for_enemy(ator)
	if sprite:
		sprite.play_attack_lunge()

# --- IA do Morto-Vivo (Ataque Aleatório) ---
func execute_simple_attack(ator: Enemy, party: Array, battle_manager):
	_perform_random_attack(ator, party, battle_manager.hud, battle_manager)
	battle_manager._finalizar_turno()

# --- IA do Morcego (Retaliar) ---
func execute_retaliate_attack(ator: Enemy, party: Array, battle_manager):
	var target = null
	var hud = battle_manager.hud

	if ator.last_attacker != null and ator.last_attacker.is_alive():
		target = ator.last_attacker
	
	if target == null:
		var vivos = party.filter(func(p): return p.is_alive())
		if vivos.size() > 0:
			target = vivos[randi() % vivos.size()]
	
	if target == null:
		battle_manager._finalizar_turno()
		return

	_play_attacker_lunge(ator, battle_manager)
	var resultado = ator.attack(target)
	if resultado.has("miss") and resultado["miss"]:
		hud.add_log_entry("%s tentou atacar %s, mas errou!" % [ator.nome, target.nome])
	else:
		var dano = resultado["damage"]
		var is_crit = resultado["crit"]
		if is_crit:
			hud.add_log_entry("%s acertou um **CRÍTICO** em %s causando %d de dano!" % [ator.nome, target.nome, dano])
		else:
			hud.add_log_entry("%s atacou %s e causou %d de dano." % [ator.nome, target.nome, dano])

	battle_manager._finalizar_turno()

# --- IA do Boss (Carregar Ataque Forte) ---
func execute_boss_ai(ator: Enemy, party: Array, battle_manager):
	var hud = battle_manager.hud

	if ator.is_charging:
		hud.add_log_entry("%s usa seu ATAQUE DEVASTADOR!" % ator.nome)
		var vivos = party.filter(func(p): return p.is_alive())
		if vivos.size() > 0:
			var target = vivos[randi() % vivos.size()]
			_play_attacker_lunge(ator, battle_manager)
			var resultado = ator.strong_attack(target)
			var dano = resultado["damage"]
			var is_crit = resultado["crit"]
			if is_crit: # <-- Corrigido o typo aqui
				hud.add_log_entry("ACERTO CRÍTICO! %s sofre %d de dano!" % [target.nome, dano])
			else:
				hud.add_log_entry("%s sofre %d de dano!" % [target.nome, dano])
		ator.is_charging = false
	else:
		var chance = randf()
		if chance < 0.4: # 40% chance de carregar
			ator.is_charging = true
			hud.add_log_entry("%s está acumulando poder..." % ator.nome)
		else: # 60% chance de ataque normal
			_perform_random_attack(ator, party, hud, battle_manager)

	battle_manager._finalizar_turno()

# --- MODIFICADO: IA do Necromante (Reviver ou Invocar) ---
func execute_summon_ai(ator: Enemy, party: Array, battle_manager):
	var hud = battle_manager.hud
	var MAX_ENEMIES = battle_manager.ENEMY_POSITIONS.size() 

	# 1. ELE ESTÁ CARREGADO?
	if ator.is_charging:
		hud.add_log_entry("%s completa o ritual!" % ator.nome)
		ator.is_charging = false
		
		# Procura por Mortos-Vivos mortos para reviver
		var mortos_vivos_mortos = battle_manager.enemies.filter(func(e): return not e.is_alive() and e.nome == "Morto-Vivo")
		
		if mortos_vivos_mortos.size() > 0:
			# --- LÓGICA DE REVIVER ---
			var alvo_para_reviver = mortos_vivos_mortos[0] # Revive o primeiro que encontrar
			battle_manager._revive_enemy(alvo_para_reviver)
		
		elif battle_manager.enemies.size() < MAX_ENEMIES:
			# --- LÓGICA DE INVOCAR (se não tiver quem reviver E tiver espaço) ---
			battle_manager._spawn_enemy_from_summon("Morto-Vivo")
		
		else:
			# --- FALHA (sem mortos E sem espaço) ---
			hud.add_log_entry("... mas nada acontece!")

	# 2. ELE NÃO ESTÁ CARREGADO
	else:
		# Verifica se tem Mortos-Vivos para reviver
		var mortos_vivos_mortos = battle_manager.enemies.filter(func(e): return not e.is_alive() and e.nome == "Morto-Vivo")
		# Verifica se tem espaço para invocar (contando apenas os vivos)
		var tem_espaco = battle_manager.enemies.filter(func(e): return e.is_alive()).size() < MAX_ENEMIES
		
		if mortos_vivos_mortos.size() > 0 or tem_espaco:
			# --- COMEÇA A CARREGAR ---
			ator.is_charging = true
			hud.add_log_entry("%s começa a canalizar energia sombria..." % ator.nome)
		else:
			# --- ATACA (se não puder reviver NEM invocar) ---
			hud.add_log_entry("%s está cercado e ataca!" % ator.nome)
			_perform_random_attack(ator, party, hud, battle_manager)
	
	# 3. Finaliza o turno
	battle_manager._finalizar_turno()


# --- FUNÇÃO AJUDANTE (ATAQUE ALEATÓRIO) ---
func _perform_random_attack(ator: Enemy, party: Array, hud, battle_manager = null):
	var vivos = party.filter(func(p): return p.is_alive())
	if vivos.size() == 0:
		return
	var target = vivos[randi() % vivos.size()]
	if battle_manager:
		_play_attacker_lunge(ator, battle_manager)
	var resultado = ator.attack(target)
	if resultado.has("miss") and resultado["miss"]:
		hud.add_log_entry("%s tentou atacar %s, mas errou!" % [ator.nome, target.nome])
	else:
		var dano = resultado["damage"]
		var is_crit = resultado["crit"]
		if is_crit:
			hud.add_log_entry("%s acertou um **CRÍTICO** em %s causando %d de dano!" % [ator.nome, target.nome, dano])
		else:
			hud.add_log_entry("%s atacou %s e causou %d de dano." % [ator.nome, target.nome, dano])
