extends Control

func _ready():
	$VBoxContainer/ButtonAgain.pressed.connect(_on_button_again_pressed)
	$VBoxContainer/ButtonMainMenu.pressed.connect(_on_button_main_menu_pressed)
	$VBoxContainer/ButtonNext.pressed.connect(_on_button_next_pressed)
	
func _on_button_next_pressed():
	print("Continuar para próxima década ainda não implementado.")

func _on_button_again_pressed():
	get_tree().change_scene_to_file("res://decades/1980s/Game1980.tscn")

func _on_button_main_menu_pressed():
	get_tree().change_scene_to_file("res://core/UI/MainMenu.tscn")
