extends Node3D

#
# PRELOAD DAS CENAS
#
var arena_scene := preload("res://decades/2000s/World/ArenaMap1.tscn")
var camera_scene := preload("res://decades/2020s/ThirdPersonCamera3D.tscn")
var hud_scene := preload("res://decades/2020s/CombatHUD2020.tscn")

# Personagens da party
var player_1 := preload("res://decades/2020s/Barbarian3D.tscn")
var player_2 := preload("res://decades/2020s/Rogue3D.tscn")
var player_3 := preload("res://decades/2020s/Knight3D.tscn")

# Inimigos
var skeleton_scene := preload("res://decades/2020s/EnemySkeleton.tscn")
var mage_scene     := preload("res://decades/2020s/EnemyMage.tscn")
var wolf_scene     := preload("res://decades/2020s/EnemyWolf.tscn")
var archer_scene   := preload("res://decades/2020s/EnemyArcher.tscn")


#
# NÓS DA CENA ATUAL
#
@onready var battle_manager := $BattleManager2020
@onready var ui_layer := $UI


func _ready():

	var arena = arena_scene.instantiate()
	add_child(arena)

	var camera = camera_scene.instantiate()
	add_child(camera)

	var hud = hud_scene.instantiate()
	ui_layer.add_child(hud)

	await get_tree().process_frame
	battle_manager.initialize(hud, camera)

	var party: Array = []
	var enemies: Array = []

	var p1 = player_1.instantiate()
	p1.is_player_controlled = true
	var p2 = player_2.instantiate()
	p2.is_player_controlled = true
	var p3 = player_3.instantiate()
	p3.is_player_controlled = true
	
	var e1 = skeleton_scene.instantiate() # O Esqueleto
	e1.name = "Esqueleto"
	var e2 = wolf_scene.instantiate()     # O Lobo
	e2.name = "Lobo"
	var e3 = archer_scene.instantiate()   # O Arqueiro
	e3.name = "Arqueiro"
	var e4 = mage_scene.instantiate()     # O Mago 
	e4.name = "Mago"
	
	p1.global_position = get_ground_position(Vector3(-3, -1, -1))
	p2.global_position = get_ground_position(Vector3(-3, 0, 0))
	p3.global_position = get_ground_position(Vector3(-3, 1, 1))

	# Inimigos
	e1.global_position = get_ground_position(Vector3(3, 0, -2))
	e2.global_position = get_ground_position(Vector3(4, 0, 0)) # Lobo mais atrás
	e3.global_position = get_ground_position(Vector3(6, 0, -2)) # Arqueiro longe
	e4.global_position = get_ground_position(Vector3(6, 0, 2))  # Mago longe

	add_child(p1)
	party.append(p1)
	add_child(p2)
	party.append(p2)	
	add_child(p3)
	party.append(p3)
	add_child(e1)
	enemies.append(e1)
	add_child(e2)
	enemies.append(e2)
	add_child(e3)
	enemies.append(e3)
	add_child(e4)
	enemies.append(e4)
	
	battle_manager.start_combat(party, enemies)

	
func get_ground_position(world_xz: Vector3, ray_height := 20.0, offset := 0.12) -> Vector3:
	var from = Vector3(world_xz.x, ray_height, world_xz.z)
	var to = Vector3(world_xz.x, -ray_height, world_xz.z)
	var space_state = get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = to
	params.collide_with_bodies = true
	params.collide_with_areas = true
	var res = space_state.intersect_ray(params)
	if res:
		var pos = res.position
		pos.y += offset   # sobe um pouco para evitar clipping
		return pos
	# fallback: sem colisão, retorna com Y=0
	var fallback = world_xz
	fallback.y = 0.0 + offset
	return fallback
