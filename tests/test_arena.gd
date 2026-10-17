extends "res://tests/game_test_case.gd"

## Ring rules: the soft wall, elimination, and the warning track.


func test_full_speed_run_breaks_through_the_soft_wall_and_eliminates() -> void:
	var arena := spawn(ARENA_SCENE) as Arena
	var eliminated := []
	arena.elimination_detected.connect(func(body: Node2D) -> void: eliminated.append(body))
	spawn_player(0, Vector2(300, 0))

	Input.action_press("p1_right")
	var frames: int = await wait_until(func(): return not eliminated.is_empty(), 6 * TICKS_PER_SECOND)
	assert_true(frames >= 0, "a full-speed run should carry a wrestler through the soft wall")


func test_slow_push_is_held_by_the_wall() -> void:
	var arena := spawn(ARENA_SCENE) as Arena
	var eliminated := []
	arena.elimination_detected.connect(func(body: Node2D) -> void: eliminated.append(body))
	var p := spawn_player(0, Vector2(300, 0))

	Input.action_press("p1_right", 0.6)
	await wait_physics(5 * TICKS_PER_SECOND)
	Input.action_release("p1_right")

	assert_true(eliminated.is_empty(), "a walking-pace push must not ring the wrestler out")
	assert_true(p.is_active, "the wrestler is still in the round")
	assert_true(p.global_position.x < arena.warning_radius, "the wall holds the wrestler inside the ring")


func test_warning_track_lowers_friction_for_the_wrestler_standing_on_it() -> void:
	var arena := spawn(ARENA_SCENE) as Arena
	var p := spawn_player(0, Vector2(500, 0))
	await wait_physics(3)
	assert_near(p.surface_friction_scale, arena.warning_friction_scale, 0.001, "friction drops on the warning track")

	p.position = Vector2.ZERO
	await wait_physics(3)
	assert_near(p.surface_friction_scale, 1.0, 0.001, "friction returns to normal on the safe floor")


func test_arena_view_draws_with_the_arena_segment_count() -> void:
	var arena := ARENA_SCENE.instantiate() as Arena
	arena.segment_count = 32
	add_to_scene(arena)
	await wait_physics(1)
	var view := arena.get_node("View")
	assert_eq(view.get("segment_count"), 32, "drawn wedges must use the same segment count as the collision shapes")
