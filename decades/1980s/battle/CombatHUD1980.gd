extends CanvasLayer

signal action_selected(action_name: String)
@onready var party_info = $PartyInfo

func _ready():
	print("PartyInfo container: ", party_info)
	print("EnemyInfo container: ", $EnemyInfo)
	$VBoxContainer/Button.text = "Atacar"
	$VBoxContainer/Button2.text = "Magia"
	$VBoxContainer/Button3.text = "Defender"
	$VBoxContainer/Button4.text = "Fugir"

	$VBoxContainer/Button.pressed.connect(func(): emit_signal("action_selected", "attack"))
	$VBoxContainer/Button2.pressed.connect(func(): emit_signal("action_selected", "magic"))
	$VBoxContainer/Button3.pressed.connect(func(): emit_signal("action_selected", "defend"))
	$VBoxContainer/Button4.pressed.connect(func(): emit_signal("action_selected", "flee"))

func set_enabled(enabled: bool):
	$VBoxContainer/Button.disabled = not enabled
	$VBoxContainer/Button2.disabled = not enabled
	$VBoxContainer/Button3.disabled = not enabled
	$VBoxContainer/Button4.disabled = not enabled
	
func update_enemy_status(enemies):
	clear_container($EnemyInfo)

	for enemy in enemies:
		var container = HBoxContainer.new()

		var name_label = Label.new()
		name_label.text = "Inimigo: " + enemy.nome
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var hp_label = Label.new()
		hp_label.text = "HP: %d/%d" % [enemy.current_hp, enemy.max_hp]

		container.add_child(name_label)
		container.add_child(hp_label)

		$EnemyInfo.add_child(container)

func update_party_info(party_members: Array):
	print("Atualizando party_info, filhos antes da limpeza:", party_info.get_child_count())
	clear_container(party_info)
	print("Filhos depois da limpeza e antes de adicionar novos:", party_info.get_child_count())

	# Adiciona as informações dos membros da party
	for member in party_members:
		var container = HBoxContainer.new()

		var name_label = Label.new()
		name_label.text = member.nome
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var hp_label = Label.new()
		hp_label.text = "HP: %d" % member.hp

		var mp_label = Label.new()
		mp_label.text = "MP: %d" % member.mp

		container.add_child(name_label)
		container.add_child(hp_label)
		container.add_child(mp_label)

		party_info.add_child(container)
		
		print("Filhos depois de adicionar os novos:", party_info.get_child_count())
		
func clear_container(container):
	print("Antes de limpar, filhos no container:", container.get_child_count())
	var children = container.get_children()
	for child in children:
		container.remove_child(child)
		child.queue_free()
	print("Depois de limpar, filhos no container:", container.get_child_count())
