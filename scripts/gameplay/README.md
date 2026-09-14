# Headless gameplay engine

`AnchorRulesEngine` is the presentation-free entry point. It owns authoritative action validation and stabilization while `AnchorGameState`, `AnchorMapDefinition`, and the entity state classes hold serializable simulation data. Rendering, scenes, input, AI, and expansion content are deliberately absent.

Gameplay balance and entity capabilities come from an immutable `AnchorRuleSet`. `AnchorCoreRuleSet` is the concrete configuration for the current authoritative game. Its Anchors move one orthogonal cell, while base O and D BoardPieces have movement range 0. Separate ruleset instances can be supplied to separate engines and AI players without changing global state, including alternate rulesets that enable other BoardPiece movement configurations. Headless AI implementations share the small `AnchorGameplayAi` interface and receive their ruleset when instantiated.

Typical use:

```gdscript
var rule_set := AnchorCoreRuleSet.new()
var engine := AnchorRulesEngine.new(rule_set)
var ai := AnchorMinimaxAi.new(rule_set)
var state := engine.new_game()
var result := engine.apply_action(state, AnchorGameplayAction.place_anchor(Vector2i(1, 1)))
if result.success:
    state = result.state
```

To experiment with another ruleset, construct `AnchorRuleSet` with an Anchor `EntityConfig`, a `BoardPieceType -> EntityConfig` dictionary, board size, category limit, and Anchor deployment limit. `EntityConfig` exposes attack, movement, attack-blocking side, targetability, HP, defense, binding, and conditional HP-reduction values through read-only accessors; exposed dictionaries and reduction lists are defensive copies.

`AttackBlockingType` is evaluated relative to an entity's owner: `SELF`, `ENEMY`, `BOTH`, or `NONE`. A blocking enemy becomes the ray target only when its immutable `targetable` configuration is true. In the core ruleset, friendly Anchors are transparent, while a protected O or D BoardPiece that reaches 0 HP becomes a non-deployable, non-targetable `PieceSpirit` that blocks both players and records its original type.

`apply_action` never mutates its input. Successful results contain a stabilized state, structured resolution events, a replayable action-log entry, and a deterministic state hash. Rejected results return the original state and a human-readable error. `get_legal_actions`, the topology query methods, scoring, debug snapshots, and `replay` use the same rules path.

When a successful action consumes the turn's second distinct category, `apply_action` also performs the authoritative start-of-next-turn transition and includes an automatic `turn_ended` event in the result.

Run the dependency-free suite with:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_tests.gd
```

The gameplay specification remains authoritative in `docs/anchor_core_rules_en.md`; this file only describes the engine interface.
