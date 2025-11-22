extends Control

var target: CombatCharacter

@onready var green_bar := $HealthBar/GreenBar
@onready var red_bar := $HealthBar/RedBar

var max_width: float = 120.0
var damage_tween: Tween
var last_hp: int = -1


func set_target(t: CombatCharacter):
	target = t


func _ready():
	max_width = green_bar.size.x


func _process(delta):
	if not target or not is_instance_valid(target):
		queue_free()
		return

	_update_health_bar()
	_update_screen_position()


# =================================================================
#       BARRA DE VIDA (VERDE INSTANTÂNEA / VERMELHA COM ATRASO)
# =================================================================
func _update_health_bar():
	if target.hp == last_hp:
		return

	last_hp = target.hp

	var ratio: float = clamp(float(target.hp) / float(target.max_hp), 0.0, 1.0)
	var target_width: float = max_width * ratio

	# barra verde → atualiza na hora
	green_bar.size.x = target_width

	# barra vermelha → tween com atraso
	if damage_tween:
		damage_tween.kill()

	damage_tween = create_tween()
	damage_tween.tween_property(
		red_bar, "size:x", target_width, 0.4
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# =================================================================
#             POSIÇÃO NA TELA + LOOK-AT OCULTO ATRÁS
# =================================================================
func _update_screen_position():
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return

	var world_pos = target.global_position + Vector3(0, 2.4, 0)
	var screen_pos = cam.unproject_position(world_pos)

	# esconder se estiver atrás da câmera
	var to_target = (world_pos - cam.global_transform.origin).normalized()
	var forward = -cam.global_transform.basis.z
	if forward.dot(to_target) <= 0.0:
		visible = false
		return

	visible = true
	position = screen_pos - size * 0.5
