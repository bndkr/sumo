extends "res://tests/game_test_case.gd"

## Start screen and pause overlay.

const MAIN_MENU_SCENE := preload("res://scenes/main_menu.tscn")


func test_main_menu_offers_play_and_quit_with_play_focused() -> void:
	var menu := add_to_scene(MAIN_MENU_SCENE.instantiate())
	await wait_physics(1)

	var play := menu.find_child("PlayButton", true, false) as Button
	var quit := menu.find_child("QuitButton", true, false) as Button
	assert_true(play != null and play.text == "Play", "the menu has a Play button")
	assert_true(quit != null and quit.text == "Quit", "the menu has a Quit button")
	assert_true(play != null and play.has_focus(), "Play starts focused so a controller can use it straight away")


func test_pause_action_is_bound_to_start_and_escape() -> void:
	var has_start := false
	var has_escape := false
	for event in InputMap.action_get_events("pause"):
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START:
			has_start = true
		if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
			has_escape = true
	assert_true(has_start, "the pause action responds to the controller's Start button")
	assert_true(has_escape, "the pause action also responds to Escape")


func test_start_button_pauses_and_resumes_a_match() -> void:
	var main := spawn(MAIN_SCENE)
	await wait_physics(3)
	var pause_menu := main.get_node("PauseMenu") as CanvasLayer

	assert_true(not tree.paused, "a match starts unpaused")
	assert_true(not pause_menu.visible, "the pause overlay starts hidden")

	await _press_button(JOY_BUTTON_START)
	assert_true(tree.paused, "Start pauses the match")
	assert_true(pause_menu.visible, "Start shows the pause overlay")

	await _press_button(JOY_BUTTON_START)
	assert_true(not tree.paused, "Start again resumes the match")
	assert_true(not pause_menu.visible, "resuming hides the overlay")


func test_pause_overlay_keeps_running_while_the_game_is_paused() -> void:
	var main := spawn(MAIN_SCENE)
	await wait_physics(3)
	var pause_menu := main.get_node("PauseMenu") as CanvasLayer

	await _press_button(JOY_BUTTON_START)
	var resume := pause_menu.find_child("ResumeButton", true, false) as Button
	assert_true(resume != null and resume.is_visible_in_tree(), "the overlay is on screen while paused")
	assert_true(resume != null and resume.has_focus(), "Resume is focused on pause so A resumes")


func test_ui_accept_is_bound_to_the_a_button() -> void:
	var has_a := false
	for event in InputMap.action_get_events("ui_accept"):
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
			has_a = true
	assert_true(has_a, "ui_accept (used by buttons) responds to A")


func test_ui_accept_keeps_the_keyboard_keys() -> void:
	var keys := []
	for event in InputMap.action_get_events("ui_accept"):
		if event is InputEventKey:
			keys.append(event.keycode)
	assert_true(KEY_ENTER in keys and KEY_SPACE in keys, "Enter and Space still press buttons")


func test_ui_cancel_is_bound_to_the_b_button() -> void:
	var has_b := false
	for event in InputMap.action_get_events("ui_cancel"):
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B:
			has_b = true
	assert_true(has_b, "ui_cancel (used to close the pause menu) responds to B")


func test_controller_a_presses_the_focused_pause_button() -> void:
	spawn(MAIN_SCENE)
	await wait_physics(3)
	await _press_button(JOY_BUTTON_START)
	assert_true(tree.paused, "Start opens the pause overlay before testing A")

	await _press_button(JOY_BUTTON_A)
	assert_true(not tree.paused, "A should press the focused Resume button")


## Sends a press and release of a controller button, as a real pad would.
func _press_button(button: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.device = 0
	press.button_index = button
	press.pressed = true
	Input.parse_input_event(press)
	await wait_physics(2)

	var release := InputEventJoypadButton.new()
	release.device = 0
	release.button_index = button
	release.pressed = false
	Input.parse_input_event(release)
	await wait_physics(2)
