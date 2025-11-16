extends Control

@onready var green_bar := $HealthBar/GreenBar
@onready var red_bar := $HealthBar/RedBar

@onready var stamina_fill := $StaminaBar/StaminaFill

var player: CombatCharacter
var max_width := 100.0
var damage_tween: Tween


func set_player(p: CombatCharacter):
	player = p


func _ready():
	max_width = green_bar.size.x


func _process(delta):
	if not player:
		return

	_update_health_bar()
	_update_stamina_bar()


# -------------------------------
# VIDA: verde = instantâneo, vermelho = atraso (dano)
# -------------------------------
var last_hp := -1

func _update_health_bar():
	if not player:
		return

	if player.hp == last_hp:
		return # evita recriar tween a cada frame

	last_hp = player.hp

	var ratio = clamp(float(player.hp) / player.max_hp, 0.0, 1.0)
	var target_width = max_width * ratio

	green_bar.size.x = target_width

	# barra vermelha com atraso
	if damage_tween:
		damage_tween.kill()

	damage_tween = create_tween()
	damage_tween.tween_property(
		red_bar, "size:x", target_width, 0.4
	)

# -------------------------------
# STAMINA: atualiza sempre
# -------------------------------
func _update_stamina_bar():
	var ratio = clamp(float(player.stamina) / player.max_stamina, 0.0, 1.0)
	stamina_fill.size.x = max_width * ratio
