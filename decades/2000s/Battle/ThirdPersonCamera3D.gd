extends Node3D

class_name ThirdPersonCamera3D

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var cam: Camera3D = $SpringArm3D/Camera3D

var follow_target: Node3D = null
var is_in_tactical_mode := false

# Ângulos (em graus)
var combat_rotation := Vector3(-30, 0, 0)
var tactical_rotation := Vector3(-30, 0, 0)

# Comprimento do SpringArm (distância da câmera ao personagem)
var combat_distance_z := 8
var tactical_distance_z := 8

# Log
var _time_accum := 0.0
var _log_interval := 1.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	spring_arm.process_mode = Node.PROCESS_MODE_ALWAYS
	cam.process_mode = Node.PROCESS_MODE_ALWAYS

	# A posição da câmera deve ser zero; o SpringArm cuida do resto
	cam.position = Vector3.ZERO
	
	# Ajuste a altura do SpringArm, não da câmera
	spring_arm.position.y = 3.5  # altura desejada da câmera em relação ao personagem
	
	set_camera_to_combat(true)

func _process(delta):
	if follow_target:
		global_position = follow_target.global_position

	_time_accum += delta
	if _time_accum >= _log_interval:
		_time_accum = 0

func set_follow_target(target: Node3D) -> void:
	follow_target = target
	
func set_camera_to_combat(immediate: bool = false):
	is_in_tactical_mode = false
	_transition_camera(combat_distance_z, combat_rotation, immediate)

func set_camera_to_tactical(immediate: bool = false):
	is_in_tactical_mode = true
	_transition_camera(tactical_distance_z, tactical_rotation, immediate)

func _transition_camera(distance_z: float, target_rot: Vector3, immediate: bool):
	var distance = abs(distance_z)

	if immediate:
		spring_arm.spring_length = distance
		spring_arm.rotation_degrees = target_rot
	else:
		var tween := get_tree().create_tween()
		tween.tween_property(spring_arm, "spring_length", distance, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(spring_arm, "rotation_degrees", target_rot, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
