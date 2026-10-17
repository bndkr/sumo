extends "res://tests/game_test_case.gd"

## Whole-game wiring, loaded from the real main scene.


func test_main_scene_without_controllers_waits_for_a_second_player() -> void:
	if not Input.get_connected_joypads().is_empty():
		skip("controllers are connected; this test expects the keyboard-only setup")
		return

	var main := spawn(MAIN_SCENE)
	await wait_physics(3)
	var manager := main.get_node("GameManager") as GameManager
	var rounds := main.get_node("RoundManager") as RoundManager

	assert_eq(manager.players.size(), 1, "keyboard fallback spawns a single wrestler")
	assert_eq(rounds.state, RoundManager.State.WAITING, "a round needs two wrestlers")
