class_name EncounterGenerator1990
extends Node


# --- FUNÇÕES MOVIDAS DO BATTLEMANAGER ---

func generate_enemies(party: Array) -> Array:
	var enemies_array = []
	var party_level = party[0].level if party.size() > 0 else 1

	var enemy_pool = []
	var enemy_count = 6

	match party_level:
		1:
			enemy_pool = ["Passaro", "Zumbi"]
			enemy_count = 6
		2:
			enemy_pool = ["Passaro", "Zumbi", "Lobo"]
			enemy_count = 6
		3:
			enemy_pool = ["Passaro", "Zumbi", "Lobo", "Necromante"]
			enemy_count = 6
		4:
			enemy_pool = ["Lobisomen", "Aguia"]
			enemy_count = 6
		5:
			enemy_pool = []
			enemy_count = 5
			for i in range(2):
				enemy_pool.append("Oni")
			var pool = ["Lobisomen", "Passaro"]
			for i in range(3):
				enemy_pool.append(pool[randi() % pool.size()])
		6:
			enemy_pool = ["Dragao", "Oni", "Oni"]
			enemy_count = 3
		_:
			enemy_pool = ["Zumbi"]
			enemy_count = 3

	for i in range(enemy_count):
		var rand_type = enemy_pool[i % enemy_pool.size()]
		# Chama a função _create_enemy_by_type (aqui embaixo)
		var enemy_data = _create_enemy_by_type(rand_type, i) 
		enemies_array.append(enemy_data)

	return enemies_array

# Esta função agora mora aqui e é chamada pelo generate_enemies
func _create_enemy_by_type(nome: String, index: int) -> Dictionary:
	# Agora ele lê do Database1990
	var base = Database1990.enemy_base_stats.get(nome) 

	if base:
		var enemy_node := Enemy1990.new()
		var position_indicator = ""
		
		# Lógica de Posição (Corrigida)
		if index < 3:
			enemy_node.position_line = "back" # Posições 0,1,2 são ATRÁS (X=250)
			position_indicator = " [B]"
		else:
			enemy_node.position_line = "front" # Posições 3,4,5 são FRENTE (X=530)
			position_indicator = " [F]"

		enemy_node.nome = "%s%s" % [nome, position_indicator]
		enemy_node.STR = base["STR"]
		enemy_node.DEX = base["DEX"]
		enemy_node.AGI = base["AGI"]
		enemy_node.CON = base["CON"]
		enemy_node.MAG = base["MAG"]
		enemy_node.INT = base["INT"]
		enemy_node.SPI = base["SPI"]
		enemy_node.LCK = base["LCK"]
		enemy_node.xp_value = base["xp_value"]
		enemy_node.attack_type = base["attack_type"]
		enemy_node.enemy_type = base["enemy_type"]

		if enemy_node.enemy_type == "Flying":
			enemy_node.alcance_estendido = true

		var rng = RandomNumberGenerator.new()
		rng.randomize()
		enemy_node.id = "%s_%06d" % [nome.to_lower(), rng.randi_range(0, 999999)]

		enemy_node.calculate_stats()
		enemy_node.set_type_resistances()
		
		enemy_node.ai_behavior = "simple_attack"

		return {
			"instance": enemy_node,
			"sprite_path": base["sprite_path"]
		}
	
	return {} # Retorna vazio se o inimigo não for encontrado
