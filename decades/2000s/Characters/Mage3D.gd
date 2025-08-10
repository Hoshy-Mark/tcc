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





func _cast_fireball(caster: CombatCharacter):
	if not caster.current_target:
		print("Sem alvo para bola de fogo!")
		return
	caster.is_performing_action = true
	if caster.anim:
		caster.anim.play("Spellcast_Shoot", -1, 1.5)
	else:
		push_error("Caster não tem anim definido!")

	await get_tree().create_timer(0.5).timeout  # ✅ corrigido
	
	var projectile_scene = preload("res://decades/2000s/Characters/Projectile.tscn")
	var projectile = projectile_scene.instantiate()
	projectile.global_position = caster.global_position + Vector3(0, 1.5, 0)
	projectile.target = caster.current_target

	get_tree().current_scene.add_child(projectile)
	print("Fez animação e lançou Fireball")

	caster.turn_charge = 0
	caster.is_turn_ready = false
	caster.is_performing_action = false
	
func _cast_ability_0():
	_cast_fireball(self)
