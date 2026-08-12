class_name EnemyUnit2000
extends CombatCharacter2000

# Role padrão (será sobrescrito pelo BattleManager)
@export_enum("Knight", "Barbarian", "Rogue", "Archer", "Mage") var enemy_role: String = "Knight"

# Variáveis de Memória (Para não spammar a IA)
var memo_target: Node3D = null
var memo_skill: String = ""

func _ready():
	super._ready() # Garante que o setup do CombatCharacter2000 rode

# Função chamada pelo BattleManager logo após spawnar
func setup_enemy(role_to_set: String):
	enemy_role = role_to_set

	# BUG: até aqui só max_hp/attack_range/move_speed eram definidos por papel.
	# attack_power, defense, dodge_chance, block_chance, crit_chance e
	# resistências nunca eram recalculados pra inimigos (_recalculate_stats()
	# só era chamado pelas classes da party), então TODO inimigo defendia
	# exatamente igual (mesma esquiva, mesmo bloqueio, mesma defesa),
	# independente de ser um Mago ou um Cavaleiro.
	#
	# Agora usamos o mesmo sistema de atributos (Força/Destreza/Constituição/
	# Inteligência/Sabedoria) que Barbarian3D/Mage3D/Rogue3D/Knight3D já usam,
	# com um "arquétipo" de atributos por papel, e deixamos _recalculate_stats()
	# derivar tudo — assim o Cavaleiro realmente tanka mais e o Ladino
	# realmente esquiva mais, e não é só o HP/alcance que muda.
	match enemy_role:
		"Archer":
			strength = 8
			dexterity = 17
			constitution = 8
			intelligence = 6
			wisdom = 11
		"Mage":
			strength = 6
			dexterity = 9
			constitution = 7
			intelligence = 18
			wisdom = 14
		"Knight":
			strength = 12
			dexterity = 8
			constitution = 16
			intelligence = 6
			wisdom = 8
			has_shield = true # Cavaleiro carrega escudo -> mais chance de bloqueio
		"Barbarian":
			strength = 18
			dexterity = 10
			constitution = 13
			intelligence = 5
			wisdom = 6
		"Rogue":
			strength = 10
			dexterity = 18
			constitution = 8
			intelligence = 8
			wisdom = 8

	_recalculate_stats()

	# _recalculate_stats() também deriva move_speed e max_hp a partir dos
	# atributos — mas o alcance/velocidade/HP por papel aqui já eram
	# calibrados à mão (curva de dificuldade testada), então reaplicamos esses
	# valores DEPOIS de recalcular, só para não perder essa calibração
	# existente enquanto ainda ganhamos defense/dodge_chance/block_chance/
	# crit_chance diferenciados por papel (que é o que realmente faltava).
	match enemy_role:
		"Archer":
			max_hp = 80
			attack_range = 10.0
			move_speed = 4.0
			gold_value = 12
		"Mage":
			max_hp = 70
			attack_range = 12.0
			move_speed = 3.5
			gold_value = 15
		"Knight":
			max_hp = 150
			attack_range = 2.2 # Um pouco maior que 2.0 para evitar travar na colisão
			move_speed = 3.0
			gold_value = 18
		"Barbarian":
			max_hp = 120
			attack_range = 2.5 # Alcance maior (Machado/Espada Grande)
			move_speed = 4.5
			gold_value = 15
		"Rogue":
			max_hp = 90
			attack_range = 2.2
			move_speed = 5.0
			gold_value = 12

	hp = max_hp
	# Garante nome único
	name = enemy_role + "_" + str(get_instance_id())
	
	if health_bar: 
		health_bar.set_health(hp, max_hp)
		
	# Aplica visuais para identificar quem é quem
	_apply_debug_visuals(role_to_set)

# Lógica de IA chamada a cada frame (ou delta) pelo BattleManager
func update_ai_attack(delta: float) -> void:
	# 1. Trava de Segurança: Se já estou agindo, não penso/movo
	if is_performing_action:
		return

	var battle_manager = get_tree().get_root().get_node("Game2000/BattleManager")
	
	# 2. Decisão (Cérebro)
	# Só pergunta para a IA se não tiver um plano ou se o alvo morreu
	if memo_target == null or not is_instance_valid(memo_target) or not memo_target.is_alive():
		var decision = EnemyAi2000.get_target_and_action(self, battle_manager)
		
		memo_target = decision["target"]
		memo_skill = decision["skill"]
		
		# Se mesmo assim não achou ninguém (todos mortos ou longe), desiste por agora
		if memo_target == null:
			_stop_moving()
			return

	# 3. Execução (Corpo)
	var dist = global_position.distance_to(memo_target.global_position)
	
	if dist > attack_range:
		# Longe demais -> Mover
		var move_pos = memo_target.global_position
		
		# Se for melee e estiver relativamente perto, tenta usar os slots laterais
		# para não encavalar com amigos
		if attack_range < 4.0 and dist < 10.0: 
			move_pos = get_slot_position_around_target(self, memo_target, battle_manager.enemies, attack_range)
		
		_move_towards(move_pos)
	else:
		# No alcance -> Parar, Girar e Atacar
		_stop_moving()
		_face_target(memo_target)
		
		if is_turn_ready:
			await _perform_skill(memo_skill, memo_target)
			
			# IMPORTANTE: Limpa a memória após atacar para reavaliar a situação
			memo_target = null 
			memo_skill = ""
			
			turn_charge = 0 
			is_turn_ready = false

# Executa a animação e aplica o efeito
func _perform_skill(skill_name, target):
	is_performing_action = true
	
	print(">> %s (%s) usando %s em %s" % [name, enemy_role, skill_name, target.name])
	
	# Animação genérica baseada na distância
	if attack_range > 3.0:
		if anim and anim.has_animation("1H_Ranged_Shoot"): 
			anim.play("1H_Ranged_Shoot")
	else:
		if anim and anim.has_animation("1H_Melee_Attack_Slice_Diagonal"): 
			anim.play("1H_Melee_Attack_Slice_Diagonal")
	
	# Delay para sincronizar o dano com a animação
	await get_tree().create_timer(0.8).timeout
	
	# Aplica efeitos reais (Dano + Status)
	match skill_name:
		"shield_bash": # Knight
			target.apply_damage(10, self)
			target.apply_status("armor_break", 10.0, self)
			
		"poison_stab": # Rogue
			target.apply_damage(8, self)
			target.apply_status("poison", 12.0, self)
			
		"brutal_strike": # Barbarian
			var dmg = 20
			if target.has_status("armor_break"): 
				dmg = 40 # Dano Dobrado!
				print("🔥 COMBO! Brutal Strike explorou Armor Break!")
			target.apply_damage(dmg, self)
			target.apply_status("bleed", 8.0, self)
			
		"necrotic_shot": # Archer
			var dmg = 15
			if target.has_status("poison"): 
				dmg = 35 # Dano Alto!
				print("☠️ COMBO! Necrotic Shot reagiu com Poison!")
			target.apply_damage(dmg, self)
			
		"poison_arrow": # Archer (Skill secundária)
			target.apply_damage(12, self)
			target.apply_status("poison", 8.0, self)

		"fireball": # Mage
			target.apply_damage(25, self)
			# (Futuramente pode adicionar status 'burning')
			var battle_manager = get_tree().get_root().get_node("Game2000/BattleManager")
			var explosion_radius = 6.0 # Tem que bater com o raio da IA
			for p in battle_manager.party_members:
				# Se está vivo E não é o alvo principal (já tomou dano)
				if p.is_alive() and p != target:
					var dist = target.global_position.distance_to(p.global_position)
					
					if dist <= explosion_radius:
						print("🔥 Dano colateral em %s!" % p.name)
						p.apply_damage(20, self) # Dano um pouco menor na área
			
		_: # O "Ataque Básico" (Ignis ou Melee)
			
			if enemy_role == "Mage":
				# --- IGNIS (Ataque Básico do Mago) ---
				print("✨ %s conjura Ignis em %s!" % [name, target.name])
				
				# Garante animação de magia, não de soco
				if anim and anim.has_animation("1H_Ranged_Shoot"): 
					anim.play("1H_Ranged_Shoot")
				
				# Dano mágico moderado (single target)
				target.apply_damage(15, self) 
				
			elif enemy_role == "Archer":
				# --- TIRO BÁSICO (Ataque Básico do Arqueiro) ---
				print("🏹 %s dispara flecha comum em %s!" % [name, target.name])
				if anim: anim.play("1H_Ranged_Shoot")
				target.apply_damage(12, self)
				
			else:
				# --- ATAQUE FÍSICO PADRÃO (Knight, Barbarian, Rogue) ---
				print("⚔️ %s ataca %s fisicamente!" % [name, target.name])
				if anim: anim.play("1H_Melee_Attack_Slice_Diagonal")
				target.apply_damage(10, self)

	is_performing_action = false

# --- DEBUG VISUAL (Sem mudar modelo 3D) ---
func _apply_debug_visuals(role: String):
	# 1. Cria um texto flutuante
	var label = Label3D.new()
	label.text = role.to_upper()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.position = Vector3(0, 2.5, 0)
	label.modulate = Color.YELLOW
	add_child(label)

	# 2. Define cor por papel
	var color = Color.WHITE
	match role:
		"Knight": color = Color.BLUE
		"Barbarian": color = Color.RED
		"Archer": color = Color.GREEN
		"Mage": color = Color.PURPLE
		"Rogue": color = Color.ORANGE
	
	# 3. Pinta o modelo
	var mesh_instance = _find_mesh_recursive(self)
	if mesh_instance:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mesh_instance.material_override = mat

func _find_mesh_recursive(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_recursive(child)
		if found: return found
	return null
