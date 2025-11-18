extends CanvasLayer
class_name AbilityHUD

signal ability_selected(ability_index)

@onready var btns := [
	$PanelContainer/MarginContainer/GrldContainer/Ability1Button,
	$PanelContainer/MarginContainer/GrldContainer/Ability2Button,
	$PanelContainer/MarginContainer/GrldContainer/Ability3Button,
	$PanelContainer/MarginContainer/GrldContainer/Ability4Button
]

var current_character: CombatCharacter2000 = null

# Cooldowns (em segundos)
var cooldown_times := [5.0, 10.0, 15.0, 20.0]
var cooldown_remaining := [0.0, 0.0, 0.0, 0.0]

func _ready():
	show()  # Agora sempre visível
	for i in range(btns.size()):
		btns[i].pressed.connect(func(): _on_ability_pressed(i))
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#2b4f7d")
	style.border_color = Color("#888888")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	$PanelContainer.add_theme_stylebox_override("panel", style)
	
func _process(delta):
	var bm = get_tree().get_root().get_node("Game2000/BattleManager")
	
	if not current_character:
		return
	
	if bm.is_tactical_pause_active != true:
		for i in range(btns.size()):
			var cd = current_character.ability_cooldowns[i]
			if cd > 0:
				btns[i].text = "%s (%.1f)" % [_get_ability_name(i), cd]
				btns[i].disabled = true
			else:
				btns[i].text = _get_ability_name(i)
				btns[i].disabled = false

func show_abilities_for(character: CombatCharacter2000):
	current_character = character

func _on_ability_pressed(index: int):
	if current_character and current_character.can_use_ability(index):
		emit_signal("ability_selected", index)

func _get_ability_name(index: int) -> String:
	if current_character:
		if current_character.name == "Mago":
			match index:
				0: return "Bola de Fogo"
				1: return "Habilidade 2"
				2: return "Habilidade 3"
				3: return "Habilidade 4"
	return "Habilidade %d" % (index + 1)
