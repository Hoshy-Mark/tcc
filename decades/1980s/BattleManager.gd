extends Node

enum BattleState { ESPERANDO_COMANDO, EXECUTANDO_ACAO, FIM_COMBATE }
var state = BattleState.ESPERANDO_COMANDO
var jogador_atual : PlayerPartyMember = null
@onready var enemy_sprite_node = $"../EnemySprite"

var party_members = []
var enemies = []
var turn_order = []
var turn_index = 0
var hud

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
	var hero1 = PlayerPartyMember.new()
	hero1.nome = "Hero"

	var hero2 = PlayerPartyMember.new()
	hero2.nome = "Mage"
	hero2.hp = 70
	hero2.mp = 50
	hero2.strength = 6
	hero2.defense = 3
	hero2.speed = 6

	party_members.append(hero1)
	party_members.append(hero2)

func _load_enemies():
	var slime = Enemy.new()
	slime.nome = "Slime"

	var goblin = Enemy.new()
	goblin.nome = "Goblin"
	goblin.max_hp = 80
	goblin.current_hp = goblin.max_hp
	goblin.strength = 10
	goblin.defense = 4
	goblin.speed = 7

	enemies.append(slime)
	enemies.append(goblin)

	# Atualiza EnemySprite (exibe apenas um visualmente, mas atualiza o primeiro)
	if enemy_sprite_node:
		enemy_sprite_node.texture = preload("res://assets/Goblin.png")
		enemy_sprite_node.set("enemy", goblin)

	# Atualiza HUD com informações dos inimigos
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
	print("Aguardando ação do jogador: %s" % player.name)

func _executar_acao_inimiga(enemy):
	state = BattleState.EXECUTANDO_ACAO
	var target = _escolher_alvo_aleatorio(party_members)
	if target:
		var damage = enemy.attack(target)
		print("%s atacou %s e causou %d de dano" % [enemy.name, target.name, damage])
	turn_index += 1
	await get_tree().create_timer(1.0).timeout
	_start_turn()

func _finalizar_turno():
	
	# Verificar se todos inimigos mortos (jogador venceu)
	if enemies.all(func(e): return not e.is_alive()):
		print("Vitória! Todos os inimigos derrotados.")
		_encerrar_combate("vitoria")
		return
	
	# Verificar se todos jogadores mortos (jogador perdeu)
	if party_members.all(func(p): return not p.is_alive()):
		print("Derrota! Todos os membros do grupo foram derrotados.")
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
	print("Jogador escolheu: ", action_name)

	match action_name:
		"attack":
			_executar_acao_ataque(jogador_atual)
		"magic":
			_executar_acao_magia(jogador_atual)
		"defend":
			_executar_defesa(jogador_atual)
		"flee":
			_tentar_fugir(jogador_atual)

func _executar_acao_ataque(actor):
	state = BattleState.EXECUTANDO_ACAO
	var alvo

	if actor is PlayerPartyMember:
		alvo = _escolher_alvo_aleatorio(enemies)
		if alvo:
			var dano = actor.attack(alvo)
			hud.update_enemy_status(enemies)
			print("%s atacou %s e causou %d de dano" % [actor.name, alvo.name, dano])
	else:
		alvo = _escolher_alvo_aleatorio(party_members)
		if alvo:
			var dano = actor.attack(alvo)
			hud.update_enemy_status(enemies)
			print("%s atacou %s e causou %d de dano" % [actor.name, alvo.name, dano])

	await get_tree().create_timer(1.0).timeout
	_finalizar_turno()

func _executar_acao_magia(actor):
	state = BattleState.EXECUTANDO_ACAO

	if actor is PlayerPartyMember:
		var spell_name = "fire"  # Exemplo fixo, pode vir do menu
		var alvo = _escolher_alvo_aleatorio(enemies)
		if alvo:
			var dano_magia = actor.cast_spell(alvo, spell_name)
			if dano_magia > 0:
				print("%s lançou %s em %s causando %d de dano" % [actor.name, spell_name, alvo.name, dano_magia])
			else:
				print("%s falhou ao lançar magia." % actor.name)
	else:
		# inimigos não usam magia (ou implementar caso queira)
		print("%s não tem magia para usar." % actor.name)

	await get_tree().create_timer(1.0).timeout
	_finalizar_turno()

func _executar_defesa(actor):
	if actor is PlayerPartyMember:
		state = BattleState.EXECUTANDO_ACAO
		actor.defend()
		print("%s está defendendo." % actor.name)
		await get_tree().create_timer(1.0).timeout
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
			print("%s conseguiu fugir!" % actor.name)
			_encerrar_combate("fuga")

		else:
			print("%s tentou fugir e falhou." % actor.name)
			_finalizar_turno()
	else:
		_finalizar_turno()

func _encerrar_combate(resultado: String):
	state = BattleState.FIM_COMBATE
	
	match resultado:
		"vitoria":
			get_tree().change_scene_to_file("res://decades/1980s/battle/VictoryScreen.tscn")
		"derrota":
			get_tree().change_scene_to_file("res://decades/1980s/battle/DefeatScreen.tscn")
		"fuga":
			get_tree().change_scene_to_file("res://decades/1980s/battle/DefeatScreen.tscn")
