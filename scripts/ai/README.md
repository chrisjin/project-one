# Headless minimax AI

`AnchorMinimaxAi` is a deterministic, presentation-free player. It receives a `GameState`, obtains exact legal actions from `AnchorRulesEngine`, simulates them through `apply_action`, and returns one legal `AnchorGameplayAction`.

The current implementation uses depth-limited alpha-beta minimax with deterministic heuristic ordering and a bounded candidate set. The bound keeps core placement branching responsive on the 7×7 board; `End Turn` is always retained as a candidate. Evaluation favors surviving BoardPieces first, followed by HP, Anchors, activation, maturity, and mild central control.

The default search depth is two atomic category actions. Minimax checks `GameState.current_player` at every node, so a player's optional second category is maximized by the same side and automatic turn advancement is handled naturally by the rules engine.

The AI has no dependency on scenes, rendering, input, or UI code and can be used directly in headless simulations.
