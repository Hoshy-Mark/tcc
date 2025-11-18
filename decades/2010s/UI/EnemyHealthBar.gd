extends Control

var target: CombatCharacter

func set_target(t):
	target = t

func _process(delta):
	if not target:
		queue_free()
		return

	# atualizar barra
	$Bar.value = target.hp
	$Bar.max_value = target.max_hp

	# converter posição 3D para 2D na tela
	var viewport := get_viewport()
	var cam := viewport.get_camera_3d()
	if cam:
		var screen_pos = cam.unproject_position(target.global_position + Vector3(0, 2.4, 0))
		position = screen_pos - size * 0.5
