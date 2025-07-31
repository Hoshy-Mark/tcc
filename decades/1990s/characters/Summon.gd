extends PlayerPartyMember1990
class_name Summon

var sprite_path: String = ""

func setup(nome, stats: Dictionary, sprite_path: String) -> void:
	self.nome = nome
	self.classe_name = "Summon"
	self.is_summon = true
	self.spell_slots = {1:4, 2:4, 3:4, 4:4, 5:4}
	for k in stats.keys():
		set(k, stats[k])  # STR, DEX, etc.
	self.sprite_path = sprite_path
	self.attack_type = "magic"
	self.spells = []
	self.position_line = "front"
	calculate_stats()
