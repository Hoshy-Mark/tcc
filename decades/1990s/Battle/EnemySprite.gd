extends Sprite2D

var enemy_data

func set_sprite(path: String) -> void:
	var tex = load(path)
	if tex:
		texture = tex
	else:
		push_error("Sprite texture not found: %s" % path)

func set_enemy(enemy):
	enemy_data = enemy
	enemy_data.died.connect(_on_enemy_died)  # escuta evento de morte

func _on_enemy_died():
	hide()  # Esconde o sprite visualmente
