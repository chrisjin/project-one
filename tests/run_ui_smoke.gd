## Headless smoke validation for scene wiring, grid projection, and UI-to-engine action flow.
extends SceneTree

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")
const Anchor = preload("res://scripts/gameplay/anchor_state.gd")
const BoardPiece = preload("res://scripts/gameplay/board_piece_state.gd")

var failures: Array[String] = []
var assertion_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene: PackedScene = load("res://scenes/debug_game.tscn")
	_assert_true(packed_scene != null, "debug game scene loads")
	var game = packed_scene.instantiate()
	root.add_child(game)
	await process_frame

	var board_view = game.get_node("BoardView")
	var hud = game.get_node("DebugHud")
	var camera: Camera3D = game.get_node("Camera3D")
	_assert_equal(hud.get_node("DebugCanvas").mouse_filter, Control.MOUSE_FILTER_IGNORE, "full-screen HUD layout leaves board-plane clicks unhandled")
	_assert_equal(game.game_state.map_definition.width, 7, "new UI match uses the standard board width")
	_assert_equal(game.game_state.map_definition.height, 7, "new UI match uses the standard board height")
	for y in range(7):
		for x in range(7):
			var cell := Vector2i(x, y)
			_assert_equal(board_view.world_to_cell(board_view.cell_to_world(cell)), cell, "cell/world mapping round-trips %s" % cell)
			var mouse_position := camera.unproject_position(board_view.cell_to_world(cell))
			_assert_equal(board_view.pick_cell(camera, mouse_position), cell, "camera ray picks projected cell %s" % cell)
	_assert_equal(_named_child_count(board_view.get_node("BoardGeometry"), "Cell_"), 49, "all 49 standard cells render")

	game._on_placement_requested(-1)
	_assert_equal(game.cell_actions.size(), 25, "Anchor placement highlights come from the 25 legal engine actions")
	game._handle_cell_click(Vector2i(0, 0))
	_assert_true(game.game_state.anchors.is_empty(), "illegal board click cannot submit an action through the normal UI flow")
	var board_click := InputEventMouseButton.new()
	board_click.button_index = MOUSE_BUTTON_LEFT
	board_click.pressed = true
	board_click.position = camera.unproject_position(board_view.cell_to_world(Vector2i(1, 1)))
	game._unhandled_input(board_click)
	_assert_true(game.game_state.anchors.has(1), "clicking an approved placement submits an Anchor action")
	if not game.game_state.anchors.has(1):
		_finish(game)
		return
	_assert_false(game.game_state.anchors[1].is_active, "new Anchor visualization receives inactive engine state")
	_assert_float(board_view.get_node("Entities/Anchor_1").get_child(0).scale.x, 0.74, "inactive Anchor renders at reduced scale")

	game._on_mode_requested(3)
	game._handle_cell_click(Vector2i(1, 1))
	_assert_true(game.game_state.anchors[1].is_active, "Action-mode Anchor click submits Rapid Activation")
	_assert_float(board_view.get_node("Entities/Anchor_1").get_child(0).scale.x, 1.0, "active Anchor renders at normal scale")
	game._on_end_turn_requested()
	_assert_equal(game.game_state.current_player, RuleTypes.Player.WHITE, "End Turn hands control to the other local player")
	game._on_pass_requested()
	_assert_equal(game.game_state.current_player, RuleTypes.Player.BLACK, "Pass hands control back to the first local player")

	game._on_placement_requested(RuleTypes.BoardPieceType.ORTHOGONAL)
	_assert_true(game.legal_main_anchor_ids.has(1), "BoardPiece placement exposes only an engine-approved physical Main Anchor")
	game._handle_cell_click(Vector2i(1, 1))
	_assert_equal(game.selected_main_anchor_id, 1, "Main Anchor selection remains explicit")
	game._handle_cell_click(Vector2i(2, 1))
	_assert_true(game.game_state.board_pieces.has(1), "O BoardPiece placement reaches the engine")
	_assert_equal(game.game_state.board_pieces[1].main_anchor_id, 1, "selected physical Main Anchor is preserved by the engine")
	_assert_true(hud._categories_label.text.contains("Placement"), "consumed action category is displayed")
	_assert_true(hud._placement_button.disabled, "consumed action category is visually disabled")
	game._on_mode_requested(2)
	game._handle_cell_click(Vector2i(2, 1))
	game._handle_cell_click(Vector2i(2, 2))
	_assert_equal(game.game_state.board_pieces[1].cell, Vector2i(2, 2), "movement selection submits the exact highlighted engine action")
	game._on_end_turn_requested()

	game._on_placement_requested(-1)
	game._handle_cell_click(Vector2i(5, 3))
	game._on_mode_requested(3)
	game._handle_cell_click(Vector2i(5, 3))
	game._on_end_turn_requested()
	_assert_true(game.game_state.anchors.has(2), "second local player can deploy and activate an Anchor")

	game._on_placement_requested(RuleTypes.BoardPieceType.DIAGONAL)
	game._handle_cell_click(Vector2i(1, 1))
	game._handle_cell_click(Vector2i(1, 2))
	_assert_equal(game.game_state.board_pieces[2].board_piece_type, RuleTypes.BoardPieceType.DIAGONAL, "D BoardPiece placement uses the selected engine action")
	game._on_end_turn_requested()

	game._on_placement_requested(RuleTypes.BoardPieceType.ORTHOGONAL)
	game._handle_cell_click(Vector2i(5, 3))
	game._handle_cell_click(Vector2i(4, 2))
	_assert_true(game.game_state.board_pieces.has(3), "second local player can place a bound O BoardPiece")
	game._on_end_turn_requested()
	game._on_mode_requested(3)
	game._handle_cell_click(Vector2i(2, 2))
	_assert_true(game.cell_actions.has(Vector2i(4, 2)), "attack target highlight comes from the engine ray for a legal action")
	game._handle_cell_click(Vector2i(4, 2))
	_assert_false(game.game_state.board_pieces.has(3), "clicking the highlighted attack target resolves engine damage and death")

	var zero_hp_state = game.rules_engine.new_game()
	var first_anchor = Anchor.new(1, RuleTypes.Player.BLACK, Vector2i(1, 1), 0, 1)
	first_anchor.is_active = true
	var second_anchor = Anchor.new(2, RuleTypes.Player.BLACK, Vector2i(3, 1), 0, 2)
	second_anchor.is_active = true
	var zero_hp_piece = BoardPiece.new(1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(2, 1), 1, 0)
	zero_hp_piece.is_mature = true
	zero_hp_piece.hp = 0
	zero_hp_state.anchors = {1: first_anchor, 2: second_anchor}
	zero_hp_state.board_pieces = {1: zero_hp_piece}
	zero_hp_state.anchors_deployed[RuleTypes.Player.BLACK] = 2
	game.game_state = game.rules_engine.stabilize(zero_hp_state)
	game._refresh_all()
	_assert_true(board_view.get_node_or_null("Entities/BoardPiece_1") != null, "legal 0-HP BoardPiece remains visible")
	_assert_float(board_view.get_node("Entities/BoardPiece_1").get_child(0).scale.x, 0.64, "0-HP BoardPiece has an obvious reduced-scale visualization")

	game.restart_match()
	game._on_pass_requested()
	game._on_pass_requested()
	_assert_true(game.game_state.is_game_over, "consecutive UI Pass commands expose engine game over")
	_assert_true(hud._game_over_panel.visible, "game-over score panel becomes visible")
	_assert_true(hud._game_over_label.text.contains("Black 0") and hud._game_over_label.text.contains("White 0"), "final engine scores are displayed")
	game.restart_match()
	_assert_false(game.game_state.is_game_over, "Restart creates a fresh engine state")

	_finish(game)


func _finish(game) -> void:
	game.queue_free()
	if failures.is_empty():
		print("PASS: %d debug-UI smoke assertions" % assertion_count)
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("FAIL: %d debug-UI failures across %d assertions" % [failures.size(), assertion_count])
	quit(1)


func _named_child_count(parent: Node, prefix: String) -> int:
	var count := 0
	for child: Node in parent.get_children():
		if child.name.begins_with(prefix):
			count += 1
	return count


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


func _assert_float(actual: float, expected: float, message: String) -> void:
	assertion_count += 1
	if not is_equal_approx(actual, expected):
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
