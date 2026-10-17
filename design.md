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

---

Would you like to start generating the code for **Milestone 1** right now?