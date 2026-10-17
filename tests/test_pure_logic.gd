extends "res://tests/game_test_case.gd"

## Rules that can be checked without running the physics simulation.


func test_two_wrestlers_spawn_on_opposite_sides() -> void:
	var first := GameManager.spawn_position(0, 2, Vector2.ZERO, 300.0)
	var second := GameManager.spawn_position(1, 2, Vector2.ZERO, 300.0)
	assert_near(first.x, -300.0, 0.01, "player 1 starts on the left")
	assert_near(second.x, 300.0, 0.01, "player 2 starts on the right")


func test_spawn_positions_sit_on_the_spawn_circle() -> void:
	for index in 4:
		var pos := GameManager.spawn_position(index, 4, Vector2.ZERO, 300.0)
		assert_near(pos.length(), 300.0, 0.01, "player %d is on the spawn circle" % (index + 1))


func test_lone_wrestler_spawns_at_the_centre() -> void:
	var pos := GameManager.spawn_position(0, 1, Vector2(5, 5), 300.0)
	assert_eq(pos, Vector2(5, 5), "a single player spawns at spawn_center")


func test_ring_wedges_form_a_closed_annulus() -> void:
	var wedges := Arena.ring_wedges(420.0, 600.0, 96)
	assert_eq(wedges.size(), 96, "one wedge per segment")
	for i in wedges.size():
		var wedge := wedges[i]
		assert_eq(wedge.size(), 4, "wedge %d is a quad" % i)
		assert_near(wedge[0].length(), 420.0, 0.01, "wedge %d inner edge" % i)
		assert_near(wedge[1].length(), 420.0, 0.01, "wedge %d inner edge" % i)
		assert_near(wedge[2].length(), 600.0, 0.01, "wedge %d outer edge" % i)
		assert_near(wedge[3].length(), 600.0, 0.01, "wedge %d outer edge" % i)
		var next := wedges[(i + 1) % wedges.size()]
		assert_true(wedge[1].distance_to(next[0]) < 0.01, "wedge %d meets wedge %d" % [i, i + 1])


func test_warning_track_spans_safe_radius_to_warning_radius() -> void:
	var arena := Arena.new()
	assert_true(not arena.is_in_warning_track(Vector2(419.9, 0.0)), "just inside the safe floor is not warning track")
	assert_true(arena.is_in_warning_track(Vector2(420.0, 0.0)), "the safe floor's edge starts the warning track")
	assert_true(arena.is_in_warning_track(Vector2(599.9, 0.0)), "just inside the wall is warning track")
	assert_true(not arena.is_in_warning_track(Vector2(600.0, 0.0)), "the warning track ends at the wall")
	arena.free()


func test_guard_coverage_matches_the_documented_cone() -> void:
	var p := spawn_player(0, Vector2.ZERO)
	p.is_guarding = true
	p.rotation = 0.0
	assert_near(p.guard_coverage_from(Vector2.from_angle(0.0)), 1.0, 0.001, "dead ahead is fully covered")
	assert_near(p.guard_coverage_from(Vector2.from_angle(deg_to_rad(45.0))), 1.0, 0.001, "45 degrees is still full coverage")
	assert_near(p.guard_coverage_from(Vector2.from_angle(deg_to_rad(60.0))), 0.99, 0.01, "60 degrees is near full")
	assert_near(p.guard_coverage_from(Vector2.from_angle(deg_to_rad(70.0))), 0.70, 0.02, "70 degrees has given out partly")
	assert_near(p.guard_coverage_from(Vector2.from_angle(deg_to_rad(80.0))), 0.24, 0.02, "80 degrees is almost gone")
	assert_near(p.guard_coverage_from(Vector2.from_angle(deg_to_rad(95.0))), 0.0, 0.001, "behind the cone is uncovered")


func test_guard_coverage_is_zero_when_not_guarding() -> void:
	var p := spawn_player(0, Vector2.ZERO)
	p.is_guarding = false
	assert_near(p.guard_coverage_from(Vector2.RIGHT), 0.0, 0.001, "no stance means no coverage")


func test_full_coverage_ratio_covers_every_direction() -> void:
	var p := spawn_player(0, Vector2.ZERO)
	p.is_guarding = true
	p.guard_coverage_ratio = 1.0
	assert_near(p.guard_coverage_from(Vector2.LEFT), 1.0, 0.001, "a 1.0 ratio covers the back too")


func test_add_knockback_accumulates_and_stop_motion_clears_it() -> void:
	var p := spawn_player(0, Vector2.ZERO)
	p.add_knockback(Vector2(100, 0))
	p.add_knockback(Vector2(0, 50))
	await wait_physics(2)
	assert_true(p.velocity.x > 90.0 and p.velocity.y > 40.0, "both impulses should add into velocity")

	p.stop_motion()
	await wait_physics(2)
	assert_true(p.velocity.length() < 0.5, "stop_motion should clear knockback, not just velocity")


func test_bind_device_repoints_joypad_actions() -> void:
	PlayerInput.bind_device(1, 7)
	assert_eq(PlayerInput.get_bound_device(1), 7, "player 2 reports device 7")
	assert_eq(_joypad_devices("p2_left"), [7], "stick actions follow the new device")
	assert_eq(_joypad_devices("p2_shove"), [7], "shove follows the new device")
	assert_eq(_joypad_devices("p2_guard"), [7], "guard follows the new device")
	_restore_default_bindings()


func test_bind_device_keeps_keyboard_fallback_on_player_one() -> void:
	PlayerInput.bind_device(0, PlayerInput.NO_DEVICE)
	assert_eq(_joypad_devices("p1_left"), [], "unbinding removes the joypad stick")
	assert_true(_has_key_event("p1_left"), "keyboard fallback survives unbinding")
	assert_true(_has_key_event("p1_shove"), "keyboard shove survives unbinding")
	_restore_default_bindings()


func test_rebinding_never_leaves_a_stale_device_behind() -> void:
	PlayerInput.bind_device(2, 5)
	PlayerInput.bind_device(2, 6)
	assert_eq(_joypad_devices("p3_right"), [6], "only the latest device remains on the stick")
	assert_eq(_joypad_devices("p3_shove"), [6], "only the latest device remains on shove")
	_restore_default_bindings()


func _joypad_devices(action: String) -> Array[int]:
	var devices: Array[int] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion or event is InputEventJoypadButton:
			devices.append(event.device)
	return devices


func _has_key_event(action: String) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return true
	return false


func _restore_default_bindings() -> void:
	for slot in PlayerInput.MAX_PLAYERS:
		PlayerInput.bind_device(slot, slot)
