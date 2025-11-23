extends Node3D
class_name ThirdPersonCamera3D2020

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var cam: Camera3D = $SpringArm3D/Camera3D

var follow_target: Node3D = null
var is_in_tactical_mode := false
var is_rotating := false
var rotation_speed := 0.3  
var yaw := 0.0  

# Ângulos (em graus)
var combat_rotation := Vector3(-35, 0, 0)
var tactical_rotation := Vector3(-35, 30, 0)

# Distância da câmera ao alvo
var combat_distance_z := 9
var tactical_distance_z := 11

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	spring_arm.process_mode = Node.PROCESS_MODE_ALWAYS
	cam.process_mode = Node.PROCESS_MODE_ALWAYS

	# Câmera sempre no zero — quem movimenta é o SpringArm
	cam.position = Vector3.ZERO

	# Posição vertical do braço
	spring_arm.position.y = 3.5

	set_process_unhandled_input(true)
	set_camera_to_combat(true)

func _process(delta):
	# FOLLOW SUAVIZADO – sem brigar com tween do BattleManager
	if follow_target and not is_in_tactical_mode:
		global_position = global_position.lerp(follow_target.global_position, 0.15)

func set_follow_target(target: Node3D) -> void:
	follow_target = target

func set_camera_to_combat(immediate: bool = false):
	is_in_tactical_mode = false
	_transition_camera(combat_distance_z, combat_rotation, immediate)

func set_camera_to_tactical(immediate: bool = false):
	is_in_tactical_mode = true
	spring_arm.position.y = 4
	yaw = spring_arm.rotation_degrees.y  
	_transition_camera(tactical_distance_z, tactical_rotation, immediate)

func _transition_camera(distance_z: float, target_rot: Vector3, immediate: bool):
	var distance = abs(distance_z)

	if immediate:
		spring_arm.spring_length = distance
		spring_arm.rotation_degrees = target_rot
	else:
		var tween := get_tree().create_tween()
		tween.tween_property(
			spring_arm, "spring_length",
			distance, 0.8
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		tween.tween_property(
			spring_arm, "rotation_degrees",
			target_rot, 0.8
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _unhandled_input(event):
	if not is_in_tactical_mode:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_rotating = event.pressed

	elif event is InputEventMouseMotion and is_rotating:
		yaw -= event.relative.x * rotation_speed
		_update_tactical_rotation()

func _update_tactical_rotation():
	var target_rot = tactical_rotation
	target_rot.y = yaw
	spring_arm.rotation_degrees = target_rot
