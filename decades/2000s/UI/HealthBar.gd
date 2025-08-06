extends Control

@onready var green_bar := $GreenBar
@onready var red_bar := $RedBar
@onready var turn_charge_bg := $TurnChargeBar/Background
@onready var turn_charge_fill := $TurnChargeBar/Fill

var max_width := 100.0
var damage_tween: Tween = null
var turn_tween: Tween = null

func _ready():
	max_width = green_bar.size.x

	# Cores
	turn_charge_bg.color = Color(0.2, 0.1, 0.0)  # fundo escuro
	turn_charge_fill.color = Color(1.0, 0.5, 0.0)  # laranja

	# Tamanhos
	$TurnChargeBar.size = Vector2(100, 15)
	turn_charge_bg.size = Vector2(100, 15)
	turn_charge_fill.size = Vector2(0, 15)  # começa vazio

	# Posição: 5 pixels abaixo da barra verde
	$TurnChargeBar.position = green_bar.position + Vector2(0, green_bar.size.y + 5)


		
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

func set_turn_charge(value: float, max_value: float) -> void:
	var ratio = clamp(value / max_value, 0.0, 1.0)
	var target_width = max_width * ratio

	# Anima o preenchimento da barra laranja
	turn_charge_fill.size.x = target_width
