# Playable 3D debug client

Run the project from Godot or execute the project binary with `--path .`. The default scene first offers **Human vs Human**, **Human vs AI as Black**, **Human vs AI as White**, and **AI vs AI** on the standard board.

- Choose **Placement**, **Movement**, or **Action**, then click only engine-highlighted sources and destinations.
- For O/D placement, click a highlighted physical Main Anchor before choosing the destination.
- **Pass** is available before using a category; **End Turn** is available afterward.
- Click an entity without a mode selected to inspect engine-provided diagnostics.
- The current player's entities in current or next-turn enemy attack paths show a red warning badge. Dual-protected BoardPieces show a golden shield for the current player and a blue shield for the opponent.
- Transparent animated threat lines use green arrows for the current player's attacks and red arrows for enemy attacks.
- **Restart** or the `R` key returns to match-mode selection.

The client rebuilds visuals from each returned `GameState`. It does not resolve legality, topology, damage, death, scoring, or other gameplay behavior. Computer turns are chosen by the presentation-free `AnchorMinimaxAi` and submitted through the same rules-engine path as human actions.
