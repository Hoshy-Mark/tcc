extends Node

enum BattleState { ESPERANDO_COMANDO, EXECUTANDO_ACAO, FIM_COMBATE }
var state = BattleState.ESPERANDO_COMANDO
var jogador_atual : PlayerPartyMember = null
@onready var enemy_sprites_node = $EnemySprites
var enemy_sprite_scene = preload("res://decades/1980s/EnemySprite.tscn")

var party_members = []
var enemies = []
var turn_order = []
var turn_index = 0
var hud
const TEMPO_ESPERA_APOS_ACAO = 0.5
var inventario = {
	"Poção de Vida": 3,
	"Poção de MP": 2
}

func _ready():
	# carregar HUD da década
	var hud_scene = preload("res://decades/1980s/battle/CombatHUD1980.tscn")
	hud = hud_scene.instantiate()
	add_child(hud)
	hud.set_enabled(false)
	hud.action_selected.connect(_on_player_action_selected)
	randomize()

	_load_party()
	_load_enemies()
	_sort_turn_order()
	_start_turn()

func _load_party():
	party_members.clear()
	
	if GameManager.saved_party_data.size() > 0:
		# Tem dados salvos, carregar a party a partir deles
		for saved_member_data in GameManager.saved_party_data:
			var member = PlayerPartyMember.new()
			print(member.nome)
			member.nome = saved_member_data.get("nome", "Desconhecido")
			member.max_hp = saved_member_data.get("max_hp", 80)
			member.hp = saved_member_data.get("hp", member.max_hp)
			member.max_mp = saved_member_data.get("max_mp", 30)
			member.mp = saved_member_data.get("mp", member.max_mp)
			member.spells = saved_member_data.get("spells", {})
			member.level = saved_member_data.get("level", 1)
			member.xp = saved_member_data.get("xp", 0)
			member.xp_to_next_level = saved_member_data.get("xp_to_next_level", 50)
			member.spell_slots = saved_member_data.get("spell_slots", {})
			member.speed = saved_member_data.get("speed", 10) # ou algum valor padrão se precisar
			party_members.append(member)  # <-- ESSENCIAL adicionar aqui

	else:
		var black_mage = PlayerPartyMember.new()
		black_mage.nome = "Mago Negro"
		black_mage.max_hp = 80
		black_mage.hp = black_mage.max_hp
		black_mage.max_mp = 30
		black_mage.mp = black_mage.max_mp
		black_mage.spells = {
			"fogo": {"level": 1, "cost": 5, "power": 20, "power_max": 100, "type": "damage"},
			"trovao": {"level": 2, "cost": 10, "power": 30, "power_max": 200, "type": "damage"}
		}
		black_mage.level = 1
		black_mage.xp = 1
		black_mage.xp_to_next_level = 50
		black_mage.spell_slots = {1: 3, 2: 2}

		# Guerreiro
		var warrior = PlayerPartyMember.new()
		warrior.nome = "Guerreiro"
		warrior.max_hp = 80
		warrior.hp = warrior.max_hp
		warrior.max_mp = 30
		warrior.mp = warrior.max_mp
		warrior.spells = {}  # sem magias
		warrior.spell_slots = {}
		warrior.level = 1
		warrior.xp = 1
		warrior.xp_to_next_level = 50

		# Maga Branca
		var white_mage = PlayerPartyMember.new()
		white_mage.nome = "Maga Branca"
		white_mage.max_hp = 80
		white_mage.hp = white_mage.max_hp
		white_mage.max_mp = 30
		white_mage.mp = white_mage.max_mp
		white_mage.spells = {
			"cura": {"level": 1, "cost": 5, "power": -10, "power_max": -10, "type": "heal"}
		}
		white_mage.spell_slots = {1: 2}
		white_mage.level = 1
		white_mage.xp = 1
		white_mage.xp_to_next_level = 50

		# Arqueiro
		var archer = PlayerPartyMember.new()
		archer.nome = "Arqueiro"
		archer.max_hp = 80
		archer.hp = archer.max_hp
		archer.max_mp = 30
		archer.mp = archer.max_mp
		archer.spells = {}
		archer.spell_slots = {}
		archer.level = 1
		archer.xp = 1
		archer.xp_to_next_level = 50

		party_members = [black_mage, warrior, white_mage, archer]
		
		for member in party_members:
			member.connect("leveled_up", Callable(self, "_on_member_leveled_up"))

func _on_member_leveled_up(new_level, member):
	hud.add_log_entry("%s subiu para o nível %d!" % [member.nome, new_level])

func _load_enemies():
	enemies.clear()

	for child in enemy_sprites_node.get_children():
		child.queue_free()
	await get_tree().process_frame  # <- adiciona isso

	var slime = Enemy.new()
	slime.id = "enemy_slime_1"
	slime.nome = "Slime"
	

	var goblin = Enemy.new()
	goblin.id = "enemy_goblin_1"
	goblin.nome = "Goblin"
	goblin.max_hp = 80
	goblin.current_hp = goblin.max_hp
	goblin.xp_value = 50
	goblin.strength = 10
	goblin.defense = 4
	goblin.speed = 7

	enemies.append(slime)
	enemies.append(goblin)

	print("DEBUG: Carregando inimigos, total: %d" % enemies.size())
	
	for i in range(enemies.size()):
		var enemy = enemies[i]
		print("DEBUG: Criando sprite para inimigo %s (ID: %s)" % [enemy.nome, enemy.id])
		var enemy_sprite = enemy_sprite_scene.instantiate()
		enemy_sprite.set_enemy(enemy)
		print("Tipo real do node instanciado: ", enemy_sprite.get_class())
		enemy_sprite.position = Vector2(1100 + i * 320, 400)
		enemy_sprites_node.add_child(enemy_sprite)
		
	print("DEBUG: Total sprites filhos: %d" % enemy_sprites_node.get_child_count())
	hud.update_enemy_status(enemies)
		
func _sort_turn_order():
	turn_order.clear()
	var all_characters = []
	for member in party_members:
		if member.is_alive():
			all_characters.append(member)
	for enemy in enemies:
		if enemy.is_alive():
			all_characters.append(enemy)
	turn_order = all_characters
	turn_order.sort_custom(_speed_sort)

func _speed_sort(a, b):
	return b.speed - a.speed  # Ordem decrescente

func _start_turn():
	
	if turn_index >= turn_order.size():
		turn_index = 0
		_sort_turn_order()

	# Atualiza HUD com status da party
	hud.update_party_info(party_members)

	var current_actor = turn_order[turn_index]

	if current_actor.is_alive():
		if current_actor is PlayerPartyMember:
			jogador_atual = current_actor
			_esperar_comando_do_jogador(current_actor)
		else:
			jogador_atual = null
			_executar_acao_inimiga(current_actor)
	else:
		turn_index += 1
		_start_turn()

func _esperar_comando_do_jogador(player):
	state = BattleState.ESPERANDO_COMANDO
	hud.set_enabled(true)
	hud.add_log_entry("%s está se preparando para agir..." % player.nome)

func _executar_acao_inimiga(enemy):
	state = BattleState.EXECUTANDO_ACAO
	var target = _escolher_alvo_aleatorio(party_members)
	if target:
		var damage = enemy.attack(target)
		hud.add_log_entry("%s atacou %s e causou %d de dano" % [enemy.nome, target.nome, damage])
	turn_index += 1
	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	_start_turn()

func _finalizar_turno():
	
	# Verificar se todos inimigos mortos (jogador venceu)
	if enemies.all(func(e): return not e.is_alive()):
		hud.add_log_entry("Vitória! Todos os inimigos derrotados.")
		_encerrar_combate("vitoria")
		return
	
	# Verificar se todos jogadores mortos (jogador perdeu)
	if party_members.all(func(p): return not p.is_alive()):
		hud.add_log_entry("Derrota! Todos os membros do grupo foram derrotados.")
		_encerrar_combate("derrota")
		return
	
	turn_index += 1
	_start_turn()

func _escolher_alvo_aleatorio(lista):
	var vivos = lista.filter(func(p): return p.is_alive())
	if vivos.size() == 0:
		return null
	return vivos[randi() % vivos.size()]
	
func _on_player_action_selected(action_name: String):
	hud.set_enabled(false)
	hud.add_log_entry("Jogador escolheu: " + action_name)

	match action_name:
		"attack":
			var alvos_validos = enemies.filter(func(e): return e.is_alive())
			hud.target_selected.connect(_on_alvo_ataque_selecionado)
			hud.show_target_selection(alvos_validos, false)
		"magic":
			print("DEBUG: Chamando _executar_acao_magia")
			_executar_acao_magia(jogador_atual)
		"defend":
			_executar_defesa(jogador_atual)
		"flee":
			_tentar_fugir(jogador_atual)
		"item":
			hud.item_selected.connect(_on_item_escolhido)
			hud.show_item_menu(inventario)

func _on_alvo_ataque_selecionado(alvo):
	if hud.target_selected.is_connected(_on_alvo_ataque_selecionado):
		hud.target_selected.disconnect(_on_alvo_ataque_selecionado)

	await _executar_acao_ataque(jogador_atual, alvo)

func _on_item_escolhido(item_name: String):
	if hud.item_selected.is_connected(_on_item_escolhido):
		hud.item_selected.disconnect(_on_item_escolhido)

	var alvos_validos = party_members.filter(func(p): return p.is_alive())

	match item_name:
		"Poção de Vida", "Poção de MP":
			hud.target_selected.connect(_on_item_alvo_escolhido.bind(item_name))
			hud.show_target_selection(alvos_validos, true)

func _on_item_alvo_escolhido(alvo, item_name: String):
	if hud.target_selected.is_connected(_on_item_alvo_escolhido):
		hud.target_selected.disconnect(_on_item_alvo_escolhido)

	# Aplica efeito
	match item_name:
		"Poção de Vida":
			var heal_amount = 30
			alvo.hp = min(alvo.max_hp, alvo.hp + heal_amount)
			hud.add_log_entry("%s usou Poção de Vida em %s (+%d HP)" % [jogador_atual.nome, alvo.nome, heal_amount])
		"Poção de MP":
			var mp_amount = 20
			alvo.mp = min(alvo.max_mp, alvo.mp + mp_amount)
			hud.add_log_entry("%s usou Poção de MP em %s (+%d MP)" % [jogador_atual.nome, alvo.nome, mp_amount])

	# Atualiza inventário
	if inventario.has(item_name):
		inventario[item_name] -= 1

	hud.update_party_info(party_members)

	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	_finalizar_turno()
	
func _executar_acao_ataque(actor, alvo):
	state = BattleState.EXECUTANDO_ACAO

	if alvo:
		var dano = actor.attack(alvo)
		hud.add_log_entry("%s atacou %s causando %d de dano" % [actor.nome, alvo.nome, dano])
		print("DEBUG: Ataque executado, dano: %d, alvo HP atual: %d" % [dano, alvo.current_hp if "current_hp" in alvo else alvo.hp])

		if alvo is Enemy and not alvo.is_alive():
			hud.add_log_entry("%s foi derrotado!" % alvo.nome)
			print("DEBUG: Inimigo %s morreu!" % alvo.nome)

			# Buscar e remover o sprite correspondente
			for child in enemy_sprites_node.get_children():
				if "enemy" in child and child.enemy.id == alvo.id:
					child.desaparecer()
					break
			
		hud.update_party_info(party_members)
		hud.update_enemy_status(enemies)

	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	_finalizar_turno()
	
func _executar_acao_magia(actor):
	state = BattleState.EXECUTANDO_ACAO

	if actor is PlayerPartyMember:
		state = BattleState.ESPERANDO_COMANDO		
		if hud.magic_selected.is_connected(_on_magia_escolhida):
			hud.magic_selected.disconnect(_on_magia_escolhida)
		
		hud.magic_selected.connect(_on_magia_escolhida)
		hud.show_magic_menu(actor)
	else:
		hud.add_log_entry("%s não tem magia para usar." % actor.nome)
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		_finalizar_turno()
		
func _save_party_status():
	var saved_data = []
	for member in party_members:
		var member_data = {
			"nome": member.nome,
			"hp": member.hp,
			"max_hp": member.max_hp,
			"mp": member.mp,
			"max_mp": member.max_mp,
			"level": member.level,
			"xp": member.xp,
			"xp_to_next_level": member.xp_to_next_level,
			"spells": member.spells,
			"spell_slots": member.spell_slots
		}
		saved_data.append(member_data)
	
	GameManager.saved_party_data = saved_data
	print("DEBUG: Status da party salvo com sucesso!")
	
func _executar_defesa(actor):
	if actor is PlayerPartyMember:
		state = BattleState.EXECUTANDO_ACAO
		actor.defend()
		hud.add_log_entry("%s está defendendo." % actor.nome)
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		_finalizar_turno()
	else:
		# inimigos não defendem (ou implementar se quiser)
		_finalizar_turno()

func _tentar_fugir(actor):
	if actor is PlayerPartyMember:
		state = BattleState.EXECUTANDO_ACAO

		var velocidade_party = 0
		for p in party_members:
			velocidade_party += p.speed
		var velocidade_inimigos = 0
		for e in enemies:
			velocidade_inimigos += e.speed

		var chance_fuga = 50 + (velocidade_party - velocidade_inimigos) * 5
		chance_fuga = clamp(chance_fuga, 10, 90)

		var sucesso = randi() % 100 < chance_fuga
		if sucesso:
			hud.add_log_entry("%s conseguiu fugir!" % actor.nome)
			_encerrar_combate("fuga")

		else:
			hud.add_log_entry("%s tentou fugir e falhou." % actor.nome)
			_finalizar_turno()
	else:
		_finalizar_turno()

func _encerrar_combate(resultado: String):
	state = BattleState.FIM_COMBATE

	if resultado == "vitoria":
		var xp_total = 0
		for enemy in enemies:
			xp_total += enemy.xp_value if "xp_value" in enemy else 50
		
		_dar_xp_para_party(xp_total)
		hud.update_party_info(party_members)
		
		_save_party_status()  # <== SALVAR AQUI
	
	await get_tree().create_timer(5.0).timeout

	match resultado:
		"vitoria":
			get_tree().change_scene_to_file("res://decades/1980s/battle/VictoryScreen.tscn")
		"derrota", "fuga":
			get_tree().change_scene_to_file("res://decades/1980s/battle/DefeatScreen.tscn")

			
func _on_magia_escolhida(spell_name: String):
	if hud.magic_selected.is_connected(_on_magia_escolhida):
		hud.magic_selected.disconnect(_on_magia_escolhida)

	hud.set_enabled(false)

	var spell_data = jogador_atual.spells.get(spell_name, null)
	if not spell_data:
		hud.add_log_entry("Erro: magia não encontrada.")
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		_finalizar_turno()
		return

	var is_heal = spell_data.type == "heal"
	var alvos_validos = party_members.filter(func(p): return p.is_alive() and p.hp < p.max_hp) if is_heal else enemies.filter(func(e): return e.is_alive())


	if alvos_validos.is_empty():
		hud.add_log_entry("Nenhum alvo válido para %s." % spell_name)
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		_finalizar_turno()
		return

	if hud.target_selected.is_connected(_on_magia_alvo_escolhido):
		hud.target_selected.disconnect(_on_magia_alvo_escolhido)

	hud.target_selected.connect(_on_magia_alvo_escolhido)

	# Armazenar o nome da magia e o caster corretamente
	hud.set_meta("spell_name", spell_name)
	hud.set_meta("is_heal", is_heal)
	hud.set_meta("caster", jogador_atual)

	hud.show_target_selection(alvos_validos, is_heal)

func _on_magia_alvo_escolhido(alvo):
	if hud.target_selected.is_connected(_on_magia_alvo_escolhido):
		hud.target_selected.disconnect(_on_magia_alvo_escolhido)

	var spell_name = hud.get_meta("spell_name")
	var is_heal = hud.get_meta("is_heal")
	var caster = hud.get_meta("caster")  # <- agora o mago certo

	var efeito = caster.cast_spell(alvo, spell_name)

	if is_heal:
		hud.update_party_info(party_members)
		if efeito < 0:
			hud.add_log_entry("%s lançou %s em %s e curou %d HP!" % [caster.nome, spell_name, alvo.nome, -efeito])
		else:
			hud.add_log_entry("%s tentou lançar %s, mas não teve efeito." % caster.nome, spell_name)
	else:
		hud.update_enemy_status(enemies)
		if efeito > 0:
			hud.add_log_entry("%s lançou %s em %s causando %d de dano!" % [caster.nome, spell_name, alvo.nome, efeito])
			if alvo is Enemy and not alvo.is_alive():
				hud.add_log_entry("%s foi derrotado!" % alvo.nome)
				print("DEBUG: Inimigo %s morreu!" % alvo.nome)

				# Buscar e remover o sprite correspondente
				for child in enemy_sprites_node.get_children():
					if "enemy" in child and child.enemy.id == alvo.id:
						child.desaparecer()
						break
		else:
			hud.add_log_entry("%s tentou lançar %s, mas não teve efeito." % caster.nome, spell_name)

	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	_finalizar_turno()

func _escolher_aliado_para_curar():
	var vivos = party_members.filter(func(p): return p.is_alive() and p.hp < p.max_hp)
	if vivos.size() == 0:
		return null
	vivos.sort_custom(func(a, b): return float(a.hp) / a.max_hp - float(b.hp) / b.max_hp)
	return vivos[0]
	
func _dar_xp_para_party(xp_por_membro: int):
	for member in party_members:
		if member.is_alive():
			member.gain_xp(xp_por_membro)
			hud.add_log_entry("%s ganhou %d XP." % [member.nome, xp_por_membro])
