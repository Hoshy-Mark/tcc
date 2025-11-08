extends Sprite2D
@export var enemy: Enemy
var enemy_id: String

# --- MODIFICADO: Renomeado e Necromante separado ---
const VISUAL_CONFIG = {
	"Morto-Vivo": {
		"variants": [
			{
				"texture": preload("res://assets/Esqueleto.png"), 
				"scale": Vector2(0.3, 0.3)
			},
			{
				"texture": preload("res://assets/Zumbi.png"), 
				"scale": Vector2(1.0, 1.0) # <-- Ajuste a escala do Zumbi!
			}
		],
		"modulate": Color(1, 1, 1)
	},
	"Morcego": {
		"variants": [
			{
				"texture": preload("res://assets/Morcego.png"), 
				"scale": Vector2(1.0, 1.0)
			}
		],
		"modulate": Color(1, 1, 1)
	},
	"Rei Morto-Vivo": {
		"variants": [
			{
				"texture": preload("res://assets/Esqueleto.png"), 
				"scale": Vector2(0.4, 0.4)
			}
		],
		"modulate": Color(1.0, 0.8, 0.8, 1.0)
	},
	"Necromante": {
		"variants": [
			{
				"texture": preload("res://assets/Necromante.png"), 
				"scale": Vector2(1.0, 1.0) # <-- Ajuste a escala!
			}
		],
		"modulate": Color(1, 1, 1)
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
		
		var variant_list = config["variants"]
		var chosen_variant = variant_list.pick_random()
		
		texture = chosen_variant["texture"]
		scale = chosen_variant["scale"]
		modulate = config["modulate"]
		
		flip_h = true


func set_enemy(e):
	enemy = e
	enemy_id = enemy.id
	_update_visual()

# --- MODIFICADO: Agora apenas esconde ---
func desaparecer():
	hide()

# --- ADICIONADO: Função para reviver ---
func reviver():
	show()
	# Re-randomiza a aparência se for um Morto-Vivo
	if enemy.nome == "Morto-Vivo":
		_update_visual()
