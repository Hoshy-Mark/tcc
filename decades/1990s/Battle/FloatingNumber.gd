extends Label

func initialize(value: int, global_pos: Vector2, tipo_valor: String = "hp") -> void:
	text = str(value)
	global_position = global_pos

	# Aumentar o tamanho da fonte (por exemplo, 40)
	add_theme_font_size_override("font_size", 40)

	# Define a cor de acordo com o tipo de valor
	match tipo_valor:
		"hp":
			modulate = Color(0.2, 1.0, 0.2) # verde
		"mp":
			modulate = Color(0.4, 0.6, 1.0) # azul
		"sp":
			modulate = Color(1.0, 0.6, 0.2) # laranja
		"damage":
			modulate = Color(1.0, 0.2, 0.2) # vermelho

	var tween := get_tree().create_tween()

	# Animação de subir e desaparecer
	tween.tween_property(self, "global_position", global_position + Vector2(0, -40), 0.8)
	tween.tween_property(self, "modulate", Color(modulate.r, modulate.g, modulate.b, 0), 0.8)

	await tween.finished
	queue_free()
