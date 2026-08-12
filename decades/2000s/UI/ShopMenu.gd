extends CanvasLayer

signal shop_closed

@onready var panel = $Panel
@onready var gold_label = $Panel/MarginContainer/VBoxContainer/GoldLabel
@onready var item_list = $Panel/MarginContainer/VBoxContainer/ItemList
@onready var continue_btn = $Panel/MarginContainer/VBoxContainer/ContinueButton

var battle_manager = null

func _ready():
	hide()

	# Mesmo estilo visual usado nos outros menus (Gambit/Attribute/Inventory)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#2b4f7d")
	style.border_color = Color("#888888")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	continue_btn.pressed.connect(_on_continue_pressed)

func open_shop(bm) -> void:
	battle_manager = bm
	_refresh()
	show()

func _refresh() -> void:
	if not battle_manager:
		return

	gold_label.text = "Ouro: %d" % GameManager.saved_gold

	for child in item_list.get_children():
		child.queue_free()

	for item_name in battle_manager.SHOP_PRICES.keys():
		var price = battle_manager.SHOP_PRICES[item_name]
		var quantidade = battle_manager.inventory.get(item_name, 0)

		var row = HBoxContainer.new()

		var label = Label.new()
		label.text = "%s (x%d) - %dg" % [item_name, quantidade, price]
		label.custom_minimum_size = Vector2(220, 0)
		row.add_child(label)

		var btn = Button.new()
		btn.text = "Comprar"
		btn.disabled = GameManager.saved_gold < price
		btn.pressed.connect(func(): _buy(item_name, price))
		row.add_child(btn)

		item_list.add_child(row)

func _buy(item_name: String, price: int) -> void:
	if GameManager.saved_gold < price:
		return
	GameManager.saved_gold -= price
	battle_manager.inventory[item_name] = battle_manager.inventory.get(item_name, 0) + 1
	_refresh()

func _on_continue_pressed() -> void:
	hide()
	emit_signal("shop_closed")
