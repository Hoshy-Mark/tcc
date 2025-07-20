extends Node2D

@onready var background = $Background

func _ready():
	$TitleLabel.text = "Jogo da década de 1980 (placeholder)"

	var battle_manager_scene = preload("res://decades/1980s/BattleManager.tscn")
	var battle_manager = battle_manager_scene.instantiate()
	add_child(battle_manager)
	battle_manager.set_background_node(background)

func set_background(texture: Texture2D):
	background.texture = texture
