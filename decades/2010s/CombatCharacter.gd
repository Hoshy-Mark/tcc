extends CharacterBody3D
class_name CombatCharacter

signal died(character)
@export var show_healthbar := false

# --- Nodos / refs ---
var anim: AnimationPlayer = null
var model: Node3D = null
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D if has_node("NavigationAgent3D") else null

# --- Atributos ---
var max_hp: int = 100
var hp: int = 100
var healthbar_scene := preload("res://decades/2010s/UI/HealthBar2010.tscn")
var healthbar: Control = null
var max_stamina: float = 100.0
var stamina: float = 100.0
var stamina_regen_idle: float = 12.0   # souls-like: regen mais lento
var stamina_regen_walk: float = 6.0
var stamina_regen_run: float = 0.0

var attack_power: int = 20
var defense_rating: float = 20.0

# Movimento
var walk_speed: float = 4.0
var run_speed: float = 6.5
var is_running: bool = false

# Estados / combate
enum State { IDLE, MOVING, ATTACKING, DODGING, STAGGERED, BLOCKING, DEAD }
var state: int = State.IDLE

var is_dodging: bool = false
var dodge_iframes: float = 0.28
var dodge_duration: float = 0.38
var dodge_stamina_cost: float = 30.0

var light_attack_cost: float = 20.0
var heavy_attack_cost: float = 40.0
var light_attack_multiplier: float = 1.0
var heavy_attack_multiplier: float = 1.6
var attack_range: float = 2.2

# Timings (tune conforme animações)
var attack_hit_time: float = 0.45      # quando o hit efetivo ocorre
var attack_total_time: float = 0.6     # tempo total da ação (para combos)
var heavy_attack_hit_time: float = 0.5
var heavy_attack_total_time: float = 0.6

# Cancel windows (souls-like: travamento inicial, depois janela para cancelar)
var action_lock_min: float = 0.18  # tempo mínimo preso
# target
var current_target: CombatCharacter = null
var manual_control: bool = false

# Camera
var camera: ThirdPersonCamera3D = null

# Defesa
var is_blocking_flag: bool = false
var block_reduction := 0.6
var block_facing_angle := 110.0

# Knockback
var knockback_strength := 6.0
var knockback_on_block_attacker := 0.5
var knockback_on_hit_target := 1

# Internos
var _attack_can_hit := true

# --- READY ---
func _ready() -> void:
	hp = clamp(hp, 0, max_hp)
	stamina = clamp(stamina, 0.0, max_stamina)

	for child in get_children():
		if child.has_node("AnimationPlayer"):
			model = child
			anim = child.get_node("AnimationPlayer")
			break

	if anim:
		anim.play("Idle")
	else:
		push_error("AnimationPlayer não encontrado em " + str(self))
		
	if show_healthbar:
		var ui_layer := get_tree().get_root().get_node("Game2010/UI")
		if ui_layer:
			healthbar = healthbar_scene.instantiate()
			ui_layer.add_child(healthbar)
			healthbar.set_target(self)

		  # dura metade do tempo

# --- PROCESS ---
func _process(delta: float) -> void:
	if state == State.DEAD:
		return
	# stamina regen dependendo do estado (souls-like)
	var regen = 0.0
	if state == State.DODGING or state == State.ATTACKING or state == State.STAGGERED:
		regen = 0.0
	elif velocity.length() > 0.1 and not is_running:
		regen = stamina_regen_walk
	elif is_running:
		regen = stamina_regen_run
	else:
		regen = stamina_regen_idle

	stamina = clamp(stamina + regen * delta, 0.0, max_stamina)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_handle_block_input()
	_handle_movement(delta)


# --- MOVIMENTO ---
func _handle_movement(delta: float) -> void:
	if state == State.DEAD:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	# Bloqueia movimento quando staggered
	if state == State.STAGGERED:
		move_and_slide()
		return

	# Dodge tem sua própria movimentação
	if state == State.DODGING:
		move_and_slide()
		return

	# Ataque permite micro-movimento (root motion fake) para fluidez
	if state == State.ATTACKING:
		# reduz velocidade mas permite pequeno avanço para não parecer congelado
		velocity = velocity * 0.30
		move_and_slide()
		return

	# Navegação automática (IA)
	if nav_agent and not manual_control:
		if not nav_agent.is_navigation_finished():
			var target_pos = nav_agent.get_next_path_position()
			var dir = target_pos - global_position
			dir.y = 0
			if dir.length() > 0.01:
				dir = dir.normalized()
				velocity = dir * (run_speed if is_running else walk_speed)
				rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 0.12)
			else:
				velocity = Vector3.ZERO
			move_and_slide()
			_update_animation_walk_idle()
			return

	# Controle manual (player)
	if manual_control:
		if is_blocking_flag:
			velocity = Vector3.ZERO
			move_and_slide()
			return

		var input_dir = Vector2(
			Input.get_action_strength("move_left") - Input.get_action_strength("move_right"),
			Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
		)
		is_running = Input.is_action_pressed("move_run") and stamina > 0

		if input_dir.length() > 0.01:
			var dir3 = Vector3(input_dir.x, 0, input_dir.y).normalized()
			var move_dir: Vector3
			if camera:
				var cam = camera.global_transform
				var forward = -cam.basis.z; forward.y = 0; forward = forward.normalized()
				var right = cam.basis.x; right.y = 0; right = right.normalized()
				move_dir = (right * input_dir.x + forward * input_dir.y).normalized()
			else:
				move_dir = dir3

			var speed = run_speed if is_running else walk_speed
			velocity = move_dir * speed
			move_and_slide()

			var yaw = atan2(move_dir.x, move_dir.z)
			rotation.y = lerp_angle(rotation.y, yaw, 0.18)

			_update_animation_walk_idle()
		else:
			velocity = Vector3.ZERO
			move_and_slide()
			_update_animation_walk_idle()
	else:
		# sem controle e sem nav -> parado
		velocity = Vector3.ZERO
		move_and_slide()
		_update_animation_walk_idle()


func _update_animation_walk_idle() -> void:
	if anim:
		if velocity.length() > 0.1 and anim.current_animation != "Walking_A":
			anim.play("Walking_A")
		elif velocity.length() <= 0.1 and anim.current_animation != "Idle" and state != State.ATTACKING:
			anim.play("Idle")


# --- ATAQUE / HIT --- 
func _find_combat_character_from_collider(col) -> CombatCharacter:
	if not col:
		return null
	var node = col
	while node:
		if node is CombatCharacter:
			return node
		if node.has_method("get_parent"):
			node = node.get_parent()
		else:
			break
	return null


func _perform_attack_sweep(from: Vector3, to: Vector3, radius: float = 0.6):
	var space = get_world_3d().direct_space_state

	var shape = SphereShape3D.new()
	shape.radius = radius

	var center = (from + to) * 0.5
	var xform = Transform3D(Basis(), center)

	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = xform
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [self]

	var result = space.intersect_shape(params, 8)
	if result.size() > 0:
		return result[0]
	return {}


func perform_attack(is_heavy := false) -> void:
	if state in [State.DODGING, State.STAGGERED, State.ATTACKING, State.DEAD]:
		return
	if is_blocking_flag:
		return

	var cost = heavy_attack_cost if is_heavy else light_attack_cost
	if stamina < cost:
		return
	stamina -= cost

	state = State.ATTACKING
	_attack_can_hit = true

	var anim_name = "1H_Melee_Attack_Chop" if is_heavy else "2H_Melee_Attack_Chop"

	# --- TOCA ATAQUE NORMAL (0.5s) ---
	anim.play(anim_name)
	anim.speed_scale = 2.0

	await get_tree().process_frame  # garante que current_animation_position vai ser atualizado

	await get_tree().create_timer(0.5).timeout

	# aplicando hit
	if not _attack_can_hit or state != State.ATTACKING:
		_finish_attack()
		return

	_apply_attack_hit(is_heavy)

	# --- COMECAR RETROCESSO EXACT-FRAME ---
	# captura o ponto EXATO onde a animação parou
	var end_pos := anim.current_animation_position
	var length := anim.get_animation(anim_name).length

	# duração do retrocesso
	var rewind_time := 0.5
	var rewind_speed := -(end_pos / rewind_time)

	anim.play(anim_name)        # mantém mesma animação
	anim.speed_scale = rewind_speed
	anim.seek(end_pos, true)   # >>> aqui está a magia = busca EXATAMENTE no mesmo frame <<<

	await get_tree().create_timer(rewind_time).timeout

	_finish_attack()

func _finish_attack():
	state = State.IDLE
	# dispara sinal para a IA saber que acabou
	emit_signal("attack_finished")
	anim.speed_scale = 1.0
	anim.play("Idle")

func _apply_attack_hit(is_heavy: bool):
	var from = global_transform.origin + Vector3(0, 1.2, 0)
	var forward = global_transform.basis.z.normalized()
	var to = from + forward * attack_range

	var swe = _perform_attack_sweep(from, to, 0.6)

	var target: CombatCharacter = null

	# Verifica se swe tem collider
	if swe.has("collider"):
		target = _find_combat_character_from_collider(swe["collider"])

	# Se por raycast mesmo assim ficou null → sem alvo
	if target == null:
		return

	# Se não estiver vivo → também finge que não acertou
	if not target.is_alive():
		return

	# Calcula o dano
	var mult = heavy_attack_multiplier if is_heavy else light_attack_multiplier
	var dmg = int(attack_power * mult)

	# Aplica hit
	target.receive_hit(dmg, self, global_position, Vector3.UP)



func _on_attack_anim_finished(anim_name):
	# seguro: limpa estado se anim terminar
	if anim_name.find("Attack") >= 0:
		if state == State.ATTACKING:
			state = State.IDLE
			if anim:
				anim.play("Idle")


# receive_hit agora recebe opcional hitstop_duration
func receive_hit(incoming: int, attacker: CombatCharacter, hit_pos: Vector3, hit_normal: Vector3, hitstop_duration: float = 0.5) -> void:
	# se estiver em dodge com iframes, evita tudo
	if state == State.DODGING:
		return

	var blocked = false

	if state == State.ATTACKING:
		_attack_can_hit = false
		state = State.STAGGERED

	if is_blocking_flag:
		var to_attacker = attacker.global_position - global_position
		to_attacker.y = 0
		if to_attacker.length() > 0.001:
			to_attacker = to_attacker.normalized()
			var forward = global_transform.basis.z; forward.y = 0; forward = forward.normalized()
			var ang = rad_to_deg(acos(clamp(forward.dot(to_attacker), -1, 1)))
			if ang <= block_facing_angle * 0.5:
				blocked = true

	var reduction = clamp(defense_rating, 0, 95) * 0.01
	var final = int(incoming * (1.0 - reduction))
	if blocked:
		final = int(final * (1.0 - block_reduction))
	final = max(final, 1)

	if blocked:
		if attacker:
			attacker._interrupt_attack_on_block()
		if anim:
			anim.stop()
			anim.play("Block_Hit")
			anim.speed_scale = 2.0
		var dir = (attacker.global_position - global_position).normalized()
		attacker.apply_knockback(-dir * knockback_on_block_attacker)
		hp -= final
	else:
		if anim:
			anim.stop()
			anim.play("Hit_B")
			anim.speed_scale = 2.0
		hp -= final
		var dir = global_position - attacker.global_position
		dir.y = 0
		if dir.length() > 0.001:
			dir = dir.normalized()
			apply_knockback_and_stagger(dir * knockback_on_hit_target, 0.45)

	# hitstop: aplica curta imobilização na vítima para sensação (não afeta timers)
	if hitstop_duration > 0.0:
		state = State.STAGGERED
		await get_tree().create_timer(hitstop_duration).timeout
		if state == State.STAGGERED:
			state = State.IDLE

	if hp <= 0:
		die()



func _interrupt_attack_on_block() -> void:
	_attack_can_hit = false
	state = State.STAGGERED
	if anim:
		anim.stop()
		anim.play("Hit_B")
		anim.speed_scale = 2.0
	apply_knockback_and_stagger(global_transform.basis.z * -knockback_on_block_attacker, 0.45)


func apply_knockback_and_stagger(force: Vector3, stagger_time: float = 0.45) -> void:
	velocity = Vector3.ZERO
	velocity += force
	move_and_slide()

	state = State.STAGGERED
	await get_tree().create_timer(stagger_time).timeout
	state = State.IDLE


func apply_knockback(force: Vector3) -> void:
	velocity += force
	move_and_slide()


# --- DODGE ---
func perform_dodge() -> void:
	if is_blocking_flag: return
	if state == State.DODGING or state == State.STAGGERED or state == State.ATTACKING: return
	if stamina < dodge_stamina_cost: return

	stamina -= dodge_stamina_cost
	state = State.DODGING

	if anim:
		anim.stop()
		anim.play("Dodge_Backward")
		anim.speed_scale = 1.0

	# movimento do dodge
	var dodge_speed := 2.2
	var dir := -global_transform.basis.z
	dir.y = 0
	dir = dir.normalized()
	velocity = dir * dodge_speed

	# iframes
	await get_tree().create_timer(dodge_iframes).timeout
	# termina iframes e aguarda resto da duração
	await get_tree().create_timer(dodge_duration - dodge_iframes).timeout

	state = State.IDLE


# --- BLOQUEIO ---
func _handle_block_input() -> void:
	if not manual_control:
		return
	if Input.is_action_pressed("defend"):
		start_blocking()
	else:
		stop_blocking()


func start_blocking() -> void:
	is_blocking_flag = true
	# em souls, bloquear não impede completamente ações, mas reduz mobilidade
	state = State.BLOCKING
	if anim and anim.current_animation != "Blocking":
		anim.play("Blocking")
		anim.speed_scale = 1.0


func stop_blocking() -> void:
	if not is_blocking_flag:
		return
	is_blocking_flag = false
	if state == State.BLOCKING:
		state = State.IDLE
	if anim and anim.current_animation == "Blocking":
		anim.play("Idle")


# --- OUTROS ---
func apply_damage(incoming: int, attacker: CombatCharacter=null) -> void:
	receive_hit(incoming, attacker, global_position, Vector3.UP)


func die() -> void:
	if state == State.DEAD:
		return

	state = State.DEAD
	hp = 0

	if anim:
		anim.play("Death_A")
		
	if healthbar:
		healthbar.queue_free()
	emit_signal("died", self)

	# espera animação terminar automaticamente (0.5s)
	await get_tree().create_timer(0.5).timeout

	queue_free()

func is_alive() -> bool:
	return hp > 0


func set_camera(cam: ThirdPersonCamera3D):
	camera = cam
