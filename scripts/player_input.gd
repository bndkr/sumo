class_name PlayerInput
extends RefCounted

## Resolves per-device movement input.
##
## Godot's Input singleton cannot ask "is action X pressed *on device N*"; an
## action only reports pressed if **any** device triggers it. The local
## multiplayer scheme therefore relies on having one action set per player slot
## (`p1_left`, `p2_left`, ...), so querying a slot's own actions yields that
## slot's stick and nothing else.
##
## Which *physical* device backs each slot is not known ahead of time, so
## [method bind_device] points a slot's actions at a real device ID at runtime.
## Godot assigns those IDs by connection order, so a slot must never assume a
## fixed ID; rebinding on every connect/disconnect is what keeps player
## ownership correct.
##
## Keyboard fallback lives on the `p1_*` actions only, so a keyboard can never
## drive slots 2-4.

const MAX_PLAYERS := 4

const DIRECTIONS: Array[String] = ["left", "right", "up", "down"]

## Action suffix for the shove button, bound per device like the movement axes.
const SHOVE_SUFFIX := "shove"

## Action suffix for the guard button.
const GUARD_SUFFIX := "guard"

## Joypad button index for the Xbox "A" button.
const JOY_BUTTON_A := 0

## Joypad button index for the Xbox "B" button.
const JOY_BUTTON_B := 1

## Sentinel device ID meaning "this slot is keyboard only, no joypad".
const NO_DEVICE := -1


## Returns the normalized stick direction for [param player_index] (0-based).
## Magnitude is 0..1, so callers can use it directly as a target velocity scale.
static func get_move_vector(player_index: int) -> Vector2:
	var prefix := action_prefix(player_index)
	if prefix == "":
		return Vector2.ZERO
	return Input.get_vector(prefix + "_left", prefix + "_right", prefix + "_up", prefix + "_down")


## True while the player's shove button is held.
static func is_shove_pressed(player_index: int) -> bool:
	var prefix := action_prefix(player_index)
	if prefix == "":
		return false
	return Input.is_action_pressed(prefix + "_" + SHOVE_SUFFIX)


## True while the player's guard button is held.
static func is_guard_pressed(player_index: int) -> bool:
	var prefix := action_prefix(player_index)
	if prefix == "":
		return false
	return Input.is_action_pressed(prefix + "_" + GUARD_SUFFIX)


## Returns "p1".."p4" for a valid 0-based [param player_index], or "" if out of range.
static func action_prefix(player_index: int) -> String:
	if player_index < 0 or player_index >= MAX_PLAYERS:
		push_warning("Player index %d is out of range (expected 0..%d)." % [player_index, MAX_PLAYERS - 1])
		return ""
	return "p%d" % (player_index + 1)


## Points [param player_index]'s actions at [param device_id].
##
## Existing joypad bindings for the slot are replaced, but keyboard bindings are
## left untouched. Pass [constant NO_DEVICE] to make the slot keyboard only.
static func bind_device(player_index: int, device_id: int) -> void:
	var prefix := action_prefix(player_index)
	if prefix == "":
		return

	# Strip every joypad binding on the slot first, then re-add. Doing both in
	# one pass means a new early return can never leave a stale device bound.
	var actions := PackedStringArray()
	for direction in DIRECTIONS:
		actions.append(prefix + "_" + direction)
	actions.append(prefix + "_" + SHOVE_SUFFIX)
	actions.append(prefix + "_" + GUARD_SUFFIX)

	for action in actions:
		if not InputMap.has_action(action):
			continue
		# Keys are a permanent fallback and must survive.
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion or event is InputEventJoypadButton:
				InputMap.action_erase_event(action, event)

	if device_id == NO_DEVICE:
		return

	for direction in DIRECTIONS:
		var action: String = prefix + "_" + direction
		if not InputMap.has_action(action):
			continue
		var motion := InputEventJoypadMotion.new()
		motion.device = device_id
		motion.axis = 0 if direction in ["left", "right"] else 1
		motion.axis_value = -1.0 if direction in ["left", "up"] else 1.0
		InputMap.action_add_event(action, motion)

	_add_button(prefix + "_" + SHOVE_SUFFIX, device_id, JOY_BUTTON_A)
	_add_button(prefix + "_" + GUARD_SUFFIX, device_id, JOY_BUTTON_B)


static func _add_button(action: String, device_id: int, index: int) -> void:
	if not InputMap.has_action(action):
		return
	var button := InputEventJoypadButton.new()
	button.device = device_id
	button.button_index = index
	InputMap.action_add_event(action, button)


## Returns the device ID currently bound to [param player_index], or
## [constant NO_DEVICE] if the slot is keyboard only or unbound.
static func get_bound_device(player_index: int) -> int:
	var prefix := action_prefix(player_index)
	if prefix == "":
		return NO_DEVICE
	for event in InputMap.action_get_events(prefix + "_right"):
		if event is InputEventJoypadMotion:
			return event.device
	return NO_DEVICE