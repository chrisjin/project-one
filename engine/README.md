# Headless core rules engine

These GDScript `RefCounted` modules use only data and Godot value types. They do not load scenes or depend on rendering, input, or controllers. `Anchor` and `BoardPiece` occupy separate registries and share globally unique integer IDs for commands and immutable Main Anchor bindings.

```gdscript
const Rules = preload("res://engine/rules_engine.gd")
var state = Rules.new_game()
var result = Rules.apply_action(state, {
    "type": "deploy_anchor", "cell": Vector2i(2, 2)
})
if result.ok:
    state = result.state
```

Coordinates are zero-based: A1 is `(0, 0)`, G7 is `(6, 6)`. Owners are Black `0` and White `1`.

| Command `type` | Fields | Category |
| --- | --- | --- |
| `deploy_anchor` | `cell: Vector2i` | Placement |
| `deploy_board_piece` | `cell`, `kind: "O" or "D"`, `main_anchor: int` | Placement |
| `move` | `id: int`, `cell` | Movement |
| `attack` | `id`, `direction: Vector2i` | Action |
| `rapid_activation` | `id` | Action |
| `end_turn` | none | Ends the current turn |

A direction is one of the four unit steps allowed by the attacking BoardPiece's geometry. The selected ray stops at its first blocker; if there is no enemy target it deals no damage. Call `end_turn` explicitly after zero, one, or two actions. Ending a turn with no actions is a Pass. Two consecutive Passes finish the game. Category exhaustion does not implicitly advance the turn.

`apply_action` returns `{ok, error, state}` and fully stabilizes each accepted action. On rejection it returns the original state without changing it. Treat returned dictionaries as read-only; retain previous states for undo. `validate` performs structural checks; `apply_action` and `legal_actions` also enforce repetition. Commands always belong to `state.side`.

`legal_actions(state)` enumerates all accepted commands, including `end_turn`. `score` counts surviving BoardPieces; `winner` returns `ongoing`, `Black`, `White`, or `draw`. Queries are available through `topology.gd` and `combat.gd`. `stabilization.gd` mutates its argument internally; callers constructing test fixtures should pass a deep copy if they need to retain the original.

Repetition keys include entity geometry, types, HP, maturation/activation, Main Anchor binding geometry, lifetime Anchor counts, side to move, consumed categories, consecutive Pass count, and game completion. Anchor Cluster partition is derived from geometry. IDs are stable in state and logs, but arbitrary ID labels, the next-ID counter, history, and logs do not distinguish repeated positions. Pass count is included because it affects termination. No elapsed turn counter makes an otherwise repeated position unique.

`state_hash(state)` hashes that canonical position. `export_record(state)` emits versioned JSON commands; `import_record(text)` validates and replays them from the standard initial position. `replay(actions)` accepts native GDScript command dictionaries. No RNG is used by current core rules. Records currently support this rules version and the standard initial position only; fixture states are for direct tests, not record import.

The implementation covers the standard 7×7 map, base O/D, and Rapid Activation. Map validity and base stats are centralized in `game_state.gd`; connectivity, combat, stabilization, and command resolution are separate extension points. Terrain, larger maps, cards, and expansion behavior are not implemented. Future content should call centralized resolution instead of duplicating legality or topology rules.

Run the direct simulation suite from the project root:

```sh
godot --headless --path . --script tests/headless_rules_test.gd
```

When the default Godot user log directory is unavailable, add `--log-file /tmp/anchor-rules-tests.log`. The runner exits nonzero on a failed check. Some topology fixtures deliberately place Anchors outside the deployment area to isolate resolution; public placement and movement still enforce the standard map.
