extends Control

## Start screen. Play loads the arena; Quit closes the game.

const GAME_SCENE := "res://scenes/main.tscn"

@onready var _play_button: Button = $Menu/PlayButton
@onready var _quit_button: Button = $Menu/QuitButton


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	# Focused up front so a controller's A button starts a match straight away.
	_play_button.grab_focus()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
