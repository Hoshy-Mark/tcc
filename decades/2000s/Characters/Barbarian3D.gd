extends "res://decades/2000s/Characters/IAs/PartyMemberAI.gd"

func _ready():
	super._ready()
	model = $Barbarian
	anim = model.get_node("AnimationPlayer")
	name = "Barbaro"
	strength = 14
	dexterity = 10
	constitution = 12
	intelligence = 2
	wisdom = 2
	has_shield = true
	_recalculate_stats()
