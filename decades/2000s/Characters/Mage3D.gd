extends CombatCharacter

func _ready():
	super._ready()
	model = $Mage
	anim = model.get_node("AnimationPlayer")
