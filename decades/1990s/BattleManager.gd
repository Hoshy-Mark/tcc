extends Node

# Referências
var hud
@onready var characters_node = $Characters

# Dados do combate
var party := []
var enemies := []
var enemy_sprites = {}  # id -> EnemySprite
var current_actor = null
var ready_queue := []
var battle_active := false 

var inventory := {
	"Potion": 3,
	"Ether": 2,
	"Elixir": 1,
	"Spirit Water": 2
}

var item_database = {
	"Potion": {"type": "heal", "power": 50, "target": "ally"},
	"Ether": {"type": "restore_mp", "power": 30, "target": "ally"},
	"Spirit Water": {"type": "restore_sp", "power": 30, "target": "ally"},
	"Elixir": {"type": "full_restore", "target": "ally"},
}

const TEMPO_ESPERA_APOS_ACAO = 0.5

var enemy_base_stats = {
	"Goblin": {
		"STR": 10, "DEX": 6, "AGI": 20, "CON": 3, "MAG": 1, "INT": 2, "SPI": 2, "LCK": 4,
		"xp_value": 10, "sprite_path": "res://assets/Goblin.png"
	},
	"Little Orc": {
		"STR": 10, "DEX": 4, "AGI": 20, "CON": 6, "MAG": 2, "INT": 3, "SPI": 3, "LCK": 3,
		"xp_value": 20, "sprite_path": "res://assets/Little Orc.png"
	},
}

var class_sprite_paths = {
	"Knight": "res://assets/classes/Knight.png",
	"Mage": "res://assets/classes/Mage.png",
	"Thief": "res://assets/classes/Thief.png",
	"Cleric": "res://assets/classes/Cleric.png",
	"Hunter": "res://assets/classes/Hunter.png",
	"Monk": "res://assets/classes/Monk.png",
	"Paladin": "res://assets/classes/Paladin.png",
	"Summoner": "res://assets/classes/Summoner.png",
}

var class_base_stats = {
	"Knight":    {"STR": 9, "DEX": 5, "AGI": 3, "CON": 9, "MAG": 1, "INT": 2, "SPI": 4, "LCK": 3},
	"Mage":      {"STR": 1, "DEX": 4, "AGI": 4, "CON": 2, "MAG": 10, "INT": 9, "SPI": 5, "LCK": 4},
	"Thief":     {"STR": 5, "DEX": 9, "AGI": 9, "CON": 3, "MAG": 1, "INT": 3, "SPI": 2, "LCK": 10},
	"Cleric":    {"STR": 2, "DEX": 4, "AGI": 20, "CON": 5, "MAG": 5, "INT": 6, "SPI": 10, "LCK": 6},
	"Hunter":    {"STR": 7, "DEX": 10, "AGI": 8, "CON": 4, "MAG": 1, "INT": 3, "SPI": 3, "LCK": 7},
	"Paladin":   {"STR": 7, "DEX": 6, "AGI": 4, "CON": 8, "MAG": 4, "INT": 5, "SPI": 8, "LCK": 4},
	"Monk":      {"STR": 60, "DEX": 7, "AGI": 6, "CON": 7, "MAG": 2, "INT": 3, "SPI": 3, "LCK": 5},
	"Summoner":  {"STR": 3, "DEX": 5, "AGI": 4, "CON": 3, "MAG": 10, "INT": 8, "SPI": 6, "LCK": 8},
}

var class_spell_slots = {
	"Mage": {1: 4, 2: 3, 3: 2},
	"Cleric": {1: 3, 2: 2, 3: 1},
	"Paladin": {1: 2},
	"Summoner": {1: 3, 2: 2},
	"Monk": {},
	"Hunter": {},
	"Thief": {},
	"Knight": {}
}

var spell_database = {
	# Magias ofensivas
	"Fire": {"type": "damage", "element": "fire", "power": 25, "power_max": 35, "cost": 5, "level": 1, "hit_chance": 95},
	"Ice": {"type": "damage", "element": "ice", "power": 22, "power_max": 32, "cost": 5, "level": 1, "hit_chance": 95},
	"Thunder": {"type": "damage", "element": "thunder", "power": 28, "power_max": 38, "cost": 6, "level": 1, "hit_chance": 90},
	"Flare": {"type": "damage", "element": "fire", "power": 80, "power_max": 100, "cost": 20, "level": 3, "hit_chance": 85},

	# Cura
	"Cure": {"type": "heal", "power": 30, "cost": 5, "level": 1},
	"Cura": {"type": "heal", "power": 60, "cost": 10, "level": 2},
	"Heal All": {"type": "heal", "power": 40, "cost": 12, "level": 3, "target_all": true},

	# Buffs e debuffs
	"Protect": {"type": "buff", "attribute": "defense", "amount": 5, "duration": 3, "cost": 6, "level": 1},
	"Shell": {"type": "buff", "attribute": "magic_defense", "amount": 5, "duration": 3, "cost": 6, "level": 1},
	"Weaken": {"type": "debuff", "attribute": "strength", "amount": -5, "duration": 3, "cost": 8, "level": 2},
	"Slow": {"type": "debuff", "attribute": "speed", "amount": -4, "duration": 3, "cost": 8, "level": 2},

	# Especiais
	"Summon Ifrit": {"type": "damage", "element": "fire", "power": 100, "power_max": 120, "cost": 25, "level": 4, "hit_chance": 100},
	"Dispel": {"type": "special", "effect": "remove_buffs", "cost": 10, "level": 2}
}

var skill_database = {
	"Power Strike": {"effect_type": "damage", "power": 35, "cost": 4, "target_type": "enemy"},
	"Quick Shot": {"effect_type": "damage", "power": 25, "cost": 3, "target_type": "enemy"},
	"Focus": {"effect_type": "buff", "scaling_stat": "AGI", "amount": 500, "duration": 3, "cost": 2, "target_type": "self"},
	"Heal Self": {"effect_type": "heal", "power": 25, "cost": 5, "target_type": "self"},
}

# Estado da batalha
var turn_order := []

var sp_values := {} 

var current_turn_index := 0



# FLUXO DO JOGO

func is_player(actor) -> bool:
	return party.has(actor)

func perform_enemy_action(enemy_actor) -> void:
	var alive_party = party.filter(func(p): return p.current_hp > 0)
	if alive_party.size() == 0:
		hud.show_top_message("Todos os jogadores foram derrotados!")
		return

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var target = alive_party[rng.randi_range(0, alive_party.size() - 1)]

	await perform_attack(enemy_actor, target)

	# 🔧 Zera ATB do inimigo
	atb_values[enemy_actor] = 0
	hud.update_atb_bars(atb_values)

	# 🔧 Espera e finaliza turno
	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	end_turn()

func get_player_position(index: int) -> Vector2:
	var positions = [
		Vector2(1180, 350),  # Jogador 0
		Vector2(1100, 550),  # Jogador 1
		Vector2(1400, 350),  # Jogador 2
		Vector2(1350, 560),  # Jogador 3
	]
	
	if index >= 0 and index < positions.size():
		return positions[index]
	else:
		# Posição padrão caso index seja inválido
		return Vector2(100, 500)

func get_enemy_position(index: int) -> Vector2:
	return Vector2(500, 400 + index * 70)

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

	return false  # A batalha continua

func end_battle(victory: bool) -> void:
	battle_active = false  # Para a batalha aqui
	hud.set_hud_buttons_enabled(false)

	if victory:
		print("Fim da batalha: Vitória")
		_save_party_status()
		await get_tree().create_timer(5.0).timeout
		start_battle()
	else:
		print("Fim da batalha: Derrota")
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://decades/1990s/battle/DefeatScreen.tscn")

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
			"skills": member.skills
		}
		saved_data.append(member_data)
	GameManager.saved_party_data = saved_data
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
		member.skills = member_data.get("skills", [])
		member.calculate_stats()
		loaded_party.append(member)
	return loaded_party

# CRIAÇÃO DE INIMIGOS E PLAYER


func spawn_party(party_data: Array) -> void:
	for i in range(party_data.size()):
		var classe_name = party_data[i]

		var player_node := PlayerPartyMember1990.new()
		player_node.classe_name = classe_name
		player_node.nome = classe_name

		var stats = class_base_stats.get(classe_name, {})
		player_node.STR = stats.get("STR", 0)
		player_node.DEX = stats.get("DEX", 0)
		player_node.AGI = stats.get("AGI", 0)
		player_node.CON = stats.get("CON", 0)
		player_node.MAG = stats.get("MAG", 0)
		player_node.INT = stats.get("INT", 0)
		player_node.SPI = stats.get("SPI", 0)
		player_node.LCK = stats.get("LCK", 0)

		player_node.calculate_stats()

		# --- Magias por classe como Spell Resource ---
		player_node.spells = []

		var spells_for_class := []
		match classe_name:
			"Mage":
				spells_for_class = ["Fire", "Ice", "Thunder", "Flare"]
			"Cleric":
				spells_for_class = ["Cure", "Cura", "Heal All", "Protect", "Shell"]
			"Paladin":
				spells_for_class = ["Cure", "Protect"]
			"Summoner":
				spells_for_class = ["Summon Ifrit", "Dispel", "Fire"]
			_:  # classes físicas
				spells_for_class = []

		for spell_name in spells_for_class:
			if spell_database.has(spell_name):
				var spell = create_spell(spell_name, spell_database[spell_name])
				player_node.spells.append(spell)
		
		player_node.spell_slots = class_spell_slots.get(classe_name, {})
		
		player_node.skills = []

		var skills_for_class := []
		
		match classe_name:
			"Knight":
				skills_for_class = ["Power Strike", "Focus"]
			"Thief":
				skills_for_class = ["Quick Shot"]
			"Monk":
				skills_for_class = ["Power Strike", "Heal Self"]
			"Hunter":
				skills_for_class = ["Quick Shot", "Focus"]
			_: # classes mágicas
				skills_for_class = []

		for skill_name in skills_for_class:
			if skill_database.has(skill_name):
				var skill = create_skill(skill_name, skill_database[skill_name])
				player_node.skills.append(skill)
		# Adiciona à party
		party[i] = player_node

		# Sprite
		var player_sprite = preload("res://decades/1990s/Battle/PlayerSprite.tscn").instantiate()
		player_sprite.set_sprite(class_sprite_paths.get(classe_name, ""))
		player_sprite.position = get_player_position(i)
		player_sprite.set_player(player_node)
		

		if classe_name == "Monk":
			player_sprite.scale = Vector2(0.8, 0.8)

		# Aqui: adiciona a referência do sprite ao player
		player_node.sprite_ref = player_sprite

		characters_node.add_child(player_sprite)

func spawn_loaded_party(loaded_party: Array) -> void:
	for i in range(loaded_party.size()):
		var player_node = loaded_party[i]

		# Sprite
		var player_sprite = preload("res://decades/1990s/Battle/PlayerSprite.tscn").instantiate()
		player_sprite.set_sprite(class_sprite_paths.get(player_node.classe_name, ""))
		player_sprite.position = get_player_position(i)
		player_sprite.set_player(player_node)

		if player_node.classe_name == "Monk":
			player_sprite.scale = Vector2(0.8, 0.8)

		player_node.sprite_ref = player_sprite

		# Adiciona ao array de party e à cena
		party[i] = player_node
		characters_node.add_child(player_sprite)
		
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

func generate_enemies() -> Array:
	var enemies_array = []
	var enemy_types = ["Goblin", "Little Orc"]
	var enemy_count = 1

	for i in range(enemy_count):
		var rand_type = enemy_types[randi() % enemy_types.size()]
		var base = enemy_base_stats.get(rand_type)

		if base:
			var enemy_node := Enemy1990.new()
			enemy_node.nome = rand_type
			enemy_node.STR = base["STR"]
			enemy_node.DEX = base["DEX"]
			enemy_node.AGI = base["AGI"]
			enemy_node.CON = base["CON"]
			enemy_node.MAG = base["MAG"]
			enemy_node.INT = base["INT"]
			enemy_node.SPI = base["SPI"]
			enemy_node.LCK = base["LCK"]
			enemy_node.xp_value = base["xp_value"]
			
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			# Gerar ID aleatório em string
			enemy_node.id = "%s_%06d" % [name.to_lower().replace(" ", "_"), rng.randi_range(0, 999999)]
			
			enemy_node.calculate_stats()

			enemies_array.append({"instance": enemy_node, "sprite_path": base["sprite_path"]})
	
	return enemies_array

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
	var hud_scene = preload("res://decades/1990s/Battle/CombatHUD1990.tscn")
	hud = hud_scene.instantiate()
	add_child(hud)

	# 🔧 Conecte o sinal aqui
	hud.action_selected.connect(_on_player_action_selected)

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
	# Armazena dados
	party = party_data.duplicate()
	enemies = generate_enemies()
	
	for member in party:
		sp_values[member] = 0.0
	# Spawn dos sprites na tela
	
	# Verifica o tipo dos dados: se é array de objetos (do save), ou nomes (novo jogo)
	if typeof(party_data[0]) == TYPE_OBJECT:
		party = party_data.duplicate()
		spawn_loaded_party(party)
	else:
		# Recebendo nomes de classes, gerar nova party
		party.resize(party_data.size())  # Garante espaço no array
		spawn_party(party_data)

	spawn_enemies(enemies)

	# Atualiza HUD com dados iniciais
	hud.update_party_info(party)
	hud.update_enemy_info(enemies)
	
	battle_active = true
	# Define ordem de turno
	turn_order = party + enemies
	
	current_turn_index = 0

	if not is_player(current_actor):
		current_actor = get_next_player_actor(current_turn_index)

	hud.show_top_message("Batalha Iniciada!")

	# Inicia o primeiro turno
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
			actor.atb_value += modified_speed * delta
			actor.atb_value = min(actor.atb_value, actor.atb_max)

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
	# Finaliza o turno atual, libera para próxima carga ATB
	is_executing_turn = false
	# Verifica estado da batalha e possivelmente começa próximo turno
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
		
	if current_actor is PlayerPartyMember and current_actor.is_defending:
		current_actor.is_defending = false
		
	is_executing_turn = true

	# Verifica se é jogador
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
	s.target_all = data.get("target_all", false)
	return s

func create_skill(name: String, data: Dictionary) -> Skill:
	var s = Skill.new()
	s.name = name
	s.cost_sp = data.get("cost_sp", 0)
	s.power = data.get("power", 0)
	s.scaling_stat = data.get("scaling_stat", "STR")
	s.hit_chance = data.get("hit_chance", 0.95)
	s.target_type = data.get("target_type", "enemy")
	s.effect_type = data.get("effect_type", "physical")
	s.status_inflicted = data.get("status_inflicted", "")
	s.status_chance = data.get("status_chance", 0.0)
	return s

func get_spell_by_name(spells: Array, name: String) -> Spell:
	for spell in spells:
		if spell.name == name:
			return spell
	return null

func _create_menu() -> void:
		hud._hide_all_panels()
		hud.hide_arrow()
		hud.show_action_menu()


# EXECUTA AÇÃO

func aplicar_dano(alvo, atacante, dano: int) -> void:
	alvo.current_hp -= dano
	if alvo.current_hp < 0:
		alvo.current_hp = 0

	var updated := false

	if is_player(alvo):
		if alvo.increase_special_charge(dano * 100):
			sp_values[alvo] = alvo.special_charge
			updated = true

	if is_player(atacante):
		if atacante.increase_special_charge(dano * 100):
			sp_values[atacante] = atacante.special_charge
			updated = true

	if updated:
		hud.update_special_bar(sp_values)

func _execute_skill(user, skill, alvo):
	var hit_roll = randf()
	if hit_roll > skill.hit_chance:
		hud.show_top_message("%s errou o uso de %s!" % [user.nome, skill.name])
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		reset_atb(user)
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		end_turn()
		return  # importante parar aqui

	if skill.effect_type == "damage":
		var base_dano = skill.power
		match skill.scaling_stat:
			"STR": base_dano += user.get_modified_stat(user.STR, "STR")
			"DEX": base_dano += user.get_modified_stat(user.DEX, "DEX")
			"INT": base_dano += user.get_modified_stat(user.INT, "INT")
			"SPI": base_dano += user.get_modified_stat(user.SPI, "SPI")
			_: base_dano += user.get_modified_stat(user.STR, "STR")

		var defesa_modificada = alvo.get_modified_stat(alvo.defense, "defense")
		var dano = base_dano - defesa_modificada
		dano = max(dano, 1)

		# Crítico opcional baseado em LCK
		var crit_chance = user.LCK * 0.01
		if randf() < crit_chance:
			dano *= 2
			hud.show_top_message("CRÍTICO! %s usou %s e causou %d de dano em %s!" % [user.nome, skill.name, dano, alvo.nome])
		else:
			hud.show_top_message("%s usou %s e causou %d de dano em %s!" % [user.nome, skill.name, dano, alvo.nome])

		aplicar_dano(alvo, user, dano)

		if alvo.current_hp <= 0:
			alvo.current_hp = 0
			if alvo.has_method("check_if_dead"):
				alvo.check_if_dead()
		hud.show_floating_number(dano, alvo, "damage")

	elif skill.effect_type == "heal":
		var cura = skill.power + user.SPI
		alvo.current_hp = min(alvo.max_hp, alvo.current_hp + cura)
		hud.show_top_message("%s usou %s e curou %d HP em %s!" % [user.nome, skill.name, cura, alvo.nome])
		hud.show_floating_number(cura, alvo, "hp")

	elif skill.effect_type == "buff":
		var effect = StatusEffect.new()
		effect.attribute = skill.scaling_stat
		effect.amount = skill.amount
		effect.duration = skill.duration if skill.duration > 0 else 3
		effect.type = StatusEffect.Type.BUFF
		alvo.apply_status_effect(effect)
		hud.show_top_message("%s aumentou %s de %s com %s!" % [user.nome, effect.attribute, alvo.nome, skill.name])

	if skill.status_inflicted != "":
		if randf() <= skill.status_chance:
			var status_effect = StatusEffect.new()
			status_effect.attribute = skill.status_inflicted
			status_effect.amount = 0  # para status como "stun", "poison", etc.
			status_effect.duration = skill.duration if skill.duration > 0 else 2
			status_effect.type = StatusEffect.Type.DEBUFF
			alvo.apply_status_effect(status_effect)
			hud.show_top_message("%s foi afetado por %s!" % [alvo.nome, skill.status_inflicted])

	reset_atb(user)
	hud.update_enemy_info(enemies)
	hud.update_party_info(party)
	_create_menu()
	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	end_turn()

func _execute_spell_area(caster, spell_name, alvos):
	var spell = get_spell_by_name(caster.spells, spell_name)
	if spell == null:
		hud.show_top_message("Magia não encontrada.")
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		end_turn()
		return

	var tipo = spell.type

	for alvo in alvos:
		if tipo == "damage":
			var base_dano = spell.power + caster.get_modified_stat(caster.INT, "INT")
			var defesa_magica = alvo.get_modified_derived_stat("magic_defense")
			var dano = base_dano - defesa_magica
			dano = max(dano, 1)
			aplicar_dano(alvo, caster, dano)
			if alvo.current_hp <= 0:
				alvo.current_hp = 0
				if alvo.has_method("check_if_dead"):
					alvo.check_if_dead()
			hud.show_top_message("%s atingido por %s: %d de dano!" % [alvo.nome, spell_name, dano])
			hud.show_floating_number(dano, alvo, "damage")

		elif tipo == "heal":
			var cura = spell.power + caster.get_modified_stat(caster.SPI, "SPI")
			alvo.current_hp = min(alvo.max_hp, alvo.current_hp + cura)
			hud.show_top_message("%s curado por %s: %d de HP!" % [alvo.nome, spell_name, cura])
			hud.show_floating_number(cura, alvo, "hp")

		elif tipo == "buff" or tipo == "debuff":
			var effect = StatusEffect.new()
			effect.attribute = spell.attribute
			effect.amount = spell.amount
			effect.duration = spell.duration
			effect.type = StatusEffect.Type.BUFF if tipo == "buff" else StatusEffect.Type.DEBUFF

			alvo.apply_status_effect(effect)

			var acao = "aumentado" if tipo == "buff" else "reduzido"
			hud.show_top_message("%s teve %s %s por %s!" % [alvo.nome, spell.attribute, acao, spell_name])
	
	reset_atb(caster)
	hud.update_enemy_info(enemies)
	hud.update_party_info(party)
	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	end_turn()

func _execute_spell_single(caster, spell_name, alvo):
	var spell = get_spell_by_name(caster.spells, spell_name)
	if spell == null:
		hud.show_top_message("Magia não encontrada.")
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		end_turn()
		return

	var tipo = spell.type
	var efeito = 0

	if tipo == "damage":
		var base_dano = spell.power + caster.get_modified_stat(caster.INT, "INT")
		var defesa_magica = alvo.get_modified_derived_stat("magic_defense")
		var dano = base_dano - defesa_magica
		dano = max(dano, 1)

		var crit_chance = caster.get_modified_stat(caster.LCK, "LCK") * 0.01
		if randf() < crit_chance:
			dano *= 2
			hud.show_top_message("CRÍTICO MÁGICO! %s usou %s e causou %d de dano em %s!" % [caster.nome, spell.name, dano, alvo.nome])
		else:
			hud.show_top_message("%s usou %s em %s causando %d de dano!" % [caster.nome, spell.name, alvo.nome, dano])

		aplicar_dano(alvo, caster, dano)
		
		if alvo.current_hp <= 0:
			alvo.current_hp = 0
			if alvo.has_method("check_if_dead"):
				alvo.check_if_dead()
				
		hud.show_floating_number(dano, alvo, "damage")

	elif tipo == "heal":
		var cura = spell.power + caster.get_modified_stat(caster.SPI, "SPI")
		alvo.current_hp = min(alvo.max_hp, alvo.current_hp + cura)
		hud.show_top_message("%s curou %s com %s em %d de HP!" % [caster.nome, alvo.nome, spell.name, cura])
		hud.show_floating_number(cura, alvo, "hp")

	elif tipo == "buff" or tipo == "debuff":
		var effect = StatusEffect.new()
		effect.attribute = spell.attribute
		effect.amount = spell.amount
		effect.duration = spell.duration
		effect.type = StatusEffect.Type.BUFF if spell.type == "buff" else StatusEffect.Type.DEBUFF
		alvo.apply_status_effect(effect)

		var acao = "aumentado" if spell.type == "buff" else "reduzido"
		hud.show_top_message("%s teve %s %s por %s!" % [alvo.nome, spell.attribute, acao, spell.name])
	
	reset_atb(caster)
	hud.update_enemy_info(enemies)
	hud.update_party_info(party)
	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	end_turn()

func perform_attack(attacker, target) -> void:
	# Obter stats modificados
	var attacker_accuracy = attacker.get_modified_stat(attacker.accuracy, "accuracy")
	var target_evasion = target.get_modified_stat(target.evasion, "evasion")
	var attacker_str = attacker.get_modified_stat(attacker.STR, "STR")
	var attacker_dex = attacker.get_modified_stat(attacker.DEX, "DEX")
	var target_def = target.get_modified_stat(target.defense, "defense")
	var attacker_lck = attacker.get_modified_stat(attacker.LCK, "LCK")

	# Calcular chance de acerto
	var hit_chance = attacker_accuracy / float(attacker_accuracy + target_evasion)
	var roll = randf()
	if roll > hit_chance:
		hud.show_top_message("%s errou o ataque!" % attacker.nome)
		reset_atb(attacker)
		hud.update_party_info(party)
		return

	# Calcular chance de crítico
	var crit_chance = attacker_lck * 0.01
	var is_crit = randf() < crit_chance

	# Calcular dano base
	var damage = attacker_str + int(attacker_dex / 2) - target_def
	damage = max(damage, 1)

	if is_crit:
		damage *= 2
		hud.show_top_message("CRÍTICO! %s causou %d de dano!" % [attacker.nome, damage])
	else:
		hud.show_top_message("%s causou %d de dano!" % [attacker.nome, damage])

	# Aplicar dano
	aplicar_dano(target, attacker, damage)
	hud.show_floating_number(damage, target, "damage")

	# Verifica se morreu
	if target.current_hp <= 0:
		target.current_hp = 0
		if target.has_method("check_if_dead"):
			target.check_if_dead()
		hud.show_top_message("%s foi derrotado!" % target.nome)

	# Reset ATB
	reset_atb(attacker)
	hud.update_enemy_info(enemies)
	hud.update_party_info(party)

func _execute_special_area(caster, especial_data, alvos):
	for alvo in alvos:
		if especial_data.type == "damage":
			var dano = especial_data.power + caster.STR
			dano -= alvo.defense
			dano = max(dano, 1)
			aplicar_dano(alvo,caster,dano)
			hud.show_floating_number(dano, alvo, "damage")

		elif especial_data.type == "heal":
			var cura = especial_data.power + caster.SPI
			alvo.current_hp = min(alvo.max_hp, alvo.current_hp + cura)
			hud.show_floating_number(cura, alvo, "hp")
	
	reset_atb(caster)
	hud.update_enemy_info(enemies)
	hud.update_party_info(party)
	_create_menu()
	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	end_turn()

func _execute_special_single(caster, especial_data: Dictionary, alvo):
	if especial_data.type == "damage":
		var dano = especial_data.power + caster.STR
		dano -= alvo.defense # Enemy1990 e PlayerPartyMember1990 possuem 'defense'
		dano = max(dano, 1)
		aplicar_dano(alvo,caster,dano)
		hud.show_floating_number(dano, alvo, "damage")

	elif especial_data.type == "heal":
		var cura = especial_data.power + caster.SPI
		alvo.heal(cura)
		hud.show_floating_number(cura, alvo, "hp")

	elif especial_data.type == "buff":
		var effect = StatusEffect.new()
		effect.attribute = especial_data.attribute
		effect.amount = especial_data.amount
		effect.duration = especial_data.duration
		effect.type = StatusEffect.Type.BUFF
		alvo.apply_status_effect(effect)
		hud.show_top_message("Buff: +%s %s para o %s" % [especial_data.amount, especial_data.attribute, alvo.nome])

	elif especial_data.type == "debuff":
		var effect = StatusEffect.new()
		effect.attribute = especial_data.attribute
		effect.amount = especial_data.amount
		effect.duration = especial_data.duration
		effect.type = StatusEffect.Type.DEBUFF
		alvo.apply_status_effect(effect)
		hud.show_top_message("Debuff: -%s %s para o $s" % [especial_data.amount, especial_data.attribute, alvo.nome])

	# Atualiza HUD e esper
	reset_atb(caster)
	hud.update_party_info(party)
	hud.update_enemy_info(enemies)
	_create_menu()
	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	end_turn()

func usar_item_em_alvo(usuario, item_name: String, item_data: Dictionary, target_id) -> void:
	# Encontrar o personagem da party com o ID correspondente
	var alvo = null
	for membro in party:
		if membro.id == target_id:
			alvo = membro
			break
	
	if alvo == null:
		print("Erro: alvo com ID %s não encontrado na party!" % target_id)
		return
		
	match item_data.type:
		"heal":
			alvo.current_hp += item_data.power
			alvo.current_hp = min(alvo.current_hp, alvo.max_hp)
			hud.show_floating_number(item_data.power, alvo, "hp")
			hud.show_top_message("%s usou %s em %s!" % [usuario.nome, item_name, alvo.nome])

		"restore_mp":
			alvo.current_mp += item_data.power
			alvo.current_mp = min(alvo.current_mp, alvo.max_mp)
			hud.show_floating_number(item_data.power, alvo, "mp")
			hud.show_top_message("%s recuperou MP com %s!" % [alvo.nome, item_name])
			
		"restore_sp":
			alvo.current_sp += item_data.power
			alvo.current_sp = min(alvo.current_mp, alvo.max_sp)
			hud.show_floating_number(item_data.power, alvo, "sp")
			hud.show_top_message("%s recuperou MP com %s!" % [alvo.nome, item_name])

		"full_restore":
			alvo.current_hp = alvo.max_hp
			alvo.current_mp = alvo.max_mp
			alvo.current_sp = alvo.max_sp
			hud.show_floating_number(alvo.max_hp, alvo, "hp")
			await get_tree().create_timer(1.0).timeout
			hud.show_floating_number(alvo.max_mp, alvo, "mp")
			await get_tree().create_timer(1.0).timeout
			hud.show_floating_number(alvo.max_sp, alvo, "sp")
			hud.show_top_message("%s foi totalmente restaurado com %s!" % [alvo.nome, item_name])

		"cure_status":
			alvo.remove_status(item_data.status)
			hud.show_top_message("%s foi curado de %s!" % [alvo.nome, item_data.status])

	# Remover item do inventário
	if inventory.has(item_name):
		inventory[item_name] -= 1
		if inventory[item_name] <= 0:
			inventory.erase(item_name)

	# Encerrar turno
	reset_atb(usuario)
	hud.update_party_info(party)
	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	hud.hide_arrow()
	end_turn()

func tentar_fugir(actor) -> void:
	var vivos = party.filter(func(p): return p.is_alive()).size()
	if vivos == 0:
		hud.show_top_message("Ninguém pode fugir!")
		return

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var agi_total = 0
	var lck_total = 0
	for membro in party:
		if membro.is_alive():
			agi_total += membro.AGI
			lck_total += membro.LCK

	var media_agi = agi_total / vivos
	var media_lck = lck_total / vivos

	# Fórmula da chance de fuga
	var chance_fuga = clamp((media_agi * 2 + media_lck) / 3 + rng.randi_range(0, 20), 0, 100)

	var roll = rng.randi_range(0, 100)

	if roll < chance_fuga:
		hud.show_top_message("%s escapou com sucesso!" % actor.nome)
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		reset_atb(actor)
		end_battle(false)  # Finaliza a batalha sem vitória
	else:
		hud.show_top_message("%s tentou fugir, mas falhou!" % actor.nome)
		await get_tree().create_timer(0.2).timeout
	# 🔧 Oculta seta de seleção
		hud.hide_arrow()
		reset_atb(actor)
		hud.set_hud_buttons_enabled(false)
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		end_turn()


# SELECIONA AÇÃO

func _on_player_action_selected(action_name: String) -> void:
	match action_name:
		"Atacar":
			var alvos_validos = enemies.filter(func(e): return e.is_alive())
			var targets = []
			for enemy in enemies:
				if enemy.is_alive():
					targets.append({
						"id": enemy.id,
						"nome": enemy.nome,
						"node_ref": enemy
					})
			hud.target_selected.connect(_on_alvo_ataque_selecionado)
			hud.show_target_menu(targets)

		"Magia", "Skills":
			if current_actor.is_magic_user():
				var magias = current_actor.get_available_spells()
				var mp = current_actor.current_mp
				var slots = current_actor.spell_slots
				if magias.is_empty():
					hud.show_top_message("%s não possui magias disponíveis." % current_actor.nome)
					await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
					next_turn()
					return
				hud.magic_selected.connect(_on_magic_selected)
				hud.show_magic_menu(magias, mp, slots)
			else:
				var skills = current_actor.skills
				if skills.is_empty():
					hud.show_top_message("%s não possui técnicas disponíveis." % current_actor.nome)
					await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
					next_turn()
					return
				hud.skill_selected.connect(_on_skill_selected)
				hud.show_skill_menu(skills, current_actor.current_sp)
		"Item":
			var items = inventory
			if items.is_empty():
				hud.show_top_message("%s não possui itens." % current_actor.nome)
				await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
				next_turn()
				return
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
			await tentar_fugir(current_actor)
			# Lógica de fuga
		"Especial":
			var especiais = current_actor.get_specials()

			if especiais.is_empty():
				await hud.show_top_message("%s não possui habilidades especiais disponíveis." % current_actor.nome)

			hud.special_selected.connect(_on_special_selected)
			hud.show_special_menu(especiais)

func _on_alvo_ataque_selecionado(alvo_id):
	if hud.target_selected.is_connected(_on_alvo_ataque_selecionado):
		hud.target_selected.disconnect(_on_alvo_ataque_selecionado)

	var jogador_atual = current_actor
	var target_enemy = find_enemy_by_id(alvo_id)
	if target_enemy:
		await perform_attack(jogador_atual, target_enemy)
	else:
		print("Alvo não encontrado:", alvo_id)

	# 🔧 Oculta seta de seleção
	hud.hide_arrow()
	
	# 🔧 Atualiza barras de ATB visualmente
	hud.update_atb_bars(atb_values)

	# 🔧 Desabilita HUD
	hud.set_hud_buttons_enabled(false)

	# 🔧 Espera e finaliza turno
	await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	end_turn()

func _on_skill_selected(skill_name: String):
	hud.skill_selected.disconnect(_on_skill_selected)

	var user = current_actor
	var skill_matches = user.skills.filter(func(s): return s.name == skill_name)

	if skill_matches.is_empty():
		return

	var skill = skill_matches[0]

	var alvos = []
	match skill.target_type:
		"enemy":
			alvos = enemies.filter(func(e): return e.current_hp > 0)
		"self":
			alvos = [user]
		"ally":
			alvos = party.filter(func(p): return p.current_hp > 0)
		_:
			alvos = enemies

	if skill.target_type == "self":
		await _execute_skill(user, skill, alvos[0])
	else:
		hud.target_selected.connect(func(id):
			var alvo = find_enemy_by_id(id)
			await _execute_skill(user, skill, alvo)
		)
		var formatted_targets = []
		for target in alvos:
			formatted_targets.append({"id": target.id, "nome": target.nome, "node_ref": target})
		hud.show_target_menu(formatted_targets)

func _on_magic_selected(spell_name: String):
	hud.magic_selected.disconnect(_on_magic_selected)

	var caster = current_actor
	
	# Buscar spell no array pelo nome
	var spell_data = null
	for spell in caster.spells:
		if spell.name.to_lower() == spell_name.to_lower():
			spell_data = spell
			break

	if not spell_data:
		hud.show_top_message("Magia não encontrada.")
		await get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		next_turn()
		return

	var tipo = spell_data.type
	var alvos := []

	match tipo:
		"heal", "buff":
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

	var is_area = spell_data.target_all

	if is_area:
		_create_menu()
		await _execute_spell_area(caster, spell_name, alvos)
		
	else:
		hud.target_selected.connect(_on_magic_target_selected)
		var formatted_targets = []
		for target in alvos:
			formatted_targets.append({
				"id": target.id,
				"nome": target.nome,
				"node_ref": target
			})
		
		hud.show_target_menu(formatted_targets)
		hud.set_meta("spell_name", spell_name)

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
		await _execute_spell_single(caster, spell_name, target)
	else:
		print("Alvo não encontrado:", alvo)

func _on_item_selected(item_name: String) -> void:
	var item_data = item_database.get(item_name, null)
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

	# Seleção de alvo
	hud.target_selected.connect(func(target):
		usar_item_em_alvo(current_actor, item_name, item_data, target)
	)
	hud.show_target_menu(target_list)

func _on_special_selected(special_name):
	hud.hide_special_menu()

	var especial = current_actor.get_specials()[special_name]

	match especial["target"]:
		"all_enemies":
			_execute_special_area(current_actor, especial, enemies)

		"ally_party":
			_execute_special_area(current_actor, especial, party)

		"self":
			_execute_special_single(current_actor, especial, current_actor)

		"enemy":
			var alvos = []
			for enemy in enemies:
				if enemy.is_alive():
					alvos.append({
						"id": enemy.id,
						"nome": enemy.nome,
						"node_ref": enemy
					})
			hud.target_selected.connect(_on_special_target_selected.bind(especial))
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
			hud.target_selected.connect(_on_special_target_selected.bind(especial))
			hud.show_target_menu(alvos)

		_:
			hud.show_top_message("Tipo de alvo inválido")
			return
	
func _on_special_target_selected(target_id, especial):

	var alvo = null

	for enemy in enemies:
		if enemy.id == target_id:
			alvo = enemy
			break
	for ally in party:
		if ally.id == target_id:
			alvo = ally
			break

	if alvo == null:
		hud.show_top_message("Alvo inválido.")
		await get_tree().create_timer(1.0).timeout
		next_turn()
		return

	await _execute_special_single(current_actor, especial, alvo)
