extends CanvasLayer

signal action_selected(action_name)
signal end_turn_pressed
signal move_requested

@onready var panel := $ActionPanel
@onready var attack_btn := $ActionPanel/AttackButton
@onready var defend_btn := $ActionPanel/DefendButton
@onready var end_turn_btn := $ActionPanel/EndTurnButton
@onready var move_btn := $ActionPanel/MoveButton

@onready var target_selector = $TargetSelector

var current_character: CombatCharacter2020 = null

func _ready():
	hide()
	_connect_buttons()

func _connect_buttons():
	attack_btn.pressed.connect(_on_attack_pressed)
	defend_btn.pressed.connect(_on_defend_pressed)
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	move_btn.pressed.connect(func(): emit_signal("move_requested"))
	

# -------------------------------------------------------------------
# MOSTRAR / ESCONDER HUD DURANTE O TURNO
# -------------------------------------------------------------------
func show_action_menu(character: CombatCharacter2020):
	current_character = character
	panel.visible = true
	show()
	_update_button_states()

func hide_action_menu():
	current_character = null
	panel.visible = false
	hide()

# -------------------------------------------------------------------
# REGRAS DE HABILITAÇÃO DOS BOTÕES
# -------------------------------------------------------------------
func _update_button_states():
	if current_character == null:
		_disable_all()
		return

	# ATENÇÃO: Em BG3-style só permite ação se o personagem tiver recursos
	attack_btn.disabled = not current_character.has_action
	defend_btn.disabled = not current_character.has_action
	end_turn_btn.disabled = false


func _disable_all():
	attack_btn.disabled = true
	defend_btn.disabled = true
	end_turn_btn.disabled = true

# -------------------------------------------------------------------
# BOTÕES DE AÇÃO
# -------------------------------------------------------------------
func _on_attack_pressed():
	if current_character and current_character.has_action:
		emit_signal("action_selected", "attack")


func _on_defend_pressed():
	if current_character and current_character.has_action:
		emit_signal("action_selected", "defend")

func _on_item_pressed():
	if current_character and current_character.has_action:
		emit_signal("action_selected", "item")

func _on_end_turn_pressed():
	emit_signal("end_turn_pressed")

# -------------------------------------------------------------------
# SELEÇÃO DE ALVO (BG3-style)
# -------------------------------------------------------------------
func show_target_selector(targets: Array, callback: Callable):
	target_selector.clear()
	for t in targets:
		target_selector.add_item(t.name)

	target_selector.show()

	target_selector.item_selected.connect(func(index):
		target_selector.hide()
		callback.call(targets[index])
	, CONNECT_ONE_SHOT)
	
func disable_all_buttons():
	attack_btn.disabled = true
	defend_btn.disabled = true
	end_turn_btn.disabled = true

func enable_buttons_for(character):
	current_character = character
	attack_btn.disabled = not character.has_action
	defend_btn.disabled = not character.has_action
	end_turn_btn.disabled = false
	
# ------- adicione ao CombatHUD2020.gd -------

@onready var turn_order_panel := $TurnOrderPanel
@onready var turn_order_list := $TurnOrderPanel/OrderList

# Atualiza a lista inteira (passa um array de characters)
func show_turn_order(chars: Array) -> void:
	for child in turn_order_list.get_children():
		child.queue_free()
	for i in range(chars.size()):
		var c = chars[i]
		var name = ""
		if is_instance_valid(c) and c.has_method("name"):
			name = c.name
		else:
			name = str(c)
		var label = Label.new()
		label.name = "Turn_%d" % i
		label.text = "%d. %s  (HP: %d)" % [i+1, name, (c.hp if is_instance_valid(c) else 0)]
		turn_order_list.add_child(label)

# Destaque qual índice é o turno atual (inteiro)
func highlight_turn_index(idx: int) -> void:
	for i in range(turn_order_list.get_child_count()):
		var label = turn_order_list.get_child(i)
		if i == idx:
			label.add_theme_color_override("font_color", Color(1, 0.9, 0.3)) # amarelo
			label.set("custom_fonts/font", null) # opcional
		else:
			label.add_theme_color_override("font_color", Color(1,1,1))

# Atualiza HPs na lista (chame sempre depois de dano/curas)
func update_turn_hp(chars: Array) -> void:
	for i in range(chars.size()):
		if i >= turn_order_list.get_child_count(): continue
		var c = chars[i]
		var label = turn_order_list.get_child(i)
		if is_instance_valid(c):
			label.text = "%d. %s  (HP: %d)" % [i+1, c.name, c.hp]

# -----------------------------
# PAINEL DE INFORMAÇÃO DO TURNO
# -----------------------------
@onready var turn_info_panel := $TurnInfoPanel
@onready var action_info_label := $TurnInfoPanel/VBoxContainer/ActionInfoLabel
@onready var move_info_label := $TurnInfoPanel/VBoxContainer/MoveInfoLabel

func update_turn_info(character):
	if not is_instance_valid(character):
		turn_info_panel.visible = false
		return

	turn_info_panel.visible = true

	# AÇÃO (apenas 1 ação por turno no seu sistema)
	var action_text = ""
	if character.has_action:
		action_text = "Ação: ✔ Disponível"
	else:
		action_text = "Ação: ✖ Já usada"

	action_info_label.text = action_text

	# MOVIMENTO
	var rm = round(character.remaining_movement * 10) / 10.0
	var maxm = round(character.max_movement * 10) / 10.0
	move_info_label.text = "Movimento: %s m / %s m" % [rm, maxm]
