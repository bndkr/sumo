# Ring-Out Rumble

A fast-paced, physics-based local multiplayer sumo wrestling game built in
Godot 4. See [design.md](design.md) for the full design and milestone list.

## Status

- [x] M1: Project skeleton & basic movement
- [x] M2: Controller assignment & multiplayer spawning
- [x] M3: The arena & dual ring zones
- [x] M4: Elimination & round reset loop
- [x] M5: The push mechanic (tap & charge)
- [ ] M6: Dynamic camera & juice
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
| Wall | 572 – 600 | Blocks normal movement; passes through above 700 px/s |
| Death zone | 600 – 3600 | Crossing it eliminates the player |

Each annulus is filled with 96 convex wedges rather than one concave ring outline,
because concave shapes are unreliable to collide against and expensive to
decompose. Raising `segment_count` smooths the approximation at a linear cost.

Tuning lives on the `Arena` node in the inspector: `safe_radius`,
`warning_radius`, `wall_thickness`, `death_zone_depth`, `warning_friction_scale`,
`segment_count`, `wall_break_speed`, `boundary_enabled`.

Shove tuning lives in the `Shove` group on the `Player` node: `charge_time`,
`tap_threshold`, `quick_shove_impulse`, `charged_shove_impulse`,
`quick_lunge_speed`, `charged_lunge_speed`, `shove_active_time`,
`shove_cooldown`, `hitbox_radius_min`, `hitbox_radius_max`,
`charge_speed_scale`, `charge_accel_scale`, `shove_self_recovery`,
`shove_friction_scale`, `shove_direction_buffer_degrees`. Knockback decay is
`knockback_decay` and is the main dial for how violent a shove feels.

`Player.stop_motion()` clears stick momentum, knockback, and the derived
velocity together. Use it rather than assigning `velocity` — `velocity` is
rebuilt every physics frame from the two accumulators, so zeroing it alone lets a
revived player keep its knockback and get launched straight back out of the ring.

The warning track is not cosmetic — at the default scale a player sliding from a
400 px/s start travels **70.8 px instead of 41.2 px**, i.e. 1.72× further,
because stopping distance goes as `1 / (friction × scale)`.

| Control | Action | Description |
| --- | --- | --- |
| Left stick | Movement | Accelerates with momentum and inertia |
| **A — tap** | Quick shove | Short forward lunge, light knockback |
| **A — hold & release** | Heavy charge | Braces while held, then a full-power lunge that can ring an opponent out |

Holding A builds charge for up to 1.5 s, shown as a gauge around the wrestler.
While charging the player is braced: slower and harder to turn, so committing
to a charge costs you positioning. On release the shove scales continuously
from tap to full power.

| Release | Forward lunge | Knockback | Measured slide |
| --- | --- | --- | --- |
| Tap (< 0.12 s) | 520 px/s | 260 | **68 px** |
| Half charge | ~1000 px/s | ~620 | **416 px** |
| Full charge | 1500 px/s | 980 | **992 px** |

Knockback decays at a constant rate, so slide distance goes as the square of the
impulse — a full charge carries an opponent about 14x further than a tap, which
is more than the arena is wide. From the centre of the ring only a full charge
will actually ring someone out; taps and half charges leave them standing.

Four things make a hit land hard and land *connected*:

- The **hitbox is short** — 28 to 34 px, sitting 28 px ahead of a body that is
  itself 26 px. A hit therefore registers just before the two bodies actually
  touch, instead of firing from across the arena.
- Wrestlers **always collide with each other**. A lunging attacker carries its
  momentum through into the victim rather than phasing past, so a charge ends in
  a real collision.
- The attacker **keeps 90% of its lunge** on impact, and friction is scaled to
  15% while a lunge is live. Ordinary friction bleeds a lunge off far faster than
  it can close on a moving victim, which left the two visibly short of each other.
- The attacker stops colliding with the **arena wall** while travelling fast
  enough to break through, and a player already past the boundary stays
  unblocked so the wall cannot shove them back in.

### Which way a shove throws you

Knockback follows the **attacker's line of attack**, not the line between the
two body centres — so a shove lands where it was aimed even when it clips
someone off-centre. Without this, a near miss squirts the victim sideways, which
makes an aimed ring-out unreliable.

`shove_direction_buffer_degrees` (default 40°) is the cutoff:

| Contact angle from the attack vector | Result |
| --- | --- |
| 0° – 40° | Thrown **along the attack vector** |
| > 40° | Genuine glancing blow — thrown along the centre-to-centre line, as billiards would |

**To revert this**, set `shove_direction_buffer_degrees` to **0** on the `Player`
node. That restores the original centre-to-centre behaviour exactly, verified at
0°, 25° and 60°.

### Getting out of the ring

The boundary wall blocks normal play but **yields to anything travelling faster
than `wall_break_speed`** (700 px/s, deliberately above the 620 px/s top speed).
That is what lets a full charge actually ring someone out instead of just
pinning them against the rim. Running at the wall never breaks through.

`Arena.boundary_enabled` is still an inspector toggle for tuning; the keyboard
shortcut that Milestone 4 used for it has been removed, since a shove is now the
real way out.

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

A round resets exactly once. If the winner then falls out during the
announcement, they are quietly retired and everyone stays put until the timer
expires — repositioning them there would snap both players back to their marks
mid-message and then do it all over again when the timer ran out.

### Testing elimination

Charge a full lunge into an opponent near the rim and you should see them
sketch out through the wall, the round resolve, and everyone reset.

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

- **`Player` emits `shove_landed(target, power)`.** M6 only needs to connect it
  to the camera for impact shake.
- **A round reset happens exactly once, and only from the round-over timer.**
  Any other path calling `GameManager.reset_players()` while a round is being
  announced produces a visible double reset. The single legitimate extra caller
  is the "fewer than two players" case in `RoundManager._on_elimination_detected`.
- **Do not disable a player's `CollisionShape2D` on elimination.** It re-enables
  deferred, while a `CharacterBody2D` still reports its old physics transform
  until `move_and_slide()` runs next step — so the death zone sees the body
  reappear inside itself and eliminates the player again on the first frame of
  the next round. Eliminated players are hidden and inert instead.
- **Never move a body by setting `global_position` and expecting physics to
  agree immediately.** A `CharacterBody2D` syncs to the physics server only
  inside `move_and_slide()`. Knockback is applied as velocity for exactly this
  reason, and M6's camera work must not assume otherwise either.
- **Anything that re-arms an `Area2D`'s monitoring re-reports every overlapping
  body**, and so does a deferred collision-shape toggle. Both produce ghost
  `body_entered` events for bodies the area still believes are inside it. The
  death zone is only ever created once, but keep it in mind before adding any
  zone that gets toggled at runtime.
- **Boundary policy lives in `Arena`, not `Player`.** `Arena._physics_process`
  decides per player whether the wall still stops them, via the `players`
  group. A player already past the boundary stays unblocked so the wall cannot
  shove them back in.
- `wall_break_speed` (700) must stay above `max_speed` (620), or ordinary
  running would breach the ring and Milestone 3's arena bounds would stop
  holding. Both are inspector values — worth asserting together if either is
  retuned.
- `GameManager.players` is the controller roster and deliberately still contains
  eliminated players; use `active_players()` for round logic, and check
  `is_active` before applying a shove to a body.
- Any connect/disconnect still repositions everyone to spawn mid-round
  (`GameManager._rebuild`). Harmless as a party-game reset, surprising otherwise.