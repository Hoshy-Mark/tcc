extends CombatCharacter

func _ready():
	super._ready()
	model = $Rogue
	anim = model.get_node("AnimationPlayer")
