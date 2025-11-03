extends Sprite2D
@export var enemy: Enemy
var enemy_id: String

# --- MODIFICADO AQUI ---
const VISUAL_CONFIG = {
	"Esqueleto": { # <-- Renomeado de "Goblin"
		"texture": preload("res://assets/Goblin.png"), # <-- Ainda usa a arte do Goblin
		"scale": Vector2(1.6, 1.6),
	},
	# "Orc" e "Little Orc" foram removidos
	"Morcego": {
		"texture": preload("res://assets/Morcego.png"),
		"scale": Vector2(1.0, 1.0),
	}
}
# --- FIM DA MODIFICAÇÃO ---

func _ready():
	if enemy:
		enemy_id = enemy.id
		_update_visual()

func _update_visual():
	if enemy.nome in VISUAL_CONFIG:
		var config = VISUAL_CONFIG[enemy.nome]
		texture = config["texture"]
		scale = config["scale"]
		
		# Como o Orc era o único não-flipado, agora podemos
		# simplesmente flipar todos (Morcego e Esqueleto)
		flip_h = true


func set_enemy(e):
	enemy = e
	enemy_id = enemy.id
	_update_visual()

func desaparecer():
	queue_free()
