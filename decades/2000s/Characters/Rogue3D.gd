extends "res://decades/2000s/Characters/IAs/PartyMemberAI.gd"

func _ready():
	super._ready()
	model = $Rogue
	anim = model.get_node("AnimationPlayer")
	name = "Ladrão"
