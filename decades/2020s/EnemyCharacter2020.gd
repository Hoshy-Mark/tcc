extends CombatCharacter2020
class_name EnemyCharacter2020

# Referência para o Cérebro (Node filho ou injetado)
@onready var ai_brain: EnemyAI = $EnemyAI

func _ready() -> void:
	super._ready()
	is_player_controlled = false
	
	# Fallback de segurança: Se esqueceu de adicionar o nó no editor, cria via código
	if not ai_brain:
		ai_brain = EnemyAI.new()
		ai_brain.name = "FallbackAI"
		add_child(ai_brain)

func take_turn(manager: Node) -> void:
	# Delega a inteligência para a classe EnemyIA
	if ai_brain:
		await ai_brain.execute_turn(self, manager)
	else:
		print("ERRO: Inimigo sem IA!")
