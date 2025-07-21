extends Node


enum BattleState { ESPERANDO_COMANDO, EXECUTANDO_ACAO, FIM_COMBATE, TURNO }
var state = BattleState.ESPERANDO_COMANDO
var jogador_atual : PlayerPartyMember = null
@onready var enemy_sprites_node = $EnemySprites
var enemy_sprite_scene = preload("res://decades/1980s/EnemySprite.tscn")

var background_node : TextureRect

const ENEMY_POSITIONS = [
	Vector2(440, 400),
	Vector2(620, 400),
	Vector2(480, 550),
	Vector2(680, 540)
]

var party_members = []
var enemies = []
var turn_order = []
var turn_index = 0
var hud
const TEMPO_ESPERA_APOS_ACAO = 0.5
var inventario = {
	"Poção de Vida": 3,
	"Poção de MP": 2,
	"Pena da Fênix": 2
}

func _ready():
	var hud_scene = preload("res://decades/1980s/battle/CombatHUD1980.tscn")
	hud = hud_scene.instantiate()
	add_child(hud)
	hud.set_enabled(false)
	hud.action_selected.connect(_on_player_action_selected)
	randomize()

	_load_party()

	await _load_enemies()

	_sort_turn_order()
	_start_turn()
	
func set_background_node(node: TextureRect):
	background_node = node

#AÇÕES DO PLAYER

func _load_party():
	party_members.clear()
	
	if GameManager.saved_party_data.size() > 0:
		# Carrega a party a partir dos dados salvos
		for saved_member_data in GameManager.saved_party_data:
			var member = PlayerPartyMember.new()
			member.setup(saved_member_data)
			party_members.append(member)
	else:
		var black_mage_data = {
			"nome": "Mago Negro",
			"vitality": 8,
			"strength": 5,
			"defense": 7,
			"accuracy": 10,
			"evasion": 8,
			"intelligence": 10,
			"magic_power": 12,
			"magic_defense": 12,
			"luck": 8,
			"speed": 6,
			"max_mp": 30,
			"mp": 30,
			"level": 1,
			"xp": 1,
			"xp_to_next_level": 100,
			"spell_slots": {1: 3, 2: 2, 3: 3, 4:2},
			"max_spell_slots": {1: 3, 2: 2, 3: 3, 4:2},
			"spells": {
				"fogo": {"level": 1, "cost": 5, "power": 10, "power_max": 15, "type": "damage", "hit_chance": 100},
				"trovao": {"level": 2, "cost": 10, "power": 15, "power_max": 30, "type": "damage", "hit_chance": 75},
				"explosao": {"level": 3, "cost": 15, "power": 10, "power_max": 15, "type": "damage", "area": true, "hit_chance": 60},
				"tempestade": {"level": 4, "cost": 20, "power": 15, "power_max": 30, "type": "damage", "area": true, "secondary_effect": {"type": "debuff", "attribute": "shock", "amount": -3, "duration": 2, "chance": 0.3}},
			}
		}

		var warrior_data = {
			"nome": "Guerreiro",
			"vitality": 12,
			"strength": 20,
			"defense": 10,
			"accuracy": 15,
			"evasion": 8,
			"intelligence": 3,
			"magic_power": 0,
			"magic_defense": 5,
			"luck": 8,
			"speed": 4,
			"max_mp": 0,
			"mp": 0,
			"level": 1,
			"xp": 1,
			"xp_to_next_level": 100,
			"spell_slots": {},
			"spells": {}
		}

		var white_mage_data = {
			"nome": "Maga Branca",
			"vitality": 8,
			"strength": 5,
			"defense": 6,
			"accuracy": 8,
			"evasion": 6,
			"intelligence": 6,
			"magic_power": 8,
			"magic_defense": 10,
			"luck": 6,
			"speed": 6,
			"max_mp": 30,
			"mp": 30,
			"level": 1,
			"xp": 1,
			"xp_to_next_level": 100,
			"spell_slots": {1: 5, 2: 3, 3: 3, 4:2},
			"max_spell_slots": {1: 3, 2: 2, 3: 2, 4:2},
			"spells": {
				"cura total": {"level": 3 ,"cost": 15, "power": -20, "power_max": -35, "type": "heal", "area": true},
				"cura": {"level": 1, "cost": 5, "power": -10, "power_max": -10, "type": "heal"},
				"protecao": {"level": 2, "cost": 5, "type": "buff", "attribute": "defense", "amount": 3, "duration": 3},
				"lentidao": {"level": 2, "cost": 5, "type": "debuff", "attribute": "speed", "amount": -2, "duration": 3}
			}
		}

		var thief_data = {
			"nome": "Ladrão",
			"vitality": 5,
			"strength": 10,
			"defense": 6,
			"accuracy": 18,
			"evasion": 12,
			"intelligence": 0,
			"magic_power": 0,
			"magic_defense": 5,
			"luck": 15,
			"speed": 10,
			"max_mp": 0,
			"mp": 0,
			"level": 1,
			"xp": 1,
			"xp_to_next_level": 100,
			"spell_slots": {},
			"spells": {}
		}

		var characters_data = [black_mage_data, warrior_data, white_mage_data, thief_data]

		for char_data in characters_data:
			var member = PlayerPartyMember.new()
			member.setup(char_data)
			member.connect("leveled_up", Callable(self, "_on_member_leveled_up"))
			party_members.append(member)

func _on_member_leveled_up(new_level, member):
	hud.add_log_entry("%s subiu para o nível %d!" % [member.nome, new_level])

func _escolher_alvo_aleatorio(lista):
	var vivos = lista.filter(func(p): return p.is_alive())
	if vivos.size() == 0:
		return null
	return vivos[randi() % vivos.size()]
	
func _on_player_action_selected(action_name: String):
	hud.set_enabled(false)

	match action_name:
		"attack":
			var alvos_validos = enemies.filter(func(e): return e.is_alive())
			hud.target_selected.connect(_on_alvo_ataque_selecionado)
			hud.show_target_selection(alvos_validos, "attack")
		"magic":
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

	var alvos_validos = []

	match item_name:
		"Poção de Vida", "Poção de MP":
			alvos_validos = party_members.filter(func(p): return p.is_alive())
		"Pena da Fênix":
			alvos_validos = party_members.filter(func(p): return not p.is_alive())

	if alvos_validos.size() > 0:
		hud.target_selected.connect(_on_item_alvo_escolhido.bind(item_name))
		hud.show_target_selection(alvos_validos, "item")
	else:
		hud.add_log_entry("Nenhum alvo válido para %s." % item_name)
		_esperar_comando_do_jogador(jogador_atual)

func _on_item_alvo_escolhido(alvo, item_name: String):
	if hud.target_selected.is_connected(_on_item_alvo_escolhido):
		hud.target_selected.disconnect(_on_item_alvo_escolhido)

	match item_name:
		"Poção de Vida":
			var heal_amount = 30
			alvo.hp = min(alvo.max_hp, alvo.hp + heal_amount)
			hud.add_log_entry("%s usou Poção de Vida em %s (+%d HP)" % [jogador_atual.nome, alvo.nome, heal_amount])

		"Poção de MP":
			var mp_amount = 20
			alvo.mp = min(alvo.max_mp, alvo.mp + mp_amount)
			hud.add_log_entry("%s usou Poção de MP em %s (+%d MP)" % [jogador_atual.nome, alvo.nome, mp_amount])

		"Pena da Fênix":
			var revive_hp = int(alvo.max_hp * 0.25)
			alvo.hp = revive_hp
			hud.add_log_entry("%s usou Pena da Fênix em %s. %s reviveu com %d HP!" % [jogador_atual.nome, alvo.nome, alvo.nome, revive_hp])

	if inventario.has(item_name):
		inventario[item_name] -= 1

	hud.update_party_info(party_members)

	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	_finalizar_turno()

func _executar_acao_magia(actor):
	state = BattleState.EXECUTANDO_ACAO

	if actor is PlayerPartyMember:
		state = BattleState.ESPERANDO_COMANDO

		# Garante que a conexão com o sinal ocorra apenas uma vez
		if not hud.magic_selected.is_connected(_on_magia_escolhida):
			hud.magic_selected.connect(_on_magia_escolhida)

		# Filtra magias desbloqueadas de acordo com o nível atual
		var magias_desbloqueadas := {}
		for nome_magia in actor.spells.keys():
			var dados_magia = actor.spells[nome_magia]
			if dados_magia.get("level", 1) <= actor.level:
				magias_desbloqueadas[nome_magia] = dados_magia

		if magias_desbloqueadas.is_empty():
			hud.add_log_entry("%s ainda não possui magias desbloqueadas." % actor.nome)
			await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
			_esperar_comando_do_jogador(actor)
			return

		hud.show_magic_menu(actor, magias_desbloqueadas)
	else:
		hud.add_log_entry("%s não tem magia para usar." % actor.nome)
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		_finalizar_turno()

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

	var tipo_magia = spell_data.type
	var alvos_validos := []

	match tipo_magia:
		"heal":
			alvos_validos = party_members.filter(func(p): return p.is_alive() and p.hp < p.max_hp)
		"buff":
			alvos_validos = party_members.filter(func(p): return p.is_alive())
		"debuff":
			alvos_validos = enemies.filter(func(e): return e.is_alive())
		_:
			alvos_validos = enemies.filter(func(e): return e.is_alive())

	if alvos_validos.is_empty():
		hud.add_log_entry("Nenhum alvo válido para %s." % spell_name)
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		_finalizar_turno()
		return

	hud.set_meta("spell_name", spell_name)
	hud.set_meta("spell_type", tipo_magia)
	hud.set_meta("caster", jogador_atual)
	hud.set_meta("targets", alvos_validos)
	hud.set_meta("is_area", spell_data.get("area", false))

	# Se magia for área, não pede seleção de alvo, executa direto
	if spell_data.get("area", false):
		# Passa a lista toda para executar direto
		await _executar_magia_area(jogador_atual, spell_name, alvos_validos)
	else:
		if hud.target_selected.is_connected(_on_magia_alvo_escolhido):
			hud.target_selected.disconnect(_on_magia_alvo_escolhido)

		hud.target_selected.connect(_on_magia_alvo_escolhido)
		hud.show_target_selection(alvos_validos, tipo_magia)

func _on_magia_alvo_escolhido(alvo):
	if hud.target_selected.is_connected(_on_magia_alvo_escolhido):
		hud.target_selected.disconnect(_on_magia_alvo_escolhido)

	var spell_name = hud.get_meta("spell_name")
	var caster = hud.get_meta("caster")
	var spell_data = caster.spells[spell_name]
	var tipo = spell_data.get("type", "damage")

	var alvos_validos = []
	match tipo:
		"heal":
			alvos_validos = party_members.filter(func(p): return p.is_alive() and p.hp < p.max_hp)
		"buff":
			alvos_validos = party_members.filter(func(p): return p.is_alive())
		"debuff":
			alvos_validos = enemies.filter(func(e): return e.is_alive())
		_:
			alvos_validos = enemies.filter(func(e): return e.is_alive())

	if not alvos_validos.has(alvo):
		hud.add_log_entry("Alvo inválido para a magia %s!" % spell_name)
		return

	var efeitos = caster.cast_spell(alvo, spell_name)
	
	for dado in efeitos:
		
		var efeito = dado["efeito"]

		if tipo == "damage":
			if dado.has("miss") and dado["miss"]:
				hud.add_log_entry("%s tentou lançar %s em %s, mas errou!" % [caster.nome, spell_name, alvo.nome])
			elif efeito > 0:
				hud.update_enemy_status(enemies)
				hud.add_log_entry("%s lançou %s em %s causando %d de dano!" % [caster.nome, spell_name, alvo.nome, efeito])
				if alvo is Enemy and not alvo.is_alive():
					hud.add_log_entry("%s foi derrotado!" % alvo.nome)
					for child in enemy_sprites_node.get_children():
						if "enemy" in child and child.enemy.id == alvo.id:
							child.desaparecer()
							break
			else:
				hud.add_log_entry("%s lançou %s em %s, mas não teve efeito." % [caster.nome, spell_name, alvo.nome])

		elif tipo == "heal":
			hud.update_party_info(party_members)
			if efeito < 0:
				hud.add_log_entry("%s lançou %s em %s e curou %d HP!" % [caster.nome, spell_name, alvo.nome, -efeito])
			else:
				hud.add_log_entry("%s tentou lançar %s em %s, mas não teve efeito." % [caster.nome, spell_name, alvo.nome])

		elif tipo == "buff" or tipo == "debuff":
			var attr = spell_data.get("attribute", "atributo")
			var amt = spell_data.get("amount", 0)
			var dur = spell_data.get("duration", 3)
			var acao = "aumentou" if tipo == "buff" else "reduziu"
			hud.add_log_entry("%s lançou %s em %s e %s %s %d por %d turnos." % [caster.nome, spell_name, alvo.nome, acao, attr, abs(amt), dur])

	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	_finalizar_turno()

func _executar_magia_area(caster, spell_name, alvos):
	var spell_data = caster.spells[spell_name]
	var tipo = spell_data.get("type", "damage")
	var secondary = spell_data.get("secondary_effect", null)

	var resultados = caster.cast_spell(alvos, spell_name)

	for dado in resultados:
		var alvo = dado["alvo"]
		var efeito = dado["efeito"]

		if tipo == "damage":
			hud.update_enemy_status(enemies)
			if efeito > 0:
				hud.add_log_entry("%s lançou %s em %s causando %d de dano!" % [caster.nome, spell_name, alvo.nome, efeito])
				if alvo is Enemy and not alvo.is_alive():
					hud.add_log_entry("%s foi derrotado!" % alvo.nome)
					for child in enemy_sprites_node.get_children():
						if "enemy" in child and child.enemy.id == alvo.id:
							child.desaparecer()
							break
			else:
				hud.add_log_entry("%s tentou lançar %s em %s, mas não teve efeito." % [caster.nome, spell_name, alvo.nome])

		elif tipo == "heal":
			hud.update_party_info(party_members)
			if efeito < 0:
				hud.add_log_entry("%s lançou %s em %s e curou %d HP!" % [caster.nome, spell_name, alvo.nome, -efeito])
			else:
				hud.add_log_entry("%s tentou lançar %s em %s, mas não teve efeito." % [caster.nome, spell_name, alvo.nome])

		elif tipo == "buff" or tipo == "debuff":
			var attr = spell_data.get("attribute", "atributo")
			var amt = spell_data.get("amount", 0)
			var dur = spell_data.get("duration", 3)
			var acao = "aumentou" if tipo == "buff" else "reduziu"
			hud.add_log_entry("%s lançou %s em %s e %s %s %d por %d turnos." % [caster.nome, spell_name, alvo.nome, acao, attr, abs(amt), dur])

		# Efeito secundário
		if secondary != null and randf() < secondary.get("chance", 0):
			var se_type = secondary.get("type", "")
			if se_type == "debuff":
				var se_effect = StatusEffect.new()
				se_effect.attribute = secondary.get("attribute", "")
				se_effect.amount = secondary.get("amount", 0)
				se_effect.duration = secondary.get("duration", 3)
				se_effect.type = StatusEffect.Type.DEBUFF
				alvo.apply_status_effect(se_effect)
				hud.add_log_entry("%s sofreu %s em %s!" % [alvo.nome, secondary.get("attribute", "um debuff"), alvo.nome])

	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	_finalizar_turno()

func _escolher_aliado_para_curar():
	var vivos = party_members.filter(func(p): return p.is_alive() and p.hp < p.max_hp)
	if vivos.size() == 0:
		return null
	vivos.sort_custom(func(a, b): return float(a.hp) / a.max_hp - float(b.hp) / b.max_hp)
	return vivos[0]

func _executar_acao_ataque(actor, alvo):
	state = BattleState.EXECUTANDO_ACAO

	if alvo:
		var resultado = actor.attack(alvo)

		# Verificar se o ataque errou
		if resultado.has("miss") and resultado["miss"]:
			hud.add_log_entry("%s tentou atacar %s, mas errou!" % [actor.nome, alvo.nome])

		else:	
			var dano = resultado["damage"]
			var is_crit = resultado["crit"]

			if is_crit:
				hud.add_log_entry("%s acertou um **CRÍTICO** em %s causando %d de dano!" % [actor.nome, alvo.nome, dano])
			else:
				hud.add_log_entry("%s atacou %s causando %d de dano." % [actor.nome, alvo.nome, dano])

			if alvo is Enemy and not alvo.is_alive():
				hud.add_log_entry("%s foi derrotado!" % alvo.nome)

				# Buscar e remover o sprite correspondente
				for child in enemy_sprites_node.get_children():
					if "enemy" in child and child.enemy.id == alvo.id:
						child.desaparecer()
						break

		hud.update_party_info(party_members)
		hud.update_enemy_status(enemies)
	
	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	_finalizar_turno()

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

# AÇÕES DO INIMIGO


func _load_enemies():
	enemies.clear()

	for child in enemy_sprites_node.get_children():
		child.queue_free()
	await get_tree().process_frame

	var party_level = _get_average_party_level()
	var possible_enemies = []

	# Determina inimigos válidos com base no nível
	if party_level <= 1:
		possible_enemies = ["Morcego", "Goblin"]
	elif party_level <= 3:
		possible_enemies = ["Morcego", "Goblin", "Little Orc"]
	elif party_level == 4:
		possible_enemies = ["Little Orc"]
	elif party_level >= 5:
		possible_enemies = ["Orc"]

	# Trocar o fundo com base no tipo de inimigo
	var background_texture : Texture2D
	if party_level >= 5:
		background_texture = preload("res://assets/Sala do Boss.png")
	else:
		background_texture = preload("res://assets/Corredores.png")

	if background_node:
		background_node.texture = background_texture

	var num_to_generate = randf_range(1, 4)
	if party_level >= 5:
		num_to_generate = 1

	for i in range(num_to_generate):
		var enemy_name = possible_enemies[randi() % possible_enemies.size()]
		var enemy = _create_enemy_by_type(enemy_name)
		enemies.append(enemy)

		var enemy_sprite = enemy_sprite_scene.instantiate()
		enemy_sprite.set_enemy(enemy)


		enemy_sprite.position = ENEMY_POSITIONS[i]

		enemy_sprites_node.add_child(enemy_sprite)

	hud.update_enemy_status(enemies)

func _create_enemy_by_type(nome: String) -> Enemy:
	var enemy = Enemy.new()
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	enemy.id = "%s_%06d" % [name.to_lower().replace(" ", "_"), rng.randi_range(0, 999999)]
	enemy.nome = nome
	
	match nome:
		"Morcego":
			enemy.max_hp = 15
			enemy.strength = 10
			enemy.defense = 3
			enemy.magic_defense = 1
			enemy.accuracy = 10
			enemy.evasion = 13
			enemy.luck = 3
			enemy.speed = 10
			enemy.xp_value = 15
		"Goblin":
			enemy.max_hp = 25
			enemy.accuracy = 10
			enemy.strength = 15
			enemy.defense = 3
			enemy.magic_defense = 2
			enemy.evasion = 5
			enemy.luck = 5
			enemy.speed = 7
			enemy.xp_value = 25
		"Little Orc":
			enemy.max_hp = 100
			enemy.strength = 30
			enemy.defense = 5
			enemy.magic_defense = 4
			enemy.accuracy = 15
			enemy.evasion = 8
			enemy.luck = 10
			enemy.speed = 5
			enemy.xp_value = 50
		"Orc":
			enemy.max_hp = 300
			enemy.strength = 50
			enemy.accuracy = 20
			enemy.defense = 8
			enemy.magic_defense = 8
			enemy.luck = 15
			enemy.evasion = 10
			enemy.speed = 3
			enemy.xp_value = 200

	enemy.current_hp = enemy.max_hp
	enemy.current_mp = enemy.max_mp
	return enemy

func _executar_acao_inimiga(enemy):
	enemy.process_status_effects()
	state = BattleState.EXECUTANDO_ACAO
	var target = _escolher_alvo_aleatorio(party_members)
	if target:
		var resultado = enemy.attack(target)

		if resultado.has("miss") and resultado["miss"]:
			hud.add_log_entry("%s tentou atacar %s, mas errou!" % [enemy.nome, target.nome])
		else:
			var dano = resultado["damage"]
			var is_crit = resultado["crit"]

			if is_crit:
				hud.add_log_entry("%s acertou um **CRÍTICO** em %s causando %d de dano!" % [enemy.nome, target.nome, dano])
			else:
				hud.add_log_entry("%s atacou %s e causou %d de dano." % [enemy.nome, target.nome, dano])

	_finalizar_turno()

func _get_average_party_level() -> int:
	if party_members.size() == 0:
		return 1  # fallback
	var total_level = 0
	for member in party_members:
		total_level += member.level
	return int(round(float(total_level) / party_members.size()))

func _boss_derrotado() -> bool:
	for enemy in enemies:
		if enemy.nome == "Orc" and not enemy.is_alive():
			return true
	return false


# CONTROLE DE FLUXO DE JOGO


func _sort_turn_order():
	turn_order.clear()

	var all_characters = []

	# Atualiza efeitos ativos e adiciona todos os vivos
	for member in party_members:
		if member.is_alive():
			member.update_status_effects()  # <-- ESSENCIAL
			all_characters.append(member)

	for enemy in enemies:
		if enemy.is_alive():
			enemy.update_status_effects()  # <-- ESSENCIAL
			all_characters.append(enemy)

	# Ordena manualmente do maior para o menor speed modificado
	for character in all_characters:
		var modified_speed = character.get_modified_stat(character.speed, "speed")
		var inserted = false
		for i in range(turn_order.size()):
			var other_speed = turn_order[i].get_modified_stat(turn_order[i].speed, "speed")
			if modified_speed > other_speed:
				turn_order.insert(i, character)
				inserted = true
				break
		if not inserted:
			turn_order.append(character)

func _speed_sort(a, b):
	return b.speed - a.speed

func _start_turn():
	if turn_index >= turn_order.size():
		turn_index = 0

	var current_actor = turn_order[turn_index]

	if not current_actor.is_alive():
		turn_index += 1
		_start_turn()
		return

	if current_actor is PlayerPartyMember:
		jogador_atual = current_actor

		# Atualiza HUD da party
		hud.update_party_info(party_members)
		hud.set_enabled(true)
		hud.highlight_current_player(jogador_atual)

		state = BattleState.ESPERANDO_COMANDO
		_esperar_comando_do_jogador(current_actor)
	else:
		jogador_atual = null
		hud.set_enabled(false)
		hud.highlight_current_player(null)
		state = BattleState.EXECUTANDO_ACAO
		_executar_acao_inimiga(current_actor)

func _esperar_comando_do_jogador(player):
	state = BattleState.ESPERANDO_COMANDO
	player.process_status_effects()
	hud.set_enabled(true)
	hud.add_log_entry("%s está se preparando para agir..." % player.nome)

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
		
	for member in party_members:
		if member.is_alive():
			member.process_status_effects()
	
	turn_index += 1
	_start_turn()

func _encerrar_combate(resultado: String):
	state = BattleState.FIM_COMBATE

	if resultado == "vitoria":
		var xp_total = 0
		for enemy in enemies:
			xp_total += enemy.xp_value if "xp_value" in enemy else 50
		
		_dar_xp_para_party(xp_total)
		hud.update_party_info(party_members)
		
		_save_party_status()
	
	await get_tree().create_timer(1.0).timeout

	match resultado:
		"vitoria":
			if _boss_derrotado():
				get_tree().change_scene_to_file("res://decades/1980s/battle/VictoryScreen.tscn")
			else:
				_carregar_proxima_batalha()
		"derrota", "fuga":
			get_tree().change_scene_to_file("res://decades/1980s/battle/DefeatScreen.tscn")
			
func _carregar_proxima_batalha():
	await get_tree().create_timer(1.0).timeout

	# 1. RECARREGA A EQUIPE A PARTIR DOS DADOS SALVOS PELA BATALHA ANTERIOR
	#    Isso limpa os objetos antigos e cria novos com o estado correto (HP, MP, XP).
	_load_party() 

	# 2. Carrega novos inimigos para a nova batalha.
	await _load_enemies() # Adicionei await aqui para garantir que carregue antes de continuar

	# 3. Organiza a ordem de turno com a equipe recarregada e os novos inimigos.
	_sort_turn_order()
	turn_index = 0
	state = BattleState.TURNO
	_start_turn()
	
func _save_party_status():
	var saved_data = []
	for member in party_members:
		var member_data = {
			"nome": member.nome,
			"vitality": member.vitality,
			"strength": member.strength,
			"defense": member.defense,
			"accuracy": member.accuracy,
			"evasion": member.evasion,
			"intelligence": member.intelligence,
			"magic_power": member.magic_power,
			"magic_defense": member.magic_defense,
			"luck": member.luck,
			"speed": member.speed,
			"hp": member.hp,
			"max_hp": member.max_hp,
			"mp": member.max_mp,
			"max_mp": member.max_mp,
			"level": member.level,
			"xp": member.xp,
			"xp_to_next_level": member.xp_to_next_level,
			"spells": member.spells,
			"spell_slots": {
				"current": member.spell_slots,
				"max": member.max_spell_slots
			}
		}
		saved_data.append(member_data)
	
	GameManager.saved_party_data = saved_data
	
func _dar_xp_para_party(xp_por_membro: int):
	for member in party_members:
		if member.is_alive():
			member.gain_xp(xp_por_membro)
			hud.add_log_entry("%s ganhou %d XP." % [member.nome, xp_por_membro])
