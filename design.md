# Game Design Document: Ring-Out Rumble

> **Core Vision:** A fast-paced, physics-based local multiplayer sumo wrestling game built in Godot 4. Simple controls (Left Stick + A Button) combined with momentum-driven mechanics create deep, tactical, high-stakes combat.

---

## 1. Game Overview & Specifications

* **Engine:** Godot 4.x (2D)
* **Genre:** Local Multiplayer Physics Brawler / Party Game
* **Players:** 2 to 4 Players (Designed for Xbox-style gamepads)
* **Aesthetic / Art:** Placeholder art (Colored circles with facing indicators/chevrons).
* **Core Rule:** Stay inside the ring. If you cross the fatal boundary, you are eliminated. Last player standing wins the round.

---

## 2. Arena Layout & Rings

The arena is structured in concentric circular zones from center to outside:

1. **The Safe Zone (Inner Circle):** Normal friction, standard movement.
2. **The Warning Track (Middle Ring):** Visual indicator (e.g., yellow/orange tint or flashing pattern). Friction is slightly reduced, making turning and stopping less responsive.
3. **The Fatal Abyss (Outer Ring / Void):** Crossing this line instantly triggers player elimination.

---

## 3. Controls & Input Mapping

Configured via Godot's **Input Map** using explicit device indices (`device = 0, 1, 2, 3`) to support multiple Xbox controllers locally.

| Control | Action | Description |
| --- | --- | --- |
| **Left Stick** | Movement | Accelerates the player in the stick's direction with momentum and inertia. |
| **A Button (Tap)** | Quick Shove | A fast, low-range push forward. Interrupts opponents and applies light knockback. |
| **A Button (Hold & Release)** | Heavy Charge | Braces the player, charges power over up to 1.5 seconds, then unleashes a high-momentum lunging shove. |
| **B Button (Hold)** | Guard | Plants the player in a defensive stance for about half a second. They cannot move or turn, take greatly reduced knockback, and reflect part of an incoming blow back at the attacker. |

---

## 4. Development Milestones

Each milestone represents a discrete, independently testable build you can rapidly prompt an AI agent to write.

### Milestone 1: Project Skeleton & Basic Movement

* **Goal:** Get a player moving smoothly with an Xbox controller on a blank background.
* **Testable Endpoint:** Plug in Controller 1, use the Left Stick to move a placeholder circle around the screen with realistic acceleration, deceleration, and facing rotation.
* **AI Prompt Target:** Write a Godot 4 `CharacterBody2D` script using `Input.get_vector()` with customizable speed, acceleration, and friction, tied to an assigned player index.

### Milestone 2: Controller Assignment & Multiplayer Spawning

* **Goal:** Support multiple independent players using separate physical gamepads.
* **Testable Endpoint:** Connect 2 (or more) Xbox controllers. The game automatically spawns Player 1 (Blue) and Player 2 (Red) at opposite sides of the screen, each controlled exclusively by their respective gamepad.
* **AI Prompt Target:** Write a GameManager script that reads connected joypads, instantiates player scenes dynamically, and assigns specific device IDs to each player's input checks.

### Milestone 3: The Arena & Dual Ring Zones

* **Goal:** Build the sumo ring with a warning track and fatal boundary.
* **Testable Endpoint:** A circular arena rendered on screen with a distinct inner floor, a colored warning perimeter, and an outer death zone. Players collide with the arena bounds.
* **AI Prompt Target:** Create a Node2D scene featuring overlapping `Area2D` zones (Warning Ring and Death Ring) with custom collision shapes and visual canvas item drawing/textures.

### Milestone 4: Elimination & Round Reset Loop

* **Goal:** Detect when a player falls out of the ring and handle round wins.
* **Testable Endpoint:** Push or drive Player 2 out of the arena. Player 2 disappears, a "Player 1 Wins Round!" message appears, and the arena resets the players to their starting positions after 2 seconds.
* **AI Prompt Target:** Write signal connections between the arena death zone `body_exited` event and a game manager that tracks scores, announces winners, and reloads player positions.

### Milestone 5: The Push Mechanic (Tap & Charge)

* **Goal:** Implement the primary offensive tool using the A button.
* **Testable Endpoint:** Tapping A performs a quick shove that knocks an opposing player backward. Holding A charges up a heavy lunge that launches opponents significantly further across the arena floor.
* **AI Prompt Target:** Add an `Area2D` hitbox in front of the player character. Implement button-press duration logic to differentiate between a quick tap (low impulse) and a charged hold (scaled impulse applied to overlapping bodies).

### Milestone 6: Dynamic Camera & Juice

* **Goal:** Keep all active players framed on screen and add polish.
* **Testable Endpoint:** As players move away from each other toward the edge of the ring, the camera smoothly zooms out to keep everyone visible. Add screen shake when a heavy charge connects.
* **AI Prompt Target:** Write a camera script that calculates the midpoint and max distance between all active player nodes, dynamically adjusting `zoom` and position, plus a shake helper function.

### Milestone 7: Commitment & Chain Reactions

* **Goal:** Give the shove a real cost when it misses, and let a shove carry through to a third player. A charge should be something you choose to commit to, not something you can throw out for free.
* **Testable Endpoint:** Fire a full charge at empty air and fail to connect. The charging wrestler is left visibly helpless for a moment afterward - unable to accelerate or shove - so an opponent who reads the whiff can land a free hit on them. Separately, shove a player hard into a third player standing downrange: the third player is visibly knocked back by the impact rather than simply blocking the incoming body.
* **AI Prompt Target:** Track whether a charge connected during its active window. On release with no hit, apply a short recovery state that scales friction up and zeroes acceleration, clearing once the wrestler touches anything or the timer expires. Separately, detect player-to-player contact while a body is under knockback and transfer a tunable fraction of the incoming impulse into the body that was struck.

#### Notes on balancing Milestone 7

* **Whiff recovery should be short and readable.** Roughly half a second
  (0.55 s in the shipped build, raised from an initial 0.35 s after playtesting
  felt too forgiving). Long enough that a whiff is a real opening, short enough
  that it is not a death sentence in a 2-player round. Only apply it to charged
  shoves; a quick tap should stay free, so mashing A is never a strategy.
* **The recovery window must not stack.** Releasing into an existing recovery should not extend it.
* **Knockback transfer is what makes 3- and 4-player rounds interesting**, and it should be a fraction of the incoming impulse rather than all of it, or a single shove will cascade through the whole lobby and remove any chance of recovering position.
* **Transferred knockback is not aimed.** Shoves throw a player along the attacker's line of attack (see Milestone 5's direction buffer); a collision should throw them along the impact direction instead. That contrast is intentional - it is the difference between being hit and being used as a weapon.
* **A body driven by knockback must not transfer into the player who hit it**, or two players would shove each other in a loop.
* Watch this milestone against ring-out balance: transfer makes it easier to fling someone out unintentionally, which interacts with the soft boundary introduced for Milestone 6.

### Milestone 8: The Guard

* **Goal:** Give the defender a real answer to the charge, at the cost of total commitment. Guarding should be a deliberate bet that the opponent will commit, not a panic button that trivialises the shove.
* **Testable Endpoint:** Hold B and the wrestler visibly plants: a depleting ring appears around them, and pushing the stick or turning does nothing at all for the duration. Time the guard to a committed charge and they barely slide, while the attacker is visibly thrown back by the reflection even if they are still leaning on the stick. After roughly half a second the stance drops, movement returns, and immediately trying to guard again fails because it is on cooldown. Being hit from behind while guarding is noticeably worse than being hit from the front.
* **AI Prompt Target:** Add a `GUARD` button action per device alongside the existing shove binding, and a guarded state on the player that, while active, zeroes stick acceleration and freezes facing rotation. In the shove hit handler, branch on whether the target is guarding: scale the incoming impulse down by a damage-taken factor, apply a reflected impulse of its own along the impact direction, and mark the blow as still connected. Drive a depleting ring in the body view from the remaining stance time, and gate re-entry behind a cooldown that starts when the stance ends.

#### Notes on balancing Milestone 8

* **"Reflect" is deliberately ambiguous in the brief and needs a decision.** The
  reading here is *bounce a share of the impulse back at the attacker*, not
  counter-shove them. Bouncing preserves the game's aimed-versus-impact
  distinction (see Milestone 7): the reflection is radial, thrown along the line
  of impact, because you cannot aim a block you did not choose to face.
* **A guard must not be a full negation.** Incoming impulse should still slide
  the defender a little, otherwise there is no readable feedback that a hit landed
  at all. The damage-taken factor is the main dial here.
* **Guard-spam is the balance risk.** If the cooldown is close to the duration,
  a patient defender simply re-guards forever and the shove stops mattering. The
  cooldown should be several times the stance length so guarding is a resource,
  not a toggle.
* **The stance is self-punishing; it does not need whiff recovery on top.** Being
  unable to move is already the cost. Running Milestone 7's whiff state during a
  stance would stack two helplessness windows and is probably oppressive.
* **Releasing B early should end the stance but still start the cooldown.**
  Otherwise a tap-block on the quick shove is strictly better than committing to
  the full window.
* **Cannot turn is a feature, not a limitation.** A guarded wrestler frozen on
  their facing can be punished from behind, which lands outside the Milestone 5
  direction buffer and therefore arrives off-axis. This is the intended counter
  to guarding and should not be patched out by making the stance rotate to face
  incoming hits.
* **A hit that lands on a guard still counts as connected** for the attacker, so
  it must not trigger Milestone 7 whiff recovery. Making a guard cause the
  attacker to whiff would be a far stronger punish than the design intends.
* **Reflections should not chain.** A reflected attacker carrying knockback into
  a third player would trigger Milestone 7 transfer, and two guards could bounce
  each other down the arena. Reflection needs to be flagged so it does not feed
  the transfer path.
* **A reflection needs the attacker to actually stop, or it does not read.** Two
  things have to happen on a covered hit, and the second one is not obvious.
  Interrupting the attacker is not sufficient on its own: it only zeroes their
  current velocity, so the very next physics frame the stick starts rebuilding
  it at full acceleration and cancels the reflection within about eight frames.
  Measured, that left a roughly 25 px drift and the attacker planted against the
  guard — the reflection was mathematically present and visually absent. A short
  **stagger**, during which stick acceleration is scaled to zero, is what lets
  the bounce carry. While staggered the attacker cannot charge or guard either,
  so a bounce is punishable rather than a free trade.
* **The bounce must clearly exceed the lunge, or it does not read.** A full
  charge carries the attacker about 99 px forward before contact. A reflection
  worth roughly that same distance is invisible: the attacker ends up back at
  their own starting position, which to a player is indistinguishable from
  simply being stopped. This is the trap worth naming, because "did they bounce?"
  is exactly the question that displacement-from-start cannot answer. Measure
  from the point of contact, and require the bounce to clear roughly 1.5x the
  lunge. At `guard_reflect_ratio` 0.5 the bounce is 246 px against a 99 px lunge,
  for a net displacement of +147 px.
* **Partial coverage must be worth something, or the cone has no shape.** Slide
  distance goes as the *square* of impulse, so a smooth fade across the cone
  makes partial coverage nearly worthless: at 60 degrees off axis a plain
  smoothstep gave 0.26 coverage and still 60% of a full unblocked knockback,
  which reads as "the guard did nothing". Coverage therefore holds at full
  across the inner part of the cone and gives out sharply at the rim, so the
  guard is either working or plainly failing. The rim is where the guard gives
  out, and it should read that way.
* **Watch the soft boundary.** A reflection strong enough to launch an opponent
  out of the ring turns guarding into a trap for the defender, and makes the
  boundary's walk-out rule dangerous in the wrong direction.
* **Guard and charge must be mutually exclusive.** They are both immobile
  commitments; holding both should resolve to one, not blend into a super-state.

#### Timing note

The stance lasts 0.5 s but a full charge takes 1.5 s to build, so a guard cannot
cover a wind-up. It has to be timed to the 0.22 s lunge, which fits inside the
window with room to spare. Guarding early does nothing, and that is the intended
read: you are betting on the lunge, not reacting to the tell.

#### Open questions before implementation

* Should the guarded body behave like a wall (other players bounce off it), or
  merely be very hard to displace? A wall is the more sumo reading of a brace,
  but it turns the stance into a body-block tool as well as a damage-reduction one.
* Should the guard slow rather than fully stop movement, to preserve some
  recovery? Full stop is the stronger commitment and the clearer read.
* Does the guard need a wind-up or recovery animation, or is the ring sufficient
  feedback? Placeholder art may not survive an animation.
