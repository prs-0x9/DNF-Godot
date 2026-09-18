# DNF (Did Not Finish) 🏁

**DNF** is a 3D racing game built in Godot 4 that flips the traditional time-trial mechanic into a high-stakes survival mode. 

Instead of racing a clock, the player races a physical Ghost car representing a specific difficulty tier. If the Ghost crosses the finish line before the player completes their required laps, the player is instantly eliminated with a "DNF" (Did Not Finish), ending the race.

## Software Architecture

This project is designed to demonstrate robust software development practices. The codebase utilizes strict object-oriented design and memory-conscious node management, reflecting core systems architecture principles essential for C++, Java, and Python engineering roles. 

Key technical implementations include:
*   **Decoupled Physics Controllers:** The `VehicleBody3D` relies on modular scripts that handle input, raycast suspension, and engine force independently.
*   **Data Serialization:** The Ghost AI system records the player's `Transform3D` arrays (position and rotation) at fixed physics intervals, serializing the data into JSON structures for smooth `_physics_process` interpolation during playback.
*   **Singleton State Management:** A global Autoload script acts as the central race manager, securely tracking lap counts and handling the game-over state without tightly coupling to the track geometry.

## Tech Stack
*   **Engine:** Godot 4.3 (Compatibility Renderer for HTML5 Web Export)
*   **Language:** GDScript
*   **Physics:** Native Godot 3D Physics Engine (VehicleBody3D / CharacterBody3D)
*   **AI:** Collaborative development utilizing Anthropic's Claude 3.5 (Fable) for complex data interpolation and procedural mesh generation algorithms.

## Current Progress (Phase 1)
*   [x] Initialized Godot 4 project and version control.
*   [x] Configured the `VehicleBody3D` node hierarchy (Chassis, Collision, Mesh).
*   [x] Calibrated center of mass and suspension settings for arcade-style handling.
*   [x] Mapped WASD input actions and implemented the core driving script.
*   [ ] Build the JSON `ghost_recorder.gd` system.
*   [ ] Implement the `race_manager.gd` Singleton.

## Known Engine Quirks
*   **VehicleBody3D Slope Sliding:** Due to a known issue in the Godot 4 physics engine, a `VehicleBody3D` parked sideways on a sloped surface will continuously slide down, regardless of the angle or applied friction. Future updates to this project will implement a raycast-based parking brake script to lock the vehicle's position when idle to bypass this engine limitation.

## How to Play (Developer Build)
1. Clone the repository.
2. Open the project folder in Godot 4.3+.
3. Open `player_car.tscn` (set as the Main Scene).
4. Press `F5` to run the project.
5. Use **W, A, S, D** or the **Arrow Keys** to steer and accelerate.

## Development Screenshot
<img width="3286" height="1080" alt="Screenshot (9)" src="https://github.com/user-attachments/assets/da60aef8-dda9-4bf3-b5d9-228f091498ce" />
