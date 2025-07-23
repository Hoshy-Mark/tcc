# res://scripts/Game1990.gd
extends Node2D

@onready var background = $Background
var battle_manager: Node = null

func _ready():
	load_battle_manager()

func load_battle_manager():
	var battle_manager_scene = load("res://decades/1990s/BattleManager.tscn")
	battle_manager = battle_manager_scene.instantiate()
	add_child(battle_manager)
	
	battle_manager.start_battle(Global.party_selection)


func set_background(texture_path: String) -> void:
	var texture = load("res://assets/Campo Verde.png")
	if texture and background:
		background.texture = texture
