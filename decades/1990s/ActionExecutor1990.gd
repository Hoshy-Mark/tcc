# ActionExecutor1990.gd
class_name ActionExecutor1990
extends Node

# Referência ao "Juiz" da batalha (o BattleManager)
var battle_manager: Node

# Constantes (podemos espelhar a do manager)
var TEMPO_ESPERA_APOS_ACAO: float = 0.5

# Construtor: Recebe o BattleManager quando é criado
func _init(manager: Node):
	self.battle_manager = manager
	if "TEMPO_ESPERA_APOS_ACAO" in battle_manager:
		self.TEMPO_ESPERA_APOS_ACAO = battle_manager.TEMPO_ESPERA_APOS_ACAO

# ============================================
# FUNÇÕES DE EXECUÇÃO DE AÇÃO
# ============================================

func perform_attack(attacker, target) -> void:
	var is_ataque_fisico = true
	
	if not pode_atacar(target, attacker, is_ataque_fisico):
		battle_manager.hud.show_top_message("Alvo fora de alcance!")
		battle_manager.reset_atb(attacker)
		battle_manager.hud.update_party_info(battle_manager.party)
		return

	# --- LÓGICA DE ANIMAÇÃO ---
	var original_attacker_pos := Vector2.ZERO # <-- CORRIGIDO
	var can_animate = attacker.has_method("get_global_position") and attacker.sprite_ref != null # <-- CORRIGIDO

	if can_animate:
		original_attacker_pos = attacker.sprite_ref.global_position
		var attack_move_offset = Vector2(-80, 0)
		if attacker is Enemy1990:
			attack_move_offset.x = 80
			
		var attack_position = original_attacker_pos + attack_move_offset
		var tween = battle_manager.create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(attacker.sprite_ref, "global_position", attack_position, 0.15)
		await tween.finished
	# --- FIM DA ANIMAÇÃO DE IDA ---

	# --- LÓGICA DE DANO ---
	var attacker_accuracy = attacker.get_modified_stat(attacker.accuracy, "accuracy")
	var target_evasion = target.get_modified_stat(target.evasion, "evasion")
	var attacker_str = attacker.get_modified_stat(attacker.STR, "STR")
	var attacker_dex = attacker.get_modified_stat(attacker.DEX, "DEX")
	var target_def = target.get_modified_stat(target.defense, "defense")
	var attacker_lck = attacker.get_modified_stat(attacker.LCK, "LCK")
	
	var hit_chance = attacker_accuracy / float(attacker_accuracy + target_evasion)
	var roll = randf()
	
	# SE O ATAQUE ERRAR
	if roll > hit_chance:
		battle_manager.hud.show_top_message("%s errou o ataque!" % attacker.nome)
		if can_animate:
			var tween_back = battle_manager.create_tween()
			tween_back.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween_back.tween_property(attacker.sprite_ref, "global_position", original_attacker_pos, 0.2)
			await tween_back.finished
		
		battle_manager.reset_atb(attacker)
		battle_manager.hud.update_party_info(battle_manager.party)
		return

	# SE O ATAQUE ACERTAR
	var crit_chance = attacker_lck * 0.01
	var is_crit = randf() < crit_chance
	var attack_type = attacker.attack_type
	var defense_modifier = 1.0
	
	if attack_type in target.attack_type_resistances:
		defense_modifier = target.attack_type_resistances[attack_type]

	var damage = attacker_str + int(attacker_dex / 2) - int(target_def * defense_modifier)
	damage = max(damage, 1)
	damage = ajustar_dano_por_posicao(damage, attacker, target, is_ataque_fisico)

	if is_crit:
		damage *= 2
		battle_manager.hud.show_top_message("CRÍTICO! %s causou %d de dano!" % [attacker.nome, damage])
	else:
		battle_manager.hud.show_top_message("%s causou %d de dano!" % [attacker.nome, damage])

	if target.get_meta("protect_active", false):
		damage *= 0.5
		battle_manager.hud.show_top_message("%s foi protegido por Protect!" % target.nome)
		
	aplicar_dano(target, attacker, damage)
	battle_manager.hud.show_floating_number(damage, target, "damage")

	if target.current_hp <= 0:
		target.current_hp = 0
		if target.has_method("check_if_dead"):
			target.check_if_dead()
		battle_manager.hud.show_top_message("%s foi derrotado!" % target.nome)
	
	# --- ANIMAÇÃO DE VOLTA (SE ACERTOU) ---
	if can_animate:
		await battle_manager.get_tree().create_timer(0.2).timeout
		var tween_back = battle_manager.create_tween()
		tween_back.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween_back.tween_property(attacker.sprite_ref, "global_position", original_attacker_pos, 0.2)
		await tween_back.finished
	# --- FIM DA ANIMAÇÃO DE VOLTA ---

	battle_manager.reset_atb(attacker)
	battle_manager.hud.update_party_info(battle_manager.party)
	
func _execute_skill(user, skill, alvo):
	# --- Checagens ---
	if user.current_sp < skill.cost:
		battle_manager.hud.show_top_message("%s não tem SP suficiente para usar %s!" % [user.nome, skill.name])
		await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()
		return
	user.current_sp -= skill.cost
	user.spell_slots[skill.level] -= 1
	
	var is_fisico = skill.effect_type == "damage" and skill.attack_type != "magic"

	if not pode_atacar(alvo, user, is_fisico):
		battle_manager.hud.show_top_message("Alvo fora de alcance!")
		await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()
		return
	
	# --- ANIMAÇÃO DE SKILL ---
	var can_animate = user.has_method("get_global_position") and user.sprite_ref != null # <-- CORRIGIDO
	var original_pos := Vector2.ZERO # <-- CORRIGIDO
	
	if can_animate:
		original_pos = user.sprite_ref.global_position

	if is_fisico and can_animate:
		var attack_move_offset = Vector2(-80, 0)
		if user is Enemy1990:
			attack_move_offset.x = 80
		var attack_position = original_pos + attack_move_offset
		var tween_go = battle_manager.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween_go.tween_property(user.sprite_ref, "global_position", attack_position, 0.15)
		await tween_go.finished
	elif can_animate: 
		var original_local_pos_y = user.sprite_ref.position.y 
		var tween_jump = battle_manager.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT_IN)
		tween_jump.tween_property(user.sprite_ref, "position:y", original_local_pos_y - 20, 0.15)
		tween_jump.tween_property(user.sprite_ref, "position:y", original_local_pos_y, 0.15).set_delay(0.15)
		await tween_jump.finished
	# --- FIM DA ANIMAÇÃO ---

	# --- LÓGICA DE ACERTO E DANO ---
	var hit_roll = randf()
	if hit_roll > skill.hit_chance:
		battle_manager.hud.show_top_message("%s errou o uso de %s!" % [user.nome, skill.name])
		if is_fisico and can_animate:
			var tween_back = battle_manager.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween_back.tween_property(user.sprite_ref, "global_position", original_pos, 0.2)
			await tween_back.finished
		
		battle_manager.reset_atb(user)
		await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()
		return

	# SE ACERTOU... (seu código de skill)
	if skill.effect_type == "damage":
		# ... (código de dano da skill) ...
		var base_dano = skill.power
		match skill.scaling_stat:
			"STR": base_dano += user.get_modified_stat(user.STR, "STR")
			"DEX": base_dano += user.get_modified_stat(user.DEX, "DEX")
			"INT": base_dano += user.get_modified_stat(user.INT, "INT")
			"SPI": base_dano += user.get_modified_stat(user.SPI, "SPI")
			_: base_dano += user.get_modified_stat(user.STR, "STR")
		var defesa_modificada = alvo.get_modified_stat(alvo.defense, "defense")
		var dano = base_dano - defesa_modificada
		dano = max(dano, 1)
		dano = ajustar_dano_por_posicao(dano, user, alvo, is_fisico)
		var element_res = 1.0
		var attack_type_res = 1.0
		if skill.has_method("element") and skill.element != "":
			element_res = alvo.element_resistances.get(skill.element.to_lower(), 1.0)
		if skill.has_method("attack_type") and skill.attack_type != "":
			attack_type_res = alvo.attack_type_resistances.get(skill.attack_type.to_lower(), 1.0)
		dano = dano * element_res * attack_type_res
		if alvo.get_meta("protect_active", false):
			dano *= 0.5
			battle_manager.hud.show_top_message("%s foi protegido por Protect!" % alvo.nome)
		var crit_chance = user.LCK * 0.01
		if randf() < crit_chance:
			dano *= 2
			battle_manager.hud.show_top_message("CRÍTICO! %s usou %s e causou %d de dano em %s!" % [user.nome, skill.name, dano, alvo.nome])
		else:
			battle_manager.hud.show_top_message("%s usou %s e causou %d de dano em %s!" % [user.nome, skill.name, dano, alvo.nome])
		var ap_gain = int(10)
		user.gain_ap(skill.name, ap_gain, false)
		aplicar_dano(alvo, user, dano)
		if alvo.current_hp <= 0:
			alvo.current_hp = 0
			if alvo.has_method("check_if_dead"):
				alvo.check_if_dead()
		battle_manager.hud.show_floating_number(dano, alvo, "damage")
		
	elif skill.effect_type == "heal":
		# ... (código de cura da skill) ...
		var cura = skill.power + user.SPI
		var ap_gain = int(10)
		user.gain_ap(skill.name, ap_gain, false)
		alvo.current_hp = min(alvo.max_hp, alvo.current_hp + cura)
		battle_manager.hud.show_top_message("%s usou %s e curou %d HP em %s!" % [user.nome, skill.name, cura, alvo.nome])
		battle_manager.hud.show_floating_number(cura, alvo, "hp")

	elif skill.effect_type == "buff":
		# ... (código de buff da skill) ...
		var effect = StatusEffect.new()
		var ap_gain = int(10)
		user.gain_ap(skill.name, ap_gain, false)
		effect.attribute = skill.scaling_stat
		effect.amount = skill.amount
		effect.duration = skill.duration if skill.duration > 0 else 3
		effect.type = StatusEffect.Type.BUFF
		alvo.apply_status_effect(effect, (skill.hit_chance * 100))
		battle_manager.hud.show_top_message("%s aumentou %s de %s com %s!" % [user.nome, effect.attribute, alvo.nome, skill.name])

	elif skill.effect_type == "special":
		# ... (código especial da skill) ...
		var ap_gain = int(10)
		user.gain_ap(skill.name, ap_gain, false)
		match skill.effect:
			"steal_item":
				attempt_steal(user, alvo)
			"scan_info":
				display_scan_info(alvo)
			"mp_drain":
				drain_mp(user, alvo)
			_:
				battle_manager.hud.show_top_message("Efeito especial desconhecido: %s" % skill.effect)
		battle_manager.reset_atb(user)
		await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()
		return 

	if skill.status_inflicted != "":
		# ... (código de status da skill) ...
		if randf() <= skill.status_chance:
			var status_effect = StatusEffect.new()
			status_effect.attribute = skill.status_inflicted
			status_effect.amount = 0
			status_effect.duration = skill.duration if skill.duration > 0 else 2
			status_effect.type = StatusEffect.Type.DEBUFF
			alvo.apply_status_effect(status_effect, (skill.hit_chance * 100))
			battle_manager.hud.show_top_message("%s foi afetado por %s!" % [alvo.nome, skill.status_inflicted])

	# --- ANIMAÇÃO DE VOLTA (SE ACERTOU) ---
	if is_fisico and can_animate:
		await battle_manager.get_tree().create_timer(0.1).timeout 
		var tween_back = battle_manager.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween_back.tween_property(user.sprite_ref, "global_position", original_pos, 0.2)
		await tween_back.finished
	# --- FIM DA ANIMAÇÃO DE VOLTA ---

	battle_manager.reset_atb(user)
	battle_manager.hud.update_party_info(battle_manager.party)
	battle_manager._create_menu()
	await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	battle_manager.end_turn()

func _execute_skill_area(user, skill, alvos):
	# --- Checagens ---
	if user.current_sp < skill.cost:
		battle_manager.hud.show_top_message("%s não tem SP suficiente para usar %s!" % [user.nome, skill.name])
		await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()
		return
	user.current_sp -= skill.cost
	user.spell_slots[skill.level] -= 1
	var is_fisico = skill.effect_type == "damage" and skill.effect_type != "magic"
	
	# --- ANIMAÇÃO (PULINHO) ---
	var can_animate = user.has_method("get_global_position") and user.sprite_ref != null # <-- CORRIGIDO
	if can_animate:
		var original_local_pos_y = user.sprite_ref.position.y 
		var tween_jump = battle_manager.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT_IN)
		tween_jump.tween_property(user.sprite_ref, "position:y", original_local_pos_y - 20, 0.15)
		tween_jump.tween_property(user.sprite_ref, "position:y", original_local_pos_y, 0.15).set_delay(0.15)
		await tween_jump.finished
	# --- FIM DA ANIMAÇÃO ---

	# --- LÓGICA DE DANO/EFEITO (Seu código original) ---
	for alvo in alvos:
		if alvo.current_hp <= 0:
			continue 
		if not pode_atacar(alvo, user, is_fisico):
			continue 
		var hit_roll = randf()
		if hit_roll > skill.hit_chance:
			battle_manager.hud.show_top_message("%s errou %s em %s!" % [user.nome, skill.name, alvo.nome])
			continue 

		if skill.effect_type == "damage":
			# ... (código de dano) ...
			var base_dano = skill.power
			match skill.scaling_stat:
				"STR": base_dano += user.get_modified_stat(user.STR, "STR")
				"DEX": base_dano += user.get_modified_stat(user.DEX, "DEX")
				"INT": base_dano += user.get_modified_stat(user.INT, "INT")
				"SPI": base_dano += user.get_modified_stat(user.SPI, "SPI")
				_: base_dano += user.get_modified_stat(user.STR, "STR")
			var defesa_modificada = alvo.get_modified_stat(alvo.defense, "defense")
			var dano = base_dano - defesa_modificada
			dano = max(dano, 1)
			dano = ajustar_dano_por_posicao(dano, user, alvo, is_fisico)
			var element_res = 1.0
			var attack_type_res = 1.0
			if skill.has_method("element") and skill.element != "":
				element_res = alvo.element_resistances.get(skill.element.to_lower(), 1.0)
			if skill.has_method("attack_type") and skill.attack_type != "":
				attack_type_res = alvo.attack_type_resistances.get(skill.attack_type.to_lower(), 1.0)
			dano *= element_res * attack_type_res
			var crit_chance = user.LCK * 0.01
			var crit = randf() < crit_chance
			if crit:
				dano *= 2
				battle_manager.hud.show_top_message("CRÍTICO! %s usou %s e causou %d de dano em %s!" % [user.nome, skill.name, dano, alvo.nome])
			else:
				battle_manager.hud.show_top_message("%s usou %s e causou %d de dano em %s!" % [user.nome, skill.name, dano, alvo.nome])
			user.gain_ap(skill.name, 100, false)
			aplicar_dano(alvo, user, dano)
			if alvo.current_hp <= 0:
				alvo.current_hp = 0
				if alvo.has_method("check_if_dead"):
					alvo.check_if_dead()
			battle_manager.hud.show_floating_number(dano, alvo, "damage")
			
		elif skill.effect_type == "heal":
			# ... (código de cura) ...
			var cura = skill.power + user.get_modified_stat(user.SPI, "SPI")
			user.gain_ap(skill.name, 100, false)
			alvo.current_hp = min(alvo.max_hp, alvo.current_hp + cura)
			battle_manager.hud.show_top_message("%s usou %s e curou %d HP em %s!" % [user.nome, skill.name, cura, alvo.nome])
			battle_manager.hud.show_floating_number(cura, alvo, "hp")
			
		elif skill.effect_type == "buff":
			# ... (código de buff) ...
			var effect = StatusEffect.new()
			user.gain_ap(skill.name, 100, false)
			effect.attribute = skill.scaling_stat
			effect.amount = skill.amount
			effect.duration = skill.duration if skill.duration > 0 else 3
			effect.type = StatusEffect.Type.BUFF
			alvo.apply_status_effect(effect, (skill.hit_chance * 100))
			battle_manager.hud.show_top_message("%s aumentou %s de %s com %s!" % [user.nome, effect.attribute, alvo.nome, skill.name])

		if skill.status_inflicted != "":
			# ... (código de status) ...
			if randf() <= skill.status_chance:
				var status_effect = StatusEffect.new()
				status_effect.attribute = skill.status_inflicted
				status_effect.amount = 0
				status_effect.duration = skill.duration if skill.duration > 0 else 2
				status_effect.type = StatusEffect.Type.DEBUFF
				alvo.apply_status_effect(status_effect, (skill.hit_chance * 100))
				battle_manager.hud.show_top_message("%s foi afetado por %s!" % [alvo.nome, skill.status_inflicted])

	# --- Finalização ---
	battle_manager.reset_atb(user)
	battle_manager.hud.update_party_info(battle_manager.party)
	await battle_manager.get_tree().create_timer(0).timeout
	battle_manager._create_menu()
	battle_manager.end_turn()

func _execute_spell_area(caster, spell_name, alvos):
	# --- Checagens ---
	var spell = get_spell_by_name(caster.spells, spell_name)
	if spell == null:
		battle_manager.hud.show_top_message("Magia não encontrada.")
		await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()
		return
	if caster.current_mp < spell.cost:
		battle_manager.hud.show_top_message("%s não tem MP suficiente para usar %s!" % [caster.nome, spell.name])
		await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()
		return
	if !caster.spell_slots.has(spell.level) or caster.spell_slots[spell.level] <= 0:
		battle_manager.hud.show_top_message("%s não tem slots de nível %d suficientes para usar %s!" % [caster.nome, spell.level, spell.name])
		await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()
		return
	caster.current_mp -= spell.cost
	caster.spell_slots[spell.level] -= 1
	
	# --- ANIMAÇÃO (PULINHO) ---
	var can_animate_caster = caster.has_method("get_global_position") and caster.sprite_ref != null # <-- CORRIGIDO
	if can_animate_caster:
		var original_local_pos_y = caster.sprite_ref.position.y
		var tween_jump = battle_manager.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT_IN)
		tween_jump.tween_property(caster.sprite_ref, "position:y", original_local_pos_y - 20, 0.15)
		tween_jump.tween_property(caster.sprite_ref, "position:y", original_local_pos_y, 0.15).set_delay(0.15)
		await tween_jump.finished
	# --- FIM DA ANIMAÇÃO ---

	# --- LÓGICA DE DANO/EFEITO (Seu código original) ---
	for alvo in alvos:
		# ... (código de dano/cura/buff de magia em área) ...
		if alvo.current_hp <= 0:
			continue
		if alvo.has_status("float") and spell.element == "earth":
			battle_manager.hud.show_top_message("%s flutuou e evitou o ataque!" % alvo.nome)
			continue
		var tipo = spell.type
		if tipo == "damage":
			var base_dano = spell.power + caster.get_modified_stat(caster.INT, "INT")
			var defesa_magica = alvo.get_modified_derived_stat("magic_defense")
			var dano = base_dano - defesa_magica
			dano = max(dano, 1)
			var crit_chance = caster.get_modified_stat(caster.LCK, "LCK") * 0.01
			if randf() < crit_chance:
				dano *= 2
				battle_manager.hud.show_top_message("CRÍTICO MÁGICO! %s usou %s e causou %d de dano em %s!" % [caster.nome, spell.name, dano, alvo.nome])
			else:
				battle_manager.hud.show_top_message("%s usou %s em %s causando %d de dano!" % [caster.nome, spell.name, alvo.nome, dano])
			var element_res = 1.0
			var attack_type_res = 1.0
			if spell.element != "":
				element_res = alvo.element_resistances.get(spell.element.to_lower(), 1.0)
			if spell.attack_type != "":
				attack_type_res = alvo.attack_type_resistances.get(spell.attack_type.to_lower(), 1.0)
			dano *= element_res * attack_type_res
			if alvo.get_meta("reflect_active", false):
				battle_manager.hud.show_top_message("%s refletiu a magia de volta para %s!" % [alvo.nome, caster.nome])
				aplicar_dano(caster, alvo, dano)
				battle_manager.hud.show_floating_number(dano, caster, "damage")
				continue
			if alvo.get_meta("shell_active", false):
				dano *= 0.5
				battle_manager.hud.show_top_message("%s foi protegido por Shell!" % alvo.nome)
			caster.gain_ap(spell.name, 100, true)
			aplicar_dano(alvo, caster, dano)
			if alvo.current_hp <= 0:
				alvo.current_hp = 0
				if alvo.has_method("check_if_dead"):
					alvo.check_if_dead()
			battle_manager.hud.show_floating_number(dano, alvo, "damage")
		elif tipo == "heal":
			var cura = spell.power + caster.get_modified_stat(caster.SPI, "SPI")
			caster.gain_ap(spell.name, 100, true)
			alvo.current_hp = min(alvo.max_hp, alvo.current_hp + cura)
			battle_manager.hud.show_top_message("%s curado por %s: %d de HP!" % [alvo.nome, spell.name, cura])
			battle_manager.hud.show_floating_number(cura, alvo, "hp")
		elif tipo == "buff" or tipo == "debuff":
			var ap_gain = int(100)
			caster.gain_ap(spell.name, ap_gain, true)
			if spell.attribute != "":
				var effect = StatusEffect.new()
				effect.attribute = spell.attribute
				effect.amount = spell.amount
				effect.duration = spell.duration
				effect.type = StatusEffect.Type.BUFF if spell.type == "buff" else StatusEffect.Type.DEBUFF
				alvo.apply_status_effect(effect, spell.chance)
				var acao = "aumentado" if spell.type == "buff" else "reduzido"
				battle_manager.hud.show_top_message("%s teve %s %s por %s!" % [alvo.nome, spell.attribute, acao, spell.name])
			for entry in spell.status_effects:
				if randf() * 100 <= entry.get("chance", 100):
					var extra_effect = StatusEffect.new()
					extra_effect.attribute = entry.get("attribute", "")
					extra_effect.amount = entry.get("amount", 0)
					extra_effect.duration = entry.get("duration", 3)
					extra_effect.type = StatusEffect.Type.DEBUFF
					alvo.apply_status_effect(extra_effect, spell.chance)
					battle_manager.hud.show_top_message("%s sofreu o efeito %s de %s!" % [alvo.nome, extra_effect.attribute, spell.name])
		elif tipo == "cure_status":
			var cured = []
			for entry in spell.status_effects:
				var attribute = entry.get("attribute", "")
				if alvo.has_status(attribute):
					alvo.remove_status_effect(attribute)
					cured.append(attribute)
			if cured.size() > 0:
				battle_manager.hud.show_top_message("%s foi curado de: %s!" % [alvo.nome, ", ".join(cured)])
			else:
				battle_manager.hud.show_top_message("%s não tinha status removíveis com %s." % [alvo.nome, spell.name])

	# --- Finalização ---
	battle_manager.reset_atb(caster)
	battle_manager.hud.update_party_info(battle_manager.party)
	await battle_manager.get_tree().create_timer(0).timeout
	battle_manager._create_menu()
	battle_manager.end_turn()

func _execute_spell_single(caster, spell_name, alvo):
	# --- Checagens ---
	var spell = get_spell_by_name(caster.spells, spell_name)
	if spell == null:
		# ... (código de erro) ...
		battle_manager.hud.show_top_message("Magia não encontrada.")
		await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()
		return
	if caster.current_mp < spell.cost:
		# ... (código de erro) ...
		battle_manager.hud.show_top_message("%s não tem MP suficiente para usar %s!" % [caster.nome, spell.name])
		await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()
		return
	if !caster.spell_slots.has(spell.level) or caster.spell_slots[spell.level] <= 0:
		# ... (código de erro) ...
		battle_manager.hud.show_top_message("%s não tem slots de nível %d suficientes para usar %s!" % [caster.nome, spell.level, spell.name])
		await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()
		return
	caster.current_mp -= spell.cost
	caster.spell_slots[spell.level] -= 1

	# --- ANIMAÇÃO (PULINHO) ---
	var can_animate_caster = caster.has_method("get_global_position") and caster.sprite_ref != null # <-- CORRIGIDO
	if can_animate_caster:
		var original_local_pos_y = caster.sprite_ref.position.y
		var tween_jump = battle_manager.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT_IN)
		tween_jump.tween_property(caster.sprite_ref, "position:y", original_local_pos_y - 20, 0.15)
		tween_jump.tween_property(caster.sprite_ref, "position:y", original_local_pos_y, 0.15).set_delay(0.15)
		await tween_jump.finished
	# --- FIM DA ANIMAÇÃO ---

	# --- LÓGICA DE DANO/EFEITO (Seu código original) ---
	var tipo = spell.type
	if tipo == "summon":
		summon_entity(spell, caster)
		battle_manager.reset_atb(caster)
		await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()
		return

	if alvo == null:
		# ... (código de erro) ...
		battle_manager.hud.show_top_message("Nenhum alvo válido.")
		await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()
		return
	if alvo.has_status("float") and spell.element == "earth":
		# ... (código de erro) ...
		battle_manager.hud.show_top_message("%s flutuou e evitou o ataque!" % alvo.nome)
		return

	if tipo == "damage":
		# ... (código de dano) ...
		var base_dano = spell.power + caster.get_modified_stat(caster.INT, "INT")
		var defesa_magica = alvo.get_modified_derived_stat("magic_defense")
		var dano = base_dano - defesa_magica
		dano = max(dano, 1)
		var crit_chance = caster.get_modified_stat(caster.LCK, "LCK") * 0.01
		if randf() < crit_chance:
			dano *= 2
			battle_manager.hud.show_top_message("CRÍTICO MÁGICO! %s usou %s e causou %d de dano em %s!" % [caster.nome, spell.name, dano, alvo.nome])
		else:
			battle_manager.hud.show_top_message("%s usou %s em %s causando %d de dano!" % [caster.nome, spell.name, alvo.nome, dano])
		var element_res = 1.0
		var attack_type_res = 1.0
		if spell.element != "":
			element_res = alvo.element_resistances.get(spell.element.to_lower(), 1.0)
		else:
			element_res = 1.0
		if spell.attack_type != "":
			attack_type_res = alvo.attack_type_resistances.get(spell.attack_type.to_lower(), 1.0)
		else:
			attack_type_res = 1.0
		dano *= element_res * attack_type_res
		if alvo.get_meta("shell_active", false):
			dano *= 0.5
			battle_manager.hud.show_top_message("%s foi protegido por Shell!" % alvo.nome)
		var ap_gain = int(100)
		caster.gain_ap(spell.name, ap_gain, true)
		aplicar_dano(alvo, caster, dano)
		if alvo.current_hp <= 0:
			alvo.current_hp = 0
			if alvo.has_method("check_if_dead"):
				alvo.check_if_dead()
		battle_manager.hud.show_floating_number(dano, alvo, "damage")
		
	elif tipo == "heal":
		# ... (código de cura) ...
		var cura = spell.power + caster.get_modified_stat(caster.SPI, "SPI")
		var ap_gain = int(100)
		caster.gain_ap(spell.name, ap_gain, true)
		alvo.current_hp = min(alvo.max_hp, alvo.current_hp + cura)
		battle_manager.hud.show_top_message("%s curou %s com %s em %d de HP!" % [caster.nome, alvo.nome, spell.name, cura])
		battle_manager.hud.show_floating_number(cura, alvo, "hp")
		
	elif tipo == "buff" or tipo == "debuff":
		# ... (código de buff/debuff) ...
		var ap_gain = int(100)
		caster.gain_ap(spell.name, ap_gain, true)
		if spell.status_effects.size() == 0 and spell.attribute != "":
			var effect = StatusEffect.new()
			effect.attribute = spell.attribute
			effect.amount = spell.amount
			effect.duration = spell.duration
			effect.type = StatusEffect.Type.BUFF if spell.type == "buff" else StatusEffect.Type.DEBUFF
			effect.status_type = spell.attribute
			alvo.apply_status_effect(effect, spell.chance)
			var acao = "aumentado" if spell.type == "buff" else "reduzido"
			battle_manager.hud.show_top_message("%s teve %s %s por %s!" % [alvo.nome, spell.attribute, acao, spell.name])
		for entry in spell.status_effects:
			var effect = StatusEffect.new()
			effect.attribute = entry["attribute"]
			effect.amount = entry["amount"]
			effect.duration = entry["duration"]
			effect.type = StatusEffect.Type.DEBUFF if spell.type == "debuff" else StatusEffect.Type.BUFF
			effect.status_type = entry["status_type"]
			effect.chance = entry["chance"]
			if randf() * 100 <= effect.chance:
				alvo.apply_status_effect(effect)
				var desc = effect.status_type if effect.status_type != "" else effect.attribute
				battle_manager.hud.show_top_message("%s sofreu o efeito %s de %s!" % [alvo.nome, desc, spell.name])

	elif tipo == "cure_status":
		# ... (código de cura de status) ...
		var cured = []
		for entry in spell.status_effects:
			var attribute = entry["attribute"]
			if alvo.has_status(attribute):
				alvo.remove_status_effect(attribute)
				cured.append(attribute)
		if cured.size() > 0:
			battle_manager.hud.show_top_message("%s foi curado de: %s!" % [alvo.nome, ", ".join(cured)])
		else:
			battle_manager.hud.show_top_message("%s não tinha status removíveis com %s." % [alvo.nome, spell.name])

	# --- Finalização ---
	battle_manager.reset_atb(caster)
	battle_manager.hud.update_party_info(battle_manager.party)
	await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	battle_manager.end_turn()

func _execute_special_area(caster, special: Special, alvos):
	# --- ANIMAÇÃO (PULINHO) ---
	var can_animate = caster.has_method("get_global_position") and caster.sprite_ref != null # <-- CORRIGIDO
	if can_animate:
		var original_local_pos_y = caster.sprite_ref.position.y
		var tween_jump = battle_manager.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT_IN)
		tween_jump.tween_property(caster.sprite_ref, "position:y", original_local_pos_y - 20, 0.15)
		tween_jump.tween_property(caster.sprite_ref, "position:y", original_local_pos_y, 0.15).set_delay(0.15)
		await tween_jump.finished
	# --- FIM DA ANIMAÇÃO ---
	
	for alvo in alvos:
		# ... (código de dano/cura/buff de especial em área) ...
		if alvo.current_hp <= 0:
			continue
		match special.effect_type:
			"damage":
				var dano = special.power + caster.get_modified_stat(caster.STR, "STR")
				dano = ajustar_dano_por_posicao(dano, caster, alvo, true)
				aplicar_dano(alvo, caster, dano)
				battle_manager.hud.show_floating_number(dano, alvo, "damage")
			"heal":
				var cura = special.power + caster.get_modified_stat(caster.SPI, "SPI")
				alvo.current_hp = min(alvo.max_hp, alvo.current_hp + cura)
				battle_manager.hud.show_floating_number(cura, alvo, "hp")
			"buff":
				var effect = StatusEffect.new()
				effect.attribute = special.attribute
				effect.amount = special.amount
				effect.duration = special.duration
				effect.type = StatusEffect.Type.BUFF
				alvo.apply_status_effect(effect)

	battle_manager.hud.show_top_message("%s usou %s!" % [caster.nome, special.name])
	battle_manager.reset_atb(caster)
	battle_manager.hud.update_party_info(battle_manager.party)
	await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout

	caster.special_charge = 0
	battle_manager.sp_values[caster] = 0
	caster.special_ready = false
	battle_manager.hud.update_special_bar(battle_manager.sp_values)

	battle_manager._create_menu()
	battle_manager.end_turn()

func _execute_special_single(user, special, alvo):
	# --- ANIMAÇÃO (PULINHO, a menos que seja físico) ---
	var is_special_fisico = special.attack_type in ["Slash", "Pierce", "Blunt", "Ranged"]
	var can_animate = user.has_method("get_global_position") and user.sprite_ref != null # <-- CORRIGIDO
	var original_pos := Vector2.ZERO # <-- CORRIGIDO
	
	if can_animate:
		original_pos = user.sprite_ref.global_position

	# SE for ESPECIAL FÍSICO, avança
	if is_special_fisico and can_animate:
		var attack_move_offset = Vector2(-80, 0)
		if user is Enemy1990:
			attack_move_offset.x = 80
		var attack_position = original_pos + attack_move_offset
		var tween_go = battle_manager.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween_go.tween_property(user.sprite_ref, "global_position", attack_position, 0.15)
		await tween_go.finished
	# SE for ESPECIAL MÁGICO/OUTRO, dá um "pulinho"
	elif can_animate: 
		var original_local_pos_y = user.sprite_ref.position.y
		var tween_jump = battle_manager.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT_IN)
		tween_jump.tween_property(user.sprite_ref, "position:y", original_local_pos_y - 20, 0.15)
		tween_jump.tween_property(user.sprite_ref, "position:y", original_local_pos_y, 0.15).set_delay(0.15)
		await tween_jump.finished
	# --- FIM DA ANIMAÇÃO ---

	# --- LÓGICA DE DANO/EFEITO (Seu código original) ---
	match special.effect_type:
		"damage":
			# ... (código de dano) ...
			var dano = special.power + user.get_modified_stat(user.STR, "STR")
			dano = ajustar_dano_por_posicao(dano, user, alvo, true)
			aplicar_dano(alvo, user, dano)
			battle_manager.hud.show_top_message("%s usou %s e causou %d de dano!" % [user.nome, special.name, dano])
			battle_manager.hud.show_floating_number(dano, alvo, "damage")
		"heal":
			# ... (código de cura) ...
			var cura = special.power + user.get_modified_stat(user.SPI, "SPI")
			alvo.current_hp = min(alvo.max_hp, alvo.current_hp + cura)
			battle_manager.hud.show_top_message("%s usou %s e curou %d HP!" % [user.nome, special.name, cura])
			battle_manager.hud.show_floating_number(cura, alvo, "hp")
		"buff":
			# ... (código de buff) ...
			var effect = StatusEffect.new()
			effect.attribute = special.attribute
			effect.amount = special.amount
			effect.duration = special.duration
			effect.type = StatusEffect.Type.BUFF
			alvo.apply_status_effect(effect)
			battle_manager.hud.show_top_message("%s usou %s e aumentou %s!" % [user.nome, special.name, special.attribute])

	# --- ANIMAÇÃO DE VOLTA (SE AVANÇOU) ---
	if is_special_fisico and can_animate:
		await battle_manager.get_tree().create_timer(0.1).timeout
		var tween_back = battle_manager.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween_back.tween_property(user.sprite_ref, "global_position", original_pos, 0.2)
		await tween_back.finished
	# --- FIM DA ANIMAÇÃO DE VOLTA ---

	# --- Finalização ---
	battle_manager.reset_atb(user)
	battle_manager.hud.update_party_info(battle_manager.party)
	await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout

	user.special_charge = 0
	battle_manager.sp_values[user] = 0
	user.special_ready = false
	battle_manager.hud.update_special_bar(battle_manager.sp_values)

	battle_manager._create_menu()
	battle_manager.end_turn()

func usar_item_em_alvo(usuario, item_name: String, item_data: Dictionary, target_id) -> void:
	# --- ANIMAÇÃO (PULINHO) ---
	var can_animate = usuario.has_method("get_global_position") and usuario.sprite_ref != null # <-- CORRIGIDO
	if can_animate:
		var original_local_pos_y = usuario.sprite_ref.position.y
		var tween_jump = battle_manager.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT_IN)
		tween_jump.tween_property(usuario.sprite_ref, "position:y", original_local_pos_y - 20, 0.15)
		tween_jump.tween_property(usuario.sprite_ref, "position:y", original_local_pos_y, 0.15).set_delay(0.15)
		await tween_jump.finished
	# --- FIM DA ANIMAÇÃO ---

	# --- LÓGICA DE ITEM (Seu código original) ---
	var alvo = null
	for membro in battle_manager.party:
		if membro.id == target_id:
			alvo = membro
			break
	if alvo == null:
		print("Erro: alvo com ID %s não encontrado na party!" % target_id)
		return
	
	match item_data.type:
		"heal":
			# ... (código) ...
			alvo.current_hp += item_data.power
			alvo.current_hp = min(alvo.current_hp, alvo.max_hp)
			battle_manager.hud.show_floating_number(item_data.power, alvo, "hp")
			battle_manager.hud.show_top_message("%s usou %s em %s!" % [usuario.nome, item_name, alvo.nome])
		"restore_mp":
			# ... (código) ...
			alvo.current_mp += item_data.power
			alvo.current_mp = min(alvo.current_mp, alvo.max_mp)
			battle_manager.hud.show_floating_number(item_data.power, alvo, "mp")
			battle_manager.hud.show_top_message("%s recuperou MP com %s!" % [alvo.nome, item_name])
		"restore_sp":
			# ... (código) ...
			alvo.current_sp += item_data.power
			alvo.current_sp = min(alvo.current_mp, alvo.max_sp)
			battle_manager.hud.show_floating_number(item_data.power, alvo, "sp")
			battle_manager.hud.show_top_message("%s recuperou MP com %s!" % [alvo.nome, item_name])
		"full_restore":
			# ... (código) ...
			alvo.current_hp = alvo.max_hp
			alvo.current_mp = alvo.max_mp
			alvo.current_sp = alvo.max_sp
			battle_manager.hud.show_floating_number(alvo.max_hp, alvo, "hp")
			await battle_manager.get_tree().create_timer(1.0).timeout
			battle_manager.hud.show_floating_number(alvo.max_mp, alvo, "mp")
			await battle_manager.get_tree().create_timer(1.0).timeout
			battle_manager.hud.show_floating_number(alvo.max_sp, alvo, "sp")
			battle_manager.hud.show_top_message("%s foi totalmente restaurado com %s!" % [alvo.nome, item_name])
		"cure_status":
			# ... (código) ...
			alvo.remove_status(item_data.status)
			battle_manager.hud.show_top_message("%s foi curado de %s!" % [alvo.nome, item_data.status])

	if battle_manager.inventory.has(item_name):
		battle_manager.inventory[item_name] -= 1
		if battle_manager.inventory[item_name] <= 0:
			battle_manager.inventory.erase(item_name)

	# --- Finalização ---
	battle_manager.reset_atb(usuario)
	battle_manager.hud.update_party_info(battle_manager.party)
	await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
	battle_manager.hud.hide_arrow()
	battle_manager.end_turn()

func tentar_fugir(actor) -> void:
	# --- ANIMAÇÃO (PULINHO) ---
	var can_animate = actor.has_method("get_global_position") and actor.sprite_ref != null # <-- CORRIGIDO
	if can_animate:
		var original_local_pos_y = actor.sprite_ref.position.y
		var tween_jump = battle_manager.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT_IN)
		tween_jump.tween_property(actor.sprite_ref, "position:y", original_local_pos_y - 20, 0.15)
		tween_jump.tween_property(actor.sprite_ref, "position:y", original_local_pos_y, 0.15).set_delay(0.15)
		await tween_jump.finished
	# --- FIM DA ANIMAÇÃO ---

	# --- LÓGICA DE FUGA (Seu código original) ---
	var party = battle_manager.party
	var vivos = party.filter(func(p): return p.is_alive()).size()
	if vivos == 0:
		battle_manager.hud.show_top_message("Ninguém pode fugir!")
		return

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var agi_total = 0
	var lck_total = 0
	for membro in party:
		if membro.is_alive():
			agi_total += membro.AGI
			lck_total += membro.LCK

	var media_agi = agi_total / vivos
	var media_lck = lck_total / vivos

	var chance_fuga = clamp((media_agi * 2 + media_lck) / 3 + rng.randi_range(0, 20), 0, 100)
	var roll = rng.randi_range(0, 100)

	if roll < chance_fuga:
		battle_manager.hud.show_top_message("%s escapou com sucesso!" % actor.nome)
		await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.reset_atb(actor)
		battle_manager.end_battle(false)
	else:
		battle_manager.hud.show_top_message("%s tentou fugir, mas falhou!" % actor.nome)
		await battle_manager.get_tree().create_timer(0.2).timeout
		battle_manager.hud.hide_arrow()
		battle_manager.reset_atb(actor)
		battle_manager.hud.set_hud_buttons_enabled(false)
		await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout
		battle_manager.end_turn()

func summon_entity(spell: Spell, caster):
	# (Não precisa de animação de pulo aqui, pois _execute_spell_single já fez)
	
	if battle_manager.in_summon_mode:
		battle_manager.hud.show_top_message("Já há uma invocação ativa!")
		return

	battle_manager.in_summon_mode = true
	battle_manager.saved_party = battle_manager.party.duplicate()
	for member in battle_manager.saved_party:
		if member.sprite_ref:
			member.sprite_ref.queue_free()

	var summon_data = spell.summon_data
	var sprite_path = summon_data.get("sprite_path", "")
	var summon = Summon.new()
	summon.setup(summon_data["nome"], summon_data, sprite_path)
	
	for spell_name in summon_data.get("spells", []):
		if Database1990.spell_database.has(spell_name):
			var new_spell = battle_manager.create_spell(spell_name, Database1990.spell_database[spell_name])
			summon.spells.append(new_spell)
	
	battle_manager.current_summon = summon
	battle_manager.party = [summon]

	var summon_sprite = preload("res://decades/1990s/Battle/PlayerSprite.tscn").instantiate()
	summon_sprite.set_sprite(sprite_path)
	summon_sprite.position = battle_manager.get_player_position(0, true)
	summon_sprite.set_player(summon)
	summon_sprite.scale = Vector2(1.5, 1.5)
	summon.sprite_ref = summon_sprite
	battle_manager.characters_node.add_child(summon_sprite)

	battle_manager.turn_order = [summon] + battle_manager.enemies
	battle_manager._create_menu()
	battle_manager.hud.update_party_info(battle_manager.party)



# Esta função é ESPECÍFICA para a skill Sopro de Fogo do Dragão
func perform_dragon_fire_breath(attacker, targets: Array):
	
	# --- ANIMAÇÃO DE PULINHO ---
	var can_animate = attacker.has_method("get_global_position") and attacker.sprite_ref != null
	if can_animate:
		var original_local_pos_y = attacker.sprite_ref.position.y
		var tween_jump = battle_manager.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT_IN)
		tween_jump.tween_property(attacker.sprite_ref, "position:y", original_local_pos_y - 20, 0.15)
		tween_jump.tween_property(attacker.sprite_ref, "position:y", original_local_pos_y, 0.15).set_delay(0.15)
		await tween_jump.finished
	# --- FIM DA ANIMAÇÃO ---
	
	var skill_power = 25 # <-- Defina o dano base do Sopro de Fogo aqui
	var skill_element = "fire"
	
	# Itera em todos os alvos vivos
	for alvo in targets:
		if not alvo.is_alive():
			continue
		
		# (Lógica de dano mágico copiada da sua _execute_spell_area)
		var base_dano = skill_power + attacker.get_modified_stat(attacker.INT, "INT")
		var defesa_magica = alvo.get_modified_derived_stat("magic_defense")
		var dano = base_dano - defesa_magica
		dano = max(dano, 1)
		
		# Aplica resistência ao Fogo
		var element_res = alvo.element_resistances.get(skill_element, 1.0)
		dano *= element_res
		dano = int(dano)
		
		# Mostra a mensagem de dano
		if element_res > 1.0:
			battle_manager.hud.show_top_message("Vulnerável! %d de dano em %s!" % [dano, alvo.nome])
		elif element_res < 1.0:
			battle_manager.hud.show_top_message("Resistiu! %d de dano em %s!" % [dano, alvo.nome])
		else:
			battle_manager.hud.show_top_message("%s causou %d de dano em %s!" % [attacker.nome, dano, alvo.nome])
		
		# Aplica o dano
		aplicar_dano(alvo, attacker, dano)
		battle_manager.hud.show_floating_number(dano, alvo, "damage")
		
		# Checa se o alvo morreu
		if alvo.current_hp <= 0:
			alvo.current_hp = 0
			if alvo.has_method("check_if_dead"):
				alvo.check_if_dead()

	# Espera o delay da ação
	await battle_manager.get_tree().create_timer(TEMPO_ESPERA_APOS_ACAO).timeout


# ============================================
# FUNÇÕES "AJUDANTES" DAS AÇÕES
# ============================================

func get_spell_by_name(spells: Array, name: String) -> Spell:

	for spell in spells:
		if spell.name == name:
			return spell
	return null

func aplicar_dano(alvo, atacante, dano: int) -> void:

	if alvo.has_blink_active():
		alvo.consume_blink_charge()
		battle_manager.hud.show_top_message("%s desviou com Blink!" % alvo.nome)
		return
	alvo.current_hp -= int(dano)
	if alvo.current_hp < 0:
		alvo.current_hp = 0
		alvo.check_if_dead()
	var updated := false
	if battle_manager.is_player(alvo):
		if alvo.increase_special_charge(dano * 0.75):
			battle_manager.sp_values[alvo] = alvo.special_charge
			updated = true
	if battle_manager.is_player(atacante):
		if atacante.increase_special_charge(dano * 0.5):
			battle_manager.sp_values[atacante] = atacante.special_charge
			updated = true
	if updated:
		battle_manager.hud.update_special_bar(battle_manager.sp_values)
	battle_manager.atualizar_obstrucao_inimigos()
	battle_manager.atualizar_obstrucao_party()

func ajustar_dano_por_posicao(dano: int, atacante, alvo, is_ataque_fisico: bool) -> int:

	if not is_ataque_fisico:
		return dano
	if atacante.position_line == "back":
		dano *= 0.7
	if alvo.position_line == "back":
		dano *= 0.5
	return int(dano)

func pode_atacar(alvo, atacante, is_ataque_fisico: bool) -> bool:

	if not is_ataque_fisico:
		return true
	if not alvo.obstruido:
		return true
	if alvo.obstruido and not atacante.alcance_estendido:
		return false
	if alvo.position_line == "front":
		return true
	return atacante.alcance_estendido

func attempt_steal(user, alvo):

	var chance_base = 0.2 + (user.DEX + user.LCK) * 0.01
	var roll = randf()
	if roll <= chance_base and alvo.loot.size() > 0:
		var item = alvo.loot.pick_random()
		battle_manager.hud.show_top_message("%s roubou %s de %s!" % [user.nome, item, alvo.nome])
		if battle_manager.inventory.has(item):
			battle_manager.inventory[item] += 1
		else:
			battle_manager.inventory[item] = 1
	else:
		battle_manager.hud.show_top_message("%s tentou roubar, mas falhou!" % user.nome)

func display_scan_info(alvo):

	var fraquezas = alvo.get_element_weaknesses() if alvo.has_method("get_element_weaknesses") else []
	var status = alvo.get_status_descriptions() if alvo.has_method("get_status_descriptions") else []
	battle_manager.hud.show_top_message("Fraquezas: %s\nStatus: %s" % [", ".join(fraquezas), ", ".join(status)])

func drain_mp(user, alvo):

	var amount = min(10, alvo.current_mp)
	alvo.current_mp -= amount
	user.current_mp += amount
	battle_manager.hud.show_top_message("%s drenou %d MP de %s!" % [user.nome, amount, alvo.nome])

func apply_spell_effects(target, spell, caster):

	for status in spell.get("status_effects", []):
		if status.has("chance") and randf() * 100 > status["chance"]:
			continue
		var effect = StatusEffect.new()
		effect.attribute = status.get("attribute", "")
		effect.amount = status.get("amount", 0)
		effect.duration = status.get("duration", 3)
		effect.status_type = status.get("status_type", "")
		if status.get("amount", 0) >= 0:
			effect.type = StatusEffect.Type.BUFF
		else:
			effect.type = StatusEffect.Type.DEBUFF
		target.apply_status_effect(effect, spell.chance)
		var acao = effect.type == StatusEffect.Type.BUFF and "aumentado" or "reduzido"
		if effect.status_type != "":
			battle_manager.hud.show_top_message("%s foi afetado por %s!" % [target.nome, effect.status_type])
		elif effect.attribute != "":
			battle_manager.hud.show_top_message("%s teve %s %s!" % [target.nome, effect.attribute, acao])
