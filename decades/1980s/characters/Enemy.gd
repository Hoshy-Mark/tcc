extends RefCounted
class_name Enemy

var nome: String = "Enemy"
var max_hp: int = 50
var current_hp: int = max_hp
var max_mp: int = 0
var current_mp: int = max_mp
var strength: int = 6
var defense: int = 2
var speed: int = 10
var xp_value = 50
var gold_value = 5
var id: String = ""
var status_effects := StatusEffectComponent.new()
var accuracy: int = 0
var evasion: int = 0
var intelligence: int = 0
var magic_power: int = 0
var magic_defense: int = 0
var luck: int = 0

var ai_behavior: String = "simple_attack"
var last_attacker: PlayerPartyMember = null

var is_charging: bool = false # <-- ADICIONADO: Variável de estado do boss

func attack(target):
	var accuracy_atacante = accuracy + int(randf() * 10) * 1.5
	
	var evasion_alvo = target.evasion + int(randf() * 10)
	if target.is_defending:
		evasion_alvo += int(target.evasion * 0.2)
		
	var accuracy_check = accuracy_atacante > evasion_alvo
	if not accuracy_check:
		return {"miss": true}

	var base_damage = max(1, strength - target.get_modified_stat(target.defense, "defense"))
	var damage_variation = randi() % 6 - 2
	var damage = max(base_damage + damage_variation, 1)

	var is_crit = randf() < (luck * 0.01)
	if is_crit:
		damage = int(damage * 1.5)

	target.take_damage(damage, self)
	return {"damage": damage, "crit": is_crit}

# --- ADICIONADO: Nova função de ataque do Boss ---
func strong_attack(target):
	# O ataque forte sempre acerta!
	var base_damage = max(1, (strength * 2) - target.get_modified_stat(target.defense, "defense")) # Dano dobrado!
	var damage_variation = randi() % 10 - 4 # Variação maior
	var damage = max(base_damage + damage_variation, 1)

	# Crítico (chance maior)
	var is_crit = randf() < (luck * 0.03)
	if is_crit:
		damage = int(damage * 1.5)

	target.take_damage(damage, self)
	return {"damage": damage, "crit": is_crit, "is_strong": true}
# --- FIM DA NOVA FUNÇÃO ---

func take_damage(amount, attacker = null):
	current_hp -= int(amount)
	current_hp = max(current_hp, 0)

	if attacker and attacker is PlayerPartyMember:
		self.last_attacker = attacker

func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)

func is_alive():
	return current_hp > 0

func reset():
	current_hp = max_hp
	current_mp = max_mp
	clear_status_effects()
	last_attacker = null
	is_charging = false # <-- ADICIONADO: Resetar o charge

func apply_status_effect(effect: StatusEffect) -> void:
	status_effects.apply_effect(effect)

func process_status_effects() -> void:
	status_effects.tick(self)

func clear_status_effects() -> void:
	status_effects.clear()

func get_modified_stat(base_value: int, stat_name: String) -> int:
	return max(base_value + status_effects.get_modifier(stat_name), 0)
