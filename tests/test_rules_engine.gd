## Focused deterministic regression suite for the headless core rules engine.
extends RefCounted

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")
const MapDefinition = preload("res://scripts/gameplay/map_definition.gd")
const Anchor = preload("res://scripts/gameplay/anchor_state.gd")
const BoardPiece = preload("res://scripts/gameplay/board_piece_state.gd")
const GameplayAction = preload("res://scripts/gameplay/gameplay_action.gd")
const RulesEngine = preload("res://scripts/gameplay/rules_engine.gd")

var engine := RulesEngine.new()
var failures: Array[String] = []
var assertion_count := 0


func run_all() -> bool:
	test_standard_map_and_action_categories()
	test_start_of_turn_maturation_and_activation()
	test_anchor_binding_capacity_and_slot_reuse()
	test_anchor_clusters_merge_and_split()
	test_supply_paths_and_cuts()
	test_damage_reduction_uses_only_main_anchor_unit_chain()
	test_secondary_anchor_protection()
	test_no_liberty_resolution_order()
	test_ray_blocking_and_first_enemy_target()
	test_attack_and_main_anchor_death_cascade()
	test_pass_scoring_replay_and_deterministic_hash()
	test_range_diagonal_scoring_and_repetition()
	test_state_copy_isolation_and_anchor_limit()
	test_legal_action_generation()
	if failures.is_empty():
		print("PASS: %d gameplay-rule assertions" % assertion_count)
		return true
	for failure: String in failures:
		push_error(failure)
	print("FAIL: %d failures across %d assertions" % [failures.size(), assertion_count])
	return false


func test_standard_map_and_action_categories() -> void:
	var state = engine.new_game()
	_assert_false(
		engine.apply_action(state, GameplayAction.place_anchor(Vector2i(0, 0))).success,
		"standard map rejects an Anchor outside B2-F6"
	)
	var placed = engine.apply_action(state, GameplayAction.place_anchor(Vector2i(1, 1)))
	_assert_true(placed.success, "standard map accepts an Anchor in B2-F6")
	state = placed.state
	_assert_false(state.anchors[1].is_active, "new Anchor begins inactive")
	_assert_false(
		engine.apply_action(state, GameplayAction.place_board_piece(RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(2, 1), 1)).success,
		"Placement cannot be used twice in one turn"
	)
	var activated = engine.apply_action(state, GameplayAction.rapid_activation(1))
	_assert_true(activated.success, "Rapid Activation consumes the distinct Action category")
	_assert_true(activated.state.anchors[1].is_active, "Rapid Activation activates this turn's Anchor")
	_assert_equal(activated.state.current_player, RuleTypes.Player.WHITE, "using the second category automatically advances the turn")
	_assert_equal(activated.state.categories_used.size(), 0, "automatic turn advancement clears categories for the next player")
	_assert_true(_has_event(activated.events, "turn_ended", {"automatic": true}), "automatic turn advancement is exposed as a resolution event")
	var replayed = engine.replay(engine.new_game(), activated.state.action_log)
	_assert_true(replayed.success, "an automatically ended turn remains replayable without a synthetic UI action")
	_assert_equal(engine.state_hash(replayed.state), engine.state_hash(activated.state), "automatic turn replay reproduces the exact state")


func test_start_of_turn_maturation_and_activation() -> void:
	var state = _fixture_state(4, 2)
	_add_anchor(state, 1, RuleTypes.Player.BLACK, Vector2i(0, 0), false, 1)
	_add_piece(state, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(1, 0), 1, 2, false, 1)
	state.turn_number = 1
	state.current_player = RuleTypes.Player.BLACK
	state.categories_used.append(RuleTypes.ActionCategory.PLACEMENT)
	state.seen_state_hashes[engine.state_hash(state)] = true
	var to_white = engine.apply_action(state, GameplayAction.end_turn())
	_assert_true(to_white.success, "Black can end a turn after fixture setup")
	_assert_false(to_white.state.anchors[1].is_active, "Black Anchor does not activate on White's turn")
	_assert_false(to_white.state.board_pieces[1].is_mature, "Black BoardPiece does not mature on White's turn")
	var to_black = engine.apply_action(to_white.state, GameplayAction.end_turn())
	_assert_true(to_black.success, "White can pass back to Black")
	_assert_true(to_black.state.anchors[1].is_active, "Anchor activates at the start of its controller's next turn")
	_assert_true(to_black.state.board_pieces[1].is_mature, "BoardPiece matures at the start of its controller's next turn")


func test_anchor_binding_capacity_and_slot_reuse() -> void:
	var state = _fixture_state(6, 2)
	_add_anchor(state, 1, RuleTypes.Player.BLACK, Vector2i(0, 0))
	for id in range(1, 4):
		_add_piece(state, id, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(id, 0), 1)
	state.seen_state_hashes[engine.state_hash(state)] = true
	var over_capacity = engine.apply_action(
		state,
		GameplayAction.place_board_piece(RuleTypes.BoardPieceType.DIAGONAL, Vector2i(4, 0), 1)
	)
	_assert_false(over_capacity.success, "a physical Anchor binds at most three surviving BoardPieces")
	state.board_pieces.erase(3)
	var reused_slot = engine.apply_action(
		state,
		GameplayAction.place_board_piece(RuleTypes.BoardPieceType.DIAGONAL, Vector2i(4, 0), 1)
	)
	_assert_true(reused_slot.success, "a truly dead BoardPiece releases its physical Anchor slot")


func test_anchor_clusters_merge_and_split() -> void:
	var state = _fixture_state(5, 3)
	_add_anchor(state, 1, RuleTypes.Player.BLACK, Vector2i(0, 1))
	_add_anchor(state, 2, RuleTypes.Player.BLACK, Vector2i(1, 1))
	_add_anchor(state, 3, RuleTypes.Player.BLACK, Vector2i(3, 1))
	var clusters = engine.compute_anchor_clusters(state, RuleTypes.Player.BLACK)
	_assert_equal(clusters.size(), 2, "orthogonally adjacent Anchors merge into one cluster")
	_assert_equal(clusters[0], [1, 2], "cluster membership uses physical Anchor IDs")
	state.anchors[2].cell = Vector2i(2, 1)
	clusters = engine.compute_anchor_clusters(state, RuleTypes.Player.BLACK)
	_assert_equal(clusters.size(), 2, "moving an Anchor can split one cluster while merging another")
	_assert_equal(clusters[1], [2, 3], "clusters are recalculated from current geometry")


func test_supply_paths_and_cuts() -> void:
	var state = _fixture_state(5, 3)
	_add_anchor(state, 1, RuleTypes.Player.BLACK, Vector2i(0, 1))
	_add_piece(state, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(4, 1), 1)
	_assert_true(engine.compute_supply(state, 1), "passable empty cells carry Main Anchor Supply")
	_add_piece(state, 2, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.DIAGONAL, Vector2i(2, 1), 1)
	_assert_true(engine.compute_supply(state, 1), "friendly BoardPieces carry Main Anchor Supply")
	for y in range(3):
		_add_anchor(state, 10 + y, RuleTypes.Player.WHITE, Vector2i(3, y))
	_assert_false(engine.compute_supply(state, 1), "an enemy wall cuts Main Anchor Supply")
	var stabilized = engine.stabilize(state)
	_assert_false(stabilized.board_pieces.has(1), "a supply-disconnected BoardPiece dies immediately")

	var terrain_state = _fixture_state(3, 1)
	_add_anchor(terrain_state, 1, RuleTypes.Player.BLACK, Vector2i(0, 0))
	_add_piece(terrain_state, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(2, 0), 1)
	terrain_state.map_definition.set_impassable(Vector2i(1, 0), true)
	_assert_false(engine.compute_supply(terrain_state, 1), "impassable terrain cuts Main Anchor Supply")


func test_damage_reduction_uses_only_main_anchor_unit_chain() -> void:
	var state = _fixture_state(5, 2)
	_add_anchor(state, 1, RuleTypes.Player.BLACK, Vector2i(0, 1))
	_add_piece(state, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(0, 0), 1, 2, true)
	_add_anchor(state, 2, RuleTypes.Player.WHITE, Vector2i(2, 1))
	_add_piece(state, 2, RuleTypes.Player.WHITE, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(2, 0), 2)
	_assert_true(engine.compute_unit_chain_connection(state, 2), "occupied friendly chain reaches the physical Main Anchor")
	var reduced_hit = engine.apply_action(state, GameplayAction.attack(1, Vector2i.RIGHT))
	_assert_true(reduced_hit.success, "mature O attacks orthogonally")
	_assert_equal(reduced_hit.state.board_pieces[2].hp, 1, "Main Anchor unit chain reduces two damage to one")

	var empty_supply = _fixture_state(5, 2)
	_add_anchor(empty_supply, 1, RuleTypes.Player.BLACK, Vector2i(0, 1))
	_add_piece(empty_supply, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(0, 0), 1, 2, true)
	_add_anchor(empty_supply, 2, RuleTypes.Player.WHITE, Vector2i(4, 1))
	_add_piece(empty_supply, 2, RuleTypes.Player.WHITE, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(2, 0), 2)
	_assert_true(engine.compute_supply(empty_supply, 2), "empty-space path still provides Supply")
	_assert_false(engine.compute_unit_chain_connection(empty_supply, 2), "empty cells do not carry damage reduction")
	var full_hit = engine.apply_action(empty_supply, GameplayAction.attack(1, Vector2i.RIGHT))
	_assert_false(full_hit.state.board_pieces.has(2), "without a Main Anchor unit chain the target takes full damage and dies")


func test_secondary_anchor_protection() -> void:
	var protected_state = _fixture_state(3, 2)
	_add_anchor(protected_state, 1, RuleTypes.Player.BLACK, Vector2i(0, 0), true)
	_add_piece(protected_state, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(1, 0), 1, 0, true)
	_add_anchor(protected_state, 2, RuleTypes.Player.BLACK, Vector2i(2, 0), true)
	var stable = engine.stabilize(protected_state)
	_assert_true(stable.board_pieces.has(1), "a mature supplied 0-HP BoardPiece survives with an active distinct Secondary cluster")
	_assert_equal(engine.secondary_anchor_cluster_ids(stable, 1), [2], "Secondary protection exposes a stable cluster ID")
	_assert_true(engine.compute_unit_chain_connection(stable, 1), "the BoardPiece remains connected to its physical Main Anchor")
	_assert_true(engine.board_piece_debug(stable, 1).zero_hp_protection_valid, "debug data exposes legal 0-HP protection")
	var anchor_debug = engine.anchor_debug(stable, 1)
	_assert_equal(anchor_debug.bound_board_piece_ids, [1], "Anchor debug data exposes bound BoardPiece IDs")
	_assert_equal(anchor_debug.binding_capacity, 3, "Anchor debug data exposes physical binding capacity")

	var same_cluster = _fixture_state(3, 2)
	_add_anchor(same_cluster, 1, RuleTypes.Player.BLACK, Vector2i(0, 0), true)
	_add_anchor(same_cluster, 2, RuleTypes.Player.BLACK, Vector2i(1, 0), true)
	_add_piece(same_cluster, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(2, 0), 1, 0, true)
	_assert_false(engine.stabilize(same_cluster).board_pieces.has(1), "another Anchor in the same cluster is not Secondary protection")

	var inactive_secondary = _fixture_state(3, 2)
	_add_anchor(inactive_secondary, 1, RuleTypes.Player.BLACK, Vector2i(0, 0), true)
	_add_piece(inactive_secondary, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(1, 0), 1, 0, true)
	_add_anchor(inactive_secondary, 2, RuleTypes.Player.BLACK, Vector2i(2, 0), false)
	_assert_false(engine.stabilize(inactive_secondary).board_pieces.has(1), "an inactive Secondary Anchor is rejected")

	var disconnected = _fixture_state(4, 2)
	_add_anchor(disconnected, 1, RuleTypes.Player.BLACK, Vector2i(0, 0), true)
	_add_piece(disconnected, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(1, 0), 1, 0, true)
	_add_anchor(disconnected, 2, RuleTypes.Player.BLACK, Vector2i(3, 0), true)
	_assert_false(engine.stabilize(disconnected).board_pieces.has(1), "losing the friendly-unit connection to Secondary protection kills a 0-HP BoardPiece")


func test_no_liberty_resolution_order() -> void:
	var one_anchor = _fixture_state(2, 1)
	_add_anchor(one_anchor, 1, RuleTypes.Player.BLACK, Vector2i(0, 0), true)
	_add_piece(one_anchor, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(1, 0), 1, 2, true)
	var dead_group = engine.stabilize(one_anchor)
	_assert_true(dead_group.anchors.is_empty() and dead_group.board_pieces.is_empty(), "a one-Anchor zero-liberty group dies as one judgment")

	var bare_anchor = _fixture_state(1, 1)
	_add_anchor(bare_anchor, 1, RuleTypes.Player.BLACK, Vector2i.ZERO, true)
	_assert_true(engine.stabilize(bare_anchor).anchors.is_empty(), "a bare zero-liberty Anchor dies")

	var two_anchor = _fixture_state(3, 1)
	_add_anchor(two_anchor, 1, RuleTypes.Player.BLACK, Vector2i(0, 0), true)
	_add_piece(two_anchor, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(1, 0), 1, 2, true)
	_add_anchor(two_anchor, 2, RuleTypes.Player.BLACK, Vector2i(2, 0), true)
	var living_group = engine.stabilize(two_anchor)
	_assert_equal(living_group.anchors.size(), 2, "Anchors remain in a zero-liberty group containing a legal dual-protected BoardPiece")
	_assert_true(living_group.board_pieces.has(1), "dual-Anchor-protected positive-HP BoardPiece survives No-Liberty")

	var supply_first = _fixture_state(4, 1)
	_add_piece(supply_first, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(0, 0), 2, 2, true)
	_add_anchor(supply_first, 1, RuleTypes.Player.BLACK, Vector2i(1, 0), true)
	_add_anchor(supply_first, 10, RuleTypes.Player.WHITE, Vector2i(2, 0), true)
	_add_anchor(supply_first, 2, RuleTypes.Player.BLACK, Vector2i(3, 0), true)
	var supply_resolved = engine.stabilize(supply_first)
	_assert_false(supply_resolved.board_pieces.has(1), "external-Main-Anchor BoardPiece dies from Supply before No-Liberty")
	_assert_true(supply_resolved.anchors.has(1), "Supply death opens a liberty that saves the internal Secondary Anchor")


func test_ray_blocking_and_first_enemy_target() -> void:
	var state = _fixture_state(5, 2)
	_add_anchor(state, 1, RuleTypes.Player.BLACK, Vector2i(0, 1))
	_add_piece(state, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(0, 0), 1, 2, true)
	_add_piece(state, 2, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.DIAGONAL, Vector2i(1, 0), 1)
	_add_anchor(state, 2, RuleTypes.Player.WHITE, Vector2i(3, 0))
	var ray = engine.trace_ray(state, 1, Vector2i.RIGHT)
	_assert_equal(ray.target, {"kind": RuleTypes.EntityKind.ANCHOR, "id": 2}, "friendly positive-HP BoardPiece is transparent and first enemy is targeted")
	state.board_pieces[2].hp = 0
	_assert_true(engine.trace_ray(state, 1, Vector2i.RIGHT).target.is_empty(), "friendly 0-HP BoardPiece blocks a normal ray")
	state.board_pieces.erase(2)
	_add_anchor(state, 3, RuleTypes.Player.BLACK, Vector2i(1, 0))
	_assert_true(engine.trace_ray(state, 1, Vector2i.RIGHT).target.is_empty(), "friendly Anchor blocks a normal ray")
	state.anchors.erase(3)
	state.map_definition.set_impassable(Vector2i(1, 0), true, false)
	_assert_equal(engine.trace_ray(state, 1, Vector2i.RIGHT).target.id, 2, "ray-transparent impassable terrain does not block attacks")
	state.map_definition.set_impassable(Vector2i(1, 0), true, true)
	_assert_true(engine.trace_ray(state, 1, Vector2i.RIGHT).target.is_empty(), "ray-blocking impassable terrain stops attacks")


func test_attack_and_main_anchor_death_cascade() -> void:
	var state = _fixture_state(5, 2)
	_add_anchor(state, 1, RuleTypes.Player.BLACK, Vector2i(0, 1))
	_add_piece(state, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(0, 0), 1, 2, true)
	_add_anchor(state, 2, RuleTypes.Player.WHITE, Vector2i(2, 0), true, 0, 2)
	_add_piece(state, 2, RuleTypes.Player.WHITE, RuleTypes.BoardPieceType.DIAGONAL, Vector2i(3, 0), 2)
	var threats := engine.compute_attack_threats(state, RuleTypes.Player.BLACK)
	_assert_equal(threats.size(), 1, "attack-threat query reports exact mature BoardPiece rays")
	_assert_equal(threats[0].target.id, 2, "attack-threat query reports the first enemy target")
	_assert_equal(threats[0].damage, 2, "attack-threat query reports engine-resolved damage")
	state.board_pieces[1].is_mature = false
	_assert_equal(engine.compute_attack_threats(state, RuleTypes.Player.BLACK).size(), 0, "immature BoardPieces are not immediate attack threats")
	var opportunities := engine.compute_attack_opportunities(state, RuleTypes.Player.BLACK)
	_assert_equal(opportunities.size(), 1, "attack-opportunity query exposes an immature BoardPiece's future attack geometry")
	_assert_equal(opportunities[0].target.id, 2, "future attack geometry uses the engine's first-enemy ray target")
	state.board_pieces[1].is_mature = true
	var result = engine.apply_action(state, GameplayAction.attack(1, Vector2i.RIGHT))
	_assert_true(result.success, "attack on the first enemy Anchor resolves")
	_assert_false(result.state.anchors.has(2), "Anchors take full damage and are destroyed at zero HP")
	_assert_false(result.state.board_pieces.has(2), "physical Main Anchor death immediately cascades to bound BoardPieces")
	_assert_true(result.state.board_pieces.has(1), "an attack does not continue through its destroyed first target")


func test_pass_scoring_replay_and_deterministic_hash() -> void:
	var initial = engine.new_game(null, 42)
	var first_pass = engine.apply_action(initial, GameplayAction.end_turn())
	var second_pass = engine.apply_action(first_pass.state, GameplayAction.end_turn())
	_assert_true(second_pass.success and second_pass.state.is_game_over, "two consecutive passes end the game")
	_assert_equal(second_pass.state.outcome, RuleTypes.Outcome.DRAW, "equal surviving BoardPiece counts produce a draw")
	_assert_equal(second_pass.state.black_score, 0, "Anchors and empty cells do not score")
	var replayed = engine.replay(engine.new_game(null, 42), second_pass.state.action_log)
	_assert_true(replayed.success, "the complete serialized action log replays successfully")
	_assert_equal(engine.state_hash(replayed.state), engine.state_hash(second_pass.state), "replay reproduces the exact deterministic state hash")
	_assert_equal(engine.state_hash(initial), engine.state_hash(initial.duplicate_state()), "equivalent states hash identically")


func test_range_diagonal_scoring_and_repetition() -> void:
	var ray_state = _fixture_state(9, 3)
	_add_anchor(ray_state, 1, RuleTypes.Player.BLACK, Vector2i(0, 1))
	_add_piece(ray_state, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(0, 0), 1, 2, true)
	_add_anchor(ray_state, 2, RuleTypes.Player.WHITE, Vector2i(7, 0))
	_assert_true(engine.trace_ray(ray_state, 1, Vector2i.RIGHT).target.is_empty(), "base BoardPiece rays stop after six grid steps on larger maps")
	ray_state.anchors[2].cell = Vector2i(6, 0)
	_assert_equal(engine.trace_ray(ray_state, 1, Vector2i.RIGHT).target.id, 2, "a target exactly six grid steps away is in range")

	var diagonal_state = _fixture_state(4, 4)
	_add_anchor(diagonal_state, 1, RuleTypes.Player.BLACK, Vector2i(0, 1))
	_add_piece(diagonal_state, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.DIAGONAL, Vector2i(0, 0), 1, 2, true)
	_add_anchor(diagonal_state, 2, RuleTypes.Player.WHITE, Vector2i(2, 2))
	_assert_equal(engine.trace_ray(diagonal_state, 1, Vector2i(1, 1)).target.id, 2, "D BoardPiece attacks on a 45-degree diagonal")
	_assert_true(engine.trace_ray(diagonal_state, 1, Vector2i.RIGHT).target.is_empty(), "D BoardPiece rejects an orthogonal attack direction")

	var scoring_state = _fixture_state(3, 2)
	_add_anchor(scoring_state, 1, RuleTypes.Player.BLACK, Vector2i(0, 0), true)
	_add_piece(scoring_state, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(1, 0), 1, 0, true)
	_add_anchor(scoring_state, 2, RuleTypes.Player.BLACK, Vector2i(2, 0), true)
	scoring_state = engine.stabilize(scoring_state)
	scoring_state.seen_state_hashes[engine.state_hash(scoring_state)] = true
	var scoring_pass = engine.apply_action(scoring_state, GameplayAction.end_turn())
	var scoring_end = engine.apply_action(scoring_pass.state, GameplayAction.end_turn())
	_assert_equal(scoring_end.state.black_score, 1, "a legally surviving 0-HP BoardPiece scores one point")
	_assert_equal(scoring_end.state.outcome, RuleTypes.Outcome.BLACK_WIN, "higher surviving BoardPiece count wins")

	var repeat_state = _fixture_state(5, 2)
	_add_anchor(repeat_state, 1, RuleTypes.Player.BLACK, Vector2i(0, 1), true)
	_add_piece(repeat_state, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(0, 0), 1, 2, true)
	_add_anchor(repeat_state, 2, RuleTypes.Player.WHITE, Vector2i(4, 1), true)
	_add_piece(repeat_state, 2, RuleTypes.Player.WHITE, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(4, 0), 2, 2, true)
	repeat_state.seen_state_hashes[engine.state_hash(repeat_state)] = true
	var transitions = [
		GameplayAction.move(RuleTypes.EntityKind.BOARD_PIECE, 1, Vector2i(1, 0)),
		GameplayAction.end_turn(),
		GameplayAction.move(RuleTypes.EntityKind.BOARD_PIECE, 2, Vector2i(3, 0)),
		GameplayAction.end_turn(),
		GameplayAction.move(RuleTypes.EntityKind.BOARD_PIECE, 1, Vector2i(0, 0)),
		GameplayAction.end_turn(),
		GameplayAction.move(RuleTypes.EntityKind.BOARD_PIECE, 2, Vector2i(4, 0)),
	]
	for action: GameplayAction in transitions:
		var transition = engine.apply_action(repeat_state, action)
		_assert_true(transition.success, "setup transition for repeated-position regression is legal")
		repeat_state = transition.state
	var forbidden_repeat = engine.apply_action(repeat_state, GameplayAction.end_turn())
	_assert_false(forbidden_repeat.success, "a turn transition cannot recreate a previously seen complete state")


func test_state_copy_isolation_and_anchor_limit() -> void:
	var state = engine.new_game()
	var placed = engine.apply_action(state, GameplayAction.place_anchor(Vector2i(1, 1)))
	_assert_true(placed.success, "copy-isolation setup action succeeds")
	_assert_true(state.anchors.is_empty(), "successful actions do not mutate their input GameState")
	_assert_equal(state.categories_used.size(), 0, "input turn metadata remains unchanged after a successful action")
	var failed = engine.apply_action(placed.state, GameplayAction.place_anchor(Vector2i(2, 1)))
	_assert_false(failed.success, "copy-isolation setup includes a rejected action")
	_assert_equal(failed.state, placed.state, "a rejected action returns the unchanged input state")

	var limit_state = _fixture_state(13, 2)
	for id in range(1, 13):
		_add_anchor(limit_state, id, RuleTypes.Player.BLACK, Vector2i(id - 1, 0))
	limit_state.seen_state_hashes[engine.state_hash(limit_state)] = true
	var thirteenth = engine.apply_action(limit_state, GameplayAction.place_anchor(Vector2i(12, 0)))
	_assert_false(thirteenth.success, "destroyed or surviving history caps each player at twelve deployed physical Anchors")


func test_legal_action_generation() -> void:
	var state = engine.new_game()
	var legal_actions = engine.get_legal_actions(state)
	var legal_transitions = engine.get_legal_transitions(state)
	var anchor_placements := 0
	var end_turns := 0
	for action: GameplayAction in legal_actions:
		if action.kind == GameplayAction.Kind.PLACE_ANCHOR:
			anchor_placements += 1
		elif action.kind == GameplayAction.Kind.END_TURN:
			end_turns += 1
	_assert_equal(anchor_placements, 25, "standard opening exposes exactly the inner 5x5 Anchor placements")
	_assert_equal(end_turns, 1, "legal actions include ending an otherwise empty turn as a pass")
	_assert_equal(legal_transitions.size(), legal_actions.size(), "legal transitions mirror the legal-action API")
	_assert_equal(
		legal_transitions[0].action.to_dictionary(),
		legal_actions[0].to_dictionary(),
		"legal transitions preserve deterministic action ordering"
	)
	_assert_equal(legal_transitions[0].state.action_log.size(), 1, "legal transitions include their resolved state")
	_assert_equal(state.action_log.size(), 0, "legal-transition generation does not mutate its input state")


func _fixture_state(width: int, height: int):
	var map_definition = MapDefinition.rectangular(width, height, true)
	return engine.new_game(map_definition)


func _add_anchor(
	state,
	id: int,
	player: RuleTypes.Player,
	cell: Vector2i,
	is_active: bool = true,
	deployed_turn: int = 0,
	hp: int = 3
) -> void:
	var anchor = Anchor.new(id, player, cell, deployed_turn, id)
	anchor.is_active = is_active
	anchor.hp = hp
	state.anchors[id] = anchor
	state.next_anchor_id = maxi(state.next_anchor_id, id + 1)
	state.anchors_deployed[player] += 1


func _add_piece(
	state,
	id: int,
	player: RuleTypes.Player,
	type: RuleTypes.BoardPieceType,
	cell: Vector2i,
	main_anchor_id: int,
	hp: int = 2,
	is_mature: bool = true,
	deployed_turn: int = 0
) -> void:
	var board_piece = BoardPiece.new(id, player, type, cell, main_anchor_id, deployed_turn)
	board_piece.hp = hp
	board_piece.is_mature = is_mature
	state.board_pieces[id] = board_piece
	state.next_board_piece_id = maxi(state.next_board_piece_id, id + 1)


func _has_event(events: Array[Dictionary], event_type: String, expected_fields: Dictionary = {}) -> bool:
	for event: Dictionary in events:
		if event.get("type", "") != event_type:
			continue
		var matches := true
		for field: Variant in expected_fields:
			if event.get(field) != expected_fields[field]:
				matches = false
				break
		if matches:
			return true
	return false


func _assert_true(condition: bool, message: String) -> void:
	assertion_count += 1
	if not condition:
		failures.append(message)


func _assert_false(condition: bool, message: String) -> void:
	_assert_true(not condition, message)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	assertion_count += 1
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
