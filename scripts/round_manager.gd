class_name RoundManager
extends Node

## Runs the round loop: elimination, winner announcement, score, and reset.
##
## Deliberately separate from [GameManager]. That node owns *who is connected*;
## this one owns *what is happening to them*. Keeping them apart means a
## controller can be unplugged mid-round without the round logic needing to know
## anything about joypad device IDs.
##
## Note on the design doc, which suggests listening for the death zone's
## `body_exited`. That would be wrong here: the death zone is the void *outside*
## the ring, so a player crossing out triggers `body_entered`. [Arena] emits
## [signal Arena.elimination_detected] for exactly that moment.

signal round_started()
## [param winner_slot] is the winning player index, or -1 for a draw.
signal round_finished(winner_slot: int)
signal round_reset()

enum State {
	WAITING, ## Fewer than two players; nothing to decide.
	ACTIVE,  ## Players are fighting.
	OVER,    ## Winner announced; reset pending.
}

## Matches design.md's "resets the players after 2 seconds".
@export var round_end_delay: float = 2.0

@export var arena_path: NodePath = ^"../Arena"
@export var game_manager_path: NodePath = ^"../GameManager"
@export var announcer_path: NodePath = ^"../Announcer"

## Rounds won per player index. Grows as controllers are added.
var scores: Array[int] = []

var state: State = State.WAITING

var _arena: Arena
var _game_manager: GameManager
var _announcer: Announcer
var _timer := 0.0
var _round_number := 0


func _ready() -> void:
	_arena = get_node_or_null(arena_path) as Arena
	_game_manager = get_node_or_null(game_manager_path) as GameManager
	_announcer = get_node_or_null(announcer_path) as Announcer

	if _arena == null or _game_manager == null:
		push_error("RoundManager: arena_path / game_manager_path did not resolve.")
		set_process(false)
		return

	_arena.elimination_detected.connect(_on_elimination_detected)
	_game_manager.players_changed.connect(_on_players_changed)


## The round is judged once per frame from here rather than from inside the
## elimination handler. The death zone reports overlapping bodies one at a time,
## so deciding the moment the *first* player leaves would crown the second and
## make a genuine double ring-out impossible. Polling batches every elimination
## that happened in the same frame into one verdict.
func _process(delta: float) -> void:
	if state == State.ACTIVE:
		_evaluate_round_end()
		return

	if state != State.OVER:
		return

	_timer -= delta
	if _timer > 0.0:
		return

	_announce_clear()
	round_reset.emit()
	state = State.WAITING
	_begin_round_if_possible()


func _on_players_changed(_players: Array[Player]) -> void:
	while scores.size() < _game_manager.players.size():
		scores.append(0)

	if state == State.WAITING:
		_begin_round_if_possible()


func _on_elimination_detected(body: Node2D) -> void:
	var player := body as Player
	if player == null or not player.is_active:
		return

	# The round is already decided. Retire them quietly and leave everyone where
	# they are - the pending reset will bring the whole roster back. Repositioning
	# here would yank the survivors back to their marks in the middle of the
	# winner announcement, and then do it again when the timer runs out.
	if state == State.OVER:
		player.set_active(false)
		return

	if state != State.ACTIVE:
		# Nothing is being decided (too few players), so do not strand anyone
		# outside the ring - put them back where they belong.
		_game_manager.reset_players()
		return

	player.set_active(false)
	_announce(
		"Player %d is out!" % (player.player_index + 1),
		1.0,
		PlayerBodyView.PLAYER_COLORS[player.player_index]
	)


func _begin_round_if_possible() -> void:
	if _game_manager.players.size() < 2:
		_announce("Connect a second controller to play", 2.0)
		return

	_round_number += 1
	_game_manager.reset_players()
	state = State.ACTIVE
	_announce("Round %d" % _round_number, 0.9)
	round_started.emit()


## Ends the round once at most one player is still active. Only meaningful
## during an ACTIVE round: with a single connected player the roster has not
## changed, and treating that as "one survivor" would crown them the winner of
## a round that never started.
func _evaluate_round_end() -> void:
	if state != State.ACTIVE:
		return
	var alive := _game_manager.active_players()
	if alive.size() > 1:
		return

	state = State.OVER
	_timer = round_end_delay

	if alive.is_empty():
		_announce("Draw!", round_end_delay)
		round_finished.emit(-1)
		return

	var winner := alive[0]
	var winner_slot := winner.player_index
	while scores.size() <= winner_slot:
		scores.append(0)
	scores[winner_slot] += 1

	var summary := PackedStringArray()
	for i in _game_manager.players.size():
		summary.append(str(scores[i] if i < scores.size() else 0))

	_announce(
		"Player %d wins the round!   %s" % [winner_slot + 1, "-".join(summary)],
		round_end_delay,
		PlayerBodyView.PLAYER_COLORS[winner_slot]
	)
	round_finished.emit(winner_slot)


func _announce(text: String, duration: float = 1.5, color: Color = Color.WHITE) -> void:
	if _announcer != null:
		_announcer.show_message(text, duration, color)


func _announce_clear() -> void:
	if _announcer != null:
		_announcer.clear()