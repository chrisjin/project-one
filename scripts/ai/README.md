# Headless minimax AI

`AnchorMinimaxAi` is a deterministic, presentation-free player. It receives a `GameState`, obtains exact legal actions from `AnchorRulesEngine`, simulates them through `apply_action`, and returns one legal `AnchorGameplayAction`.

The current implementation uses depth-limited alpha-beta minimax with deterministic heuristic ordering and a bounded candidate set. The bound keeps core placement branching responsive on the 7×7 board; `End Turn` is always retained as a candidate. Evaluation favors surviving BoardPieces first, followed by HP, Anchors, activation, maturity, Main Anchor unit-chain damage reduction, valid dual-Anchor protection, and friendly-group liberties. Main Anchors gain additional value for each bound BoardPiece, while an enemy attack ray applies a larger penalty when the threatened Anchor is damaged or supports several BoardPieces.

The heuristic has no coordinate or board-center preference. Its positional terms use only topology reported by the rules engine. Liberties are counted once per friendly group and capped at six, preventing open-space accumulation from outweighing material. Supply is not separately rewarded because stabilization removes supply-disconnected BoardPieces before a candidate state is evaluated.

The default search depth is three atomic category actions with eight candidates per node. From the beginning of a normal turn, this covers both of the AI's possible categories and at least one opponent reply. Minimax checks `GameState.current_player` at every node, so a player's optional second category is maximized by the same side and automatic turn advancement is handled naturally by the rules engine.

The AI has no dependency on scenes, rendering, input, or UI code and can be used directly in headless simulations.
