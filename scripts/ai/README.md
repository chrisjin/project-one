# Headless minimax AI

`AnchorMinimaxAi` is a deterministic, presentation-free player. It receives a `GameState`, obtains exact legal actions from `AnchorRulesEngine`, simulates them through `apply_action`, and returns one legal `AnchorGameplayAction`.

The current implementation uses depth-limited alpha-beta minimax with deterministic heuristic ordering and a bounded candidate set. The bound keeps core placement branching responsive on the 7×7 board; `End Turn` is always retained as a candidate. Evaluation favors surviving BoardPieces first, followed by HP, Anchors, activation, maturity, Main Anchor unit-chain damage reduction, valid dual-Anchor protection, and friendly-group liberties. A Main Anchor inherits one BoardPiece base value for every bound BoardPiece because its death removes all of them. Enemy attack rays apply larger penalties when the threatened Anchor is damaged or supports several BoardPieces.

The heuristic has no coordinate or board-center preference. Its positional terms use only topology reported by the rules engine. Liberties are counted once per friendly group and capped at six, preventing open-space accumulation from outweighing material. A small symmetric O/D imbalance penalty encourages complementary orthogonal and diagonal attack coverage without intrinsically preferring either type. Supply is not separately rewarded because stabilization removes supply-disconnected BoardPieces before a candidate state is evaluated.

The default search depth is three atomic category actions with up to eight candidates per node. From the beginning of a normal turn, this covers both of the AI's possible categories and at least one opponent reply. Minimax checks `GameState.current_player` at every node, so a player's optional second category is maximized by the same side and automatic turn advancement is handled naturally by the rules engine.

Search reuses states already resolved by the legal-action query, caches repeated evaluations, and has a deterministic node budget. Crowded positions reduce descendant branching from eight to six. At twelve board entities, search uses depth two, four descendant candidates, and six root candidates. This bounds late-game thinking time without using a machine-dependent timer or changing engine legality.

The AI has no dependency on scenes, rendering, input, or UI code and can be used directly in headless simulations.

Search applies a 20-point action cost to moving an entity deployed during the same turn, favoring direct placement and productive second actions over minor positional gains. The cost participates in candidate ordering and minimax for both players; it never removes legal moves or overrides a larger tactical gain. New Anchor moves to cells that prohibit Anchor deployment are exempt. Base BoardPieces cannot move under the current core rules.
