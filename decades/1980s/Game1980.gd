extends Node2D

@onready var background = $Background

func _ready():
	$TitleLabel.text = "Jogo da década de 1980 (placeholder)"
	# Nearest-neighbor em vez de linear: evita o borrão do upscale/downscale
	# e aproxima do visual "pixelado" da era (efeito completo depende de
	# trocar os assets por pixel art de baixa resolução).
	background.texture_filter = TEXTURE_FILTER_NEAREST

	var battle_manager_scene = preload("res://decades/1980s/BattleManager.tscn")
	var battle_manager = battle_manager_scene.instantiate()
	add_child(battle_manager)
	battle_manager.set_background_node(background)
