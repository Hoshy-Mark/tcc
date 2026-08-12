extends "res://decades/2000s/Characters/IAs/PartyMemberAI.gd"

func _ready():
	super._ready()
	model = $Barbarian
	anim = model.get_node("AnimationPlayer")
	name = "Barbaro"
	strength = 14
	dexterity = 10
	constitution = 12
	intelligence = 2
	wisdom = 2
	has_shield = true
	_recalculate_stats()

# Habilidade 0: Investida Brutal — golpe pesado de dois alvos com dano bem
# acima do ataque básico + sangramento. Espelha o "brutal_strike" que os
# Bárbaros inimigos já usam, do lado da party.
func _cast_ability_0():
	_cast_brutal_strike(self)

func _cast_brutal_strike(caster: CombatCharacter2000):
	if not caster.current_target or not caster.current_target.is_alive():
		return

	caster.is_performing_action = true
	if caster.anim and caster.anim.has_animation("2H_Melee_Attack_Spin"):
		caster.anim.play("2H_Melee_Attack_Spin")
	elif caster.anim:
		caster.anim.play("1H_Melee_Attack_Slice_Diagonal")

	await get_tree().create_timer(0.6).timeout

	var target = caster.current_target
	if target and is_instance_valid(target) and target.is_alive():
		var dmg = int(caster.attack_power * 1.8) # bem mais forte que o ataque básico
		target.apply_damage(dmg, caster)
		target.apply_status("bleed", 6.0, caster)
		if target.has_method("add_threat"):
			target.add_threat(caster, dmg)

	caster.turn_charge = 0
	caster.is_turn_ready = false
	caster.is_performing_action = false

