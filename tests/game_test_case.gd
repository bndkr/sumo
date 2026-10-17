extends RefCounted

## Base class for the headless test suite. See run_tests.gd.
##
## Test methods are named test_* and may await physics frames. Assertions record
## failures instead of aborting, so one run reports every problem in a test.
## Physics ticks at a fixed 60 Hz headless, so frame counts convert to seconds.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ARENA_SCENE := preload("res://scenes/arena.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const TICKS_PER_SECOND := 60

var tree: SceneTree
var failures := PackedStringArray()
var skip_reason := ""
var _spawned: Array[Node] = []


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	assert_true(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	assert_true(
		absf(actual - expected) <= tolerance,
		"%s (expected %.3f +/- %.3f, got %.3f)" % [message, expected, tolerance, actual]
	)


func skip(reason: String) -> void:
	skip_reason = reason


func spawn(scene: PackedScene) -> Node:
	return add_to_scene(scene.instantiate())


## Adds a node the caller configured before it enters the tree.
func add_to_scene(node: Node) -> Node:
	tree.root.add_child(node)
	_spawned.append(node)
	return node


func spawn_player(index: int, at: Vector2) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.player_index = index
	player.position = at
	return add_to_scene(player) as Player


## physics_frame fires before bodies run _physics_process for that tick, so after
## one await a body still shows the state from the previous tick.
func wait_physics(frames: int) -> void:
	for i in frames:
		await tree.physics_frame


## Waits until [param condition] holds. Returns the frames waited, or -1 on timeout.
func wait_until(condition: Callable, max_frames: int) -> int:
	for frame in max_frames:
		if condition.call():
			return frame
		await tree.physics_frame
	return -1


## Holds [param action] down for [param seconds], then releases it.
func hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await wait_physics(roundi(seconds * TICKS_PER_SECOND))
	Input.action_release(action)


func cleanup() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
