# Headless gameplay engine

`AnchorRulesEngine` is the presentation-free entry point. It owns authoritative action validation and stabilization while `AnchorGameState`, `AnchorMapDefinition`, and the entity state classes hold serializable simulation data. Rendering, scenes, input, AI, and expansion content are deliberately absent.

Typical use:

```gdscript
var engine := AnchorRulesEngine.new()
var state := engine.new_game()
var result := engine.apply_action(state, AnchorGameplayAction.place_anchor(Vector2i(1, 1)))
if result.success:
    state = result.state
```

`apply_action` never mutates its input. Successful results contain a stabilized state, structured resolution events, a replayable action-log entry, and a deterministic state hash. Rejected results return the original state and a human-readable error. `get_legal_actions`, the topology query methods, scoring, debug snapshots, and `replay` use the same rules path.

Run the dependency-free suite with:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_tests.gd
```

The gameplay specification remains authoritative in `docs/anchor_core_rules_en.md`; this file only describes the engine interface.
