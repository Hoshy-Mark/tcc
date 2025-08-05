extends CharacterBody3D
class_name CombatCharacter

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var model: Node3D = null
var anim: AnimationPlayer = null
var health_bar_scene := preload("res://decades/2000s/UI/HealthBar.tscn")
var health_bar: Control = null
var progress_bar: ProgressBar = null

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

		# Aqui aplica o deslocamento
		var offset_x = -50  # ajustar para o lado que quiser
		var offset_y = -25  # ajustar para cima/baixo

		health_bar.position = screen_pos + Vector2(offset_x, offset_y)

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
		move_and_slide()

func _update_turn_charge(delta: float) -> void:
	if is_turn_ready:
		return
	
	turn_charge += charge_speed * delta
	
	if turn_charge >= turn_threshold:
		turn_charge = turn_threshold
		is_turn_ready = true

		# Notifica o BattleManager quando estiver pronto
		var manager = get_tree().get_root().get_node("Main/BattleManager") # ajuste o caminho se necessário
		if manager and manager.has_method("on_character_ready"):
			manager.on_character_ready(self)

func receive_damage(amount: int):
	hp -= amount
	hp = max(hp, 0)
	print(name, " sofreu ", amount, " de dano! HP restante: ", hp)

	if anim:
		anim.play("Hit_B")

	if health_bar:
		health_bar.set_health(hp, max_hp)

	if hp <= 0:
		_die()

func _die():
	print(name, " morreu!")

	if anim:
		anim.play("Death_A") 
	
	if health_bar:
		health_bar.queue_free()
	
	await get_tree().create_timer(2.0).timeout

	# Remover da lista do BattleManager
	var manager = get_tree().get_root().get_node("Game2000/BattleManager")  # Ajuste o caminho conforme a cena
	if manager:
		if self in manager.enemies:
			manager.enemies.erase(self)
		elif self in manager.party_members:
			manager.party_members.erase(self)

	queue_free()

func set_camera(cam: Camera3D):
	if cam:
		camera = cam
