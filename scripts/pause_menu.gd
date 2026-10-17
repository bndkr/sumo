extends CanvasLayer

## Pause overlay for a match. Start on a controller (or Escape) toggles it.
##
## The layer and its children run in ALWAYS process mode, so the overlay keeps
## responding while the rest of the game is paused.

const MENU_SCENE := "res://scenes/main_menu.tscn"

@onready var _resume_button: Button = $Center/Panel/Menu/ResumeButton
@onready var _menu_button: Button = $Center/Panel/Menu/MainMenuButton
@onready var _quit_button: Button = $Center/Panel/Menu/QuitButton


func _ready() -> void:
	_resume_button.pressed.connect(resume)
	_menu_button.pressed.connect(_on_main_menu_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			resume()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		resume()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = true
	_resume_button.grab_focus()


func resume() -> void:
	visible = false
	get_tree().paused = false


func _on_main_menu_pressed() -> void:
	# Unpause before switching: the pause state belongs to the tree, not the scene.
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
