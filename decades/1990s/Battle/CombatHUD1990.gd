extends CanvasLayer

signal action_selected(action_name: String)
signal magic_selected(spell_name: String)
signal target_selected(alvo)
signal item_selected(item_name: String)
signal skill_selected(skill_name: String)
signal special_selected(special)
signal line_target_selected(linha: String)
signal back_pressed

@onready var action_panel = $HUDPanel/ActionPanel
@onready var magic_panel = $HUDPanel/MagicPanel
@onready var item_panel = $HUDPanel/ItemPanel
@onready var target_panel = $HUDPanel/TargetPanel
@onready var vbox_magic_list = $HUDPanel/MagicPanel/VBoxMagicList
@onready var vbox_item_list = $HUDPanel/ItemPanel/VBoxItemList
@onready var vbox_target_list = $HUDPanel/TargetPanel/VBoxTargetList
@onready var hud_panel = $HUDPanel
@onready var top_message = $TopMessage
@onready var PartyInfo = $PartyStatus/PartyInfo
@onready var PartyStatus = $PartyStatus
@onready var EnemyStatus = $EnemyStatus/EnemyInfo
@onready var gray_arrow_texture := preload("res://assets/Seta Desabilitada.png")
@onready var normal_arrow_texture := preload("res://assets/Seta.png")

var arrow_instance: Node2D = null
var atb_bars = {}
var special_bars = {} 
var special_buttons := []
var buttons = {}
var current_player_node: Node = null

func _ready():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.3)
	style.border_color = Color(0.5, 0.5, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	
	PartyStatus.add_theme_stylebox_override("panel", style)
	hud_panel.add_theme_stylebox_override("panel", style.duplicate()) # <- Aqui a moldura do painel de ações

	_create_action_buttons()
	show_action_menu()
	magic_panel.custom_minimum_size = Vector2(500, 210)
	item_panel.custom_minimum_size = Vector2(500, 210)
	target_panel.custom_minimum_size = Vector2(500, 210)

func _create_action_buttons(player = null):
	clear(action_panel)
	buttons.clear()
	var actions = ["Atacar"]
	if player and player.is_magic_user():
		actions.append("Magia")
	else:
		actions.append("Skills")
	actions += ["Defender", "Fugir", "Item", "Especial"]
	for action_name in actions:
		var button = Button.new()
		button.text = action_name
		button.name = action_name
		
		if action_name == "Especial" and player != null:
			button.disabled = not player.special_ready
		
		button.pressed.connect(_on_action_button_pressed.bind(action_name))
		action_panel.add_child(button)
		buttons[action_name] = button



# MOSTRAR MENUS


func show_skill_menu(skills: Array, player_sp: int):
	_hide_all_panels()
	clear(vbox_magic_list) # reutilizar o mesmo painel da magia
	magic_panel.visible = true
	
	for skill in skills:
		var button = Button.new()
		button.text = "%s | SP: %d" % [skill.name, skill.cost]
		button.disabled = player_sp < skill.cost
		button.custom_minimum_size = Vector2(500, 40)
		button.pressed.connect(_on_skill_button_pressed.bind(skill.name))
		vbox_magic_list.add_child(button)

	# Botão de voltar	
	var back_button = Button.new()
	back_button.text = "Voltar"
	back_button.custom_minimum_size = Vector2(500, 40)
	back_button.pressed.connect(_on_back_button_pressed)
	vbox_magic_list.add_child(back_button)

func show_target_menu(targets: Array, current_actor = null):
	_hide_all_panels()
	clear(vbox_target_list)
	target_panel.visible = true
	hide_arrow()

	# Ordenar alvos: primeiro os da frente, depois os de trás
	var front_targets = []
	var back_targets = []

	for t in targets:
		if t["node_ref"].position_line == "back":
			back_targets.append(t)
		else:
			front_targets.append(t)

	targets = front_targets + back_targets

	# Mostrar seta acima do primeiro alvo (opcional)
	if targets.size() > 0:
		var selected_enemy = targets[0]["node_ref"]
		show_arrow_above_node(selected_enemy)

	for target in targets:
		var button = Button.new()
		var enemy_node = target["node_ref"]
		var is_desabilitado = false

		if not enemy_node.is_alive():
			is_desabilitado = true
		elif current_actor != null and enemy_node.obstruido and not current_actor.alcance_estendido:
			is_desabilitado = true

		button.text = target["nome"]
		button.custom_minimum_size = Vector2(500, 40)
		button.disabled = is_desabilitado

		button.mouse_entered.connect(func():
			if arrow_instance and target.has("node_ref"):
				var target_pos = enemy_node.get_global_position() + Vector2(0, -90)
				arrow_instance.initialize(target_pos)
				if is_desabilitado:
					arrow_instance.arrow_sprite.texture = gray_arrow_texture
				else:
					arrow_instance.arrow_sprite.texture = normal_arrow_texture
		)

		if not is_desabilitado:
			button.pressed.connect(_on_target_button_pressed.bind(target["id"]))

		vbox_target_list.add_child(button)

	# Botão de voltar
	var back_button = Button.new()
	back_button.text = "Voltar"
	back_button.custom_minimum_size = Vector2(500, 40)
	back_button.pressed.connect(_on_back_button_pressed)
	vbox_target_list.add_child(back_button)

func show_item_menu(items: Dictionary):
	_hide_all_panels()
	item_panel.visible = true
	clear(vbox_item_list)

	for item_name in items.keys():
		var button = Button.new()
		button.text = "%s (x%d)" % [item_name, items[item_name]]
		button.custom_minimum_size = Vector2(500, 40)
		vbox_item_list.add_child(button)
		button.pressed.connect(_on_item_pressed.bind(item_name))
	
	# Botão de voltar	
	var back_button = Button.new()
	back_button.text = "Voltar"
	back_button.custom_minimum_size = Vector2(500, 40)
	back_button.pressed.connect(_on_back_button_pressed)
	vbox_item_list.add_child(back_button)

func show_magic_menu(spells: Dictionary, player_mp: int, spell_slots: Dictionary) -> void:
	_hide_all_panels()
	magic_panel.visible = true
	clear(vbox_magic_list)

	for spell_name in spells.keys():
		var spell = spells[spell_name]
		var slot_level = spell.level
		var slots_disponiveis = spell_slots.get(slot_level, 0)



		var button = Button.new()
		button.text = "%s | MP: %d | Slots: %d" % [spell_name.capitalize(), spell.cost, slots_disponiveis]
		button.disabled = (player_mp < spell.cost or slots_disponiveis <= 0)
		button.custom_minimum_size = Vector2(500, 40)
		button.pressed.connect(_on_spell_button_pressed.bind(spell_name))
		vbox_magic_list.add_child(button)
	
	# Botão de voltar	
	var back_button = Button.new()
	back_button.text = "Voltar"
	back_button.custom_minimum_size = Vector2(500, 40)
	back_button.pressed.connect(_on_back_button_pressed)
	vbox_magic_list.add_child(back_button)

func show_special_menu(specials: Array) -> void:
	_hide_all_panels()
	clear(vbox_magic_list) # reutilizar o mesmo painel da magia
	magic_panel.visible = true
	
	for special in specials:
		var button = Button.new()
		button.text = "%s" % special.name
		button.custom_minimum_size = Vector2(500, 40)
		button.pressed.connect(_on_special_button_pressed.bind(special))
		vbox_magic_list.add_child(button)
	
	# Botão de voltar
	var back_button = Button.new()
	back_button.text = "Voltar"
	back_button.custom_minimum_size = Vector2(500, 40)
	back_button.pressed.connect(_on_back_button_pressed)
	vbox_magic_list.add_child(back_button)

func show_action_menu(player = null):
	_hide_all_panels()
	_create_action_buttons(player)
	set_hud_buttons_enabled(false)  # Por padrão, desabilita até ativar no momento certo
	action_panel.visible = true

	if player:
		current_player_node = player  # ← usado para seta e botão
		indicate_current_player(player)

func show_line_target_menu(options: Array):
	_hide_all_panels()
	clear(vbox_target_list)
	target_panel.visible = true

	for linha in options:
		var button = Button.new()
		button.text = "Linha da " + linha.capitalize()  # Ex: "Linha da Frente"
		button.custom_minimum_size = Vector2(500, 40)
		button.pressed.connect(func():
			emit_signal("line_target_selected", linha)
			_hide_all_panels()
		)
		vbox_target_list.add_child(button)

	# Botão de voltar
	var back_button = Button.new()
	back_button.text = "Voltar"
	back_button.custom_minimum_size = Vector2(500, 40)
	back_button.pressed.connect(_on_back_button_pressed)
	vbox_target_list.add_child(back_button)


# PRESSIONAR BOTÃO


func _on_skill_button_pressed(skill_name: String) -> void:
	magic_panel.visible = false
	emit_signal("skill_selected", skill_name)

func _on_target_button_pressed(target_id: String) -> void:
	if arrow_instance:
		arrow_instance.queue_free()
		arrow_instance = null
	emit_signal("target_selected", target_id)
	_hide_all_panels()
	show_action_menu(current_player_node)

func _on_spell_button_pressed(spell_name: String) -> void:
	magic_panel.visible = false
	emit_signal("magic_selected", spell_name)

func _on_item_pressed(item_name: String):
	item_selected.emit(item_name)

func _on_back_button_pressed() -> void:
	emit_signal("back_pressed")

func _on_action_button_pressed(action_name: String) -> void:
	emit_signal("action_selected", action_name)

func _on_special_button_pressed(special) -> void:
	special_selected.emit(special)


# UPDATES


func update_enemy_info(enemies: Array) -> void:
	clear(EnemyStatus)

	for enemy in enemies:
		var panel = Panel.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0, 0)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(1, 0.3, 0.3)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		panel.add_theme_stylebox_override("panel", style)
		panel.custom_minimum_size = Vector2(180, 100)

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_bottom", 8)

		var vbox = VBoxContainer.new()

		var name_label = Label.new()
		name_label.text = enemy.nome
		name_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
		vbox.add_child(name_label)

		var hp_label = Label.new()
		hp_label.text = "HP: %d/%d" % [enemy.current_hp, enemy.max_hp]
		vbox.add_child(hp_label)

		var mp_label = Label.new()
		mp_label.text = "MP: %d/%d" % [enemy.current_mp, enemy.max_mp]
		vbox.add_child(mp_label)

		margin.add_child(vbox)
		panel.add_child(margin)
		EnemyStatus.add_child(panel)

func update_party_info(party_members: Array) -> void:
	
	clear(PartyInfo)
	atb_bars.clear()
	special_bars.clear()
	
	for member in party_members:
		var hbox = Control.new()
		hbox.add_theme_constant_override("separation", 16)
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.custom_minimum_size = Vector2(0, 45)
		
		var name_label = Label.new()
		name_label.text = member.nome
		name_label.set_position(Vector2(20, 10))
		name_label.custom_minimum_size = Vector2(200, 40)
		name_label.add_theme_font_size_override("font_size", 22)
		hbox.add_child(name_label)
		
		# HP
		var hp_label = Label.new()
		hp_label.text = "HP %d/%d" % [member.current_hp, member.max_hp]
		hp_label.set_position(Vector2(220, 10))
		hp_label.custom_minimum_size = Vector2(200, 40)
		hp_label.add_theme_font_size_override("font_size", 22)
		hbox.add_child(hp_label)
		
		# Level
		var level_label = Label.new()
		level_label.text = "Lv %d" % member.level
		level_label.set_position(Vector2(440, 10))
		level_label.custom_minimum_size = Vector2(100, 40)
		level_label.add_theme_font_size_override("font_size", 22)
		hbox.add_child(level_label)
		
		# XP
		var xp_label = Label.new()
		xp_label.text = "XP %d" % member.xp
		xp_label.set_position(Vector2(560, 10))
		xp_label.custom_minimum_size = Vector2(120, 40)
		xp_label.add_theme_font_size_override("font_size", 22)
		hbox.add_child(xp_label)
		
		# Container manual para a ATB
		var atb_container = Control.new()
		atb_container.custom_minimum_size = Vector2(200, 40)

		# Texto "Tempo"
		var atb_label = Label.new()
		atb_label.text = "Tempo"
		atb_label.add_theme_font_size_override("font_size", 10)
		atb_label.set_position(Vector2(780, 3))  # Posição em pixels
		atb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		atb_label.size_flags_horizontal = Control.SIZE_FILL
		atb_container.add_child(atb_label)

		# Barra ATB
		var atb_bar = ProgressBar.new()
		atb_bar.min_value = 0
		atb_bar.max_value = 100
		atb_bar.value = member.atb_value
		atb_bar.show_percentage = false
		atb_bar.custom_minimum_size = Vector2(200, 20)
		atb_bar.set_position(Vector2(700, 18))  # Y = 15 pixels abaixo do label
		atb_bar.size_flags_horizontal = Control.SIZE_FILL

		# Cores
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0, 0, 1)
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = Color(1, 1, 0)
		atb_bar.add_theme_stylebox_override("background", bg_style)
		atb_bar.add_theme_stylebox_override("fill", fill_style)

		atb_container.add_child(atb_bar)
		hbox.add_child(atb_container)
		atb_bars[member] = atb_bar
		
		# Container manual para a Especial
		var sp_container = Control.new()
		sp_container.custom_minimum_size = Vector2(200, 40)

		# Texto "Especial"
		var sp_label = Label.new()
		sp_label.text = "Especial"
		sp_label.add_theme_font_size_override("font_size", 10)
		sp_label.set_position(Vector2(1050, 2))  # Alinhado com o "Tempo"
		sp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sp_label.size_flags_horizontal = Control.SIZE_FILL
		sp_container.add_child(sp_label)

		# Barra Especial
		var sp_bar = ProgressBar.new()
		sp_bar.min_value = 0
		sp_bar.max_value = 100
		sp_bar.value = member.special_charge
		sp_bar.show_percentage = false
		sp_bar.custom_minimum_size = Vector2(200, 20)
		sp_bar.set_position(Vector2(970, 18))  # Mesmo Y da barra ATB
		sp_bar.size_flags_horizontal = Control.SIZE_FILL

		# Cores barra especial (fundo cinza escuro, barra laranja)
		var bg_sp_style = StyleBoxFlat.new()
		bg_sp_style.bg_color = Color(0.2, 0.2, 0.2)  # cinza escuro
		var fill_sp_style = StyleBoxFlat.new()
		fill_sp_style.bg_color = Color(1, 0.5, 0)  # laranja
		sp_bar.add_theme_stylebox_override("background", bg_sp_style)
		sp_bar.add_theme_stylebox_override("fill", fill_sp_style)

		sp_container.add_child(sp_bar)
		hbox.add_child(sp_container)
		special_bars[member] = sp_bar

		# Salva a barra no dicionário para atualizar depois
		atb_bars[member] = atb_bar
		
		PartyInfo.add_child(hbox)
		
	PartyStatus.custom_minimum_size = Vector2(1200, 205)

func update_special_bar(special_values):
	for member in special_bars.keys(): 
		if special_values.has(member): 
			special_bars[member].value = special_values[member]
			if buttons.has("Especial") and member == current_player_node:
				buttons["Especial"].disabled = special_values[member] < 100

func update_atb_bars(atb_values):
	for member in atb_bars.keys():
		if atb_values.has(member):
			atb_bars[member].value = atb_values[member]


# EFEITOS VISUAIS


func show_floating_number(value: int, node: Node, tipo_valor: String = "hp") -> void:
	var floating_number_scene = load("res://decades/1990s/Battle/FloatingNumber.tscn")
	var instance = floating_number_scene.instantiate()
	add_child(instance)

	var position = node.get_global_position() + Vector2(0, -100)
	instance.initialize(value, position, tipo_valor)

func show_arrow_above_node(target_node: Node):
	if arrow_instance:
		arrow_instance.queue_free()

	var arrow_scene = load("res://decades/1990s/Battle/ArrowIndicator.tscn")
	arrow_instance = arrow_scene.instantiate()
	add_child(arrow_instance)

	var target_pos = target_node.get_global_position() + Vector2(0, -90)
	arrow_instance.initialize(target_pos)
	arrow_instance.scale = Vector2(0.2, 0.2)

func show_top_message(text: String, duration := 2.0):
	top_message.text = text
	top_message.visible = true
	await get_tree().create_timer(duration).timeout
	top_message.visible = false


# OCULTAR


func hide_arrow():
	if arrow_instance:
		arrow_instance.queue_free()
		arrow_instance = null

func _hide_all_panels():
	action_panel.visible = false
	magic_panel.visible = false
	item_panel.visible = false
	target_panel.visible = false

func hide_special_menu() -> void:
	if has_node("SpecialMenu"):
		get_node("SpecialMenu").queue_free()
	special_buttons.clear()

func hide_special_button():
	if buttons.has("Especial"):
		buttons["Especial"].disabled = true


# AUXILIO


func clear(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func indicate_current_player(player_node: Node):
	show_arrow_above_node(player_node)

func set_hud_buttons_enabled(enabled: bool, player = null) -> void:
	for action_name in buttons.keys():
		var button = buttons[action_name]
		
		# Troca dinâmica do texto do botão "Skill" para "Magia" se for mago
		if action_name == "Skills" or action_name == "Magias" or action_name == " " :
			if player != null:
				if player and player.is_magic_user():
					button.text = "Magias"
				else:
					button.text = "Skills"
			else:
				button.text = " "

		# Caso especial: "Especial"
		if action_name == "Especial" and player != null:
			button.disabled = not player.special_ready

			# Criar estilo para fundo laranja se estiver habilitado
			if player.special_ready:
				var style_enabled = StyleBoxFlat.new()
				style_enabled.bg_color = Color(1, 0.5, 0)  # laranja
				button.add_theme_stylebox_override("normal", style_enabled)
			else:
				button.remove_theme_stylebox_override("normal")  # remove override e usa tema padrão
		else:
			button.disabled = not enabled
