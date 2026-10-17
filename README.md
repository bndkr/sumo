# Ring-Out Rumble

A fast-paced, physics-based local multiplayer sumo wrestling game built in
Godot 4. See [design.md](design.md) for the full design and milestone list.

## Status

- [x] M1: Project skeleton & basic movement
- [x] M2: Controller assignment & multiplayer spawning
- [ ] M3: The arena & dual ring zones
- [ ] M4: Elimination & round reset loop
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

## Layout

| Path | Purpose |
| --- | --- |
| `scripts/game_manager.gd` | Detects joypads, spawns/removes players, binds devices |
| `scripts/player.gd` | `CharacterBody2D` movement: acceleration, friction, facing rotation |
| `scripts/player_input.gd` | Player slot ↔ action set ↔ device binding |
| `scripts/player_body_view.gd` | Placeholder art: colored disc + facing chevron |
| `scripts/fit_camera.gd` | Centres and zooms to fit the roster |
| `scripts/main.gd` | Scene entry point; wires the manager to the camera |
| `scenes/player.tscn` | Player scene |
| `scenes/main.tscn` | Main scene |

Movement tuning lives on the `Player` node in the inspector: `player_index`,
`max_speed`, `acceleration`, `friction`, `turn_speed`. The default ratio gives
roughly a 0.24 s time to top speed and 0.34 s to coast to a stop, so momentum is
pronounced — intentional, since Milestone 5's charged shove builds on it.

## Notes for future milestones

- `FitCamera` is deliberately plain — it exists so M2's "players on opposite
  sides" endpoint is visible. M6 replaces it with tuned damping and shake.
- M3 moves `spawn_center` and `spawn_radius` onto the arena; players are
  currently laid out on an imaginary circle of radius 300 around the origin.
- M4 will need players removed from `GameManager.players` on elimination, which
  means teardown has to stop assuming a player is permanent.