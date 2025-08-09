extends "res://decades/2000s/Characters/IAs/PartyMemberAI.gd"

func _ready():
	super._ready()
	model = $Mage
	anim = model.get_node("AnimationPlayer")
	name = "Mago"
	strength = 4
	dexterity = 8
	constitution = 8
	intelligence = 14
	wisdom = 6
	_recalculate_stats()
