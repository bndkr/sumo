class_name PlayerInput
extends RefCounted

## Resolves per-device movement input.
##
## Godot's Input singleton cannot ask "is action X pressed *on device N*"; an
## action only reports pressed if **any** device triggers it. The local
## multiplayer scheme therefore relies on having one action set per device
## (`p1_left` bound to device 0 only, `p2_left` to device 1 only, and so on), so
## querying a player's own actions yields that player's stick and nothing else.
##
## Keyboard fallback lives on the `p1_*` actions only, so a keyboard never
## drives players 2-4.

const MAX_PLAYERS := 4

## Returns the normalized stick direction for [param player_index] (0-based).
## Magnitude is 0..1, so callers can use it directly as a target velocity scale.
static func get_move_vector(player_index: int) -> Vector2:
	var prefix := action_prefix(player_index)
	if prefix == "":
		return Vector2.ZERO
	return Input.get_vector(prefix + "_left", prefix + "_right", prefix + "_up", prefix + "_down")


## Returns "p1".."p4" for a valid 0-based [param player_index], or "" if out of range.
static func action_prefix(player_index: int) -> String:
	if player_index < 0 or player_index >= MAX_PLAYERS:
		push_warning("Player index %d is out of range (expected 0..%d)." % [player_index, MAX_PLAYERS - 1])
		return ""
	return "p%d" % (player_index + 1)