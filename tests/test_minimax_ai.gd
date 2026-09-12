## Focused deterministic tests for the presentation-free minimax player.
extends RefCounted

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")
const MapDefinition = preload("res://scripts/gameplay/map_definition.gd")
const Anchor = preload("res://scripts/gameplay/anchor_state.gd")
const BoardPiece = preload("res://scripts/gameplay/board_piece_state.gd")
const GameplayAction = preload("res://scripts/gameplay/gameplay_action.gd")
const RulesEngine = preload("res://scripts/gameplay/rules_engine.gd")
const MinimaxAi = preload("res://scripts/ai/minimax_ai.gd")

var engine := RulesEngine.new()
var ai := MinimaxAi.new(engine, 2, 16)
var failures: Array[String] = []
var assertion_count := 0


func run_all() -> bool:
	test_deterministic_legal_opening()
	test_immediate_material_win_is_preferred()
	test_only_legal_turn_transition_is_returned()
	test_coordinates_have_no_intrinsic_value()
	test_rule_connections_improve_evaluation()
	test_headless_ai_sequence_is_reproducible()
	if failures.is_empty():
		print("PASS: %d minimax-AI assertions" % assertion_count)
		return true
	for failure: String in failures:
		push_error(failure)
	print("FAIL: %d AI failures across %d assertions" % [failures.size(), assertion_count])
	return false


func test_deterministic_legal_opening() -> void:
	var state = engine.new_game(null, 17)
	var original_hash := engine.state_hash(state)
	var first_action = ai.choose_action(state)
	var repeated_action = ai.choose_action(state.duplicate_state())
	_assert_true(first_action != null, "AI returns an opening action")
	_assert_equal(first_action.to_dictionary(), repeated_action.to_dictionary(), "identical states produce the same action")
	_assert_equal(engine.state_hash(state), original_hash, "search does not mutate its input state")
	_assert_equal(state.action_log.size(), 0, "search simulations do not leak into the input action log")
	_assert_true(engine.apply_action(state, first_action).success, "chosen opening action is accepted by the rules engine")
	_assert_equal(first_action.kind, GameplayAction.Kind.PLACE_ANCHOR, "heuristic AI establishes a Main Anchor instead of opening with Pass")


func test_immediate_material_win_is_preferred() -> void:
	var state = engine.new_game(MapDefinition.rectangular(5, 3, true))
	_add_anchor(state, 1, RuleTypes.Player.BLACK, Vector2i(0, 1))
	_add_piece(state, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(1, 1), 1)
	_add_anchor(state, 2, RuleTypes.Player.WHITE, Vector2i(3, 1), 2)
	_add_piece(state, 2, RuleTypes.Player.WHITE, RuleTypes.BoardPieceType.DIAGONAL, Vector2i(4, 1), 2)
	state.categories_used.append(RuleTypes.ActionCategory.PLACEMENT)
	state.seen_state_hashes[engine.state_hash(state)] = true
	var action = ai.choose_action(state)
	_assert_equal(action.kind, GameplayAction.Kind.ATTACK, "minimax prefers destroying an exposed Main Anchor and its bound BoardPiece")
	var result = engine.apply_action(state, action)
	_assert_true(result.success, "preferred attack remains an exact legal engine action")
	_assert_false(result.state.anchors.has(2), "chosen attack removes the exposed enemy Main Anchor")
	_assert_false(result.state.board_pieces.has(2), "chosen attack receives the engine's Main Anchor death cascade")


func test_only_legal_turn_transition_is_returned() -> void:
	var state = engine.new_game()
	state.categories_used.append(RuleTypes.ActionCategory.PLACEMENT)
	state.categories_used.append(RuleTypes.ActionCategory.MOVEMENT)
	state.seen_state_hashes[engine.state_hash(state)] = true
	var action = ai.choose_action(state)
	_assert_equal(action.kind, GameplayAction.Kind.END_TURN, "AI returns End Turn when it is the only legal action")
	_assert_true(engine.apply_action(state, action).success, "forced AI turn transition is engine-approved")


func test_coordinates_have_no_intrinsic_value() -> void:
	var off_center = engine.new_game(MapDefinition.rectangular(7, 7, true))
	_add_anchor(off_center, 1, RuleTypes.Player.BLACK, Vector2i(1, 1))
	var center = engine.new_game(MapDefinition.rectangular(7, 7, true))
	_add_anchor(center, 1, RuleTypes.Player.BLACK, Vector2i(3, 3))
	_assert_equal(
		ai.evaluate_state(off_center, RuleTypes.Player.BLACK),
		ai.evaluate_state(center, RuleTypes.Player.BLACK),
		"equally free cells have equal value regardless of distance from board center"
	)


func test_rule_connections_improve_evaluation() -> void:
	var unit_chain = engine.new_game(MapDefinition.rectangular(5, 3, true))
	_add_anchor(unit_chain, 1, RuleTypes.Player.BLACK, Vector2i(0, 1))
	_add_piece(unit_chain, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(1, 1), 1)
	var empty_supply_path = engine.new_game(MapDefinition.rectangular(5, 3, true))
	_add_anchor(empty_supply_path, 1, RuleTypes.Player.BLACK, Vector2i(0, 1))
	_add_piece(empty_supply_path, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(2, 1), 1)
	_assert_true(engine.compute_supply(empty_supply_path, 1), "comparison BoardPiece has Supply through empty terrain")
	_assert_false(engine.compute_unit_chain_connection(empty_supply_path, 1), "empty Supply path does not grant damage reduction")
	_assert_true(engine.compute_unit_chain_connection(unit_chain, 1), "adjacent friendly chain grants engine damage reduction")
	_assert_true(
		ai.evaluate_state(unit_chain, RuleTypes.Player.BLACK) > ai.evaluate_state(empty_supply_path, RuleTypes.Player.BLACK),
		"AI values Main Anchor unit-chain damage reduction"
	)

	var dual_protected = engine.new_game(MapDefinition.rectangular(5, 3, true))
	_add_anchor(dual_protected, 1, RuleTypes.Player.BLACK, Vector2i(0, 1))
	_add_piece(dual_protected, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(1, 1), 1)
	_add_anchor(dual_protected, 2, RuleTypes.Player.BLACK, Vector2i(2, 1))
	var secondary_disconnected = engine.new_game(MapDefinition.rectangular(5, 3, true))
	_add_anchor(secondary_disconnected, 1, RuleTypes.Player.BLACK, Vector2i(0, 1))
	_add_piece(secondary_disconnected, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(1, 1), 1)
	_add_anchor(secondary_disconnected, 2, RuleTypes.Player.BLACK, Vector2i(4, 1))
	_assert_true(engine.has_dual_anchor_protection(dual_protected, 1), "connected distinct active Anchor Cluster grants protection")
	_assert_false(engine.has_dual_anchor_protection(secondary_disconnected, 1), "disconnected Anchor Cluster grants no protection")
	_assert_true(
		ai.evaluate_state(dual_protected, RuleTypes.Player.BLACK) > ai.evaluate_state(secondary_disconnected, RuleTypes.Player.BLACK),
		"AI values valid dual-Anchor protection"
	)


func test_headless_ai_sequence_is_reproducible() -> void:
	var first_sequence := _simulate_actions(23, 6)
	var second_sequence := _simulate_actions(23, 6)
	_assert_equal(first_sequence, second_sequence, "headless AI-vs-AI action sequences are deterministic")
	_assert_equal(first_sequence.size(), 6, "headless AI can drive successive turns without any scene or UI")


func _simulate_actions(seed: int, action_count: int) -> Array[Dictionary]:
	var state = engine.new_game(null, seed)
	var actions: Array[Dictionary] = []
	for _index in range(action_count):
		if state.is_game_over:
			break
		var action = ai.choose_action(state)
		if action == null:
			break
		var result = engine.apply_action(state, action)
		if not result.success:
			break
		actions.append(action.to_dictionary())
		state = result.state
	return actions


func _add_anchor(state, id: int, player: RuleTypes.Player, cell: Vector2i, hp: int = 3) -> void:
	var anchor = Anchor.new(id, player, cell, 0, id)
	anchor.is_active = true
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
	main_anchor_id: int
) -> void:
	var board_piece = BoardPiece.new(id, player, type, cell, main_anchor_id, 0)
	board_piece.is_mature = true
	state.board_pieces[id] = board_piece
	state.next_board_piece_id = maxi(state.next_board_piece_id, id + 1)


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
