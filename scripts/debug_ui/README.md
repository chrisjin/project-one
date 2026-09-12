# Playable 3D debug client

Run the project from Godot or execute the project binary with `--path .`. The default scene opens a local Black-versus-White match on the standard board.

- Choose **Placement**, **Movement**, or **Action**, then click only engine-highlighted sources and destinations.
- For O/D placement, click a highlighted physical Main Anchor before choosing the destination.
- **Pass** is available before using a category; **End Turn** is available afterward.
- Click an entity without a mode selected to inspect engine-provided diagnostics.
- **Restart** or the `R` key creates a fresh match.

The client rebuilds visuals from each returned `GameState`. It does not resolve legality, topology, damage, death, scoring, or other gameplay behavior.
