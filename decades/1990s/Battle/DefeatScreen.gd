extends Control

func _ready():
	$VBoxContainer/ButtonAgain.pressed.connect(_on_button_again_pressed)
	$VBoxContainer/ButtonMainMenu.pressed.connect(_on_button_main_menu_pressed)
	$VBoxContainer/ButtonLoad.pressed.connect(_on_button_load_pressed)

	
func _on_button_again_pressed():
	GameManager.resetar_dados()
	get_tree().change_scene_to_file("res://decades/1990s/Game1990.tscn")

func _on_button_main_menu_pressed():
	get_tree().change_scene_to_file("res://core/UI/MainMenu.tscn")

func _on_button_load_pressed():
	if GameManager.saved_party_data.size() > 0:
		get_tree().change_scene_to_file("res://decades/1990s/Game1990.tscn")
	else:
		print("Nenhum progresso salvo encontrado.")
