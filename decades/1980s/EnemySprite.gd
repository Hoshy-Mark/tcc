extends Sprite2D

@export var enemy: Enemy

func _ready():
	if enemy:
		_update_visual()

func _update_visual():
	match enemy.nome:
		"Slime":
			texture = preload("res://assets/Goblin.png")
		"Goblin":
			texture = preload("res://assets/Goblin.png")

	scale = Vector2(2, 2)
	flip_h = true  # ou: scale.x = -2
	
	if enemy.current_hp <= 0:
		self.modulate = Color(1, 1, 1, 0.4)
	else:
		self.modulate = Color(1, 1, 1, 1)
