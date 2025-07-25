extends Control

const CLASS_DATA = {
		"Mage": {
			"icon": "res://assets/classes/Mage.png",
			"description": "Alta magia ofensiva, defesa baixa.",
			"role": "DPS Mágico"
		},
		"Cleric": {
			"icon": "res://assets/classes/Cleric.png",
			"description": "Cura e suporte com magia sagrada.",
			"role": "Healer"
		},
		"Summoner": {
			"icon": "res://assets/classes/Summoner.png",
			"description": "Invoca criaturas e usa magia de apoio.",
			"role": "Suporte Mágico"
		},
		"Paladin": {
			"icon": "res://assets/classes/Paladin.png",
			"description": "Alta defesa e cura com magia leve.",
			"role": "Tank/Healer"
		},
		"Hunter": {
			"icon": "res://assets/classes/Hunter.png",
			"description": "Ataques à distância e efeitos de status.",
			"role": "Suporte"
		},
		"Monk": {
			"icon": "res://assets/classes/Monk.png",
			"description": "Ataque rápido e cura com habilidades físicas.",
			"role": "Híbrido"
		},
		"Thief": {
			"icon": "res://assets/classes/Thief.png",
			"description": "Alta velocidade e chance de crítico.",
			"role": "DPS Físico"
		},
		"Knight": {
			"icon": "res://assets/classes/Knight.png",
			"description": "Alta defesa e ataque moderado.",
			"role": "Tank"
		},
}

const MAGIC_CLASSES := ["Mage", "Cleric", "Summoner", "Paladin"]
const PHYSICAL_CLASSES := ["Monk", "Knight", "Thief", "Hunter"]

var selected_classes := []
const MAX_SELECTION := 4

@onready var class_grid := $MarginContainer/VBoxContainer/ClassGrid
@onready var description_label := $MarginContainer/VBoxContainer/DescriptionLabel
@onready var selection_label := $MarginContainer/VBoxContainer/HBoxContainer/Label
@onready var confirm_button := $MarginContainer/VBoxContainer/Confirmar

func _ready():

	class_grid.add_theme_constant_override("h_separation", 200)
	class_grid.add_theme_constant_override("v_separation", 60)
	confirm_button.custom_minimum_size = Vector2(60, 60)

	selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_label.custom_minimum_size = Vector2(60, 60)

	for class_id in CLASS_DATA.keys():
		var class_info = CLASS_DATA[class_id]

		var class_box = VBoxContainer.new()
		class_box.alignment = BoxContainer.ALIGNMENT_CENTER
		class_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var name_label = Label.new()
		name_label.text = class_id
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		class_box.add_child(name_label)

		var button = TextureButton.new()
		button.name = class_id
		button.set("custom_styles/normal", StyleBoxFlat.new())  # Reset visual
		button.texture_normal = load(class_info.icon)
		button.tooltip_text = class_info.description
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.scale = Vector2(0.4, 0.4)
		button.connect("pressed", Callable(self, "_on_class_selected").bind(class_id, button))
		class_box.add_child(button)

		var desc_label = Label.new()
		desc_label.text = class_info.description
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.custom_minimum_size = Vector2(100, 40)
		class_box.add_child(desc_label)

		class_grid.add_child(class_box)

	_update_selection_label()
	confirm_button.disabled = true
	confirm_button.connect("pressed", _on_confirm_pressed)

func _on_class_selected(class_id: String, button: TextureButton):
	if class_id in selected_classes:
		selected_classes.erase(class_id)
		button.remove_theme_stylebox_override("panel")
	else:
		if selected_classes.size() >= MAX_SELECTION:
			return
		
		# Limite de 2 por tipo
		var magic_count = selected_classes.filter(func(c): return c in MAGIC_CLASSES).size()
		var physical_count = selected_classes.filter(func(c): return c in PHYSICAL_CLASSES).size()

		if class_id in MAGIC_CLASSES and magic_count >= 2:
			return
		if class_id in PHYSICAL_CLASSES and physical_count >= 2:
			return

		selected_classes.append(class_id)

	_update_selection_label()
	_update_button_states()
	description_label.text = CLASS_DATA[class_id].description
	confirm_button.disabled = selected_classes.size() != MAX_SELECTION


func _update_button_states():
	var magic_count = selected_classes.filter(func(c): return c in MAGIC_CLASSES).size()
	var physical_count = selected_classes.filter(func(c): return c in PHYSICAL_CLASSES).size()

	for box in class_grid.get_children():
		var button = box.get_child(1)
		var class_id = button.name
		var is_selected = class_id in selected_classes

		if is_selected:
			button.disabled = false
			button.modulate.a = 1.0  # Totalmente visível
		elif class_id in MAGIC_CLASSES and magic_count >= 2:
			button.disabled = true
			button.modulate.a = 0.3  # Transparente
		elif class_id in PHYSICAL_CLASSES and physical_count >= 2:
			button.disabled = true
			button.modulate.a = 0.3
		else:
			button.disabled = false
			button.modulate.a = 1.0

func _update_selection_label():
	selection_label.text = "Selecionados: %d/%d" % [selected_classes.size(), MAX_SELECTION]

func _on_confirm_pressed():
	# Armazene os dados selecionados para próxima cena
	Global.party_selection = selected_classes.duplicate()
	get_tree().change_scene_to_file("res://decades/1990s/Game1990.tscn")
