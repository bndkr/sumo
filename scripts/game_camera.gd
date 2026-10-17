class_name GameCamera
extends Camera2D

## Keeps every player still in the round framed, and shakes on impact.
##
## Framing uses the bounding box of the *active* players rather than the roster.
## Eliminated players are still in [member GameManager.players] because their
## controller is connected, and they come to rest out in the void - framing the
## roster would drag the camera off the ring the moment anyone is knocked out.
##
## Shake is trauma-based: hits add trauma, trauma decays linearly, and the
## applied offset scales with trauma raised to 1.5 - enough curve to fall away
## quickly, without squaring a mid-power hit into invisibility.

## Slack around the players' bounding box, as a multiplier on [member body_margin].
@export var padding: float = 1.25

## World-space slack kept around every player, in pixels. Tracks the wrestler
## size, so framing padding stays proportional if the bodies are rescaled.
@export var body_margin: float = 96.0

## Never zoom in past 1:1, so the ring always stays in frame.
@export var max_zoom: float = 1.0

## Never zoom out past this. Comfortably enough to hold the whole arena.
@export var min_zoom: float = 0.3

## Higher converges faster. 0 disables easing.
@export var position_damping: float = 7.0

## Deliberately slower than [member position_damping]; slow zoom reads as a
## deliberate camera move rather than a snap.
@export var zoom_damping: float = 3.5

@export_group("Shake")
## Hits weaker than this do not shake the camera at all, so taps stay quiet.
@export_range(0.0, 1.0, 0.05) var shake_power_threshold: float = 0.35

## Trauma added by a full-power hit at point-blank range.
@export var shake_trauma_per_hit: float = 0.85

## Trauma lost per second.
@export var shake_decay: float = 2.0

## Pixel offset applied at full trauma. Scaled with the rest of the world so
## shake reads the same regardless of how big the wrestlers are.
@export var shake_intensity: float = 104.0

## How fast the shake noise is sampled, in noise-units per second. Needs to be
## high enough to read as a jitter - a fraction of a hertz just samples a flat
## patch of noise and the shake comes out as zero.
@export var shake_frequency: float = 26.0

## Hits further away than this shake least; nearer hits shake most.
@export var shake_falloff_distance: float = 900.0

var _manager: GameManager
var _connected: Array[Player] = []
var _trauma := 0.0
var _shake_time := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.seed = 1337
	_noise.frequency = shake_frequency
	make_current()


## Starts following the players owned by [param manager]. Safe to call once.
func bind(manager: GameManager) -> void:
	_manager = manager
	manager.players_changed.connect(_on_players_changed)
	_rebind_signals(manager.players)


func _on_players_changed(roster: Array[Player]) -> void:
	_rebind_signals(roster)


## (Re)wires impact signals. Listens to the whole roster rather than just the
## active players, because an eliminated player becomes active again on reset.
func _rebind_signals(roster: Array[Player]) -> void:
	for player in _connected:
		if player.shove_landed.is_connected(_on_shove_landed):
			player.shove_landed.disconnect(_on_shove_landed)
	_connected.clear()
	for player in roster:
		player.shove_landed.connect(_on_shove_landed)
		_connected.append(player)


## Adds camera trauma. [param amount] is roughly 0..1 and stacks, but saturates
## at 1 so a pile-up cannot send the view into orbit.
func shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	_update_shake(delta)
	if _manager == null:
		return
	var alive := _manager.active_players()
	if alive.is_empty():
		return
	_update_framing(alive, delta)


func _update_framing(alive: Array[Player], delta: float) -> void:
	var lowest := alive[0].global_position
	var highest := lowest
	for player in alive:
		lowest = lowest.min(player.global_position)
		highest = highest.max(player.global_position)

	var pad := Vector2.ONE * body_margin * padding
	var needed := (highest - lowest) + pad * 2.0
	var view := get_viewport_rect().size
	var target := clampf(
		minf(view.x / maxf(needed.x, 1.0), view.y / maxf(needed.y, 1.0)),
		min_zoom,
		max_zoom
	)

	var centre := (lowest + highest) * 0.5
	global_position = global_position.lerp(centre, clampf(position_damping * delta, 0.0, 1.0))
	zoom = zoom.lerp(Vector2.ONE * target, clampf(zoom_damping * delta, 0.0, 1.0))


func _update_shake(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		return

	_shake_time += delta
	# Trauma to the power of 1.5 rather than squared: squaring makes a mid-power
	# hit almost invisible, which is exactly the range where a shove should
	# still land. Still curved, so it falls away faster than linearly.
	var amount := pow(_trauma, 1.5) * shake_intensity
	offset = Vector2(
		_noise.get_noise_2d(_shake_time, 0.0),
		_noise.get_noise_2d(0.0, _shake_time)
	) * amount
	_trauma = maxf(0.0, _trauma - shake_decay * delta)


func _on_shove_landed(target: Player, power: float) -> void:
	if power < shake_power_threshold:
		return
	# Distant impacts read as less personal, and a full-screen jolt from across
	# the arena is disorienting rather than exciting.
	var distance := target.global_position.distance_to(global_position)
	var proximity := 1.0 - clampf(distance / shake_falloff_distance, 0.0, 1.0) * 0.7
	shake(shake_trauma_per_hit * power * proximity)