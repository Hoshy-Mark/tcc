extends CanvasLayer

signal editor_closed

@onready var panel = $BackgroundPanel/HBoxContainer/Panel
@onready var background_panel = $BackgroundPanel
@onready var label_title = $BackgroundPanel/HBoxContainer/Panel/Label
@onready var slot_1 = $BackgroundPanel/HBoxContainer/Panel/VBoxContainer/Slot1/OptionButton
@onready var slot_2 = $BackgroundPanel/HBoxContainer/Panel/VBoxContainer/Slot2/OptionButton
@onready var slot_3 = $BackgroundPanel/HBoxContainer/Panel/VBoxContainer/Slot3/OptionButton
@onready var btn_confirm = $BackgroundPanel/HBoxContainer/Panel/ConfirmButton
@onready var btn_cancel = $BackgroundPanel/HBoxContainer/Panel/CancelButton
@onready var party_list = $BackgroundPanel/HBoxContainer/PartyList

var current_character: CombatCharacter = null
var available_gambits: Array = []  # Referências para Gambits
var active_gambits: Array = []
var party_members: Array = []

func _ready():
	hide()
	btn_confirm.pressed.connect(_on_confirm_pressed)
	btn_cancel.pressed.connect(_on_cancel_pressed)

	# Estilo visual: fundo azul, borda cinza
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#2b4f7d")
	style.border_color = Color("#888888")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)

	panel.add_theme_stylebox_override("panel", style)
	background_panel.add_theme_stylebox_override("panel", style)  # <- Aplica também aqui

func open_for_character(character: CombatCharacter):
	current_character = character
	available_gambits = GambitDefinitions.get_default_gambits()
	if character.has_meta("gambits"):
		
		active_gambits = character.gambits.duplicate(true)  # true = deep copy
	else:
		active_gambits = [null, null, null]

	label_title.text = "Editar Gambits de: %s" % character.name

	_fill_slot(slot_1, 0)
	_fill_slot(slot_2, 1)
	_fill_slot(slot_3, 2)

	show()
	_set_hud_enabled(false)

func _fill_slot(slot_button: OptionButton, slot_index: int):
	if slot_button == null:
		push_error("Slot %d está nulo!" % slot_index)
		return

	slot_button.clear()
	slot_button.add_item("Nenhum", -1)  # Primeira opção vazia

	for i in range(available_gambits.size()):
		var gambit = available_gambits[i]
		slot_button.add_item(gambit.description)
		slot_button.set_item_metadata(i + 1, gambit)  # +1 pois "Nenhum" é o 0

	var selected_gambit = active_gambits[slot_index]
	if selected_gambit != null:
		for i in range(available_gambits.size()):
			if available_gambits[i].id == selected_gambit.id:
				slot_button.select(i + 1)
				break
	else:
		slot_button.select(0)


func _on_confirm_pressed():
	if slot_1 == null or slot_2 == null or slot_3 == null:
		push_error("Um dos OptionButtons está nulo!")
		return
	
	var selections = [
		slot_1.get_selected_metadata(),
		slot_2.get_selected_metadata(),
		slot_3.get_selected_metadata()
	]

	# Aqui, você só precisa checar duplicatas entre os que não são nulos
	var filtered = selections.filter(func(g): return g != null)
	var unique = _remove_duplicates(filtered)

	if filtered.size() != unique.size():
		print("Gambits repetidos não são permitidos.")
		return

	active_gambits.clear()
	for gambit in selections:
		active_gambits.append(gambit)  # Pode ser null

	current_character.gambits = active_gambits
	current_character.set_meta("gambits", active_gambits)
	print("Selecionados:", selections)
	_set_hud_enabled(true)
	hide()
	_exit_tactical_pause()
	emit_signal("editor_closed")  # Emite o sinal

func _on_cancel_pressed():
	_set_hud_enabled(true)
	hide()
	_exit_tactical_pause()
	emit_signal("editor_closed")  # Emite o sinal

func _exit_tactical_pause():
	var battle_manager = get_tree().get_root().find_child("BattleManager", true, false)
	if battle_manager and battle_manager.is_tactical_pause_active:
		battle_manager._toggle_tactical_pause()

func _remove_duplicates(arr: Array) -> Array:
	var seen = {}
	var result = []
	for item in arr:
		if item == null:
			result.append(item)  # Permitir múltiplos "Nenhum"
		elif not seen.has(item):
			seen[item] = true
			result.append(item)
	return result

func _set_hud_enabled(enabled: bool):
	var hud = get_tree().get_root().find_child("HUD", true, false)
	if hud:
		# Passa enabled = false para desabilitar todos os botões (incluindo gambit)
		hud._set_buttons_enabled(enabled)

func open_for_party(party: Array):
	party_members = party
	_clear_party_list()
	
	for member in party_members:
		var btn = Button.new()
		btn.text = member.name
		btn.pressed.connect(func():
			open_for_character(member)
		)
		party_list.add_child(btn)
		
	var index = -1
	
	for member in party_members:
		index += 1
		if member.active == true:
			print(member.name)
			print("entrou")
			open_for_character(party_members[index])  # Mostra primeiro membro
	show()
	_set_hud_enabled(false)
	
func _clear_party_list():
	for child in party_list.get_children():
		child.queue_free()
