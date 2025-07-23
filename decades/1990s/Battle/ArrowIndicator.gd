extends Node2D

@onready var arrow_sprite: Sprite2D = $Arrow
var tween: Tween

func initialize(initial_global_position: Vector2):
	global_position = initial_global_position
	_start_float_animation()

func _start_float_animation():
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_loops()

	var float_offset = Vector2(0, -10)
	var start_pos = global_position
	var end_pos = start_pos + float_offset

	tween.tween_property(self, "global_position", end_pos, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", start_pos, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
