extends Node2D

func _ready():
	$TitleLabel.text = "Jogo da década de 1980 (placeholder)"

	var battle_manager_scene = preload("res://decades/1980s/BattleManager.tscn")
	var battle_manager = battle_manager_scene.instantiate()
	add_child(battle_manager)
