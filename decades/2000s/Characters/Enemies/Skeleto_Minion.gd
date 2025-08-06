extends "res://decades/2000s/Characters/IAs/EnemeyIA.gd"

func _ready():
	super._ready()
	model = $Skeleton_Minion
	anim = model.get_node("AnimationPlayer")
	move_speed = 1.0 
