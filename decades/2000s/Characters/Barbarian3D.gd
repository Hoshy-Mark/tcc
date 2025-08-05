extends CombatCharacter

func _ready():
	super._ready()
	model = $Barbarian
	anim = model.get_node("AnimationPlayer")
