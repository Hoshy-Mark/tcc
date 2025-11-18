extends CanvasLayer

signal editor_closed

@onready var background_panel = $BackgroundPanel
@onready var party_list = $BackgroundPanel/HBoxContainer/PartyList
@onready var label_title = $BackgroundPanel/HBoxContainer/Panel/LabelTitle
@onready var points_label = $BackgroundPanel/HBoxContainer/Panel/PointsLabel
@onready var confirm_btn = $BackgroundPanel/HBoxContainer/Panel/ConfirmButton
@onready var cancel_btn = $BackgroundPanel/HBoxContainer/Panel/CancelButton

# Labels e botões dos atributos
@onready var attr_labels = {
	"strength": $BackgroundPanel/HBoxContainer/Panel/AttributesContainer/StrengthValue,
	"dexterity": $BackgroundPanel/HBoxContainer/Panel/AttributesContainer/DexterityValue,
	"constitution": $BackgroundPanel/HBoxContainer/Panel/AttributesContainer/ConstitutionValue,
	"intelligence": $BackgroundPanel/HBoxContainer/Panel/AttributesContainer/IntelligenceValue,
	"wisdom": $BackgroundPanel/HBoxContainer/Panel/AttributesContainer/WisdomValue
}

@onready var plus_buttons = {
	"strength": $BackgroundPanel/HBoxContainer/Panel/AttributesContainer/StrengthPlus,
	"dexterity": $BackgroundPanel/HBoxContainer/Panel/AttributesContainer/DexterityPlus,
	"constitution": $BackgroundPanel/HBoxContainer/Panel/AttributesContainer/ConstitutionPlus,
	"intelligence": $BackgroundPanel/HBoxContainer/Panel/AttributesContainer/IntelligencePlus,
	"wisdom": $BackgroundPanel/HBoxContainer/Panel/AttributesContainer/WisdomPlus
}

@onready var minus_buttons = {
	"strength": $BackgroundPanel/HBoxContainer/Panel/AttributesContainer/StrengthMinus,
	"dexterity": $BackgroundPanel/HBoxContainer/Panel/AttributesContainer/DexterityMinus,
	"constitution": $BackgroundPanel/HBoxContainer/Panel/AttributesContainer/ConstitutionMinus,
	"intelligence": $BackgroundPanel/HBoxContainer/Panel/AttributesContainer/IntelligenceMinus,
	"wisdom": $BackgroundPanel/HBoxContainer/Panel/AttributesContainer/WisdomMinus
}

var party_members: Array = []
var current_character: CombatCharacter2000 = null
var points_left: int = 0
var temp_allocations = {} # Ex: {"strength": 0, "dexterity": 0, ...}
var battle_manager = null

func _ready():
	hide()
	$BackgroundPanel/HBoxContainer.add_theme_constant_override("separation", 20)
	confirm_btn.pressed.connect(_on_confirm_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	for attr in plus_buttons.keys():
		plus_buttons[attr].pressed.connect(func(): _on_plus_pressed(attr))
		minus_buttons[attr].pressed.connect(func(): _on_minus_pressed(attr))

		# Estilo visual: fundo azul, borda cinza
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#2b4f7d")
	style.border_color = Color("#888888")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)

	background_panel.add_theme_stylebox_override("panel", style)  # <- Aplica também aqui
	
func open_for_party(party: Array, BattleManager):
	party_members = party
	battle_manager = BattleManager
	_clear_party_list()
	for member in party_members:
		var btn = Button.new()
		btn.text = member.name
		btn.pressed.connect(func():
			open_for_character(member)
		)
		party_list.add_child(btn)

	# Abre no primeiro personagem por padrão
	if party_members.size() > 0:
		open_for_character(party_members[0])

	show()

func open_for_character(character: CombatCharacter2000):
	current_character = character
	label_title.text = "Atributos de: %s (Nível %d)" % [character.name, character.level]

	# Checa se há pontos não gastos (ex: vindos do BattleManager)
	if not character.has_meta("points_to_spend"):
		character.set_meta("points_to_spend", 0)

	points_left = character.get_meta("points_to_spend")
	points_label.text = "Pontos restantes: %d" % points_left

	# Zera as alocações temporárias
	temp_allocations.clear()
	for attr in attr_labels.keys():
		temp_allocations[attr] = 0
		attr_labels[attr].text = str(character.get(attr))
	
	_update_confirm_button_state()

func _on_plus_pressed(attr: String):
	if points_left > 0:
		points_left -= 1
		temp_allocations[attr] += 1
		attr_labels[attr].text = str(current_character.get(attr) + temp_allocations[attr])
		points_label.text = "Pontos restantes: %d" % points_left
		_update_confirm_button_state()

func _on_minus_pressed(attr: String):
	if temp_allocations[attr] > 0:
		points_left += 1
		temp_allocations[attr] -= 1
		attr_labels[attr].text = str(current_character.get(attr) + temp_allocations[attr])
		points_label.text = "Pontos restantes: %d" % points_left
		_update_confirm_button_state()

func _on_confirm_pressed():
	if points_left == 0:
		for attr in temp_allocations.keys():
			current_character.set(attr, current_character.get(attr) + temp_allocations[attr])

		current_character.set_meta("points_to_spend", points_left)
		emit_signal("editor_closed")
		hide()
	# Despausar o jogo e voltar para modo combate
	if battle_manager:
		battle_manager._toggle_tactical_pause()

func _on_cancel_pressed():
	# Reseta os valores para os originais
	open_for_character(current_character)
	emit_signal("editor_closed")
	hide()
	
	# Despausar o jogo e voltar para modo combate
	if battle_manager:
		battle_manager._toggle_tactical_pause()

func _clear_party_list():
	for child in party_list.get_children():
		child.queue_free()

func _update_confirm_button_state():
	confirm_btn.disabled = points_left > 0
