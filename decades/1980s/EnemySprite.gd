extends Sprite2D

@export var enemy: Enemy

func _ready():
	if enemy:
		_update_visual()

func _update_visual():
	if enemy.hp <= 0:
		self.modulate = Color(1, 1, 1, 0.4)  # Semitransparente se morto
	else:
		self.modulate = Color(1, 1, 1, 1)
