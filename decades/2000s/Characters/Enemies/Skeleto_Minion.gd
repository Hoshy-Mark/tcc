extends "res://decades/2000s/Characters/IAs/EnemeyIA.gd"

func _ready():
	super._ready()
	model = $Skeleton_Minion
	anim = model.get_node("AnimationPlayer")
	move_speed = 1.0
	strength = 5
	dexterity = 5
	constitution = 5
	intelligence = 5
	wisdom = 5
	_recalculate_stats()

	aggro_range = 7.5  # metade do mago, por exemplo
	attack_range = 2.0  # ataque corpo a corpo
