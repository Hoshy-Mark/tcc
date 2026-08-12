extends Control

func _ready():
	$VBoxContainer/ButtonAgain.pressed.connect(_on_button_again_pressed)
	$VBoxContainer/ButtonMainMenu.pressed.connect(_on_button_main_menu_pressed)

func _on_button_again_pressed():
	get_tree().change_scene_to_file("res://decades/2000s/Game2000.tscn")

func _on_button_main_menu_pressed():
	get_tree().change_scene_to_file("res://core/UI/MainMenu.tscn")
