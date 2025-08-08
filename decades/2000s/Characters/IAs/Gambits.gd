class_name Gambit
extends Resource

enum TargetType { SELF, ALLY, ENEMY, LOWEST_HP_ALLY }

# Identificador único
var id: String = ""

# Função condicional e ação
var condition: Callable
var action: Callable
var priority: int = 0  # Para ordenação dos gambits

# Metadados
var description := "Descrição do gambit"
var target_type := TargetType.SELF

func is_condition_met(character: CombatCharacter) -> bool:
	return condition.call(character)

func execute_action(character: CombatCharacter) -> void:
	action.call(character)
