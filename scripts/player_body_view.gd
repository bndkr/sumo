class_name PlayerBodyView
extends Node2D

## Placeholder art for a wrestler: a colored disc with a chevron pointing in the
## body's facing direction. Purely visual - collision lives on the parent
## CharacterBody2D. Swapped for real sprites later without touching gameplay.
##
## RADIUS must match the CollisionShape2D in player.tscn. Every figure here is
## the pre-scale value times 1.6, so the body's proportions, the chevron, the
## charge gauge and the label all keep their relationship to the collision shape.

const RADIUS := 42.0
const CHEVRON_LENGTH := 26.0
const CHEVRON_WIDTH := 21.0
const OUTLINE_WIDTH := 5.0
const CHEVRON_INSET := 10.0
const CHARGE_GAP := 11.0
const CHARGE_WIDTH := 8.0
const LABEL_SIZE := 32

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


## Mirrors the owning player's shove charge, 0..1.
var charge_ratio: float = 0.0:
	set(value):
		var clamped := clampf(value, 0.0, 1.0)
		if is_equal_approx(clamped, charge_ratio):
			return
		charge_ratio = clamped
		queue_redraw()

## Seconds the impact flash takes to fade.
const FLASH_TIME := 0.22

var _flash := 0.0


func _process(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash = maxf(0.0, _flash - delta / FLASH_TIME)
	queue_redraw()


## Bright flash on being struck. Makes a landing hit legible at speed, when the
## shove is over almost before the knockback reads.
func flash() -> void:
	_flash = 1.0
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
	color = color.lerp(Color(1.0, 1.0, 1.0), _flash * 0.8)

	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, color.darkened(0.45), OUTLINE_WIDTH, true)

	# Chevron tip leads along +X, which is where the body rotates to face.
	var tip := Vector2(RADIUS + CHEVRON_LENGTH - CHEVRON_INSET, 0.0)
	var back := Vector2(RADIUS - CHEVRON_INSET, 0.0)
	draw_colored_polygon(
		PackedVector2Array([tip, back + Vector2(0.0, -CHEVRON_WIDTH), back + Vector2(0.0, CHEVRON_WIDTH)]),
		Color(1.0, 1.0, 1.0, 0.9),
	)

	var font := ThemeDB.fallback_font
	if font == null:
		return
	var label := str(player_index + 1)
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1.0, LABEL_SIZE)
	draw_string(
		font,
		Vector2(-text_size.x * 0.5, text_size.y * 0.32),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1.0,
		LABEL_SIZE,
		Color(0.05, 0.05, 0.08, 0.75),
	)

	if charge_ratio > 0.0:
		_draw_charge_arc(charge_ratio)


## Wind-up gauge around the body. Grows and reddens with charge so a held shove
## reads at a glance without any text.
func _draw_charge_arc(ratio: float) -> void:
	var from := -PI * 0.5
	var to := from + TAU * ratio
	draw_arc(Vector2.ZERO, RADIUS + CHARGE_GAP, from, to, 32, Color(1.0, 0.85, 0.35, 0.95), CHARGE_WIDTH, true)