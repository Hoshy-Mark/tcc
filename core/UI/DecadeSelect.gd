extends Control

func _ready():
	$VBoxContainer/GridContainer/Button1980.pressed.connect(_on_1980_pressed)
	$VBoxContainer/ButtonVoltar.pressed.connect(_on_voltar_pressed)

func _on_1980_pressed():
	DecadeManager.select_decade(1980)
	DecadeManager.load_selected_decade_scene()

func _on_voltar_pressed():
	get_tree().change_scene_to_file("res://core/UI/MainMenu.tscn")
