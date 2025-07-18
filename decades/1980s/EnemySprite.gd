extends Sprite2D
@export var enemy: Enemy
var enemy_id: String

const VISUAL_CONFIG = {
	"Goblin": {
		"texture": preload("res://assets/Goblin.png"),
		"scale": Vector2(1.6, 1.6),
	},
	"Orc": {
		"texture": preload("res://assets/Orc.png"),
		"scale": Vector2(1.5, 1.5),
	},
	"Little Orc": {
		"texture": preload("res://assets/Little Orc.png"),
		"scale": Vector2(1.2, 1.2),
	},
	"Morcego": {
		"texture": preload("res://assets/Morcego.png"),
		"scale": Vector2(1.0, 1.0),
	}
}

func _ready():
	if enemy:
		enemy_id = enemy.id
		_update_visual()

func _update_visual():
	if enemy.nome in VISUAL_CONFIG:
		var config = VISUAL_CONFIG[enemy.nome]
		texture = config["texture"]
		scale = config["scale"]
	else:
		print("⚠️ Sem configuração visual para: ", enemy.nome)

	flip_h = true

func set_enemy(e):
	enemy = e
	enemy_id = enemy.id
	_update_visual()

func desaparecer():
	queue_free()
