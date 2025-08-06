extends CharacterBody3D
class_name CombatCharacter

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var vision_cone: MeshInstance3D = $VisionCone
var model: Node3D = null
var anim: AnimationPlayer = null
var health_bar_scene := preload("res://decades/2000s/UI/HealthBar.tscn")
var health_bar: Control = null
var progress_bar: ProgressBar = null
var vision_cone_material: StandardMaterial3D = null
# Atributos
var move_speed := 4.0
var hp := 100
var max_hp := 100
var camera: Camera3D = null

# Controle
var is_moving := false
var manual_control := false
var target_position := Vector3.ZERO
var is_performing_action := false

var turn_charge := 0.0
var turn_threshold := 100.0
var charge_speed := 20.0
var is_turn_ready := false

func _ready():
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if vision_cone:
		# Fixar rotação local para frente do personagem
		vision_cone.rotation_degrees = Vector3(90, 0, 0)  # apenas X

		# Escala e posição relativa
		vision_cone.scale = Vector3(0.3, 0.5, 0.3)
		vision_cone.position = Vector3(0, 3.0, 0)  # na frente e acima

		# Copiar material
		var original_material = vision_cone.get_active_material(0)
		if original_material:
			vision_cone_material = original_material.duplicate()
			vision_cone.set_surface_override_material(0, vision_cone_material)

	
	# Localizar modelo/anim
	for child in get_children():
		if child.has_node("AnimationPlayer"):
			model = child
			anim = model.get_node("AnimationPlayer")
			break

	if anim:
		anim.process_mode = Node.PROCESS_MODE_ALWAYS
		anim.play("Idle")
	else:
		push_error("AnimationPlayer não encontrado no personagem: " + str(self))

	# Instanciar barra de vidaawwa
	health_bar = health_bar_scene.instantiate()

	# Corrigir local de adição — buscar CanvasLayer "UI" no topo
	var ui_layer = get_tree().get_root().get_node("Game2000/UI")
	if ui_layer:
		ui_layer.add_child(health_bar)
	else:
		push_error("UI Layer (CanvasLayer) não encontrado!")

	if health_bar:
		health_bar.set_health(hp, max_hp)

func _process(delta):
	if not health_bar or not model:
		return

	var head_pos = model.global_transform.origin + Vector3(0, 2.5, 0)

	if not camera:
		camera = get_viewport().get_camera_3d()

	if camera:
		var screen_pos = camera.unproject_position(head_pos)
		var camera_forward = -camera.global_transform.basis.z
		var to_char = (head_pos - camera.global_transform.origin).normalized()
		var dot = camera_forward.dot(to_char)
		health_bar.visible = dot > 0.0

		# Aplica o deslocamento na posição da barra
		var offset_x = -50  # ajustar para o lado que quiser
		var offset_y = -25  # ajustar para cima/baixo

		health_bar.position = screen_pos + Vector2(offset_x, offset_y)

		# Atualiza a barra de vida
		health_bar.set_health(hp, max_hp)

		# Atualiza a barra de turno (turn_charge)
		health_bar.set_turn_charge(turn_charge, turn_threshold)

func _physics_process(delta: float) -> void:
	_handle_movement(delta)

func _handle_movement(delta: float) -> void:
	if is_performing_action:
		move_and_slide()
		return  # <- Evita processar input ou mudar animação

	if manual_control:
		var input_dir = Vector2(
			Input.get_action_strength("move_left") - Input.get_action_strength("move_right"),
			Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
		).normalized()

		if input_dir.length() > 0.01:
			var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
			velocity = direction * move_speed
			move_and_slide()

			var target_yaw = atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 0.1)

			anim.play("Walking_A")
		else:
			velocity = Vector3.ZERO
			move_and_slide()
			anim.play("Idle")
	else:
		if is_moving:
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_position).normalized()
			velocity = direction * move_speed
			rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 0.1)
			move_and_slide()
			if anim and anim.current_animation != "Walking_A":
				anim.play("Walking_A")
		else:
			velocity = Vector3.ZERO
			move_and_slide()
			if anim and anim.current_animation != "Idle":
				anim.play("Idle")

func _update_turn_charge(delta: float) -> void:
	if is_turn_ready:
		return
	
	turn_charge += charge_speed * delta
	
	if turn_charge >= turn_threshold:
		turn_charge = turn_threshold
		is_turn_ready = true

		var manager = get_tree().get_root().get_node("Game2000/BattleManager")  # corrigido o caminho
		if manager and manager.has_method("on_character_ready"):
			manager.on_character_ready(self)


func receive_damage(amount: int) -> void:
	print(name, " recebeu ", amount, " de dano! HP antes: ", hp)
	hp -= amount
	hp = max(hp, 0)
	print(name, " HP depois do dano: ", hp)

	is_performing_action = true  # BLOQUEIA movimento durante animação

	if anim:
		anim.play("Hit_B")

	if health_bar:
		health_bar.set_health(hp, max_hp)

	await get_tree().create_timer(1.0).timeout  # Espera 1 segundo

	is_performing_action = false  # Libera o movimento, se ainda estiver vivo

	if hp <= 0:
		print(name, " está morrendo")
		await _die()

func _die() -> void:
	print(name, " morreu!")

	is_performing_action = true  # Evita se mover durante a morte

	if anim:
		anim.play("Death_A") 
	
	if health_bar:
		health_bar.queue_free()

	await get_tree().create_timer(1.0).timeout  # Espera 1 segundo antes de remover

	# Remover da lista do BattleManager
	var manager = get_tree().get_root().get_node("Game2000/BattleManager")
	if manager:
		if self in manager.enemies:
			manager.enemies.erase(self)
		elif self in manager.party_members:
			manager.party_members.erase(self)

	await get_tree().create_timer(1.0).timeout  # Espera mais 1 segundo para "sumir"

	queue_free()

func set_camera(cam: Camera3D):
	if cam:
		camera = cam

func update_ai(_delta: float) -> void:
	# IA desativada, ataques automáticos serão tratados no BattleManager
	pass
	
func _update_vision_cone(target: CombatCharacter, attack_range: float):
	if not vision_cone_material or not target:
		return

	# Atualiza a cor do cone com base na distância
	var distance := global_position.distance_to(target.global_position)
	var is_in_range := distance <= attack_range
	var color := Color(1, 0, 0, 0.4) if is_in_range else Color(0, 0, 1, 0.4)
	vision_cone_material.albedo_color = color

	# Faz o cone mirar no inimigo (rotaciona localmente em Y)
	var local_direction = (to_local(target.global_position)).normalized()
	var angle = atan2(local_direction.x, local_direction.z)
	vision_cone.rotation.y = angle

func is_alive() -> bool:
	return hp > 0
