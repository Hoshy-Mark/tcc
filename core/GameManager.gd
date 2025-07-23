extends Node

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

var current_state: GameState = GameState.MENU

var saved_party_data : Array = []


func start_game() -> void:
	current_state = GameState.PLAYING
	print("Estado: PLAYING")

func end_game() -> void:
	current_state = GameState.GAME_OVER
	get_tree().change_scene_to_file("res://core/UI/GameOver.tscn")

func pause_game() -> void:
	current_state = GameState.PAUSED
	get_tree().paused = true

func resume_game() -> void:
	current_state = GameState.PLAYING
	get_tree().paused = false
	
func resetar_dados() -> void:
	saved_party_data.clear()
	print("DEBUG: Dados salvos resetados!")
	
func has_saved_data() -> bool:
	return saved_party_data.size() > 0
