class_name PlayerBodyView
extends Node2D

## Placeholder art for a wrestler: a colored disc with a chevron pointing in the
## body's facing direction. Purely visual - collision lives on the parent
## CharacterBody2D. Swapped for real sprites later without touching gameplay.

const RADIUS := 26.0
const CHEVRON_LENGTH := 16.0
const CHEVRON_WIDTH := 13.0

## Player colors, indexed by player_index (see design.md: Blue then Red).
const PLAYER_COLORS: Array[Color] = [
	Color(0.29, 0.56, 0.94),
	Color(0.94, 0.33, 0.31),
	Color(0.36, 0.80, 0.45),
	Color(0.95, 0.76, 0.26),
]

var player_index: int = 0:
	set(value):
		var clamped := clampi(value, 0, PlayerBodyView.PLAYER_COLORS.size() - 1)
		if clamped == player_index:
			return
		player_index = clamped
		queue_redraw()


func _ready() -> void:
	# Mirror the owning player's slot so a respawned or re-indexed wrestler
	# recolours itself without the GameManager knowing about presentation.
	var owner_player := get_parent() as Player
	if owner_player == null:
		return
	player_index = owner_player.player_index
	owner_player.player_index_changed.connect(_on_player_index_changed)


func _on_player_index_changed(index: int) -> void:
	player_index = index


func _draw() -> void:
	var color: Color = PLAYER_COLORS[player_index]

	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, color.darkened(0.45), 3.0, true)

	# Chevron tip leads along +X, which is where the body rotates to face.
	var tip := Vector2(RADIUS + CHEVRON_LENGTH - 6.0, 0.0)
	var back := Vector2(RADIUS - 6.0, 0.0)
	draw_colored_polygon(
		PackedVector2Array([tip, back + Vector2(0.0, -CHEVRON_WIDTH), back + Vector2(0.0, CHEVRON_WIDTH)]),
		Color(1.0, 1.0, 1.0, 0.9),
	)

	var font := ThemeDB.fallback_font
	if font == null:
		return
	var label := str(player_index + 1)
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1.0, 20)
	draw_string(
		font,
		Vector2(-text_size.x * 0.5, text_size.y * 0.32),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1.0,
		20,
		Color(0.05, 0.05, 0.08, 0.75),
	)