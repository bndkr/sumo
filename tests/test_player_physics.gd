extends "res://tests/game_test_case.gd"

## Shove, whiff, guard and knockback rules. These drive the real input actions,
## so they take the same path a controller does.


func test_charged_shove_into_empty_air_whiffs_for_the_recovery_time() -> void:
	var p := spawn_player(0, Vector2.ZERO)
	await hold("p1_shove", 0.5)

	var entered: int = await wait_until(func(): return p.recovery_state == Player.RecoveryState.WHIFFED, 60)
	assert_true(entered >= 0, "a charged lunge that hits nothing should leave the wrestler whiffed")

	var lasted: int = await wait_until(func(): return p.recovery_state == Player.RecoveryState.NONE, 120)
	assert_true(lasted >= 0, "the whiff should end")
	assert_near(lasted / float(TICKS_PER_SECOND), p.whiff_recovery_time, 0.05, "whiff recovery length")


func test_quick_tap_never_whiffs() -> void:
	var p := spawn_player(0, Vector2.ZERO)
	await hold("p1_shove", 0.05)

	var whiffed := false
	for i in 90:
		await tree.physics_frame
		if p.recovery_state == Player.RecoveryState.WHIFFED:
			whiffed = true
	assert_true(not whiffed, "a tap stays free - mashing A is never a strategy")


func test_whiffed_wrestler_cannot_start_another_charge() -> void:
	var p := spawn_player(0, Vector2.ZERO)
	await hold("p1_shove", 0.5)
	await wait_until(func(): return p.recovery_state == Player.RecoveryState.WHIFFED, 60)

	Input.action_press("p1_shove")
	await wait_physics(5)
	assert_eq(p.shove_state, Player.ShoveState.READY, "no counter-attack while whiffed")
	Input.action_release("p1_shove")


func test_guard_entered_during_a_lunge_does_not_stack_with_the_whiff() -> void:
	var p := spawn_player(0, Vector2.ZERO)
	await hold("p1_shove", 0.5)
	await wait_physics(3)
	Input.action_press("p1_guard")

	var entered: int = await wait_until(func(): return p.recovery_state == Player.RecoveryState.WHIFFED, 60)
	assert_true(entered >= 0, "the lunge should still whiff")
	assert_true(
		not (p.is_guarding and p.recovery_state == Player.RecoveryState.WHIFFED),
		"a stance must not run on top of whiff recovery - the two helplessness windows stack"
	)
	Input.action_release("p1_guard")


func test_guarded_wrestler_cannot_move_or_turn() -> void:
	var p := spawn_player(0, Vector2.ZERO)
	Input.action_press("p1_guard")
	await wait_physics(3)
	Input.action_press("p1_down")
	await wait_physics(20)
	Input.action_release("p1_down")
	Input.action_release("p1_guard")

	assert_near(p.position.length(), 0.0, 0.5, "the stick does nothing while planted")
	assert_near(p.rotation, 0.0, 0.001, "facing is frozen while planted")


func test_guarding_wrestler_cannot_start_a_charge() -> void:
	var p := spawn_player(0, Vector2.ZERO)
	Input.action_press("p1_guard")
	await wait_physics(2)
	Input.action_press("p1_shove")
	await wait_physics(5)
	assert_eq(p.shove_state, Player.ShoveState.READY, "guard and charge are mutually exclusive")
	Input.action_release("p1_shove")
	Input.action_release("p1_guard")


func test_guard_cannot_be_re_entered_until_the_cooldown_passes() -> void:
	var p := spawn_player(0, Vector2.ZERO)
	Input.action_press("p1_guard")
	await wait_physics(3)
	Input.action_release("p1_guard")
	await wait_physics(2)
	assert_true(not p.is_guarding, "releasing early ends the stance")

	await wait_physics(10)
	Input.action_press("p1_guard")
	await wait_physics(2)
	assert_true(not p.is_guarding, "re-entry is refused during the cooldown")
	Input.action_release("p1_guard")

	await wait_physics(120)
	Input.action_press("p1_guard")
	await wait_physics(2)
	assert_true(p.is_guarding, "the guard is available again once the cooldown has passed")
	Input.action_release("p1_guard")


func test_full_charge_blocked_by_guard_reflects_and_bounces_the_attacker() -> void:
	var attacker := spawn_player(0, Vector2.ZERO)
	var defender := spawn_player(1, Vector2(150, 0))
	defender.rotation = PI

	var contact := []
	var staggered := []
	var on_reflect := func(_target: Player, _coverage: float) -> void:
		contact.append(attacker.global_position.x)
		staggered.append(attacker.is_staggered)
	attacker.guard_reflected.connect(on_reflect)

	Input.action_press("p1_shove")
	await wait_physics(100)
	Input.action_release("p1_shove")
	Input.action_press("p2_guard")

	var reflected: int = await wait_until(func(): return contact.size() > 0, 30)
	assert_true(reflected >= 0, "a full charge into a frontal guard should be reflected")
	await wait_physics(40)
	Input.action_release("p2_guard")

	if contact.is_empty():
		return
	var bounce := float(contact[0]) - attacker.global_position.x
	assert_true(
		bounce >= 150.0,
		"the bounce should clear 1.5x the ~99 px lunge, measured from contact (got %.1f px)" % bounce
	)
	assert_true(staggered[0], "the attacker is staggered so the bounce can carry")
	assert_true(
		defender.global_position.x - 150.0 < 60.0,
		"a covered defender should slide only a little (slid %.1f px)" % (defender.global_position.x - 150.0)
	)


func test_struck_wrestler_passes_part_of_its_knockback_on() -> void:
	var source := spawn_player(0, Vector2(-400, 0))
	var carrier := spawn_player(1, Vector2.ZERO)
	spawn_player(2, Vector2(90, 0))

	var passed := []
	carrier.knockback_transferred.connect(func(_target: Player, speed: float) -> void: passed.append(speed))
	carrier.add_knockback(Vector2(800, 0), source)

	await wait_until(func(): return passed.size() > 0, 60)
	assert_eq(passed.size(), 1, "one transfer when the carried body meets a third player")
	if not passed.is_empty():
		assert_near(
			float(passed[0]), carrier.knockback_transfer_ratio * 790.0, 20.0,
			"the third player receives the transfer ratio of the carried speed"
		)


func test_knockback_is_never_passed_back_to_the_wrestler_who_threw_it() -> void:
	var thrower := spawn_player(0, Vector2(90, 0))
	var carrier := spawn_player(1, Vector2.ZERO)

	var passed := []
	carrier.knockback_transferred.connect(func(_target: Player, speed: float) -> void: passed.append(speed))
	carrier.add_knockback(Vector2(800, 0), thrower)

	await wait_physics(60)
	assert_eq(passed.size(), 0, "momentum is never handed back to the thrower")


func test_knockback_transfer_is_available_again_after_its_cooldown() -> void:
	var source := spawn_player(0, Vector2(-400, 0))
	var carrier := spawn_player(1, Vector2.ZERO)
	var third := spawn_player(2, Vector2(90, 0))

	var passed := []
	carrier.knockback_transferred.connect(func(_target: Player, speed: float) -> void: passed.append(speed))
	carrier.add_knockback(Vector2(800, 0), source)
	await wait_until(func(): return passed.size() > 0, 60)

	# Let the first hit play out fully, then reproduce the same collision.
	await wait_physics(150)
	carrier.stop_motion()
	third.stop_motion()
	carrier.position = Vector2.ZERO
	third.position = Vector2(90, 0)
	await wait_physics(2)

	carrier.add_knockback(Vector2(800, 0), source)
	await wait_until(func(): return passed.size() > 1, 60)
	assert_true(
		passed.size() > 1,
		"a second, separate collision should transfer again once knockback_transfer_cooldown has passed"
	)


func test_reduced_surface_friction_lengthens_the_slide() -> void:
	var grip := spawn_player(0, Vector2(0, -300))
	var slick := spawn_player(1, Vector2(0, 300))
	slick.surface_friction_scale = 0.6

	var grip_slide := await _slide_after_push("p1_right", grip)
	var slick_slide := await _slide_after_push("p2_right", slick)
	var ratio := slick_slide / maxf(grip_slide, 0.001)
	assert_true(
		ratio > 1.5 and ratio < 1.8,
		"0.6 friction should slide about 1.67x further (got %.2fx)" % ratio
	)


func test_warning_track_makes_turning_less_responsive() -> void:
	var grip := spawn_player(0, Vector2(0, -300))
	var slick := spawn_player(1, Vector2(0, 300))
	slick.surface_friction_scale = 0.6

	Input.action_press("p1_right")
	Input.action_press("p2_right")
	await wait_physics(40)
	Input.action_release("p1_right")
	Input.action_release("p2_right")

	Input.action_press("p1_up")
	Input.action_press("p2_up")
	await wait_physics(6)
	Input.action_release("p1_up")
	Input.action_release("p2_up")

	var grip_turn := absf(grip.rotation)
	var slick_turn := absf(slick.rotation)
	assert_true(
		slick_turn < grip_turn,
		"design.md says the warning track turns the wrestler less responsively (grip turned %.3f rad, warning track %.3f rad)" % [grip_turn, slick_turn]
	)


func test_whiffed_wrestler_cannot_guard() -> void:
	var p := spawn_player(0, Vector2.ZERO)
	await hold("p1_shove", 0.5)
	await wait_until(func(): return p.recovery_state == Player.RecoveryState.WHIFFED, 60)

	Input.action_press("p1_guard")
	await wait_physics(3)
	assert_true(not p.is_guarding, "a whiffed wrestler has no stance to fall back on")
	Input.action_release("p1_guard")


func test_guard_entered_after_a_hit_does_not_cancel_its_slide() -> void:
	var p := spawn_player(0, Vector2.ZERO)
	p.add_knockback(Vector2(800, 0))
	await wait_physics(3)

	Input.action_press("p1_guard")
	await wait_physics(2)
	assert_true(
		p.velocity.length() > 100.0,
		"a late guard should not undo a hit that was not blocked (velocity %.1f)" % p.velocity.length()
	)
	Input.action_release("p1_guard")


func test_knockback_passed_into_a_guard_is_reduced_like_a_direct_hit() -> void:
	var source := spawn_player(0, Vector2(-400, 0))
	var carrier := spawn_player(1, Vector2.ZERO)
	var guard := spawn_player(2, Vector2(90, 0))
	guard.rotation = PI
	Input.action_press("p3_guard")
	await wait_physics(3)

	var passed := []
	carrier.knockback_transferred.connect(func(_target: Player, speed: float) -> void: passed.append(speed))
	carrier.add_knockback(Vector2(800, 0), source)
	await wait_until(func(): return passed.size() > 0, 60)

	assert_true(not passed.is_empty(), "the carried wrestler should reach the guard")
	if not passed.is_empty():
		assert_true(
			float(passed[0]) < carrier.knockback_transfer_ratio * 790.0 * 0.5,
			"a covered guard should absorb most of a transferred shove (passed %.1f)" % float(passed[0])
		)
	Input.action_release("p3_guard")


func _slide_after_push(action: String, p: Player) -> float:
	Input.action_press(action)
	await wait_physics(40)
	Input.action_release(action)
	var start := p.global_position
	await wait_until(func(): return p.velocity.is_zero_approx(), 240)
	return p.global_position.distance_to(start)
