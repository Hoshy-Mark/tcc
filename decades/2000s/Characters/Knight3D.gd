extends CombatCharacter

func _ready():
	super._ready()
	model = $Knight
	anim = model.get_node("AnimationPlayer")
