class_name GameManager
extends Node

## Detects connected gamepads and owns one [Player] per controller.
##
## Design decisions worth knowing:
##
## * Godot assigns joypad device IDs by connection order, so those IDs shift
##   whenever something connects or disconnects. Nothing here hardcodes a device:
##   the whole roster is rebuilt from [method Input.get_connected_joypads] on
##   every change, and each player slot is re-bound to a real ID.
## * Rebuilds are deferred by one frame because the signal can arrive before
##   [method Input.get_connected_joypads] reflects the change.
## * With no controller attached, a single keyboard-driven player is spawned so
##   the game stays testable. Set [member keyboard_fallback] to false for a
##   controller-only build.

## Emitted whenever the roster changes. The array is owned by this node.
signal players_changed(players: Array[Player])

@export var player_scene: PackedScene = preload("res://scenes/player.tscn")

## Container the spawned players are added to, relative to this node.
@export var player_root_path: NodePath = ^"../Players"

## Distance from [member spawn_center] at which players are placed.
@export var spawn_radius: float = 300.0

## Players are laid out on a circle around this point.
@export var spawn_center: Vector2 = Vector2.ZERO

## Spawn one keyboard-driven player when no controller is connected.
@export var keyboard_fallback: bool = true

var players: Array[Player] = []

var _player_root: Node2D
var _device_ids: Array[int] = []
var _last_signature := ""


func _ready() -> void:
	_player_root = get_node_or_null(player_root_path) as Node2D
	if _player_root == null:
		push_error("GameManager: player_root_path %s does not resolve to a Node2D." % player_root_path)

	# Godot 4 replaced joy_connected/joy_disconnected with a single
	# joy_connection_changed(device, connected) signal.
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_rebuild.call_deferred()


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	# Deferred: the connected-joypad list is not guaranteed to be updated yet.
	_rebuild.call_deferred()


## Spawn point for player [param index] given a roster of [param count] players.
## Static so the layout can be reasoned about (and tested) on its own.
static func spawn_position(index: int, count: int, center: Vector2, radius: float) -> Vector2:
	if count <= 1:
		return center
	# Player 1 sits at the left (PI rad) so two players face each other across
	# the screen; each further player steps a third of a turn around the circle.
	var angle := PI + TAU * float(index) / float(count)
	return center + Vector2.from_angle(angle) * radius


func _rebuild() -> void:
	_device_ids.assign(Input.get_connected_joypads())
	_device_ids.sort()

	if _device_ids.size() > PlayerInput.MAX_PLAYERS:
		push_warning(
			"%d controllers connected but only %d player slots exist; ignoring the extras."
			% [_device_ids.size(), PlayerInput.MAX_PLAYERS]
		)
		_device_ids.resize(PlayerInput.MAX_PLAYERS)

	if _device_ids.is_empty() and keyboard_fallback:
		_device_ids.append(PlayerInput.NO_DEVICE)

	# Trim from the end so the remaining players keep their slot index.
	while players.size() > _device_ids.size():
		# Array.pop_back() returns Variant even on a typed array, so annotate.
		var extra: Player = players.pop_back()
		extra.queue_free()

	for slot in _device_ids.size():
		PlayerInput.bind_device(slot, _device_ids[slot])
		if slot < players.size():
			players[slot].player_index = slot
		else:
			_spawn_player(slot)

	for slot in players.size():
		players[slot].global_position = spawn_position(slot, players.size(), spawn_center, spawn_radius)

	_log_roster()
	players_changed.emit(players)


## Restores every player to its spawn point and to full participation.
## Milestone 4 calls this to begin a new round.
func reset_players() -> void:
	for slot in players.size():
		var player := players[slot]
		# Move first, then revive. A player knocked out is still lying in the
		# death zone when the round resets, and [method Player.set_active] only
		# resumes physics - so the body has to be back inside the ring before it
		# starts moving again, or the arena will eliminate it once more.
		player.global_position = spawn_position(slot, players.size(), spawn_center, spawn_radius)
		player.stop_motion()
		player.reset_shove()
		player.set_active(true)


## Players still in the round. Excludes eliminated players, which are still in
## [member players] because their controller is still connected.
func active_players() -> Array[Player]:
	var alive: Array[Player] = []
	for player in players:
		if player.is_active:
			alive.append(player)
	return alive


func _spawn_player(slot: int) -> void:
	if _player_root == null:
		return
	var player := player_scene.instantiate() as Player
	player.player_index = slot
	_player_root.add_child(player)
	players.append(player)


func _log_roster() -> void:
	var lines := PackedStringArray()
	for slot in players.size():
		var device := _device_ids[slot]
		var source := "keyboard" if device == PlayerInput.NO_DEVICE else Input.get_joy_name(device)
		lines.append("  Player %d -> device %s (%s)" % [slot + 1, str(device), source])
	var signature := "\n".join(lines)
	if signature == _last_signature:
		return
	_last_signature = signature
	print("[GameManager] %d player(s) active\n%s" % [players.size(), signature])