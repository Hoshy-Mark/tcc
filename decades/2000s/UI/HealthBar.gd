extends Control

@onready var green_bar := $GreenBar
@onready var red_bar := $RedBar

var max_width := 100.0
var damage_tween: Tween = null

func _ready():
	max_width = green_bar.size.x

func set_health(current: int, max: int) -> void:
	var health_ratio = clamp(float(current) / float(max), 0.0, 1.0)

	# Ajusta largura da barra verde (vida atual)
	if green_bar:
		green_bar.size.x = max_width * health_ratio

	# Anima a barra vermelha (com delay para mostrar o dano tomado)
	if red_bar:
		if damage_tween:
			damage_tween.kill()

		damage_tween = create_tween()
		damage_tween.tween_property(red_bar, "size:x", max_width * health_ratio, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
