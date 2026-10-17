class_name Announcer
extends CanvasLayer

## Screen-space banner for round messages: "Round 1", winners, draws.
##
## The whole panel hides when there is no message, so an idle announcer draws
## nothing at all rather than leaving its backdrop parked over the arena.
##
## Separate from [RoundManager] so the round rules never touch a Control node,
## matching the logic/view split used by [Player] and [Arena].

## Fade duration at both ends of a message.
@export var fade_time: float = 0.3

@onready var _panel: PanelContainer = $Banner
@onready var _label: Label = $Banner/Label

var _duration := 0.0
var _timer := 0.0
## Fade length actually used for the message on screen, capped to half of it.
var _effective_fade := 0.0


## Shows [param text], fading in, holding for [param duration], then fading out
## and hiding itself. A new message replaces any current one immediately.
##
## The banner carries its own dark backdrop and a border tinted to [param color].
## The text itself is player-coloured, which against the clay arena or the amber
## warning track was close to unreadable.
func show_message(text: String, duration: float = 1.5, color: Color = Color.WHITE) -> void:
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_tint_border(color)
	# The panel is what carries the backdrop, so it is what has to be hidden when
	# idle. Fading the label alone would leave an empty black rectangle sitting in
	# the middle of the arena for the whole message gap.
	_panel.visible = true
	_panel.modulate.a = 0.0
	_duration = maxf(duration, fade_time)
	# Each end uses half the message. Without the cap, a message shorter than
	# twice the fade has its in and out ramps overlap and it never reaches full
	# opacity - it fades up and straight back down.
	_effective_fade = minf(fade_time, _duration * 0.5)
	_timer = _duration


func _tint_border(color: Color) -> void:
	var style := _panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	style.border_color = Color(color.r, color.g, color.b, 0.9)


func clear() -> void:
	_duration = 0.0
	_timer = 0.0
	_panel.visible = false
	_panel.modulate.a = 1.0


func _process(delta: float) -> void:
	if _duration <= 0.0:
		return

	_timer -= delta
	if _timer <= 0.0:
		clear()
		return

	var elapsed := _duration - _timer
	var ramp := maxf(_effective_fade, 0.001)
	var alpha := minf(
		clampf(elapsed / ramp, 0.0, 1.0),
		clampf(_timer / ramp, 0.0, 1.0)
	)
	# Fade the panel, not just the label, so the backdrop arrives and leaves with
	# the text instead of flashing up empty.
	_panel.modulate.a = alpha