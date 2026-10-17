class_name Scoreboard
extends CanvasLayer

## Running round wins for each connected player, pinned to the top-left corner.
##
## Lists the whole roster rather than only the players still in the round: an
## eliminated player is out of the fight but still has a tally.

@export var round_manager_path: NodePath = ^"../RoundManager"
@export var game_manager_path: NodePath = ^"../GameManager"

@onready var _label: RichTextLabel = $Panel/Label

var _round_manager: RoundManager
var _game_manager: GameManager


func _ready() -> void:
	_round_manager = get_node_or_null(round_manager_path) as RoundManager
	_game_manager = get_node_or_null(game_manager_path) as GameManager
	if _round_manager == null or _game_manager == null:
		push_error("Scoreboard: round_manager_path / game_manager_path did not resolve.")
		set_process(false)
		return

	_round_manager.scores_changed.connect(_on_scores_changed)
	_game_manager.players_changed.connect(func(_p): _rebuild())
	_rebuild()


func _on_scores_changed(_scores: Array[int]) -> void:
	_rebuild()


func _rebuild() -> void:
	if _round_manager == null or _game_manager == null:
		return
	var lines := PackedStringArray()
	for i in _game_manager.players.size():
		var swatch: Color = PlayerBodyView.PLAYER_COLORS[i]
		var wins: int = _round_manager.scores[i] if i < _round_manager.scores.size() else 0
		lines.append("[color=#%s]P%d[/color]   [b]%d[/b]" % [
			swatch.to_html(false), i + 1, wins,
		])
	_label.text = "\n".join(lines)