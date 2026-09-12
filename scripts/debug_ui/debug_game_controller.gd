## Local two-player interaction controller that submits only engine-approved actions.
class_name AnchorDebugGameController
extends Node3D

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")
const GameplayAction = preload("res://scripts/gameplay/gameplay_action.gd")
const RulesEngine = preload("res://scripts/gameplay/rules_engine.gd")

enum Mode {
	NONE,
	PLACEMENT,
	MOVEMENT,
	ACTION,
}

const PLACEMENT_NONE := -2
const PLACE_ANCHOR := -1

@onready var camera: Camera3D = $Camera3D
@onready var board_view: AnchorDebugBoardView = $BoardView
@onready var hud: AnchorDebugHud = $DebugHud

var rules_engine := RulesEngine.new()
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


func _ready() -> void:
	var camera_target := Vector3(camera.position.x, 0.0, camera.position.z)
	camera.look_at(camera_target, Vector3(0.0, 0.0, -1.0))
	hud.mode_requested.connect(_on_mode_requested)
	hud.placement_requested.connect(_on_placement_requested)
	hud.end_turn_requested.connect(_on_end_turn_requested)
	hud.pass_requested.connect(_on_pass_requested)
	hud.restart_requested.connect(restart_match)
	restart_match()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		restart_match()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell := board_view.pick_cell(camera, event.position)
		if cell.x >= 0:
			_handle_cell_click(cell)
			get_viewport().set_input_as_handled()


func restart_match() -> void:
	game_state = rules_engine.new_game()
	mode = Mode.NONE
	placement_choice = PLACEMENT_NONE
	selected_entity.clear()
	selected_main_anchor_id = 0
	status_message = "New local match. Black moves first. Choose Placement or Pass."
	_refresh_all()


func _on_mode_requested(requested_mode: int) -> void:
	if game_state.is_game_over:
		return
	mode = requested_mode as Mode
	placement_choice = PLACEMENT_NONE
	selected_entity.clear()
	selected_main_anchor_id = 0
	match mode:
		Mode.PLACEMENT:
			status_message = "Choose Anchor, O BoardPiece, or D BoardPiece."
		Mode.MOVEMENT:
			status_message = "Select a highlighted movable entity."
		Mode.ACTION:
			status_message = "Select a highlighted attacker or inactive Anchor."
	_rebuild_interaction()


func _on_placement_requested(requested_type: int) -> void:
	if game_state.is_game_over:
		return
	mode = Mode.PLACEMENT
	placement_choice = requested_type
	selected_entity.clear()
	selected_main_anchor_id = 0
	status_message = "Choose a highlighted placement cell." if requested_type == PLACE_ANCHOR else "Choose a highlighted physical Main Anchor first."
	_rebuild_interaction()


func _on_end_turn_requested() -> void:
	if game_state.categories_used.is_empty():
		_set_feedback("Use Pass when taking no actions.")
		return
	_submit_action(_legal_end_turn_action())


func _on_pass_requested() -> void:
	if not game_state.categories_used.is_empty():
		_set_feedback("Pass is available only before using an action category.")
		return
	_submit_action(_legal_end_turn_action())


func _handle_cell_click(cell: Vector2i) -> void:
	if game_state.is_game_over:
		return
	match mode:
		Mode.PLACEMENT:
			_handle_placement_click(cell)
		Mode.MOVEMENT:
			_handle_movement_click(cell)
		Mode.ACTION:
			_handle_action_click(cell)
		_:
			_inspect_cell(cell)


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
	board_view.refresh_from_state(game_state, cell_highlights, selected_entity)
	hud.set_active_mode(mode as AnchorDebugHud.Mode)
	hud.refresh(game_state, legal_actions, status_message)


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


func _submit_action(action) -> void:
	if action == null:
		_set_feedback("No legal turn transition is available.")
		return
	var acting_player := _player_name(game_state.current_player)
	var was_pass: bool = action.kind == GameplayAction.Kind.END_TURN and game_state.categories_used.is_empty()
	var result = rules_engine.apply_action(game_state, action)
	if not result.success:
		_set_feedback("Engine rejected action: %s" % result.error)
		return
	game_state = result.state
	mode = Mode.NONE
	placement_choice = PLACEMENT_NONE
	selected_entity.clear()
	selected_main_anchor_id = 0
	if game_state.is_game_over:
		status_message = "Game over after consecutive passes."
	elif action.kind == GameplayAction.Kind.END_TURN:
		status_message = "%s passed." % acting_player if was_pass else "%s ended the turn." % acting_player
	else:
		status_message = "%s resolved successfully." % _action_name(action)
	_refresh_all()


func _refresh_all() -> void:
	legal_actions = rules_engine.get_legal_actions(game_state)
	cell_actions.clear()
	source_actions.clear()
	legal_main_anchor_ids.clear()
	cell_highlights.clear()
	board_view.refresh_from_state(game_state, cell_highlights, selected_entity)
	hud.set_active_mode(mode as AnchorDebugHud.Mode)
	hud.refresh(game_state, legal_actions, status_message)
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
	board_view.refresh_from_state(game_state, cell_highlights, selected_entity)
	hud.refresh(game_state, legal_actions, status_message)


func _inspect_or_reject(cell: Vector2i, message: String) -> void:
	var entity: Dictionary = game_state.entity_at(cell)
	if not entity.is_empty():
		selected_entity = entity
		_show_selected_debug()
	status_message = "Illegal click: %s" % message
	board_view.refresh_from_state(game_state, cell_highlights, selected_entity)
	hud.refresh(game_state, legal_actions, status_message)


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


func _set_feedback(message: String) -> void:
	status_message = message
	hud.refresh(game_state, legal_actions, status_message)


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
