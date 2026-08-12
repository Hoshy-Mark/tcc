extends Sprite2D

var player: PlayerPartyMember1990
var is_dead := false

func _ready():
	# Nearest-neighbor em vez de linear: evita o borrão do upscale, mais
	# perto do visual "pixelado" da época (efeito completo depende de
	# trocar os assets por pixel art de baixa resolução).
	texture_filter = TEXTURE_FILTER_NEAREST

func set_sprite(path: String) -> void:
	var tex = load(path)
	if tex:
		texture = tex
	else:
		push_error("Sprite texture not found: %s" % path)

func set_player(p):
	player = p
	player.died.connect(_on_player_died)
	
func _on_player_died():
	if is_dead:
		return
	is_dead = true
	texture = load("res://assets/Lapide.png")
	scale = Vector2(0.6, 0.6)
