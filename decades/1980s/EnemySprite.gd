extends Sprite2D
# Não usa @export: Enemy agora é RefCounted (não Node/Resource), então o
# editor não sabe serializá-lo/exibi-lo no Inspector. Sempre é atribuído
# via código, através de set_enemy().
var enemy: Enemy
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
	# Nearest-neighbor: visual mais "cru"/pixelado em vez do blur do filtro
	# linear padrão. set_enemy() já roda antes disso (chamado antes do
	# add_child pelo BattleManager), então não repetimos _update_visual()
	# aqui — evita re-sortear a variante do sprite à toa.
	texture_filter = TEXTURE_FILTER_NEAREST

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

# --- ADICIONADO: Feedback visual de dano recebido ---
# Recua um pouco e pisca em vermelho, depois volta ao normal.
func play_hit_feedback() -> void:
	var original_pos = position
	var original_modulate = modulate

	# Um único Tween: posição e cor em paralelo em cada etapa (recuar+piscar,
	# depois voltar ao normal). Dois create_tween() separados no mesmo
	# nó/frame competiam entre si e nenhum dos dois animava.
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + Vector2(15, 0), 0.08)
	tween.parallel().tween_property(self, "modulate", Color(1, 0.2, 0.2, original_modulate.a), 0.08)
	tween.tween_property(self, "position", original_pos, 0.15)
	tween.parallel().tween_property(self, "modulate", original_modulate, 0.15)

# --- ADICIONADO: Feedback visual de ataque (o inimigo golpeando) ---
# Avança na direção do alvo e volta, simulando o golpe.
func play_attack_lunge() -> void:
	var original_pos = position
	var lunge_tween = create_tween()
	lunge_tween.tween_property(self, "position", original_pos + Vector2(-25, 0), 0.12)
	lunge_tween.tween_property(self, "position", original_pos, 0.12)

# --- ADICIONADO: Função para reviver ---
func reviver():
	show()
	# Re-randomiza a aparência se for um Morto-Vivo
	if enemy.nome == "Morto-Vivo":
		_update_visual()
