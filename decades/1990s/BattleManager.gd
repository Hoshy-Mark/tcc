extends Node

# Referências
var hud
@onready var characters_node = $Characters

var encounter_generator: EncounterGenerator1990
var enemy_ai: EnemyAi1990
var action_executor: ActionExecutor1990

# Dados do combate
var party := []
var enemies := []
var enemy_sprites = {}  
var current_actor = null
var ready_queue := []
var battle_active := false 
var in_summon_mode := false
var current_summon = null
var saved_party := []

var inventory := {
	"Potion": 3,
	"Ether": 2,
	"Elixir": 1,
	"Spirit Water": 2
}

# Preços da loja que abre entre uma batalha e outra.
const SHOP_PRICES = {
	"Potion": 15,
	"Ether": 15,
	"Spirit Water": 15,
	"Elixir": 50
}
const EQUIPMENT_CATALOG = [
	{"nome": "Espada Longa", "slot": "weapon", "strength_bonus": 8, "price": 40},
	{"nome": "Machado de Guerra", "slot": "weapon", "strength_bonus": 15, "price": 80},
	{"nome": "Cota de Malha", "slot": "armor", "con_bonus": 4, "price": 35},
	{"nome": "Armadura de Placas", "slot": "armor", "con_bonus": 8, "price": 70},
]

const TEMPO_ESPERA_APOS_ACAO = 0.5
const ATB_GLOBAL_MULTIPLIER = 3.0

# Estado da batalha
var turn_order := []
var sp_values := {} 
var current_turn_index := 0

# FLUXO DO JOGO

func perform_enemy_action(enemy_actor: Enemy1990) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# --- Lógica de Status (Perfeita, não mude) ---
	if enemy_actor.is_charmed:
		print("Status: Charm ativo para", enemy_actor.name)
		var allies = enemies.filter(func(e): return e.is_alive())
		if allies.is_empty():
			end_turn()
			return
		var target = allies[rng.randi_range(0, allies.size() - 1)]
		
		await action_executor.perform_attack(enemy_actor, target)

		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		end_turn()
		return

	elif enemy_actor.is_confused:
		print("Status: Confusão ativo para", enemy_actor.name)
		var all_targets = (party + enemies).filter(func(a): return a.is_alive())
		if all_targets.is_empty():
			end_turn()
			return
		var target = all_targets[rng.randi_range(0, all_targets.size() - 1)]

		await action_executor.perform_attack(enemy_actor, target)
		
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		end_turn()
		return
	enemy_ai.execute_turn(enemy_actor, party, enemies, self)
	
## As fórmulas de posicionamento (obstrução, dano por posição, alcance)
# moram no autoload CombatFormulas1990 — ver esse arquivo para a lógica.
# Antes havia cópias locais aqui e no ActionExecutor1990 que divergiram:
# essa cópia calculava o índice do "protetor" da frente errado (i - 3 em
# vez de i + 3, que é como EncounterGenerator1990 realmente distribui as
# posições), então a proteção da retaguarda nunca funcionava.
func atualizar_obstrucao_inimigos() -> void:
	CombatFormulas1990.atualizar_obstrucao_inimigos(enemies)

func atualizar_obstrucao_party() -> void:
	CombatFormulas1990.atualizar_obstrucao_party(party)

func is_player(actor) -> bool:
	if actor is PlayerPartyMember1990:
		return true
	if actor is Summon: 
		return true
	# Se não for nenhum dos dois, é um inimigo.
	return false
	
func get_player_position(index: int, is_front: bool) -> Vector2:
	var front_positions = [
		Vector2(1180, 400),  # Jogador 0 front
		Vector2(1100, 600),  # Jogador 1 back
	]
	var back_positions = [
		Vector2(1400, 400),  # Jogador 2 front
		Vector2(1350, 610),  # Jogador 3 back
	]

	# Usa a posição baseada na linha
	if is_front:
		if index < front_positions.size():
			return front_positions[index]
	else:
		if index < back_positions.size():
			return back_positions[index]

	# Fallback se algo der errado
	return Vector2(100, 500)

func get_enemy_position(index: int) -> Vector2:
	var base_x = 250
	var base_y = 380
	var offset_y = 120  # distância vertical entre inimigos na mesma linha
	var offset_x = 280  # distância horizontal entre as duas linhas

	if index < 3:
		# Linha da frente
		return Vector2(base_x, base_y + index * offset_y)
	else:
		# Linha de trás - mais atrás (X) e mais abaixo (Y)
		var tras_index = index - 3
		return Vector2(base_x + offset_x, base_y + tras_index * offset_y)  # 40 a mais no Y

func check_battle_state() -> bool:
	# Verifica se todos os inimigos estão mortos
	var all_enemies_dead = enemies.all(func(e): return not e.is_alive())

	if all_enemies_dead:
		hud.show_top_message("Vitória! Todos os inimigos foram derrotados.")
		end_battle(true)
		return true

	# Verifica se todos os jogadores estão mortos
	var all_players_dead = party.all(func(p): return not p.is_alive())

	if all_players_dead:
		hud.show_top_message("Derrota! Todos os heróis caíram.")
		end_battle(false)
		return true

		# Checa se o summon morreu
	if in_summon_mode and (not current_summon or not current_summon.is_alive()):
		restore_saved_party()
		return false  # A batalha continua
		
	return false  # A batalha continua

# O Dragão (nível 6) é o único encontro de "boss" gerado pelo
# EncounterGenerator1990 — derrotá-lo fecha o loop, em vez de encadear
# batalhas para sempre.
func _boss_derrotado() -> bool:
	for enemy in enemies:
		if enemy.nome.begins_with("Dragão") and not enemy.is_alive():
			return true
	return false

func end_battle(victory: bool) -> void:
	battle_active = false  # Para a batalha aqui
	hud.set_hud_buttons_enabled(false)

	if victory:
		if in_summon_mode:
			restore_saved_party()
		print("Fim da batalha: Vitória")

		var total_xp = 0
		var total_gold = 0
		for enemy in enemies:
			total_xp += enemy.xp_value
			total_gold += enemy.gold_value if "gold_value" in enemy else 5

		# XP dividido entre os membros VIVOS (antes cada um ganhava o total
		# inteiro, o que inflava a progressão).
		var vivos = party.filter(func(p): return p.is_alive())
		if vivos.size() > 0:
			var xp_share = int(total_xp / float(vivos.size()))
			for member in vivos:
				member.gain_xp(xp_share)
		for member in party:
			unlock_available_spells_and_skills(member)

		GameManager.saved_gold += total_gold
		hud.show_top_message("O grupo encontrou %d de ouro!" % total_gold)

		if _boss_derrotado():
			_save_party_status()
			await get_tree().create_timer(2.0).timeout
			get_tree().change_scene_to_file("res://decades/1990s/Battle/VictoryScreen.tscn")
			return

		await get_tree().create_timer(2.0).timeout
		await _abrir_loja()
		_save_party_status()
		start_battle()
	else:
		print("Fim da batalha: Derrota")
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://decades/1990s/battle/DefeatScreen.tscn")

# --- LOJA (entre batalhas) ---
func _abrir_loja() -> void:
	hud.set_hud_buttons_enabled(false)
	if not hud.shop_buy_requested.is_connected(_on_shop_buy_requested):
		hud.shop_buy_requested.connect(_on_shop_buy_requested)
	if not hud.shop_equip_requested.is_connected(_on_shop_equip_requested):
		hud.shop_equip_requested.connect(_on_shop_equip_requested)

	hud.show_shop(GameManager.saved_gold, inventory, SHOP_PRICES, EQUIPMENT_CATALOG)
	await hud.shop_closed

	hud.shop_buy_requested.disconnect(_on_shop_buy_requested)
	hud.shop_equip_requested.disconnect(_on_shop_equip_requested)

func _on_shop_buy_requested(item_name: String) -> void:
	var price = SHOP_PRICES.get(item_name, 0)
	if GameManager.saved_gold < price:
		return
	GameManager.saved_gold -= price
	inventory[item_name] = inventory.get(item_name, 0) + 1
	hud.show_shop(GameManager.saved_gold, inventory, SHOP_PRICES, EQUIPMENT_CATALOG)

func _on_shop_equip_requested(item: Dictionary) -> void:
	if GameManager.saved_gold < item.get("price", 0):
		return
	_connect_target_selected(_on_shop_equip_target_selecionado.bind(item))
	var targets = []
	for member in party:
		targets.append({"id": member.id, "nome": member.nome, "node_ref": member})
	# allow_dead=true: equipar um aliado caído deve funcionar (o bônus vale
	# quando ele for revivido), a loja não é uma ação de combate.
	hud.show_target_menu(targets, null, true)

func _on_shop_equip_target_selecionado(target_id, item: Dictionary) -> void:
	var alvo = null
	for member in party:
		if member.id == target_id:
			alvo = member
			break
	if alvo == null:
		return
	GameManager.saved_gold -= item.get("price", 0)
	if item.get("slot") == "weapon":
		alvo.equip_weapon(item)
	else:
		alvo.equip_armor(item)
	hud.show_top_message("%s equipou %s!" % [alvo.nome, item.get("nome", "item")])
	hud.show_shop(GameManager.saved_gold, inventory, SHOP_PRICES, EQUIPMENT_CATALOG)

func _save_party_status() -> void:
	var saved_data = []
	for member in party:
		var member_data = {
			"nome": member.nome,
			"classe_name": member.classe_name,
			"STR": member.STR,
			"DEX": member.DEX,
			"AGI": member.AGI,
			"CON": member.CON,
			"MAG": member.MAG,
			"INT": member.INT,
			"SPI": member.SPI,
			"LCK": member.LCK,
			"current_hp": member.current_hp,
			"max_hp": member.max_hp,
			"current_mp": member.current_mp,
			"max_mp": member.max_mp,
			"max_sp": member.max_sp,
			"current_sp": member.current_sp,
			"spells": member.spells,
			"spell_slots": member.spell_slots,
			"skills": member.skills,
			"level": member.level,
			"xp": member.xp,
			"xp_to_next_level": member.xp_to_next_level,
			"position_line": member.position_line,
			"alcance_estendido": member.alcance_estendido,
			"spell_upgrades": member.spell_upgrades,
			"skill_upgrades": member.skill_upgrades,
			"equipped_weapon": member.equipped_weapon,
			"equipped_armor": member.equipped_armor,
		}
		saved_data.append(member_data)

	GameManager.saved_party_data = saved_data
	GameManager.saved_inventario = inventory.duplicate()
	print("DEBUG: Dados salvos para 1990.")

func _load_party() -> Array:
	var loaded_party := []
	for member_data in GameManager.saved_party_data:
		var member := PlayerPartyMember1990.new()
		member.nome = member_data["nome"]
		member.classe_name = member_data["classe_name"]
		member.STR = member_data["STR"]
		member.DEX = member_data["DEX"]
		member.AGI = member_data["AGI"]
		member.CON = member_data["CON"]
		member.MAG = member_data["MAG"]
		member.INT = member_data["INT"]
		member.SPI = member_data["SPI"]
		member.LCK = member_data["LCK"]
		member.current_hp = member_data["current_hp"]
		member.max_hp = member_data["max_hp"]
		member.current_mp = member_data["current_mp"]
		member.max_mp = member_data["max_mp"]
		member.current_sp = member_data["current_sp"]
		member.max_sp = member_data["max_sp"]
		member.spells = member_data.get("spells", [])
		member.spell_slots = member_data.get("spell_slots", {})
		member.max_spell_slots = Database1990.class_spell_slots.get(member.classe_name, {})
		
		member.skills = member_data.get("skills", [])
		member.level = member_data.get("level", 1)
		member.xp = member_data.get("xp", 0)
		member.xp_to_next_level = member_data.get("xp_to_next_level", 100)
		member.position_line = member_data.get("position_line", "back")
		member.alcance_estendido = member_data.get("alcance_estendido", false)
		member.spell_upgrades = member_data.get("spell_upgrades", {})
		member.skill_upgrades = member_data.get("skill_upgrades", {})

		# O bônus de equipamento já está embutido em STR/CON (salvos acima).
		# calculate_stats() deriva defense/max_hp/etc. a partir deles, então
		# só precisamos lembrar QUAL item está equipado (pra trocar depois
		# sem duplicar o bônus) — não reaplicamos nada aqui.
		member.equipped_weapon = member_data.get("equipped_weapon", {})
		member.equipped_armor = member_data.get("equipped_armor", {})

		member.calculate_stats()
		loaded_party.append(member)
	return loaded_party

func restore_saved_party():
	in_summon_mode = false
	party = saved_party.duplicate()
	saved_party.clear()

	# Remove sprite do summon
	if current_summon and current_summon.sprite_ref:
		current_summon.sprite_ref.queue_free()
	current_summon = null

	# Recria sprites dos membros salvos
	var front_index = 0
	var back_index = 0

	for member in party:
		member.restore_spell_slots()  # 🧠 Restaurar slots de magia

		var is_front = member.position_line == "front"
		var sprite_pos_index = 0
		if is_front:
			sprite_pos_index = front_index
		else:
			sprite_pos_index = back_index

		var sprite = preload("res://decades/1990s/Battle/PlayerSprite.tscn").instantiate()
		sprite.set_sprite(Database1990.class_sprite_paths.get(member.classe_name, ""))
		sprite.position = get_player_position(sprite_pos_index, is_front)
		sprite.set_player(member)

		if is_front:
			front_index += 1
		else:
			back_index += 1

		if member.classe_name == "Monk":
			sprite.scale = Vector2(0.8, 0.8)

		member.sprite_ref = sprite
		characters_node.add_child(sprite)

	# Atualiza turnos e HUD
	turn_order = party + enemies
	hud.update_party_info(party)
	atualizar_obstrucao_party() 

# CRIAÇÃO DE INIMIGOS E PLAYER

func spawn_party(party_data: Array) -> void:
	var has_paladin = "Paladin" in party_data
	var has_hunter = "Hunter" in party_data
	var front_index = 0
	var back_index = 0
	for i in range(party_data.size()):
		var classe_name = party_data[i]
		var player_node := PlayerPartyMember1990.new()
		player_node.classe_name = classe_name
		player_node.nome = classe_name

		var stats = Database1990.class_base_stats.get(classe_name, {})
		player_node.STR = stats.get("STR", 0)
		player_node.DEX = stats.get("DEX", 0)
		player_node.AGI = stats.get("AGI", 0)
		player_node.CON = stats.get("CON", 0)
		player_node.MAG = stats.get("MAG", 0)
		player_node.INT = stats.get("INT", 0)
		player_node.SPI = stats.get("SPI", 0)
		player_node.LCK = stats.get("LCK", 0)
		player_node.attack_type = stats.get("attack_type", " ")

		player_node.calculate_stats()
		player_node.level = 1


		unlock_available_spells_and_skills(player_node)
		player_node.spell_upgrades = Database1990.class_spell_trees.get(classe_name, {}).get("spell_upgrades", {})
		player_node.skill_upgrades = Database1990.class_spell_trees.get(classe_name, {}).get("skill_upgrades", {})

		# Lógica de posição baseada na presença de Hunter e Paladin
		if classe_name == "Paladin":
			if has_hunter:
				player_node.position_line = "front"
			else:
				player_node.position_line = "back"
		elif classe_name == "Hunter":
			if has_paladin:
				player_node.position_line = "back"
			else:
				player_node.position_line = "front"
		elif classe_name in ["Monk", "Knight", "Thief"]:
			player_node.position_line = "front"
		else:
			player_node.position_line = "back"

		# Ajuste especial para Hunter
		if classe_name == "Hunter":
			player_node.alcance_estendido = true

		# Pega os slots base do Database
		var slots_base = Database1990.class_spell_slots.get(classe_name, {})
		
		# Salva a cópia máxima (O "backup")
		player_node.max_spell_slots = slots_base.duplicate() 
		
		# Define os slots atuais
		player_node.spell_slots = slots_base.duplicate() 
		
		print(classe_name)
		print(player_node.spell_slots)
		party[i] = player_node


		#Define posição do sprite com base na linha
		var is_front = player_node.position_line == "front"
		var sprite_pos_index = 0
		if is_front:
			sprite_pos_index = front_index
		else:
			sprite_pos_index = back_index
		var player_sprite = preload("res://decades/1990s/Battle/PlayerSprite.tscn").instantiate()
		player_sprite.set_sprite(Database1990.class_sprite_paths.get(classe_name, ""))
		player_sprite.position = get_player_position(sprite_pos_index, is_front)
		player_sprite.set_player(player_node)

		if is_front:
			front_index += 1
		else:
			back_index += 1

		if classe_name == "Monk":
			player_sprite.scale = Vector2(0.8, 0.8)

		player_node.sprite_ref = player_sprite
		characters_node.add_child(player_sprite)
		
	atualizar_obstrucao_party()

func spawn_loaded_party(loaded_party: Array) -> void:
	var front_index = 0
	var back_index = 0
	
	for i in range(loaded_party.size()):
		var player_node = loaded_party[i]
		player_node.restore_spell_slots()

		#Define posição do sprite com base na linha
		var is_front = player_node.position_line == "front"
		var sprite_pos_index = 0
		
		if is_front:
			sprite_pos_index = front_index
		else:
			sprite_pos_index = back_index
		var player_sprite = preload("res://decades/1990s/Battle/PlayerSprite.tscn").instantiate()
		player_sprite.set_sprite(Database1990.class_sprite_paths.get(player_node.classe_name, ""))
		player_sprite.position = get_player_position(sprite_pos_index, is_front)
		player_sprite.set_player(player_node)

		if is_front:
			front_index += 1
		else:
			back_index += 1

		if player_node.classe_name == "Monk":
			player_sprite.scale = Vector2(0.8, 0.8)

		player_node.sprite_ref = player_sprite
		characters_node.add_child(player_sprite)
		
	atualizar_obstrucao_party()

func spawn_enemies(enemy_data: Array) -> void:
	for i in range(enemy_data.size()):
		var enemy_info = enemy_data[i]
		var enemy_sprite = preload("res://decades/1990s/Battle/EnemySprite.tscn").instantiate()
		enemy_sprite.set_sprite(enemy_info["sprite_path"])
		enemy_sprite.position = get_enemy_position(i)

		enemy_sprite.set_enemy(enemy_info["instance"])
		enemy_info["instance"].sprite_ref = enemy_sprite

		enemies[i] = enemy_info["instance"]  # Substitui no array por instância
		characters_node.add_child(enemy_sprite)


func find_enemy_by_id(id: String) -> Enemy1990:
	for enemy in enemies:
		if enemy.id == id:
			return enemy
	return null


# SISTEMA DE ATB

const ATB_MAX := 100
const ATB_INCREMENT_BASE := 10  # pode ajustar conforme a velocidade

var atb_values := {}  # dicionário: personagem -> valor atual do ATB
var ready_to_act := []  # fila de personagens com ATB cheio (100)
var is_executing_turn := false  # controla se alguém está executando/decidindo ação

func _ready():

	encounter_generator = EncounterGenerator1990.new()
	enemy_ai = EnemyAi1990.new()
	action_executor = ActionExecutor1990.new(self)

	if not GameManager.saved_inventario.is_empty():
		inventory = GameManager.saved_inventario.duplicate()

	var hud_scene = preload("res://decades/1990s/Battle/CombatHUD1990.tscn")
	hud = hud_scene.instantiate()
	add_child(hud)

	hud.action_selected.connect(_on_player_action_selected)
	hud.back_pressed.connect(_on_hud_back_pressed)

# Garante que só um handler escute target_selected/line_target_selected
# por vez. Sem isso, sair de um menu (Atacar, Item, Magia...) sem escolher
# um alvo e abrir outro menu deixava o handler antigo conectado — cada
# seleção de alvo então disparava várias ações de uma vez (ex: usar um
# item repetidas vezes, ou atacar E lançar magia no mesmo clique).
func _connect_target_selected(handler: Callable) -> void:
	for connection in hud.target_selected.get_connections():
		hud.target_selected.disconnect(connection["callable"])
	hud.target_selected.connect(handler)

func _connect_line_target_selected(handler: Callable) -> void:
	for connection in hud.line_target_selected.get_connections():
		hud.line_target_selected.disconnect(connection["callable"])
	hud.line_target_selected.connect(handler)

func start_battle(party_data: Array = []) -> void:
	if party_data.is_empty() and GameManager.saved_party_data.size() > 0:
		party_data = _load_party()
	elif party_data.is_empty():
		push_error("Nenhum dado de party fornecido e nenhum save encontrado.")
		return

	for child in characters_node.get_children():
		child.queue_free()
	enemy_sprites.clear()
	enemies.clear()
	

	if party_data[0] is PlayerPartyMember1990:
		party = party_data.duplicate()
		spawn_loaded_party(party)
	else:
		party.resize(party_data.size())
		spawn_party(party_data)

	for member in party:
		sp_values[member] = 0.0

	enemies = encounter_generator.generate_enemies(party)
	spawn_enemies(enemies)
	atualizar_obstrucao_inimigos()
	
	hud.update_party_info(party)
	#hud.update_enemy_info(enemies)
	
	battle_active = true
	turn_order = party + enemies
	current_turn_index = 0

	if not is_player(current_actor):
		current_actor = get_next_player_actor(current_turn_index)

	hud.show_top_message("Batalha Iniciada!")
	next_turn()

func get_next_player_actor(start_index: int):
	var size = turn_order.size()
	var idx = start_index
	for i in range(size):
		var actor = turn_order[idx]
		if is_player(actor):
			return actor
		idx = (idx + 1) % size
	return null

func update_atb(delta):
	for actor in turn_order:
		if actor.is_alive():
			var modified_speed = actor.get_modified_derived_stat("speed")
			actor.atb_value += modified_speed * delta
			actor.atb_value = min(actor.atb_value, actor.atb_max)

func check_ready_actors():
	for actor in turn_order:
		if actor.atb_value >= actor.atb_max and actor not in ready_queue and actor.is_alive():
			ready_queue.append(actor)

func _process(delta):
	if not battle_active:
		return

	if is_executing_turn or ready_to_act.size() > 0:
		return

	for actor in turn_order:
		if actor.is_alive():
			var modified_speed = actor.get_modified_derived_stat("speed")

			if actor.active_status_effects.any(func(e): return e.attribute == "haste"):
				modified_speed *= 1.5
			if actor.active_status_effects.any(func(e): return e.attribute == "slow"):
				modified_speed *= 0.5
			if actor.active_status_effects.any(func(e): return e.attribute in ["stop", "stun", "paralysis"]):
				continue

			actor.atb_value += modified_speed * delta * ATB_GLOBAL_MULTIPLIER

	# Verifica quem está pronto
	var actors_filled = []
	for actor in turn_order:
		if actor.is_alive() and actor.atb_value >= actor.atb_max and not ready_to_act.has(actor):
			actors_filled.append(actor)

	if actors_filled.size() > 0:
		actors_filled.shuffle()
		for actor in actors_filled:
			ready_to_act.append(actor)

	var atb_values = {}
	for actor in turn_order:
		atb_values[actor] = actor.atb_value
	hud.update_atb_bars(atb_values)

	if not is_executing_turn and ready_to_act.size() > 0:
		next_turn()

func end_turn():
	is_executing_turn = false
	
	if is_player(current_actor):
		for spell_name in current_actor.spell_ap.keys():
			check_ability_mastery(current_actor, spell_name, true)
		for skill_name in current_actor.skill_ap.keys():
			check_ability_mastery(current_actor, skill_name, false)

	# Continua fluxo de batalha
	if not check_battle_state():
		if ready_to_act.size() > 0:
			next_turn()

func next_turn():
	if ready_to_act.is_empty():
		return
	current_actor = ready_to_act.pop_front()

	if not current_actor or not current_actor.is_alive():
		next_turn()
		return

	#Se petrificado, ignorar turno completamente
	if current_actor.is_petrified:
		current_actor.atb_value = 0
		next_turn()
		return

	# Processar status a cada turno
	current_actor.process_status_effects()

	if not current_actor.can_act:
		current_actor.atb_value = 0
		next_turn()
		return

	if current_actor is PlayerPartyMember1990 and current_actor.is_defending:
		current_actor.is_defending = false

	is_executing_turn = true

	if is_player(current_actor):
		hud.set_hud_buttons_enabled(true, current_actor)
		hud.indicate_current_player(current_actor)
	else:
		await get_tree().create_timer(0.5).timeout
		perform_enemy_action(current_actor)

	current_actor.atb_value = 0

func reset_atb(actor):
	actor.atb_value = 0
	hud.update_atb_bars({actor: 0})

# CRIAÇÃO

func create_spell(name: String, data: Dictionary) -> Spell:
	var s = Spell.new()
	s.name = name
	s.cost = data.get("cost", 0)
	s.power = data.get("power", 0)
	s.power_max = data.get("power_max", s.power)
	s.level = data.get("level", 1)
	s.type = data.get("type", "")
	s.attribute = data.get("attribute", "")
	s.amount = data.get("amount", 0)
	s.duration = data.get("duration", 3)
	s.target_group = data.get("target_group", "single")
	s.target_all = data.get("target_all", s.target_group == "area")
	s.element = data.get("element", "")
	s.attack_type = data.get("attack_type", "")
	
	s.status_effects = []

	# Caso seja um buff com atributo direto (como Haste, Blink, Protect...)
	if s.type == "buff" and data.has("attribute"):
		var effect = StatusEffect.new()
		effect.attribute = data["attribute"]
		effect.amount = data.get("amount", 0)
		effect.duration = data.get("duration", 3)
		effect.type = StatusEffect.Type.BUFF
		effect.status_type = data["attribute"]
		s.status_effects.append(effect)

	# Caso tenha lista de status_effects (ex: debuffs como Poison Cloud, Sleep, etc.)
	elif data.has("status_effects"):
		for effect_dict in data["status_effects"]:
			var effect = StatusEffect.new()
			effect.attribute = effect_dict.get("attribute", "")
			effect.amount = effect_dict.get("amount", -1)
			effect.duration = effect_dict.get("duration", 3)
			effect.chance = effect_dict.get("chance", 100)
			effect.status_type = effect_dict.get("attribute", "")
			effect.type = StatusEffect.Type.DEBUFF
			s.status_effects.append(effect)

	# Geração automática da descrição
	var desc_parts = []

	match s.type:
		"damage":
			var dmg = "Causa %d-%d de dano" % [s.power, s.power_max]
			if s.element != "":
				dmg += " de elemento %s" % s.element
			if s.attack_type != "":
				dmg += " (%s)" % s.attack_type
			desc_parts.append(dmg)

		"heal":
			desc_parts.append("Restaura %d de HP" % s.power)

		"buff":
			desc_parts.append("Aplica buff: %s por %d turnos" % [s.attribute.capitalize(), s.duration])

		"debuff":
			desc_parts.append("Tenta aplicar debuff")

		"summon":
			if data.has("summon_data"):
				s.summon_data = data["summon_data"]
				desc_parts.append("Invoca %s para lutar temporariamente." % s.summon_data.get("nome", "???"))

	# Adiciona efeitos de status, se houver
	if not s.status_effects.is_empty():
		for eff in s.status_effects:
			var status = "%s (%d%% de chance, %d turno(s))" % [eff.attribute.capitalize(), eff.chance, eff.duration]
			desc_parts.append("Efeito: " + status)

	# Tipo de alvo
	match s.target_group:
		"single":
			desc_parts.append("Alvo único")
		"line":
			desc_parts.append("Afeta inimigos em linha")
		"area":
			desc_parts.append("Afeta todos os inimigos")

	# Custo
	desc_parts.append("Custo: %d MP" % s.cost)

	# Junta tudo na descrição final
	s.description = ". ".join(desc_parts) + "."

	return s

func create_skill(name: String, data: Dictionary) -> Skill:
	var s = Skill.new()
	s.name = name
	s.cost = data.get("cost", 0)
	s.power = data.get("power", 0)
	s.amount = data.get("amount", 0)
	s.scaling_stat = data.get("scaling_stat", "STR")
	s.hit_chance = data.get("hit_chance", 0.95)
	s.target_type = data.get("target_type", "enemy")
	s.effect_type = data.get("effect_type", "physical")
	s.status_inflicted = data.get("status_inflicted", "")
	s.status_chance = data.get("status_chance", 0.0)
	s.element = data.get("element", "")
	s.attack_type = data.get("attack_type", "")
	s.duration = data.get("duration", 0)
	s.level = data.get("level", 1)
	s.effect = data.get("effect", "")
	return s

func create_special(name: String, data: Dictionary) -> Special:
	var s = Special.new()
	s.name = name
	s.effect_type = data.get("effect_type", "")
	s.attack_type = data.get("attack_type", "")
	s.power = data.get("power", 0)
	s.target_type = data.get("target_type", "")
	s.scaling_stat = data.get("scaling_stat", "")
	s.amount = data.get("amount", 0)
	s.duration = data.get("duration", 0)
	s.level = data.get("level", 1)
	return s

func _create_menu() -> void:
	hud._hide_all_panels()
	hud.show_action_menu()
	hud.hide_arrow()

func unlock_available_spells_and_skills(player):
	var tree = Database1990.class_spell_trees.get(player.classe_name, {"spells": {}, "skills": {}})

	player.spells.clear()
	player.skills.clear()
	player.specials.clear()

	# Desbloquear magias
	for spell_name in tree.spells.keys():
		var reqs = tree.spells[spell_name]
		# Confere level e atributos, default 0 caso não exista
		var level_req = reqs.get("level", 0)
		var int_req = reqs.get("INT", 0)
		var spi_req = reqs.get("SPI", 0)

		if player.level >= level_req and player.INT >= int_req and player.SPI >= spi_req:
			if Database1990.spell_database.has(spell_name):
				var spell = create_spell(spell_name, Database1990.spell_database[spell_name])
				player.spells.append(spell)

	# Desbloquear skills
	for skill_name in tree.skills.keys():
		var reqs = tree.skills[skill_name]
		var level_req = reqs.get("level", 0)

		var stat_req_pass = true
		for stat in reqs.keys():
			if stat == "level":
				continue
			# Verifica se o player tem stats mínimos (ex: STR, AGI, etc)
			if player.get(stat) < reqs[stat]:
				stat_req_pass = false
				break

		if player.level >= level_req and stat_req_pass:
			if Database1990.skill_database.has(skill_name):
				var skill = create_skill(skill_name, Database1990.skill_database[skill_name])
				player.skills.append(skill)
	
	# Desbloquear specials
	for special_name in tree.specials.keys():
		var reqs = tree.specials[special_name]
		var level_req = reqs.get("level", 0)

		var stat_req_pass = true
		for stat in reqs.keys():
			if stat == "level":
				continue
			if player.get(stat) < reqs[stat]:
				stat_req_pass = false
				break

		if player.level >= level_req and stat_req_pass:
			if Database1990.special_database.has(special_name):
				var special = create_special(special_name, Database1990.special_database[special_name])
				player.specials.append(special)

func check_ability_mastery(member, ability_name: String, is_spell: bool) -> void:
	var ap_dict
	if is_spell:
		ap_dict = member.spell_ap
	else:
		ap_dict = member.skill_ap
	var data = ap_dict[ability_name]
	var current_level = data.get("level", 1)
	var current_ap = data.get("current", 0)
	var ap_needed_per_level = {1: 50, 2: 100, 3: 200}

	if current_level >= 3:
		return

	var ap_needed = ap_needed_per_level[current_level]
	if current_ap >= ap_needed:
		data["level"] += 1
		data["current"] = 0
		member.apply_mastery_bonus(ability_name, data["level"], is_spell)
		if data["level"] == 3:
			if is_spell and ability_name in member.spell_upgrades:
				var evolved = member.spell_upgrades[ability_name]
				if evolved in Database1990.spell_database:
					var evolved_spell = create_spell(evolved, Database1990.spell_database[evolved])
					member.spells.append(evolved_spell)
					member.spell_ap[evolved] = {"current": 0, "level": 1}
					print("%s desbloqueou %s!" % [member.nome, evolved])
			elif not is_spell and ability_name in member.skill_upgrades:
				var evolved = member.skill_upgrades[ability_name]  # Corrigido aqui
				if evolved in Database1990.skill_database:
					# Se tiver função create_skill, use ela. Se não, create_spell pode funcionar.
					var evolved_skill = create_skill(evolved, Database1990.skill_database[evolved])
					member.skills.append(evolved_skill)
					member.skill_ap[evolved] = {"current": 0, "level": 1}
					print("%s desbloqueou %s!" % [member.nome, evolved])


# SELECIONA AÇÃO

func _on_player_action_selected(action_name: String) -> void:
	match action_name:
		"Atacar":
			if current_actor.is_charmed:
				# Charm: ataca jogadores aleatórios
				var vivos = party.filter(func(p): return p.is_alive() and p != current_actor)
				if vivos.is_empty():
					end_turn()
					return
				var rng = RandomNumberGenerator.new()
				rng.randomize()
				var alvo = vivos[rng.randi_range(0, vivos.size() - 1)]
				await action_executor.perform_attack(current_actor, alvo)
				await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
				end_turn()
				return

			elif current_actor.is_confused:
				# Confuse: ataca qualquer um (inimigo ou aliado)
				var possiveis_alvos = (party + enemies).filter(func(a): return a.is_alive() and a != current_actor)
				if possiveis_alvos.is_empty():
					end_turn()
					return
				var rng = RandomNumberGenerator.new()
				rng.randomize()
				var alvo = possiveis_alvos[rng.randi_range(0, possiveis_alvos.size() - 1)]
				await action_executor.perform_attack(current_actor, alvo)
				await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
				end_turn()
				return

			else:
				# Caso normal
				var alvos_validos = enemies.filter(func(e): return e.is_alive())
				var targets = []
				for enemy in enemies:
					if enemy.is_alive():
						targets.append({
							"id": enemy.id,
							"nome": enemy.nome,
							"node_ref": enemy
						})
				_connect_target_selected(_on_alvo_ataque_selecionado)
				hud.show_target_menu(targets, current_actor)

		"Magia", "Skills":
			# Impede uso se estiver com status mental
			if current_actor.is_charmed or current_actor.is_confused:
				hud.show_top_message("%s está desorientado demais para usar habilidades!" % current_actor.nome)
				await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
				return

			if current_actor.is_magic_user():
				var magias_dict = current_actor.get_available_spells()
				var magias = magias_dict.values()  # Pega só os objetos spell
				var mp = current_actor.current_mp
				var slots = current_actor.spell_slots
				if magias.is_empty():
					hud.show_top_message("%s não possui magias disponíveis." % current_actor.nome)
					await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
					return
				if not hud.magic_selected.is_connected(_on_magic_selected):
					hud.magic_selected.connect(_on_magic_selected)
				hud.show_ability_menu(
					magias,
					"MP",
					current_actor.current_mp,
					current_actor.spell_slots,
					{
						"nome": current_actor.nome,
						"atual": current_actor.current_mp,
						"max": current_actor.max_mp
					}
				)
			else:
				var skills = current_actor.skills
				if skills.is_empty():
					hud.show_top_message("%s não possui técnicas disponíveis." % current_actor.nome)
					await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
					return
				if not hud.skill_selected.is_connected(_on_skill_selected):
					hud.skill_selected.connect(_on_skill_selected)
				hud.show_ability_menu(
					skills,
					"SP",
					current_actor.current_sp,
					current_actor.spell_slots,  # skills não usam slots
					{
						"nome": current_actor.nome,
						"atual": current_actor.current_sp,
						"max": current_actor.max_sp
					}
				)
		"Item":
			var items = inventory
			if items.is_empty():
				hud.show_top_message("%s não possui itens." % current_actor.nome)
				await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
				next_turn()
				return
			if not hud.item_selected.is_connected(_on_item_selected):
				hud.item_selected.connect(_on_item_selected)
			hud.show_item_menu(items)
		"Defender":
			current_actor.is_defending = true
			hud.show_top_message("%s está em posição defensiva!" % current_actor.nome)
			reset_atb(current_actor)
			hud.update_party_info(party)
			hud.set_hud_buttons_enabled(false)
			await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
			hud.hide_arrow()
			end_turn()
			# Lógica de defesa
		"Fugir":
			print("Tentando fugir da batalha")
			await action_executor.tentar_fugir(current_actor)
			# Lógica de fuga
		"Especial":
				# --- TRAVA DE SEGURANÇA 1 ---
				# Checa se o ator ATUAL tem a variável "specials"
				if not "specials" in current_actor:
					await hud.show_top_message("%s não possui habilidades especiais disponíveis." % current_actor.nome)
					await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
					return # Para a execução aqui

				var especiais = current_actor.specials

				# --- TRAVA DE SEGURANÇA 2 ---
				# Checa se a lista de especiais está vazia
				if especiais.is_empty():
					await hud.show_top_message("%s não possui habilidades especiais disponíveis." % current_actor.nome)
					await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
					# Também força o próximo turno
					next_turn()
					return # Para a execução aqui

				# Se passou nas duas travas, o menu é mostrado com segurança
				if not hud.special_selected.is_connected(_on_special_selected):
					hud.special_selected.connect(_on_special_selected)
				hud.show_ability_menu(
					especiais,
					"Especial",
					0,
					{},
					{ "nome": current_actor.nome }
				)

func _on_alvo_ataque_selecionado(alvo_id):
	if hud.target_selected.is_connected(_on_alvo_ataque_selecionado):
		hud.target_selected.disconnect(_on_alvo_ataque_selecionado)

	var jogador_atual = current_actor
	var target_enemy = find_enemy_by_id(alvo_id)
	if target_enemy:
		await action_executor.perform_attack(jogador_atual, target_enemy)
	else:
		print("Alvo não encontrado:", alvo_id)

	hud.hide_arrow()
	
	hud.update_atb_bars(atb_values)

	hud.set_hud_buttons_enabled(false)

	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	end_turn()

func _on_skill_selected(skill_name: String):
	if hud.skill_selected.is_connected(_on_skill_selected):
		hud.skill_selected.disconnect(_on_skill_selected)

	var user = current_actor
	var skill_matches = user.skills.filter(func(s): return s.name == skill_name)

	if skill_matches.is_empty():
		return

	var skill = skill_matches[0]
	hud.set_meta("skill_name", skill_name)

	var alvos = []
	match skill.target_type:
		"enemy":
			alvos = enemies.filter(func(e): return e.current_hp > 0)
		"self":
			alvos = [user]
		"ally":
			alvos = party.filter(func(p): return p.current_hp > 0)
		"all_enemies":
			alvos = enemies.filter(func(e): return e.current_hp > 0)
		"line":
			# Habilita seleção de linha (frente/trás)
			_connect_line_target_selected(_on_skill_line_target_selected)
			hud.set_meta("spell_name", skill.name)
			hud.show_line_target_menu(["frente", "trás"])
			return  # Aguarda seleção do jogador
		_:
			alvos = enemies.filter(func(e): return e.current_hp > 0)

	if skill.target_type == "self":
		await action_executor._execute_skill(user, skill, user)
	elif skill.target_type == "all_enemies":
		await action_executor._execute_skill_area(user, skill, alvos)
	else:
		# Caso padrão: mostra seleção de alvos
		_connect_target_selected(_on_skill_target_selected)

		var formatted_targets = []
		for target in alvos:
			formatted_targets.append({
				"id": target.id,
				"nome": target.nome,
				"node_ref": target
			})
		hud.show_target_menu(formatted_targets, current_actor)

func _on_magic_selected(spell_name: String):
	hud.magic_selected.disconnect(_on_magic_selected)

	var caster = current_actor

	# Buscar spell no array pelo nome
	var spell_data: Spell = null
	for spell in caster.spells:
		if spell.name.to_lower() == spell_name.to_lower():
			spell_data = spell
			break

	if not spell_data:
		hud.show_top_message("Magia não encontrada.")
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		next_turn()
		return
	
	# Se for uma magia de invocação, executa direto e pula o alvo
	if spell_data.type == "summon":
		await action_executor._execute_spell_single(caster, spell_name, null)
		return
	
	var tipo = spell_data.type
	var alvos := []

	# Magias que curam "knockout" (ex: Revive) precisam poder mirar em
	# aliados CAÍDOS — do contrário não existe forma de reviver ninguém.
	var revives = spell_data.status_effects.any(func(e): return e.attribute == "knockout")

	if tipo == "cure_status" and revives:
		alvos = party.duplicate()
	else:
		match tipo:
			"heal", "buff", "cure_status":
				alvos = party.filter(func(p): return p.current_hp > 0)
			"debuff", "damage":
				alvos = enemies.filter(func(e): return e.current_hp > 0)
			_:
				alvos = enemies.filter(func(e): return e.current_hp > 0)

	if alvos.is_empty():
		hud.show_top_message("Nenhum alvo válido.")
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		next_turn()
		return

	var target_group = spell_data.target_group

	match target_group:
		"area":
			await action_executor._execute_spell_area(caster, spell_name, alvos)

		"line":
			# Jogador escolhe "frente" ou "trás"
			_connect_line_target_selected(_on_magic_line_target_selected)
			hud.show_line_target_menu(["frente", "trás"])
			hud.set_meta("spell_name", spell_name)

		"single", _:
			_connect_target_selected(_on_magic_target_selected)
			var formatted_targets = []
			for target in alvos:
				formatted_targets.append({
					"id": target.id,
					"nome": target.nome,
					"node_ref": target
				})
			hud.show_target_menu(formatted_targets, null, revives)
			hud.set_meta("spell_name", spell_name)

func _on_magic_line_target_selected(linha: String):
	hud.line_target_selected.disconnect(_on_magic_line_target_selected)

	var spell_name = hud.get_meta("spell_name")
	var caster = current_actor

	var linha_alvos = []
	
	if linha == "frente":
		linha_alvos = enemies.filter(func(e): return e.current_hp > 0 and e.position_line == "front")
	elif linha == "trás":
		linha_alvos = enemies.filter(func(e): return e.current_hp > 0 and e.position_line == "back")

	await action_executor._execute_spell_area(caster, spell_name, linha_alvos)

func _on_skill_line_target_selected(linha: String):
	hud.line_target_selected.disconnect(_on_skill_line_target_selected)

	var skill_name = hud.get_meta("skill_name")  # Corrigido de "spell_name" para "skill_name"
	var caster = current_actor

	var skill_matches = caster.skills.filter(func(s): return s.name == skill_name)
	if skill_matches.is_empty():
		print("Skill não encontrada:", skill_name)
		return

	var skill = skill_matches[0]

	var linha_alvos = []
	if linha == "frente":
		linha_alvos = enemies.filter(func(e): return e.current_hp > 0 and e.position_line == "front")
	elif linha == "trás":
		linha_alvos = enemies.filter(func(e): return e.current_hp > 0 and e.position_line == "back")

	await action_executor._execute_skill_area(caster, skill, linha_alvos)

func _on_magic_target_selected(alvo):
	hud.target_selected.disconnect(_on_magic_target_selected)

	var spell_name = hud.get_meta("spell_name")
	var caster = current_actor

	var target = find_enemy_by_id(alvo)
	
	if target == null:
		# Tenta encontrar nos aliados (party)
		for membro in party:
			if membro.id == alvo:
				target = membro
				break

	if target:
		await action_executor._execute_spell_single(caster, spell_name, target)
	else:
		print("Alvo não encontrado:", alvo)

func _on_skill_target_selected(target_id):
	if hud.target_selected.is_connected(_on_skill_target_selected):
		hud.target_selected.disconnect(_on_skill_target_selected)

	var user = current_actor
	var skill_name = hud.get_meta("skill_name")

	var skill_matches = user.skills.filter(func(s): return s.name == skill_name)
	if skill_matches.is_empty():
		print("Skill não encontrada:", skill_name)
		return

	var skill = skill_matches[0]
	var target = find_enemy_by_id(target_id)

	if target == null:
		for member in party:
			if member.id == target_id:
				target = member
				break

	if target:
		await action_executor._execute_skill(user, skill, target)
	else:
		hud.show_top_message("Alvo inválido.")
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		next_turn()

func _on_item_selected(item_name: String) -> void:
	if hud.item_selected.is_connected(_on_item_selected):
		hud.item_selected.disconnect(_on_item_selected)

	var item_data = Database1990.item_database.get(item_name, null)
	if item_data == null:
		hud.show_top_message("Item desconhecido!")
		return

	var target_list = []
	for membro in party:
		if membro.is_alive():
			target_list.append({
				"id": membro.id,
				"nome": membro.nome,
				"node_ref": membro
			})

	# Seleção de alvo. Usa método nomeado (com bind) em vez de lambda
	# anônima: uma lambda nova conectada a cada uso de item nunca era
	# desconectada, então depois de alguns itens usados numa mesma
	# batalha, escolher QUALQUER alvo disparava o uso do item várias vezes.
	_connect_target_selected(_on_item_target_selected.bind(item_name, item_data))
	hud.show_target_menu(target_list)

func _on_item_target_selected(target_id, item_name: String, item_data: Dictionary) -> void:
	action_executor.usar_item_em_alvo(current_actor, item_name, item_data, target_id)

func _on_special_selected(especial):
	
	hud.hide_special_menu()

	if especial == null:
		hud.show_top_message("Especial não encontrado.")
		await get_tree().create_timer(1.0).timeout
		next_turn()
		return

	match especial.target_type:
		"all_enemies":
			action_executor._execute_special_area(current_actor, especial, enemies)

		"ally_party":
			action_executor._execute_special_area(current_actor, especial, party)

		"self":
			action_executor._execute_special_single(current_actor, especial, current_actor)

		"enemy":
			var alvos = []
			for enemy in enemies:
				if enemy.is_alive():
					alvos.append({
						"id": enemy.id,
						"nome": enemy.nome,
						"node_ref": enemy
					})
			_connect_target_selected(_on_special_target_selected.bind(especial))
			hud.show_target_menu(alvos)

		"ally":
			var alvos = []
			for ally in party:
				if ally.is_alive():
					alvos.append({
						"id": ally.id,
						"nome": ally.nome,
						"node_ref": ally
					})
			_connect_target_selected(_on_special_target_selected.bind(especial))
			hud.show_target_menu(alvos)

		_:
			hud.show_top_message("Tipo de alvo inválido.")
			await get_tree().create_timer(1.0).timeout
			next_turn()

func _on_special_target_selected(target_id, especial):
	if hud.target_selected.is_connected(_on_special_target_selected):
		hud.target_selected.disconnect(_on_special_target_selected)

	var alvo = null

	for enemy in enemies:
		if enemy.id == target_id:
			alvo = enemy
			break
	if alvo == null:
		for ally in party:
			if ally.id == target_id:
				alvo = ally
				break

	if alvo == null:
		hud.show_top_message("Alvo inválido.")
		await get_tree().create_timer(1.0).timeout
		next_turn()
		return

	await action_executor._execute_special_single(current_actor, especial, alvo)

func _on_hud_back_pressed():
	# Desconecta todos os sinais temporários
	if hud.magic_selected.is_connected(_on_magic_selected):
		hud.magic_selected.disconnect(_on_magic_selected)
	if hud.skill_selected.is_connected(_on_skill_selected):
		hud.skill_selected.disconnect(_on_skill_selected)
	if hud.special_selected.is_connected(_on_special_selected):
		hud.special_selected.disconnect(_on_special_selected)
	if hud.target_selected.is_connected(_on_skill_target_selected):
		hud.target_selected.disconnect(_on_skill_target_selected)
	if hud.target_selected.is_connected(_on_magic_target_selected):
		hud.target_selected.disconnect(_on_magic_target_selected)
	if hud.target_selected.is_connected(_on_special_target_selected):
		hud.target_selected.disconnect(_on_special_target_selected)
	if hud.line_target_selected.is_connected(_on_magic_line_target_selected):
		hud.line_target_selected.disconnect(_on_magic_line_target_selected)
	if hud.line_target_selected.is_connected(_on_skill_line_target_selected):
		hud.line_target_selected.disconnect(_on_skill_line_target_selected)

	# Limpa quaisquer metadados pendentes
	hud.set_meta("skill_name", null)
	hud.set_meta("spell_name", null)

	# Retorna ao menu de ações
	hud.show_action_menu()
	hud.set_hud_buttons_enabled(true, current_actor)
	hud.indicate_current_player(current_actor)
