extends Node

# Este script pode ser um singleton (AutoLoad)

func get_default_gambits() -> Array:
	var gambits := []

	var g1 := Gambit.new()
	g1.id = "heal_low_hp"
	g1.description = "Curar aliado com menos de 20% HP"
	g1.target_type = Gambit.TargetType.LOWEST_HP_ALLY
	g1.condition = func(char):
		for ally in get_allies(char):
			if ally.hp / ally.max_hp < 0.2 and ally.is_alive():
				char.set_meta("gambit_target", ally)
				return true
		return false

	g1.action = func(char):
		var target = char.get_meta("gambit_target")
		if target and target.is_alive() and target.hp < target.max_hp:
			print(char.name, " cura ", target.name)
			target.hp = min(target.hp + 40, target.max_hp)
		else:
			print("Gambit alvo inválido ou já curado.")

	gambits.append(g1)

	return gambits
# Utilitários de busca (simples)
func get_allies(char: CombatCharacter) -> Array:
	var bm = get_tree().get_root().get_node("Game2000/BattleManager")
	if bm == null:
		return []
	return bm.party_members if char in bm.party_members else bm.enemies

func get_enemies(char: CombatCharacter) -> Array:
	var bm = get_tree().get_root().get_node("Game2000/BattleManager")
	if bm == null:
		return []
	return bm.enemies if char in bm.party_members else bm.party_members
