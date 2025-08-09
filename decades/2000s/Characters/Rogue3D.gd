extends "res://decades/2000s/Characters/IAs/PartyMemberAI.gd"

func _ready():
	super._ready()
	model = $Rogue
	anim = model.get_node("AnimationPlayer")
	name = "Ladrão"
	strength = 8
	dexterity = 14
	constitution = 8
	intelligence = 6
	wisdom = 4
	_recalculate_stats()
