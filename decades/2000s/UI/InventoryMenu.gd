extends CanvasLayer

signal item_selected(item_data, target)

@onready var item_list = $Panel/MarginContainer/VBoxContainer
@onready var panel = $Panel
var inventory_data = []
var party_members = []

func _ready():
	hide()

		# Estilo visual: fundo azul, borda cinza
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#2b4f7d")
	style.border_color = Color("#888888")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)

	panel.add_theme_stylebox_override("panel", style)  # <- Aplica também aqui

func open(inventory: Array, party: Array):
	inventory_data = inventory
	party_members = party
	
	for child in item_list.get_children():
		child.queue_free()

	for item in inventory_data:
		var row = HBoxContainer.new()

		# OptionButton para selecionar alvo
		var target_selector = OptionButton.new()
		target_selector.add_item("-- Selecione o alvo --")
		for member in party_members:
			target_selector.add_item(member.name)
		row.add_child(target_selector)


		var spacer = MarginContainer.new()
		spacer.custom_minimum_size = Vector2(10, 0)
		row.add_child(spacer)


		# Botão para usar item
		var btn = Button.new()
		btn.text = item.name
		btn.disabled = true
		row.add_child(btn)

		# Habilita botão quando alvo for selecionado
		target_selector.item_selected.connect(func(index):
			btn.disabled = (index == 0)
		)

		# Usa item no alvo escolhido
		btn.pressed.connect(func():
			var index = target_selector.get_selected_id()
			if index > 0:
				var target = _get_target_by_name(target_selector.get_item_text(index))
				emit_signal("item_selected", item, target)
		)

		item_list.add_child(row)

	show()

func close():
	hide()

func _get_target_by_name(name: String):
	for member in party_members:
		if member.name == name:
			return member
	return null
