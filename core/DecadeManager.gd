extends Node

var selected_decade: int = 1980

func select_decade(year: int) -> void:
	selected_decade = year
	print("Década selecionada: %s" % selected_decade)

func load_selected_decade_scene() -> void:
	match selected_decade:
		1980:
			get_tree().change_scene_to_file("res://decades/1980s/Game1980.tscn")
		1990:
			get_tree().change_scene_to_file("res://decades/1990s/Game1990.tscn")
		2000:
			get_tree().change_scene_to_file("res://decades/2000s/Game2000.tscn")
		2010:
			get_tree().change_scene_to_file("res://decades/2010s/Game2010.tscn")
		2020:
			get_tree().change_scene_to_file("res://decades/2020s/Game2020.tscn")
		_:
			push_error("Década %s não implementada." % selected_decade)
