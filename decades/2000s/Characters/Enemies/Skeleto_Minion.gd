extends CombatCharacter

func _ready():
	super._ready()
	model = $Skeleton_Minion
	anim = model.get_node("AnimationPlayer")

func update_ai(delta):
	pass
