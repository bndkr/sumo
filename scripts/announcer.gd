class_name Announcer
extends CanvasLayer

## Screen-space banner for round messages: "Round 1", winners, draws.
##
## Separate from [RoundManager] so the round rules never touch a Control node,
## matching the logic/view split used by [Player] and [Arena].

## Fade duration at both ends of a message.
@export var fade_time: float = 0.3

@onready var _label: Label = $Label

var _duration := 0.0
var _timer := 0.0


## Shows [param text], fading in, holding for [param duration], then fading out
## and hiding itself. A new message replaces any current one immediately.
func show_message(text: String, duration: float = 1.5, color: Color = Color.WHITE) -> void:
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_label.visible = true
	_label.modulate.a = 0.0
	_duration = maxf(duration, fade_time)
	_timer = _duration


func clear() -> void:
	_duration = 0.0
	_timer = 0.0
	_label.visible = false
	_label.modulate.a = 1.0


func _process(delta: float) -> void:
	if _duration <= 0.0:
		return

	_timer -= delta
	if _timer <= 0.0:
		clear()
		return

	var elapsed := _duration - _timer
	var alpha := minf(
		clampf(elapsed / fade_time, 0.0, 1.0),
		clampf(_timer / fade_time, 0.0, 1.0)
	)
	_label.modulate.a = alpha