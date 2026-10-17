# Ring-Out Rumble

A fast-paced, physics-based local multiplayer sumo wrestling game built in
Godot 4. See [design.md](design.md) for the full design and milestone list.

## Status

- [x] M1: Project skeleton & basic movement
- [x] M2: Controller assignment & multiplayer spawning
- [x] M3: The arena & dual ring zones
- [x] M4: Elimination & round reset loop
- [ ] M5: The push mechanic (tap & charge)
- [ ] M5: The push mechanic (tap & charge)
- [ ] M6: Dynamic camera & juice

## Requirements

Godot **4.7.2** stable (Windows build verified).

## Running

The Godot executable is not on `PATH`; invoke it by full path:

```powershell
& "$env:USERPROFILE\Downloads\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64.exe" --path .
```

Or add that directory to `PATH` and use `godot --path .`.

Headless checks:

```powershell
godot --headless --path . --editor --quit     # import / validate
godot --headless --path . --quit-after 120    # startup smoke test
```

## Controls

Each player slot owns a private set of Input Map actions (`p1_left` … `p4_down`),
because Godot's `Input` singleton cannot query "is this action pressed *on device
N*" — an action reports pressed if **any** device triggers it. Querying a slot's
own actions therefore yields only that slot's stick.

Which *physical* controller backs each slot is decided at runtime by
`GameManager`, never hardcoded. Godot assigns joypad device IDs by connection
order, so those IDs shift whenever anything connects or disconnects; the manager
rebuilds the whole roster on every `joy_connection_changed` and re-points each
slot's actions at a real device. Players are placed around `spawn_center`,
starting at the left of the arena and stepping evenly around the circle, so two
players end up on opposite sides.

| Slot | Bound device | Controls |
| --- | --- | --- |
| 1 | first connected controller | Left stick (or D-pad) |
| 2 | second connected controller | Left stick (or D-pad) |
| 3 | third connected controller | Left stick (or D-pad) |
| 4 | fourth connected controller | Left stick (or D-pad) |

With **no controller connected**, a single keyboard-driven player is still
spawned so the game stays testable (`keyboard_fallback` on the `GameManager`
node). Keyboard bindings live on the `p1_*` actions only, so a keyboard can
never drive slots 2-4.

Run with the `_console.exe` build to see which device drives which slot:

```
[GameManager] 2 player(s) active
  Player 1 -> device 0 (XInput Controller)
  Player 2 -> device 1 (Xbox Wireless Controller)
```

Up to 4 controllers are supported; extras are ignored with a warning.

## The arena

Concentric zones, built procedurally from `Arena` so the radii have exactly one
definition and collision can never drift from what is drawn:

| Zone | Radius | Behaviour |
| --- | --- | --- |
| Safe floor | 0 – 420 | Normal friction |
| Warning track | 420 – 600 | Friction × 0.6 — you slide further and turn more sluggishly |
| Wall | 572 – 600 | Solid `StaticBody2D` ring; players currently cannot leave |
| Death zone | 600 – 3600 | Crossing it eliminates the player |

Each annulus is filled with 96 convex wedges rather than one concave ring outline,
because concave shapes are unreliable to collide against and expensive to
decompose. Raising `segment_count` smooths the approximation at a linear cost.

Tuning lives on the `Arena` node in the inspector: `safe_radius`,
`warning_radius`, `wall_thickness`, `death_zone_depth`, `warning_friction_scale`,
`segment_count`.

The warning track is not cosmetic — at the default scale a player sliding from a
400 px/s start travels **70.8 px instead of 41.2 px**, i.e. 1.72× further,
because stopping distance goes as `1 / (friction × scale)`.

## Rounds

A round needs **two or more** connected players. Below that the game shows
`Connect a second controller to play` and waits.

1. A player crossing the boundary is eliminated: they vanish, stop simulating,
   and keep their controller bound so they can return next round.
2. When one player is left they win, and the running score is shown.
3. Two seconds later everyone is restored to their spawn marks and the next
   round starts. If the last two players leave on the same tick it is a draw and
   nobody scores.

The verdict is evaluated once per frame in `RoundManager._process`, not inside
the elimination handler. The death zone reports overlapping bodies one at a
time, so deciding on the first elimination would crown whoever happened to be
second and make a genuine double ring-out impossible.

### Testing elimination

Milestone 3's solid wall makes the death zone unreachable on foot and Milestone
5's shove does not exist yet, so there is a temporary toggle: **press `O`** to
open or close the boundary wall, then drive out of the ring. Milestone 5 should
remove this — a real shove should be the only way out, at which point
`Arena.boundary_enabled` can go away entirely.

## Layout

| Path | Purpose |
| --- | --- |
| `scripts/arena.gd` | Zone shapes, wall collision, warning-track friction |
| `scripts/arena_view.gd` | Draws floor, warning track, pulsing rim, start lines |
| `scripts/round_manager.gd` | Round state, elimination, winner, scores, reset |
| `scripts/announcer.gd` | Fading centre-screen banner for round messages |
| `scripts/game_manager.gd` | Detects joypads, spawns/removes players, binds devices |
| `scripts/player.gd` | `CharacterBody2D` movement: acceleration, friction, facing rotation |
| `scripts/player_input.gd` | Player slot ↔ action set ↔ device binding |
| `scripts/player_body_view.gd` | Placeholder art: colored disc + facing chevron |
| `scripts/fit_camera.gd` | Centres and zooms to fit the roster |
| `scripts/main.gd` | Scene entry point; wires the manager to the camera |
| `scenes/player.tscn` | Player scene |
| `scenes/arena.tscn` | Arena scene |
| `scenes/main.tscn` | Main scene |

Movement tuning lives on the `Player` node in the inspector: `player_index`,
`max_speed`, `acceleration`, `friction`, `turn_speed`. The default ratio gives
roughly a 0.24 s time to top speed and 0.34 s to coast to a stop, so momentum is
pronounced — intentional, since Milestone 5's charged shove builds on it.

## Notes for future milestones

- **M5 should remove the wall toggle.** `debug_toggle_wall` and
  `Arena.boundary_enabled` exist purely because M3 mandates a solid boundary
  while M4 requires players to leave it. Once the shove can breach the wall,
  neither is needed.
- **Do not disable a player's `CollisionShape2D` on elimination.** It re-enables
  deferred, while a `CharacterBody2D` still reports its old physics transform
  until `move_and_slide()` runs next step — so the death zone sees the body
  reappear inside itself and eliminates the player again on the first frame of
  the next round. Eliminated players are hidden and inert instead; moving them
  back to their spawn mark deregisters them from the area naturally.
- `death_zone_depth` (3000) is far larger than the camera can see, so M5's heavy
  shove cannot fling someone off the edge of the detection volume.
- **M5 must apply knockback as velocity, not by teleporting.** The same stale
  transform problem applies to any body moved without going through
  `move_and_slide()`.
- M3 needed no separate `SafeZone` area: anything outside the warning annulus
  simply keeps `surface_friction_scale = 1.0`.
- `FitCamera` is deliberately plain — M6 replaces it with tuned damping and
  shake. At `min_zoom = 0.45` it cannot quite frame a player pinned against the
  far side of the ring, so M6 should revisit that clamp.
- `GameManager.players` is the controller roster and deliberately still contains
  eliminated players; use `active_players()` for round logic. M5's hit detection
  must ignore inactive bodies.
- Any connect/disconnect still repositions everyone to spawn mid-round
  (`GameManager._rebuild`). Harmless as a party-game reset, surprising otherwise.