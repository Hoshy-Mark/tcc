extends Control

func _ready():
	$VBoxContainer/Button.pressed.connect(_on_voltar_pressed)

func _on_voltar_pressed():
	get_tree().change_scene_to_file("res://core/UI/MainMenu.tscn")
