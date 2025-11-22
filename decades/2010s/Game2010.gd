extends Node3D

var arena_scene := preload("res://decades/2000s/World/ArenaMap1.tscn")
var camera_scene := preload("res://decades/2000s/Battle/ThirdPersonCamera3D.tscn")
var hud_scene := preload("res://decades/2010s/UI/MainHUD2010.tscn") # vida + stamina

@onready var battle_manager := $BattleManager2010
@onready var ui_layer := $UI

func _ready():
	var arena = arena_scene.instantiate()
	add_child(arena)

	var camera = camera_scene.instantiate()
	add_child(camera)
	
	var hud = hud_scene.instantiate()
	ui_layer.add_child(hud)
	battle_manager.set_player_hud(hud)
	
	if camera:
		battle_manager.set_camera(camera)
