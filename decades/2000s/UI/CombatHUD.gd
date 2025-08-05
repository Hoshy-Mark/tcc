extends CanvasLayer

signal action_selected(action_name)

@onready var panel := $ActionPanel
@onready var attack_btn := $ActionPanel/AttackButton
@onready var defend_btn := $ActionPanel/DefendButton
@onready var item_btn := $ActionPanel/ItemButton
@onready var tween := create_tween()

var current_character: CombatCharacter = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_adjust_ui_size()

	attack_btn.pressed.connect(_on_AttackButton_pressed)
	defend_btn.pressed.connect(_on_DefendButton_pressed)
	item_btn.pressed.connect(_on_ItemButton_pressed)

	show()
	panel.visible = true
	_set_buttons_enabled(false)

func _process(delta):
	if current_character == null or current_character.is_turn_ready:
		return

	# Progresso entre 0.0 e 1.0
	var charge_percent := current_character.turn_charge / current_character.turn_threshold
	_update_buttons_opacity(charge_percent)

func _set_buttons_enabled(enabled: bool) -> void:
	attack_btn.disabled = not enabled
	defend_btn.disabled = not enabled
	item_btn.disabled = not enabled

	# Quando habilitados, opacidade volta para 1
	var alpha = 1.0 if enabled else 0.3
	attack_btn.modulate.a = alpha
	defend_btn.modulate.a = alpha
	item_btn.modulate.a = alpha

func _update_buttons_opacity(percent: float) -> void:
	var alpha = clamp(percent, 0.3, 1.0)

	# Interpolação suave com Tween
	tween.kill()  # Cancela tweens anteriores

	tween = create_tween()
	tween.tween_property(attack_btn, "modulate:a", alpha, 0.3)
	tween.tween_property(defend_btn, "modulate:a", alpha, 0.3)
	tween.tween_property(item_btn, "modulate:a", alpha, 0.3)

func show_action_menu(character: CombatCharacter):
	if panel == null:
		push_error("HUD: ActionPanel está nulo! Verifique a estrutura da cena.")
		return

	current_character = character
	panel.visible = true
	_set_buttons_enabled(character.is_turn_ready)
	if character.is_turn_ready:
		attack_btn.grab_focus()

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
