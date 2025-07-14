extends CenterContainer

func _ready():
	$VBoxContainer/ButtonJogar.pressed.connect(_on_jogar_pressed)
	$VBoxContainer/ButtonOpcoes.pressed.connect(_on_opcoes_pressed)
	$VBoxContainer/ButtonSair.pressed.connect(_on_sair_pressed)

func _on_jogar_pressed():
	get_tree().change_scene_to_file("res://core/UI/DecadeSelect.tscn")

func _on_opcoes_pressed():
	# Substitua pelo caminho correto para opções
	get_tree().change_scene_to_file("res://core/UI/Options.tscn")

func _on_sair_pressed():
	get_tree().quit()
