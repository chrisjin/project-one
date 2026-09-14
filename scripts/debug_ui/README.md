# Playable 3D debug client

Run the project from Godot or execute the project binary with `--path .`. The default scene first offers **Human vs Human**, **Human vs AI as Black**, **Human vs AI as White**, and **AI vs AI** on the standard board.

- Choose **Placement**, **Movement**, or **Action**, then click only engine-highlighted sources and destinations. In the core game, Movement highlights Anchors only; base O and D BoardPieces cannot move.
- For O/D placement, click a highlighted physical Main Anchor before choosing the destination.
- **Pass** is available before using a category; **End Turn** is available afterward.
- Click an entity without a mode selected to inspect engine-provided diagnostics.
- The right panel keeps entity diagnostics on top and shows Black/White casualties, current board counts, remaining Anchor deployments, and newest-first action traces below.
- Each Anchor shows its remaining BoardPiece binding slots as a small number at its bottom-left.
- The current player's entities in current or next-turn enemy attack paths show a red warning badge. Dual-protected BoardPieces show a golden shield for the current player and a blue shield for the opponent. BoardPieces with active Main Anchor damage reduction show a teal `-1` shield. A protected O or D reduced to 0 HP renders as its engine-provided PieceSpirit state.
- Transparent animated threat lines use green arrows for the current player's attacks and red arrows for enemy attacks.
- **Restart** or the `R` key returns to match-mode selection.

The client rebuilds visuals from each returned `GameState`. It does not resolve legality, topology, damage, death, scoring, or other gameplay behavior. Computer turns are chosen by a presentation-free `AnchorMinimaxAi` worker on a background thread and submitted on the main thread through the same rules-engine path as human actions.
