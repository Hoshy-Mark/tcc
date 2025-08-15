extends "res://decades/2000s/Characters/IAs/EnemeyIA.gd"

const FIREBALL_COOLDOWN_TIME = 3.0

var state = STATE_IDLE
var attacker: CombatCharacter = null
var fireball_cooldown := FIREBALL_COOLDOWN_TIME
var is_casting := false  # flag para controlar ataque único

enum {
	STATE_IDLE,
	STATE_ATTACKING
}

func _ready():
	super._ready()
	model = $Skeleton_Mage
	anim = model.get_node("AnimationPlayer")
	move_speed = 0.0 # sem movimento
	strength = 5
	dexterity = 5
	constitution = 5
	intelligence = 5
	wisdom = 5
	_recalculate_stats()
	aggro_range = 10.0
	attack_range = 2.0

func _process(delta):
	if not health_bar or not model:
		return

	_update_health_bar_ui()

	if fireball_cooldown > 0:
		fireball_cooldown -= delta

	update_ai(delta)

func update_ai(delta):
	var target_to_attack = attacker if attacker else _choose_target_based_on_strategy()

	if not target_to_attack:
		state = STATE_IDLE
		return

	state = STATE_ATTACKING

	if fireball_cooldown <= 0 and not is_casting:
		is_casting = true
		await _cast_fireball(self, target_to_attack)
		fireball_cooldown = FIREBALL_COOLDOWN_TIME
		is_casting = false

func _choose_target_based_on_strategy() -> CombatCharacter:
	var manager = get_tree().get_root().get_node("Game2000/BattleManager")
	if manager == null:
		return null

	var target = null
	var max_hp = -1
	for p in manager.party_members:
		if p.is_alive():
			var dist = global_position.distance_to(p.global_position)
			if dist <= aggro_range:
				if p.hp > max_hp:
					max_hp = p.hp
					target = p
	return target

func _cast_fireball(caster: CombatCharacter, target: CombatCharacter) -> void:
	if not target:
		return
	is_performing_action = true
	if caster.anim:
		caster.anim.play("Spellcast_Shoot", -1, 1.5)

	await get_tree().create_timer(0.5).timeout

	var projectile_scene = preload("res://decades/2000s/Characters/Projectile.tscn")
	var projectile = projectile_scene.instantiate()
	projectile.global_position = caster.global_position + Vector3(0, 1.5, 0)
	projectile.target = target
	get_tree().current_scene.add_child(projectile)

	is_performing_action = false

func apply_damage(amount: int, attacker_char: CombatCharacter):
	super.apply_damage(amount, attacker_char)
	if is_alive():
		attacker = attacker_char
		state = STATE_ATTACKING
