extends Sprite2D
@export var enemy: Enemy
var enemy_id: String

func _ready():
	if enemy:
		enemy_id = enemy.id
		_update_visual()

func _update_visual():
	match enemy.nome:
		"Slime":
			texture = preload("res://assets/Morcego.png")  # Corrigi o sprite do Slime, antes tinha Goblin duplicado
		"Goblin":
			texture = preload("res://assets/Goblin.png")
	scale = Vector2(2, 2)
	flip_h = true
		
func set_enemy(e):
	enemy = e
	enemy_id = enemy.id
	_update_visual()
	
func desaparecer():
	queue_free()  # Remove o sprite da cena
