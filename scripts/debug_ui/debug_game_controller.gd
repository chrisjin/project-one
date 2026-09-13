## Local human/AI match controller that submits only engine-approved actions.
class_name AnchorDebugGameController
extends Node3D

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")
const GameplayAction = preload("res://scripts/gameplay/gameplay_action.gd")
const CoreRuleSet = preload("res://scripts/gameplay/core_rule_set.gd")
const RulesEngine = preload("res://scripts/gameplay/rules_engine.gd")
const MinimaxAi = preload("res://scripts/ai/minimax_ai.gd")

const AI_ACTION_DELAY_SECONDS := 0.18

enum Mode {
	NONE,
	PLACEMENT,
	MOVEMENT,
	ACTION,
}

enum ContextOption {
	BOARD_PIECE_MOVE = 1,
	BOARD_PIECE_ACTION,
	BOARD_PIECE_ATTACK,
	ANCHOR_MOVE,
	ANCHOR_PLACEMENT,
	PLACE_ANCHOR,
	PLACE_O_BOARD_PIECE,
	PLACE_D_BOARD_PIECE,
}

enum MatchMode {
	HUMAN_VS_HUMAN,
	HUMAN_VS_AI,
	HUMAN_VS_AI_AS_WHITE,
	AI_VS_AI,
}

const PLACEMENT_NONE := -2
const PLACE_ANCHOR := -1
const MAIN_ANCHOR_OPTION_BASE := 1000

@onready var camera: Camera3D = $Camera3D
@onready var board_view: AnchorDebugBoardView = $BoardView
@onready var hud: AnchorDebugHud = $DebugHud

var rule_set := CoreRuleSet.new()
var rules_engine := RulesEngine.new(rule_set)
var minimax_ai
var game_state
var legal_actions: Array = []
var mode: Mode = Mode.NONE
var placement_choice: int = PLACEMENT_NONE
var selected_entity: Dictionary = {}
var selected_main_anchor_id := 0
var cell_actions: Dictionary = {}
var source_actions: Dictionary = {}
var legal_main_anchor_ids: Dictionary = {}
var cell_highlights: Dictionary = {}
var status_message := ""
var context_cell := Vector2i(-1, -1)
var context_entity: Dictionary = {}
var context_screen_position := Vector2.ZERO
var context_action_options: Dictionary = {}
var match_mode: MatchMode = MatchMode.HUMAN_VS_HUMAN
var match_started := false
var _ai_running := false
var _ai_generation := 0


func _ready() -> void:
	minimax_ai = MinimaxAi.new(rule_set)
	var camera_target := Vector3(camera.position.x, 0.0, camera.position.z)
	camera.look_at(camera_target, Vector3(0.0, 0.0, -1.0))
	hud.mode_requested.connect(_on_mode_requested)
	hud.placement_requested.connect(_on_placement_requested)
	hud.end_turn_requested.connect(_on_end_turn_requested)
	hud.pass_requested.connect(_on_pass_requested)
	hud.restart_requested.connect(_show_match_setup)
	hud.context_option_requested.connect(_on_context_option_requested)
	hud.match_mode_requested.connect(_start_match)
	restart_match()
	_show_match_setup()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_show_match_setup()
		get_viewport().set_input_as_handled()
		return
	if not _can_accept_human_input():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell := board_view.pick_cell(camera, event.position)
		if cell.x >= 0:
			_handle_cell_click(cell, event.position)
			get_viewport().set_input_as_handled()


func restart_match() -> void:
	_ai_generation += 1
	_ai_running = false
	game_state = rules_engine.new_game()
	mode = Mode.NONE
	placement_choice = PLACEMENT_NONE
	selected_entity.clear()
	selected_main_anchor_id = 0
	_clear_context()
	status_message = "New %s match. Black moves first." % _match_mode_name()
	hud.set_match_mode_text(_match_mode_summary())
	_refresh_all()
	_schedule_ai_turn_if_needed()


func _start_match(requested_mode: int) -> void:
	match_mode = requested_mode as MatchMode
	match_started = true
	hud.hide_match_setup()
	restart_match()


func _show_match_setup() -> void:
	_ai_generation += 1
	_ai_running = false
	match_started = false
	mode = Mode.NONE
	placement_choice = PLACEMENT_NONE
	selected_entity.clear()
	selected_main_anchor_id = 0
	_clear_context()
	status_message = "Choose Human vs Human, either Human vs AI side, or AI vs AI."
	hud.set_match_mode_text("Choose match mode")
	_refresh_all()
	hud.show_match_setup()


func _on_mode_requested(requested_mode: int) -> void:
	if game_state.is_game_over or not _can_accept_human_input():
		return
	mode = requested_mode as Mode
	placement_choice = PLACEMENT_NONE
	selected_entity.clear()
	selected_main_anchor_id = 0
	_clear_context()
	match mode:
		Mode.PLACEMENT:
			status_message = "Choose Anchor, O BoardPiece, or D BoardPiece."
		Mode.MOVEMENT:
			status_message = "Select a highlighted movable entity."
		Mode.ACTION:
			status_message = "Select a highlighted attacker or inactive Anchor."
	_rebuild_interaction()


func _on_placement_requested(requested_type: int) -> void:
	if game_state.is_game_over or not _can_accept_human_input():
		return
	mode = Mode.PLACEMENT
	placement_choice = requested_type
	selected_entity.clear()
	selected_main_anchor_id = 0
	_clear_context()
	status_message = "Choose a highlighted placement cell." if requested_type == PLACE_ANCHOR else "Choose a highlighted physical Main Anchor first."
	_rebuild_interaction()


func _on_end_turn_requested() -> void:
	if not _can_accept_human_input():
		return
	if game_state.categories_used.is_empty():
		_set_feedback("Use Pass when taking no actions.")
		return
	_submit_action(_legal_end_turn_action())


func _on_pass_requested() -> void:
	if not _can_accept_human_input():
		return
	if not game_state.categories_used.is_empty():
		_set_feedback("Pass is available only before using an action category.")
		return
	_submit_action(_legal_end_turn_action())


func _handle_cell_click(cell: Vector2i, screen_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if game_state.is_game_over or not _can_accept_human_input():
		return
	if _should_open_context_for_different_entity(cell):
		_exit_active_interaction()
		_open_context_for_cell(cell, screen_position)
		return
	match mode:
		Mode.PLACEMENT:
			_handle_placement_click(cell)
		Mode.MOVEMENT:
			_handle_movement_click(cell)
		Mode.ACTION:
			_handle_action_click(cell)
		_:
			_open_context_for_cell(cell, screen_position)


func _should_open_context_for_different_entity(cell: Vector2i) -> bool:
	if mode == Mode.NONE or selected_entity.is_empty() or cell_actions.has(cell):
		return false
	var clicked_entity: Dictionary = game_state.entity_at(cell)
	return not clicked_entity.is_empty() \
		and _entity_key(clicked_entity) != _entity_key(selected_entity)


func _exit_active_interaction() -> void:
	mode = Mode.NONE
	placement_choice = PLACEMENT_NONE
	selected_entity.clear()
	selected_main_anchor_id = 0
	cell_actions.clear()
	source_actions.clear()
	legal_main_anchor_ids.clear()
	cell_highlights.clear()
	_clear_context()
	hud.set_active_mode(AnchorDebugHud.Mode.NONE)


func _open_context_for_cell(cell: Vector2i, screen_position: Vector2) -> void:
	context_cell = cell
	context_entity = game_state.entity_at(cell)
	context_screen_position = _context_position(cell, screen_position)
	context_action_options.clear()
	_inspect_cell(cell)
	if context_entity.is_empty():
		hud.show_context_menu("Place at %s" % _cell_name(cell), [
			_context_item(ContextOption.PLACE_ANCHOR, "Anchor", _has_anchor_placement_at(cell)),
			_context_item(ContextOption.PLACE_O_BOARD_PIECE, "O BoardPiece", _has_board_piece_placement_at(cell, RuleTypes.BoardPieceType.ORTHOGONAL)),
			_context_item(ContextOption.PLACE_D_BOARD_PIECE, "D BoardPiece", _has_board_piece_placement_at(cell, RuleTypes.BoardPieceType.DIAGONAL)),
		], context_screen_position)
		return
	if game_state.entity_player(context_entity) != game_state.current_player:
		hud.hide_context_menu()
		return
	if context_entity.kind == RuleTypes.EntityKind.BOARD_PIECE:
		hud.show_context_menu("BoardPiece #%d" % context_entity.id, [
			_context_item(ContextOption.BOARD_PIECE_MOVE, "Move", _has_source_action(context_entity, GameplayAction.Kind.MOVE)),
			_context_item(ContextOption.BOARD_PIECE_ACTION, "Action", _has_source_action(context_entity, GameplayAction.Kind.ATTACK)),
		], context_screen_position)
		return
	var anchor_items: Array[Dictionary] = [
		_context_item(ContextOption.ANCHOR_MOVE, "Move", _has_source_action(context_entity, GameplayAction.Kind.MOVE)),
	]
	if _anchor_has_binding_slot(context_entity.id):
		anchor_items.append(_context_item(
			ContextOption.ANCHOR_PLACEMENT,
			"Placement",
			_has_anchor_board_piece_placement(context_entity.id)
		))
	hud.show_context_menu("Anchor #%d" % context_entity.id, anchor_items, context_screen_position)


func _on_context_option_requested(option_id: int) -> void:
	if game_state.is_game_over or not _can_accept_human_input():
		return
	if context_action_options.has(option_id):
		_submit_action(context_action_options[option_id])
		return
	match option_id:
		ContextOption.BOARD_PIECE_MOVE, ContextOption.ANCHOR_MOVE:
			_begin_context_entity_mode(Mode.MOVEMENT, "Choose a highlighted movement destination.")
		ContextOption.BOARD_PIECE_ACTION:
			hud.show_context_menu("Action", [
				_context_item(ContextOption.BOARD_PIECE_ATTACK, "Attack", _has_source_action(context_entity, GameplayAction.Kind.ATTACK)),
			], context_screen_position)
		ContextOption.BOARD_PIECE_ATTACK:
			_begin_context_entity_mode(Mode.ACTION, "Choose a highlighted attack target.")
		ContextOption.ANCHOR_PLACEMENT:
			hud.show_context_menu("Place from Anchor #%d" % context_entity.id, [
				_context_item(ContextOption.PLACE_O_BOARD_PIECE, "O BoardPiece", _has_anchor_board_piece_placement(context_entity.id, RuleTypes.BoardPieceType.ORTHOGONAL)),
				_context_item(ContextOption.PLACE_D_BOARD_PIECE, "D BoardPiece", _has_anchor_board_piece_placement(context_entity.id, RuleTypes.BoardPieceType.DIAGONAL)),
			], context_screen_position)
		ContextOption.PLACE_ANCHOR:
			_submit_action(_anchor_placement_at(context_cell))
		ContextOption.PLACE_O_BOARD_PIECE:
			_begin_context_placement(RuleTypes.BoardPieceType.ORTHOGONAL)
		ContextOption.PLACE_D_BOARD_PIECE:
			_begin_context_placement(RuleTypes.BoardPieceType.DIAGONAL)


func _begin_context_entity_mode(requested_mode: Mode, message: String) -> void:
	mode = requested_mode
	placement_choice = PLACEMENT_NONE
	selected_entity = context_entity.duplicate()
	selected_main_anchor_id = 0
	hud.hide_context_menu()
	status_message = message
	_show_selected_debug()
	_rebuild_interaction()


func _begin_context_placement(board_piece_type: RuleTypes.BoardPieceType) -> void:
	if not context_entity.is_empty() and context_entity.kind == RuleTypes.EntityKind.ANCHOR:
		mode = Mode.PLACEMENT
		placement_choice = board_piece_type
		selected_entity = context_entity.duplicate()
		selected_main_anchor_id = context_entity.id
		hud.hide_context_menu()
		status_message = "Choose a highlighted destination for Anchor #%d." % selected_main_anchor_id
		_show_selected_debug()
		_rebuild_interaction()
		return
	_show_main_anchor_menu(board_piece_type)


func _show_main_anchor_menu(board_piece_type: RuleTypes.BoardPieceType) -> void:
	context_action_options.clear()
	var items: Array[Dictionary] = []
	var option_id := MAIN_ANCHOR_OPTION_BASE
	for action in legal_actions:
		if action.kind != GameplayAction.Kind.PLACE_BOARD_PIECE:
			continue
		if action.cell != context_cell or action.board_piece_type != board_piece_type:
			continue
		context_action_options[option_id] = action
		items.append(_context_item(option_id, "Main Anchor #%d" % action.main_anchor_id, true))
		option_id += 1
	if items.is_empty():
		_set_feedback("No engine-approved Main Anchor can place there.")
		hud.hide_context_menu()
		return
	hud.show_context_menu("Choose Main Anchor", items, context_screen_position)


func _handle_placement_click(cell: Vector2i) -> void:
	if placement_choice == PLACEMENT_NONE:
		_inspect_or_reject(cell, "Choose Anchor, O BoardPiece, or D BoardPiece first.")
		return
	if placement_choice == PLACE_ANCHOR:
		if cell_actions.has(cell):
			_submit_action(cell_actions[cell])
		else:
			_inspect_or_reject(cell, "That cell is not an engine-approved Anchor placement.")
		return
	if selected_main_anchor_id == 0:
		var entity: Dictionary = game_state.entity_at(cell)
		if not entity.is_empty() and entity.kind == RuleTypes.EntityKind.ANCHOR and legal_main_anchor_ids.has(entity.id):
			selected_main_anchor_id = entity.id
			selected_entity = entity
			status_message = "Main Anchor A%d selected. Choose a highlighted destination." % entity.id
			_show_selected_debug()
			_rebuild_interaction()
		else:
			_inspect_or_reject(cell, "Select one of the highlighted physical Main Anchors.")
		return
	if cell_actions.has(cell):
		_submit_action(cell_actions[cell])
	else:
		_inspect_or_reject(cell, "That destination is not legal for the selected Main Anchor.")


func _handle_movement_click(cell: Vector2i) -> void:
	if not selected_entity.is_empty() and cell_actions.has(cell):
		_submit_action(cell_actions[cell])
		return
	var entity: Dictionary = game_state.entity_at(cell)
	var key: String = _entity_key(entity)
	if not entity.is_empty() and source_actions.has(key):
		selected_entity = entity
		status_message = "Entity selected. Choose a highlighted movement destination."
		_show_selected_debug()
		_rebuild_interaction()
	else:
		_inspect_or_reject(cell, "Select a highlighted movable entity or legal destination.")


func _handle_action_click(cell: Vector2i) -> void:
	if not selected_entity.is_empty() and cell_actions.has(cell):
		_submit_action(cell_actions[cell])
		return
	var entity: Dictionary = game_state.entity_at(cell)
	var key: String = _entity_key(entity)
	if not entity.is_empty() and source_actions.has(key):
		var actions: Array = source_actions[key]
		if actions.size() == 1 and actions[0].kind == GameplayAction.Kind.RAPID_ACTIVATION:
			_submit_action(actions[0])
			return
		selected_entity = entity
		status_message = "Attacker selected. Choose a highlighted enemy target."
		_show_selected_debug()
		_rebuild_interaction()
	else:
		_inspect_or_reject(cell, "Select a highlighted attacker, Rapid Activation target, or attack target.")


func _rebuild_interaction() -> void:
	cell_actions.clear()
	source_actions.clear()
	legal_main_anchor_ids.clear()
	cell_highlights.clear()
	match mode:
		Mode.PLACEMENT:
			_build_placement_interaction()
		Mode.MOVEMENT:
			_build_movement_interaction()
		Mode.ACTION:
			_build_action_interaction()
	_refresh_board_view()
	hud.set_active_mode(mode as AnchorDebugHud.Mode)
	hud.refresh(game_state, legal_actions, status_message, _can_accept_human_input())


func _build_placement_interaction() -> void:
	if placement_choice == PLACEMENT_NONE:
		return
	for action in legal_actions:
		if placement_choice == PLACE_ANCHOR:
			if action.kind == GameplayAction.Kind.PLACE_ANCHOR:
				cell_actions[action.cell] = action
				cell_highlights[action.cell] = "placement"
			continue
		if action.kind != GameplayAction.Kind.PLACE_BOARD_PIECE or action.board_piece_type != placement_choice:
			continue
		if selected_main_anchor_id == 0:
			legal_main_anchor_ids[action.main_anchor_id] = true
			cell_highlights[game_state.anchors[action.main_anchor_id].cell] = "anchor_choice"
		elif action.main_anchor_id == selected_main_anchor_id:
			cell_actions[action.cell] = action
			cell_highlights[action.cell] = "placement"


func _build_movement_interaction() -> void:
	for action in legal_actions:
		if action.kind != GameplayAction.Kind.MOVE:
			continue
		var entity := {"kind": action.entity_kind, "id": action.entity_id}
		var key := _entity_key(entity)
		if not source_actions.has(key):
			source_actions[key] = []
		source_actions[key].append(action)
		if selected_entity.is_empty():
			cell_highlights[game_state.entity_cell(entity)] = "source"
		elif key == _entity_key(selected_entity):
			cell_actions[action.cell] = action
			cell_highlights[action.cell] = "movement"


func _build_action_interaction() -> void:
	for action in legal_actions:
		var entity: Dictionary
		if action.kind == GameplayAction.Kind.ATTACK:
			entity = {"kind": RuleTypes.EntityKind.BOARD_PIECE, "id": action.entity_id}
		elif action.kind == GameplayAction.Kind.RAPID_ACTIVATION:
			entity = {"kind": RuleTypes.EntityKind.ANCHOR, "id": action.entity_id}
		else:
			continue
		var key := _entity_key(entity)
		if not source_actions.has(key):
			source_actions[key] = []
		source_actions[key].append(action)
		if selected_entity.is_empty():
			cell_highlights[game_state.entity_cell(entity)] = "source"
		elif key == _entity_key(selected_entity) and action.kind == GameplayAction.Kind.ATTACK:
			var ray := rules_engine.trace_ray(game_state, action.entity_id, action.direction)
			if not ray.target.is_empty():
				var target_cell: Vector2i = game_state.entity_cell(ray.target)
				cell_actions[target_cell] = action
				cell_highlights[target_cell] = "attack"


func _submit_action(action, is_ai_action: bool = false) -> bool:
	if action == null:
		_set_feedback("No legal turn transition is available.")
		return false
	var acting_player := _player_name(game_state.current_player)
	var actor_label := "%s AI" % acting_player if is_ai_action else acting_player
	var was_pass: bool = action.kind == GameplayAction.Kind.END_TURN and game_state.categories_used.is_empty()
	var result = rules_engine.apply_action(game_state, action)
	if not result.success:
		_set_feedback("Engine rejected action: %s" % result.error)
		return false
	game_state = result.state
	var automatically_ended_turn := _has_automatic_turn_end_event(result.events)
	mode = Mode.NONE
	placement_choice = PLACEMENT_NONE
	selected_entity.clear()
	selected_main_anchor_id = 0
	_clear_context()
	if game_state.is_game_over:
		status_message = "Game over after consecutive passes."
	elif action.kind == GameplayAction.Kind.END_TURN:
		status_message = "%s passed." % actor_label if was_pass else "%s ended the turn." % actor_label
	elif automatically_ended_turn:
		status_message = "%s: %s resolved; the turn ended automatically." % [actor_label, _action_name(action)]
	else:
		status_message = "%s: %s resolved." % [actor_label, _action_name(action)]
	_refresh_all()
	if not is_ai_action:
		_schedule_ai_turn_if_needed()
	return true


func _refresh_all() -> void:
	legal_actions = rules_engine.get_legal_actions(game_state)
	cell_actions.clear()
	source_actions.clear()
	legal_main_anchor_ids.clear()
	cell_highlights.clear()
	_refresh_board_view()
	hud.set_active_mode(mode as AnchorDebugHud.Mode)
	hud.refresh(game_state, legal_actions, status_message, _can_accept_human_input())
	if game_state.is_game_over:
		hud.hide_context_menu()
	if selected_entity.is_empty():
		hud.clear_entity_debug()


func _inspect_cell(cell: Vector2i) -> void:
	var entity: Dictionary = game_state.entity_at(cell)
	if entity.is_empty():
		selected_entity.clear()
		status_message = "Cell %s is empty." % _cell_name(cell)
		hud.clear_entity_debug()
	else:
		selected_entity = entity
		status_message = "Inspecting %s." % _cell_name(cell)
		_show_selected_debug()
	_refresh_board_view()
	hud.refresh(game_state, legal_actions, status_message, _can_accept_human_input())


func _inspect_or_reject(cell: Vector2i, message: String) -> void:
	var entity: Dictionary = game_state.entity_at(cell)
	if not entity.is_empty():
		selected_entity = entity
		_show_selected_debug()
	status_message = "Illegal click: %s" % message
	_refresh_board_view()
	hud.refresh(game_state, legal_actions, status_message, _can_accept_human_input())


func _selected_binding_visual() -> Dictionary:
	# Binding membership comes from engine diagnostics; the board only draws the supplied IDs.
	if selected_entity.is_empty():
		return {}
	var anchor_id: int
	if selected_entity.kind == RuleTypes.EntityKind.ANCHOR:
		anchor_id = selected_entity.id
	else:
		var board_piece_data: Dictionary = rules_engine.board_piece_debug(game_state, selected_entity.id)
		anchor_id = int(board_piece_data.get("main_anchor_id", 0))
	var anchor_data: Dictionary = rules_engine.anchor_debug(game_state, anchor_id)
	if anchor_data.is_empty():
		return {}
	return {
		"anchor_id": anchor_id,
		"board_piece_ids": anchor_data.bound_board_piece_ids.duplicate(),
	}


func _refresh_board_view() -> void:
	board_view.refresh_from_state(
		game_state,
		cell_highlights,
		selected_entity,
		_selected_binding_visual(),
		_current_player_entity_statuses()
	)


func _current_player_entity_statuses() -> Dictionary:
	# Future opportunities include immature enemies that mature before their next action window.
	var statuses: Dictionary = {}
	var perspective: RuleTypes.Player = game_state.current_player
	for opportunity: Dictionary in rules_engine.compute_attack_opportunities(
		game_state,
		RuleTypes.opponent(perspective)
	):
		var target: Dictionary = opportunity.get("target", {})
		if target.is_empty() or game_state.entity_player(target) != perspective:
			continue
		var target_key := _entity_key(target)
		if not statuses.has(target_key):
			statuses[target_key] = {}
		statuses[target_key]["attack_threat"] = true
	for board_piece_id: int in game_state.board_pieces:
		var board_piece = game_state.board_pieces[board_piece_id]
		if board_piece.player != perspective:
			continue
		var debug_data: Dictionary = rules_engine.board_piece_debug(game_state, board_piece_id)
		if not bool(debug_data.get("dual_anchor_protection", false)):
			continue
		var board_piece_key := _entity_key({
			"kind": RuleTypes.EntityKind.BOARD_PIECE,
			"id": board_piece_id,
		})
		if not statuses.has(board_piece_key):
			statuses[board_piece_key] = {}
		statuses[board_piece_key]["dual_anchor_protection"] = true
	return statuses


func _show_selected_debug() -> void:
	if selected_entity.is_empty():
		hud.clear_entity_debug()
		return
	if selected_entity.kind == RuleTypes.EntityKind.BOARD_PIECE:
		var data := rules_engine.board_piece_debug(game_state, selected_entity.id)
		var type_name := "O" if data.board_piece_type == RuleTypes.BoardPieceType.ORTHOGONAL else "D"
		hud.show_entity_debug("%s BoardPiece #%d" % [type_name, data.board_piece_id], [
			"Owner: %s" % _player_name(data.owner),
			"HP: %d" % data.hp,
			"Maturity: %s" % ("mature" if data.is_mature else "immature"),
			"Main Anchor ID: %d" % data.main_anchor_id,
			"Main Anchor alive: %s" % _yes_no(data.main_anchor_alive),
			"Supply valid: %s" % _yes_no(data.supply_valid),
			"Main unit chain: %s" % _yes_no(data.unit_chain_connected),
			"Damage reduction: %s" % _yes_no(data.damage_reduction_active),
			"Secondary clusters: %s" % str(data.secondary_anchor_cluster_ids),
			"0-HP protection: %s" % _yes_no(data.zero_hp_protection_valid),
			"Friendly group: %s" % data.friendly_group_id,
			"Liberties: %d" % data.liberty_count,
		])
	else:
		var data := rules_engine.anchor_debug(game_state, selected_entity.id)
		hud.show_entity_debug("Anchor #%d" % data.anchor_id, [
			"Owner: %s" % _player_name(data.owner),
			"HP: %d" % data.hp,
			"Activation: %s" % ("active" if data.is_active else "inactive"),
			"AnchorCluster ID: %d" % data.anchor_cluster_id,
			"Bound BoardPieces: %s" % str(data.bound_board_piece_ids),
			"Binding: %d / %d" % [data.bound_board_piece_count, data.binding_capacity],
			"Deployment index: %d" % data.deployment_index,
			"Zero liberties: %s" % _yes_no(data.zero_liberty),
			"Protected group: %s" % _yes_no(data.protected_group_membership),
		])


func _legal_end_turn_action():
	for action in legal_actions:
		if action.kind == GameplayAction.Kind.END_TURN:
			return action
	return null


func _anchor_placement_at(cell: Vector2i):
	for action in legal_actions:
		if action.kind == GameplayAction.Kind.PLACE_ANCHOR and action.cell == cell:
			return action
	return null


func _has_anchor_placement_at(cell: Vector2i) -> bool:
	return _anchor_placement_at(cell) != null


func _has_board_piece_placement_at(cell: Vector2i, board_piece_type: RuleTypes.BoardPieceType) -> bool:
	for action in legal_actions:
		if action.kind == GameplayAction.Kind.PLACE_BOARD_PIECE \
				and action.cell == cell \
				and action.board_piece_type == board_piece_type:
			return true
	return false


func _has_source_action(entity: Dictionary, action_kind: GameplayAction.Kind) -> bool:
	if entity.is_empty():
		return false
	for action in legal_actions:
		if action.kind != action_kind or action.entity_id != entity.id:
			continue
		if action.kind == GameplayAction.Kind.MOVE and action.entity_kind != entity.kind:
			continue
		return true
	return false


func _has_anchor_board_piece_placement(
	anchor_id: int,
	board_piece_type: int = PLACEMENT_NONE
) -> bool:
	for action in legal_actions:
		if action.kind != GameplayAction.Kind.PLACE_BOARD_PIECE or action.main_anchor_id != anchor_id:
			continue
		if board_piece_type == PLACEMENT_NONE or action.board_piece_type == board_piece_type:
			return true
	return false


func _anchor_has_binding_slot(anchor_id: int) -> bool:
	var debug_data: Dictionary = rules_engine.anchor_debug(game_state, anchor_id)
	return not debug_data.is_empty() \
		and debug_data.bound_board_piece_count < debug_data.binding_capacity


func _context_item(option_id: int, text: String, enabled: bool) -> Dictionary:
	return {"id": option_id, "text": text, "enabled": enabled}


func _context_position(cell: Vector2i, requested_position: Vector2) -> Vector2:
	if requested_position.x >= 0.0 and requested_position.y >= 0.0:
		return requested_position
	return camera.unproject_position(board_view.cell_to_world(cell))


func _clear_context() -> void:
	context_cell = Vector2i(-1, -1)
	context_entity.clear()
	context_action_options.clear()
	hud.hide_context_menu()


func _has_automatic_turn_end_event(events: Array[Dictionary]) -> bool:
	for event: Dictionary in events:
		if event.get("type", "") == "turn_ended" and bool(event.get("automatic", false)):
			return true
	return false


func _set_feedback(message: String) -> void:
	status_message = message
	hud.refresh(game_state, legal_actions, status_message, _can_accept_human_input())


func _schedule_ai_turn_if_needed() -> void:
	if not match_started or game_state.is_game_over or _ai_running:
		return
	if not _is_ai_player(game_state.current_player):
		return
	_ai_running = true
	var generation := _ai_generation
	status_message = "%s AI is thinking…" % _player_name(game_state.current_player)
	_refresh_all()
	call_deferred("_run_ai_actions", generation)


func _run_ai_actions(generation: int) -> void:
	await get_tree().process_frame
	while generation == _ai_generation \
			and match_started \
			and not game_state.is_game_over \
			and _is_ai_player(game_state.current_player):
		status_message = "%s AI is thinking…" % _player_name(game_state.current_player)
		_refresh_all()
		await get_tree().process_frame
		var action = minimax_ai.choose_action(game_state)
		if generation != _ai_generation or not match_started:
			return
		if action == null or not _submit_action(action, true):
			status_message = "AI could not produce an engine-approved action."
			break
		if game_state.is_game_over or not _is_ai_player(game_state.current_player):
			break
		await get_tree().create_timer(AI_ACTION_DELAY_SECONDS).timeout
	_ai_running = false
	if generation == _ai_generation:
		_refresh_all()


func _can_accept_human_input() -> bool:
	return match_started \
		and not _ai_running \
		and not game_state.is_game_over \
		and not _is_ai_player(game_state.current_player)


func _is_ai_player(player: RuleTypes.Player) -> bool:
	return match_mode == MatchMode.AI_VS_AI \
		or (match_mode == MatchMode.HUMAN_VS_AI and player == RuleTypes.Player.WHITE) \
		or (match_mode == MatchMode.HUMAN_VS_AI_AS_WHITE and player == RuleTypes.Player.BLACK)


func _match_mode_name() -> String:
	match match_mode:
		MatchMode.HUMAN_VS_AI, MatchMode.HUMAN_VS_AI_AS_WHITE:
			return "Human vs AI"
		MatchMode.AI_VS_AI:
			return "AI vs AI"
	return "Human vs Human"


func _match_mode_summary() -> String:
	if match_mode == MatchMode.HUMAN_VS_AI:
		return "Human vs AI  •  Black: Human  •  White: AI"
	if match_mode == MatchMode.HUMAN_VS_AI_AS_WHITE:
		return "Human vs AI  •  Black: AI  •  White: Human"
	if match_mode == MatchMode.AI_VS_AI:
		return "AI vs AI  •  Black: AI  •  White: AI"
	return "Human vs Human"


func _entity_key(entity: Dictionary) -> String:
	if entity.is_empty():
		return ""
	return "%d:%d" % [entity.kind, entity.id]


func _cell_name(cell: Vector2i) -> String:
	return "%s%d" % [String.chr(65 + cell.x), cell.y + 1]


func _action_name(action) -> String:
	match action.kind:
		GameplayAction.Kind.PLACE_ANCHOR:
			return "Anchor placement"
		GameplayAction.Kind.PLACE_BOARD_PIECE:
			return "BoardPiece placement"
		GameplayAction.Kind.MOVE:
			return "Movement"
		GameplayAction.Kind.ATTACK:
			return "Attack"
		GameplayAction.Kind.RAPID_ACTIVATION:
			return "Rapid Activation"
	return "Action"


func _player_name(player: RuleTypes.Player) -> String:
	return "Black" if player == RuleTypes.Player.BLACK else "White"


func _yes_no(value: bool) -> String:
	return "yes" if value else "no"
