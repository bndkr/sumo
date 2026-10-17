# Ring-Out Rumble

A fast-paced, physics-based local multiplayer sumo wrestling game built in
Godot 4. See [design.md](design.md) for the full design and milestone list.

## Status

**Milestone 1 — Project Skeleton & Basic Movement: implemented.**

- [x] M1: Project skeleton & basic movement
- [ ] M2: Controller assignment & multiplayer spawning
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

Each player index owns a private set of Input Map actions (`p1_left` … `p4_down`)
bound to a single joypad device, because Godot's `Input` singleton cannot query
"is this action pressed *on device N*". Devices are assigned to players by
index: player 1 → device 0, player 2 → device 1, and so on.

| Player | Device | Controls |
| --- | --- | --- |
| 1 | 0 | Left stick (or D-pad), or `WASD` / arrow keys |
| 2 | 1 | Left stick (or D-pad) |
| 3 | 2 | Left stick (or D-pad) |
| 4 | 3 | Left stick (or D-pad) |

The keyboard fallback is bound to the `p1_*` actions only, so a keyboard can
never drive players 2–4. Axis values are clamped to each player's own
deadzone inside `Input.get_vector()`.

## Layout

| Path | Purpose |
| --- | --- |
| `scripts/player.gd` | `CharacterBody2D` movement: acceleration, friction, facing rotation |
| `scripts/player_input.gd` | Resolves a player index to its device's input actions |
| `scripts/player_body_view.gd` | Placeholder art: colored disc + facing chevron |
| `scripts/main.gd` | Scene entry point; spawns player 1 and frames the camera |
| `scenes/player.tscn` | Player scene |
| `scenes/main.tscn` | Main scene |

Tuning lives on the `Player` node in the inspector: `player_index`, `max_speed`,
`acceleration`, `friction`, `turn_speed`. The default ratio gives roughly a
0.24 s time to top speed and 0.34 s to coast to a stop, so momentum is
pronounced — intentional, since Milestone 5's charged shove builds on it.

## Notes for future milestones

- `main.gd` hardcodes a single player instance; M2 replaces this with a
  `GameManager` that spawns one player per connected joypad.
- The camera in `main.tscn` only follows one player with a deadzone; M6
  replaces it with dynamic framing across all active players.