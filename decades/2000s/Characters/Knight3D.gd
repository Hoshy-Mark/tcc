extends "res://decades/2000s/Characters/IAs/PartyMemberAI.gd"

func _ready():
	super._ready()
	model = $Knight
	anim = model.get_node("AnimationPlayer")
	name = "Cavaleiro"
	strength = 12
	dexterity = 8
	constitution = 14
	intelligence = 2
	wisdom = 4
	has_shield = true
	_recalculate_stats()
