extends CombatCharacter
class_name EnemyAI

# Define o papel do inimigo no grupo
@export_enum("Tank", "Healer", "DPS") var role: String = "DPS"

# Referências
var player: CombatCharacter = null
var battle_manager = null
var squad_mates: Array = []

# Configurações de IA
var decision_timer: float = 0.0
var decision_interval: float = 0.5 # Pensa a cada 0.5s
var ai_attack_cooldown: float = 0.0
var ai_attack_range: float = 2.0
var role_attack_interval: float = 2.0 # Tempo base entre ataques

func _ready():
	super._ready()
	manual_control = false

	# 1. Encontra o BattleManager e o Player
	battle_manager = get_tree().get_root().get_node_or_null("Game2010/BattleManager2010")
	if battle_manager:
		player = battle_manager.player_character
		squad_mates = battle_manager.enemies # Pega referência dos amigos
	else:
		# Fallback se não achar o manager
		player = get_tree().get_first_node_in_group("player")

	# 2. Configura Stats baseado no Role (Opcional, se quiser forçar stats aqui)
	call_deferred("_setup_role_stats")
	
	call_deferred("_apply_debug_visuals")

func _setup_role_stats():
	match role:
		"Tank":
			max_hp = 250
			attack_power = 15
			defense_rating = 40.0 
			ai_attack_range = 2.5
			attack_range = 2.5
			role_attack_interval = 2.5
			
		"Healer":
			max_hp = 80
			attack_power = 10
			defense_rating = 5.0 # Papel
			ai_attack_range = 10.0
			attack_range = 10.0
			role_attack_interval = 4.0
			
		"DPS":
			max_hp = 100
			attack_power = 15 
			defense_rating = 10.0
			ai_attack_range = 8.0
			attack_range = 5.0
			role_attack_interval = 4.0


func _physics_process(delta: float) -> void:
	# Processa física básica do CombatCharacter
	super._physics_process(delta)

	if state == State.DEAD or state == State.STAGGERED:
		return

	if battle_manager:
		squad_mates = battle_manager.enemies
		if is_instance_valid(battle_manager.player_character):
			player = battle_manager.player_character
		else:
			player = null

	if not player or not player.is_alive():
		_stop_moving()
		return

	# Cooldown de ataque
	if ai_attack_cooldown > 0: 
		ai_attack_cooldown -= delta

	# Timer de decisão (Cérebro)
	decision_timer -= delta
	if decision_timer <= 0:
		_ai_logic()
		decision_timer = decision_interval

# --- LÓGICA CENTRAL (O CÉREBRO) ---
func _ai_logic():
	match role:
		"Tank": _logic_tank()
		"Healer": _logic_healer()
		"DPS": _logic_dps()

# 1. TANK: Protege o Healer
func _logic_tank():
	# Procura se o Healer foi atacado recentemente
	var healer = _find_squad_member("Healer")
	
	if healer and healer.last_attacker == player:
		# Player bateu no Healer -> Tank Fica Bravo
		var dist = global_position.distance_to(player.global_position)
		if dist < 3.5:
			print("🛡️ TANK: Ei! Deixa o Healer em paz!")
			_face_target(player.global_position)
			_try_attack(true) # Ataque Pesado (Simula Stun/Taunt)
		else:
			_move_to(player.global_position) # Corre para proteger
	else:
		# Comportamento Padrão
		_standard_combat_behavior(player)

# 2. HEALER: Cura quem precisa
func _logic_healer():
	# Procura aliado com vida < 60%
	var low_hp_ally = _find_low_hp_ally(0.6)
	
	if low_hp_ally:
		var dist = global_position.distance_to(low_hp_ally.global_position)
		
		# Precisa chegar perto para curar (ex: 4 metros)
		if dist < 4.0:
			print("🚑 HEALER: Curando %s!" % low_hp_ally.name)
			_stop_moving()
			_face_target(low_hp_ally.global_position)
			
			# Usa animação de ataque para fingir que é cast de cura
			if ai_attack_cooldown <= 0:
				perform_attack(false) # Ataque leve (animação rápida)
				# APLICA A CURA REAL:
				low_hp_ally.apply_heal(30, name)
				ai_attack_cooldown = 3.0 # Cooldown da cura
		else:
			_move_to(low_hp_ally.global_position)
	else:
		# Ninguém para curar -> Fica longe do player
		var dist_player = global_position.distance_to(player.global_position)
		if dist_player < 8.0:
			# Foge um pouco
			var dir = (global_position - player.global_position).normalized()
			_move_to(global_position + dir * 2.0)
		else:
			_stop_moving()
			_face_target(player.global_position)

# 3. LÓGICA DO DPS (Arqueiro/Atirador)
func _logic_dps():
	if not player: return
	
	var dist = global_position.distance_to(player.global_position)
	
	# --- LÓGICA DE "KITING" (Manter Distância) ---ds
	
	if dist < 4.0:
		# 1. Muito perto! FUGIR!
		# Calcula vetor oposto ao jogador
		var dir_away = (global_position - player.global_position).normalized()
		# Tenta correr para um ponto 3 metros atrás
		_move_to(global_position + dir_away * 3.0)
		
	elif dist > ai_attack_range:
		# 2. Muito longe! PERSEGUIR!
		# Usa a lógica padrão para chegar no alcance
		_move_to(player.global_position)
		
	else:
		# 3. Distância Perfeita (Entre 4.0 e 8.0)! ATACAR!
		_stop_moving()
		_face_target(player.global_position)
		
		# Usa ataque leve (tiro rápido)
		_try_attack(false)

# --- COMPORTAMENTOS PADRÃO ---
func _standard_combat_behavior(target):
	if not target: return
	var dist = global_position.distance_to(target.global_position)
	
	if dist > ai_attack_range:
		_move_to(target.global_position)
	else:
		_stop_moving()
		_face_target(target.global_position)
		_try_attack(false) # Tenta ataque normal

func _move_to(pos: Vector3):
	if nav_agent:
		nav_agent.set_target_position(pos)


func _stop_moving():
	if nav_agent:
		nav_agent.set_target_position(global_position)
	velocity = Vector3.ZERO

func _face_target(pos: Vector3):
	var dir = pos - global_position
	dir.y = 0
	if dir.length() > 0.1:
		var target_yaw = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 0.2)

func _try_attack(is_heavy: bool):
	# Verifica Stamina E Cooldown
	if stamina >= light_attack_cost and ai_attack_cooldown <= 0:
		
		# 1. Toca a animação (Melee ou Tiro)
		perform_attack(is_heavy)
		
		# 2. Reseta o Cooldown
		ai_attack_cooldown = role_attack_interval + randf() 
		
		# 3. Lógica de Dano à Distância (DPS/Healer)
		if ai_attack_range > 3.0 and player:
			var dist = global_position.distance_to(player.global_position)
			
			if dist <= ai_attack_range + 1.0: # +1 de margem
				# Aguarda o tempo da animação do tiro 
				await get_tree().create_timer(0.5).timeout
				
				# Verifica novamente se player está vivo antes de aplicar dano
				if player and player.is_alive():
					print("🏹 [SQUAD] Tiro certeiro em %s!" % player.name)
					
					var dmg = attack_power * (1.6 if is_heavy else 1.0)
					
					# Nota: Aqui você está chamando receive_hit direto. 
					# O ideal futuramente seria lançar um Projectile, mas para simulação funciona.
					player.receive_hit(int(dmg), self, player.global_position, Vector3.UP)

# --- FUNÇÕES DE BUSCA ---
func _find_squad_member(target_role: String):
	for mate in squad_mates:
		# Checa se é vivo, se é EnemyAI e se é o role certo
		if is_instance_valid(mate) and mate.is_alive() and mate is EnemyAI and mate.role == target_role:
			return mate
	return null

func _find_low_hp_ally(threshold: float):
	for mate in squad_mates:
		if is_instance_valid(mate) and mate.is_alive():
			if float(mate.hp) / float(mate.max_hp) < threshold:
				return mate
	return null

func _apply_debug_visuals():
	# 1. Texto flutuante (Nome do Role)
	var label = Label3D.new()
	label.text = role.to_upper()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.position = Vector3(0, 2.5, 0) # Ajuste a altura se ficar dentro da cabeça
	label.modulate = Color.YELLOW
	add_child(label)

	# 2. Definição de Cor
	var color = Color.WHITE
	match role:
		"Tank": 
			color = Color(0.2, 0.2, 0.8) # Azul Escuro (Proteção)
		"Healer": 
			color = Color(0.2, 0.8, 0.2) # Verde (Cura)
		"DPS": 
			color = Color(0.8, 0.2, 0.2) # Vermelho (Dano)
	
	# 3. Pintar o Modelo
	var mesh_instance = _find_mesh_recursive(self)
	if mesh_instance:
		# Cria um material novo via código
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mesh_instance.material_override = mat

# Função auxiliar para achar a malha 3D dentro dos filhos
func _find_mesh_recursive(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_recursive(child)
		if found: return found
	return null
	#
