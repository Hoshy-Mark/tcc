extends CanvasLayer

signal action_selected(action_name)

@onready var panel := $ActionPanel
@onready var attack_btn := $ActionPanel/AttackButton
@onready var defend_btn := $ActionPanel/DefendButton
@onready var item_btn := $ActionPanel/ItemButton
@onready var gambit_btn := $ActionPanel/GambitButton
var GambitEditorScene: PackedScene = preload("res://decades/2000s/UI/GambitEditor.tscn")
var gambit_editor: Node = null
@onready var tween := create_tween()

var current_character: CombatCharacter = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_adjust_ui_size()

	attack_btn.pressed.connect(_on_AttackButton_pressed)
	defend_btn.pressed.connect(_on_DefendButton_pressed)
	item_btn.pressed.connect(_on_ItemButton_pressed)
	gambit_btn.pressed.connect(_on_GambitButton_pressed)

	gambit_btn.disabled = false
	gambit_btn.visible = true

	show()
	panel.visible = true
	_set_buttons_enabled(false)

func _process(delta):
	if current_character == null or current_character.is_turn_ready:
		return

	var charge_percent := current_character.turn_charge / current_character.turn_threshold
	_update_buttons_opacity(charge_percent)

func _set_buttons_enabled(enabled: bool) -> void:
	attack_btn.disabled = not enabled
	defend_btn.disabled = not enabled
	item_btn.disabled = not enabled
	
	# Botão de Gambit sempre habilitado
	gambit_btn.disabled = false

	var alpha = 1.0 if enabled and current_character.is_turn_ready else 0.3
	attack_btn.modulate.a = alpha
	defend_btn.modulate.a = alpha
	item_btn.modulate.a = alpha
	
	# Gambit sempre com opacidade cheia
	gambit_btn.modulate.a = 1.0

func _update_buttons_opacity(percent: float) -> void:
	var alpha = clamp(percent, 0.3, 1.0)

	# Interpolação suave com Tween
	tween.kill()  # Cancela tweens anteriores

	tween = create_tween()
	tween.tween_property(attack_btn, "modulate:a", alpha, 0.3)
	tween.tween_property(defend_btn, "modulate:a", alpha, 0.3)
	tween.tween_property(item_btn, "modulate:a", alpha, 0.3)

func show_action_menu(character: CombatCharacter):
	current_character = character
	panel.visible = true
	_set_buttons_enabled(character.is_turn_ready)
	gambit_btn.visible = true

func hide_action_menu():
	_set_buttons_enabled(false)
	current_character = null

func _adjust_ui_size():
	panel.size = Vector2(300, 160)
	panel.position = Vector2(600, 800)

func _on_AttackButton_pressed():
	emit_signal("action_selected", "attack")

func _on_DefendButton_pressed():
	emit_signal("action_selected", "defend")

func _on_ItemButton_pressed():
	emit_signal("action_selected", "item")

func _on_GambitButton_pressed():
	var battle_manager = get_tree().get_root().find_child("BattleManager", true, false)
	if battle_manager:
		var party = battle_manager.get_party_members()  # Certifique-se de que esse método existe

		if party.size() == 0:
			push_warning("Nenhum membro na party para editar gambits.")
			return

		# Pausar o jogo taticamente
		battle_manager._toggle_tactical_pause()

		if gambit_editor == null:
			gambit_editor = GambitEditorScene.instantiate()
			get_tree().get_root().add_child(gambit_editor)
			gambit_editor.connect("editor_closed", Callable(self, "_on_gambit_editor_closed"))

		gambit_editor.open_for_party(party)
		gambit_btn.disabled = true  # Desativa enquanto estiver aberto
			
func _on_gambit_editor_closed():
	gambit_btn.disabled = false
	
func set_gambit_button_enabled(enabled: bool):
	gambit_btn.disabled = not enabled
	gambit_btn.modulate.a = 1.0 if enabled else 0.3
