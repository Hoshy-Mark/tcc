extends CanvasLayer

signal action_selected(action_name: String)
signal magic_selected(spell_name: String)
signal target_selected(alvo)
signal item_selected(item_name: String)
signal shop_buy_requested(item_name: String)
signal shop_equip_requested(item: Dictionary)
signal shop_closed
signal _continue_confirmed

var party_panels := {}

# --- Pacing "aperte para continuar" ---
# Em vez de resolver ações num timer fixo, o combate pausa em cada
# mensagem até o jogador confirmar (clique ou ENTER/espaço), como nos
# RPGs de 1980 (Dragon Quest, Wizardry, Ultima).
var _waiting_for_continue := false

@onready var magic_menu = $MagicMenu
@onready var party_info = $Panel/PartyInfo
@onready var log_text_edit = $LogPanel/LogTextEdit
@onready var continue_prompt = $LogPanel/ContinuePrompt
@onready var target_window = $WindowTargetSelection
@onready var target_container = $WindowTargetSelection/ScrollContainer/VBoxContainer
@onready var item_window = $ItemWindow
@onready var enemy_info = $EnemyInfo
@onready var item_vbox = $ItemWindow/ScrollContainer/VBoxContainer
@onready var shop_window = $ShopWindow
@onready var shop_vbox = $ShopWindow/ScrollContainer/VBoxContainer

func _ready():
	# Caixa alta nos textos fixos da UI: convenção comum em RPGs de 1980
	# (Dragon Quest, Ultima, Wizardry), que rodavam com fontes bitmap sem
	# minúsculas ou com minúsculas pouco legíveis em telas de baixa resolução.
	$VBoxContainer/Button.text = "ATACAR"
	$VBoxContainer/Button2.text = "MAGIA"
	$VBoxContainer/Button3.text = "DEFENDER"
	$VBoxContainer/Button4.text = "FUGIR"
	$VBoxContainer/Button5.text = "ITEM"
	target_window.hide()
	item_window.hide()
	get_viewport().gui_embed_subwindows = true

	log_text_edit.add_theme_font_size_override("normal_font_size", 10)

	magic_menu.mode = Window.MODE_WINDOWED
	magic_menu.borderless = true
	magic_menu.unresizable = true
	magic_menu.position = Vector2(1200, 150)
	
	item_window.mode = Window.MODE_WINDOWED
	item_window.borderless = true
	item_window.unresizable = true
	item_window.position = Vector2(1330, 150)
	
	target_window.mode = Window.MODE_WINDOWED
	target_window.borderless = true
	target_window.unresizable = true
	target_window.position = Vector2(1070, 150)

	shop_window.mode = Window.MODE_WINDOWED
	shop_window.borderless = true
	shop_window.unresizable = true
	shop_window.position = Vector2(1200, 470)
	shop_window.hide()

	$VBoxContainer/Button5.pressed.connect(func(): emit_signal("action_selected", "item"))
	$VBoxContainer/Button.pressed.connect(func(): emit_signal("action_selected", "attack"))
	$VBoxContainer/Button2.pressed.connect(func(): emit_signal("action_selected", "magic"))
	$VBoxContainer/Button3.pressed.connect(func(): emit_signal("action_selected", "defend"))
	$VBoxContainer/Button4.pressed.connect(func(): emit_signal("action_selected", "flee"))
	
func show_target_selection(alvos: Array, _spell_type: String) -> void:
	clear(target_window)

	var max_button_width := 0

	for alvo in alvos:
		var botao = Button.new()
		botao.text = alvo.nome
		botao.custom_minimum_size = Vector2(200, 60)
		botao.add_theme_font_size_override("font_size", 24)
		botao.pressed.connect(Callable(self, "_on_target_button_pressed").bind(alvo))
		target_container.add_child(botao)

		# Medir largura do texto
		var font := botao.get_theme_font("font")
		var font_size := botao.get_theme_font_size("font_size")
		var width := font.get_string_size(botao.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 40
		max_button_width = max(max_button_width, width)

	# Botão Voltar
	var voltar_btn = Button.new()
	voltar_btn.text = "VOLTAR"
	voltar_btn.custom_minimum_size = Vector2(200, 60)
	voltar_btn.add_theme_font_size_override("font_size", 24)
	voltar_btn.pressed.connect(_on_voltar_target_btn_pressed)
	target_container.add_child(voltar_btn)

	# Aplicar tamanho final
	max_button_width = max(max_button_width, 200)
	var popup_height := 300
	target_window.set_size(Vector2(max_button_width, popup_height))
	target_window.get_node("ScrollContainer").custom_minimum_size = Vector2(max_button_width, popup_height)
	target_window.popup()

func _on_target_button_pressed(alvo):
	emit_signal("target_selected", alvo)
	target_window.hide()

func show_item_menu(inventario: Dictionary) -> void:
	clear(item_window)

	var max_button_width := 0

	for item_name in inventario.keys():
		var quantidade = inventario[item_name]
		if quantidade <= 0:
			continue

		var botao = Button.new()
		botao.text = "%s (x%d)" % [item_name, quantidade]
		botao.custom_minimum_size = Vector2(200, 60)
		botao.add_theme_font_size_override("font_size", 20)
		botao.pressed.connect(_on_item_button_pressed.bind(item_name))
		item_vbox.add_child(botao)

		# Medir largura do texto
		var font := botao.get_theme_font("font")
		var font_size := botao.get_theme_font_size("font_size")
		var width := font.get_string_size(botao.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 40
		max_button_width = max(max_button_width, width)

	# Botão Voltar
	var voltar_btn = Button.new()
	voltar_btn.text = "VOLTAR"
	voltar_btn.custom_minimum_size = Vector2(200, 60)
	voltar_btn.add_theme_font_size_override("font_size", 24)
	voltar_btn.pressed.connect(func(): 
		item_window.hide()
		set_enabled(true)
	)
	item_vbox.add_child(voltar_btn)
	
	# Aplicar tamanho final
	max_button_width = max(max_button_width, 200)
	var popup_height := 300
	item_window.set_size(Vector2(max_button_width, popup_height))
	item_window.get_node("ScrollContainer").custom_minimum_size = Vector2(max_button_width, popup_height)
	item_window.popup()

func set_enabled(enabled: bool):
	$VBoxContainer/Button.disabled = not enabled
	$VBoxContainer/Button2.disabled = not enabled
	$VBoxContainer/Button3.disabled = not enabled
	$VBoxContainer/Button4.disabled = not enabled
	$VBoxContainer/Button5.disabled = not enabled

func add_log_entry(text: String) -> void:
	log_text_edit.text += text + "\n"

# Pausa o fluxo até o jogador confirmar a mensagem (clique do mouse ou
# ENTER/espaço). Chamado pelo BattleManager no lugar do antigo timer fixo.
func wait_for_continue() -> void:
	_waiting_for_continue = true
	continue_prompt.show()
	await _continue_confirmed
	continue_prompt.hide()

func _unhandled_input(event: InputEvent) -> void:
	if not _waiting_for_continue:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		_waiting_for_continue = false
		get_viewport().set_input_as_handled()
		_continue_confirmed.emit()

func _on_voltar_target_btn_pressed():
	target_window.hide()
	set_enabled(true)
	
func _on_item_button_pressed(item_name: String):
	item_window.hide()
	emit_signal("item_selected", item_name)

# --- Loja (entre batalhas) ---
func show_shop(gold: int, inventario: Dictionary, consumable_prices: Dictionary, equipment_catalog: Array) -> void:
	clear(shop_window)

	var gold_label = Label.new()
	gold_label.text = "OURO: %d" % gold
	gold_label.add_theme_font_size_override("font_size", 22)
	shop_vbox.add_child(gold_label)

	var consumables_label = Label.new()
	consumables_label.text = "-- CONSUMÍVEIS --"
	shop_vbox.add_child(consumables_label)

	for item_name in consumable_prices.keys():
		var price = consumable_prices[item_name]
		var quantidade = inventario.get(item_name, 0)
		var botao = Button.new()
		botao.text = "%s (x%d) - %dg" % [item_name, quantidade, price]
		botao.disabled = gold < price
		botao.custom_minimum_size = Vector2(260, 50)
		botao.add_theme_font_size_override("font_size", 18)
		botao.pressed.connect(_on_shop_buy_pressed.bind(item_name))
		shop_vbox.add_child(botao)

	var equip_label = Label.new()
	equip_label.text = "-- EQUIPAMENTOS --"
	shop_vbox.add_child(equip_label)

	for item in equipment_catalog:
		var price = item.get("price", 0)
		var bonus_text = ""
		if item.has("strength_bonus"):
			bonus_text = "+%d ATQ" % item["strength_bonus"]
		elif item.has("defense_bonus"):
			bonus_text = "+%d DEF" % item["defense_bonus"]
		var botao = Button.new()
		botao.text = "%s (%s) - %dg" % [item.get("nome", "?"), bonus_text, price]
		botao.disabled = gold < price
		botao.custom_minimum_size = Vector2(260, 50)
		botao.add_theme_font_size_override("font_size", 18)
		botao.pressed.connect(_on_shop_equip_pressed.bind(item))
		shop_vbox.add_child(botao)

	var continuar_btn = Button.new()
	continuar_btn.text = "CONTINUAR"
	continuar_btn.custom_minimum_size = Vector2(260, 50)
	continuar_btn.add_theme_font_size_override("font_size", 20)
	continuar_btn.pressed.connect(_on_shop_continue_pressed)
	shop_vbox.add_child(continuar_btn)

	shop_window.set_size(Vector2(300, 420))
	shop_window.get_node("ScrollContainer").custom_minimum_size = Vector2(300, 420)
	shop_window.popup()

func _on_shop_buy_pressed(item_name: String) -> void:
	emit_signal("shop_buy_requested", item_name)

func _on_shop_equip_pressed(item: Dictionary) -> void:
	emit_signal("shop_equip_requested", item)

func _on_shop_continue_pressed() -> void:
	shop_window.hide()
	emit_signal("shop_closed")

func update_enemy_status(enemies: Array) -> void:
	clear_container($EnemyInfo)

	for enemy in enemies:
		var panel = Panel.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(1, 0, 0)
		style.anti_aliasing = false
		panel.add_theme_stylebox_override("panel", style)
		panel.custom_minimum_size = Vector2(180, 100)

		var margin_container = MarginContainer.new()
		margin_container.add_theme_constant_override("margin_left", 8)
		margin_container.add_theme_constant_override("margin_top", 8)
		margin_container.add_theme_constant_override("margin_right", 8)
		margin_container.add_theme_constant_override("margin_bottom", 8)

		var box = VBoxContainer.new()

		var name_label = Label.new()
		name_label.text = enemy.nome
		name_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
		box.add_child(name_label)

		var hp_label = Label.new()
		hp_label.text = "HP: %d/%d" % [enemy.current_hp, enemy.max_hp]
		box.add_child(hp_label)

		var mp_label = Label.new()
		mp_label.text = "MP: %d/%d" % [enemy.current_mp, enemy.max_mp]
		box.add_child(mp_label)

		margin_container.add_child(box)
		panel.add_child(margin_container)
		$EnemyInfo.add_child(panel)

func show_magic_menu(player: PlayerPartyMember, magias := {}) -> void:
	# Usa todas as magias se nenhuma lista personalizada for passada
	if magias.is_empty():
		magias = player.spells

	clear(magic_menu)

	var scroll = magic_menu.get_node("ScrollContainer")
	var vbox = scroll.get_node("VBoxContainer")

	var max_button_width := 0

	for spell_name in magias.keys():
		var spell = magias[spell_name]
		var slot_level = spell.get("level", 1)
		var slots_disponiveis = player.spell_slots.get(slot_level, 0)

		var button = Button.new()
		var texto = "%s | MP: %d | " % [spell_name.capitalize(), spell["cost"]]

		match spell.get("type", "damage"):
			"damage":
				var power_min = spell.get("power", 0)
				var power_max = spell.get("power_max", power_min)
				texto += "Poder: %d-%d | " % [power_min, power_max]
			"heal":
				var power = spell.get("power", 0)
				texto += "Cura: %d | " % [-power]
			"buff":
				var attr = spell.get("attribute", "atributo")
				var amount = spell.get("amount", 0)
				texto += "Buff %s %+d | " % [attr.capitalize(), amount]
			"debuff":
				var attr = spell.get("attribute", "atributo")
				var amount = spell.get("amount", 0)
				texto += "Debuff %s %d | " % [attr.capitalize(), amount]

		texto += "Slots: %d" % slots_disponiveis
		button.text = texto
		button.disabled = (player.mp < spell["cost"] or slots_disponiveis <= 0)
		button.custom_minimum_size = Vector2(200, 60)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_on_spell_button_pressed.bind(spell_name))
		vbox.add_child(button)

		# Medir largura do texto
		var font := button.get_theme_font("font")
		var font_size := button.get_theme_font_size("font_size")
		var width := font.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 40
		max_button_width = max(max_button_width, width)

	# Botão Voltar
	var voltar_btn = Button.new()
	voltar_btn.text = "VOLTAR"
	voltar_btn.custom_minimum_size = Vector2(200, 60)
	voltar_btn.add_theme_font_size_override("font_size", 24)
	voltar_btn.pressed.connect(_on_voltar_btn_pressed)
	vbox.add_child(voltar_btn)

	max_button_width = max(max_button_width, 200)
	var popup_height := 300
	magic_menu.set_size(Vector2(max_button_width, popup_height))
	scroll.custom_minimum_size = Vector2(max_button_width, popup_height)
	magic_menu.popup()
	
func _on_spell_button_pressed(spell_name):
	magic_menu.hide()
	emit_signal("magic_selected", spell_name)
	
func _on_voltar_btn_pressed():
	magic_menu.hide()
	set_enabled(true)
	


func update_party_info(party_members: Array) -> void:
	clear_container(party_info)
	party_panels.clear()

	for member in party_members:
		var panel = Panel.new()
		var style = _create_default_panel_style()
		panel.add_theme_stylebox_override("panel", style)
		panel.custom_minimum_size = Vector2(160, 100)

		var margin_container = MarginContainer.new()
		margin_container.add_theme_constant_override("margin_left", 8)
		margin_container.add_theme_constant_override("margin_top", 8)
		margin_container.add_theme_constant_override("margin_right", 8)
		margin_container.add_theme_constant_override("margin_bottom", 8)

		var vbox = VBoxContainer.new()

		# Nome
		var name_label = Label.new()
		name_label.text = member.nome
		name_label.add_theme_color_override("font_color", Color.WHITE)
		vbox.add_child(name_label)

		# Linha 1: HP e Nível
		var row1 = HBoxContainer.new()
		var hp_label = Label.new()
		hp_label.text = "HP: %d/%d" % [member.hp, member.max_hp]
		row1.add_child(hp_label)

		var spacer1 = Control.new()
		spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row1.add_child(spacer1)

		var level_label = Label.new()
		level_label.text = "  LV: %d" % member.level
		row1.add_child(level_label)

		vbox.add_child(row1)

		# Linha 2: MP e XP
		var row2 = HBoxContainer.new()
		var mp_label = Label.new()
		mp_label.text = "MP: %d/%d" % [member.mp, member.max_mp]
		row2.add_child(mp_label)

		var spacer2 = Control.new()
		spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(spacer2)

		var xp_label = Label.new()
		xp_label.text = "  XP: %d" % member.xp
		row2.add_child(xp_label)

		vbox.add_child(row2)


		margin_container.add_child(vbox)
		panel.add_child(margin_container)
		party_info.add_child(panel)

		# Salva a referência
		party_panels[member] = panel

func _create_default_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 1, 1)
	style.anti_aliasing = false
	return style

func highlight_current_player(current_player):
	for member in party_panels.keys():
		var panel = party_panels[member]
		var style = _create_default_panel_style()

		if member == current_player:
			style.border_color = Color(0, 1, 1)  # Ciano saturado (paleta alto-contraste)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
		panel.add_theme_stylebox_override("panel", style)

func clear_container(container):
	var children = container.get_children()
	for child in children:
		container.remove_child(child)
		child.queue_free()

func clear(container):
	var vbox = container.get_node("ScrollContainer/VBoxContainer")
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.queue_free()
