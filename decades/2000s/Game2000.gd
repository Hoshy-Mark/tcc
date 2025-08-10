extends Node3D

var arena_scene := preload("res://decades/2000s/World/ArenaMap1.tscn")
var camera_scene := preload("res://decades/2000s/Battle/ThirdPersonCamera3D.tscn")
var hud_scene := preload("res://decades/2000s/UI/CombatHUD.tscn")
var ability_hud_scene := preload("res://decades/2000s/UI/AbilityHUD.tscn")

@onready var battle_manager := $BattleManager
@onready var ui_layer := $UI

func _ready():
	var arena = arena_scene.instantiate()
	add_child(arena)

	var camera = camera_scene.instantiate()
	add_child(camera)

	var hud = hud_scene.instantiate()
	ui_layer.add_child(hud)

	var ability_hud = ability_hud_scene.instantiate()
	ui_layer.add_child(ability_hud)

	battle_manager._setup_ui_with_hud(hud)
	battle_manager.set_camera(camera)
	battle_manager.set_ability_hud(ability_hud)
	battle_manager.ability_hud.show_abilities_for(battle_manager.player_character)
