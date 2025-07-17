extends Control

func _ready():
	$VBoxContainer/ButtonAgain.pressed.connect(_on_button_again_pressed)
	$VBoxContainer/ButtonMainMenu.pressed.connect(_on_button_main_menu_pressed)
	$VBoxContainer/ButtonLoad.pressed.connect(_on_button_load_pressed)

	
func _on_button_again_pressed():
	GameManager.resetar_dados()
	get_tree().change_scene_to_file("res://decades/1980s/Game1980.tscn")

func _on_button_main_menu_pressed():
	get_tree().change_scene_to_file("res://core/UI/MainMenu.tscn")

func _on_button_load_pressed():
	if GameManager.saved_party_data.size() > 0:
		print("Progresso carregado com sucesso!")
		get_tree().change_scene_to_file("res://decades/1980s/Game1980.tscn")
	else:
		print("Nenhum progresso salvo encontrado.")
