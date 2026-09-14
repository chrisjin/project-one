## Minimal local-match controls and engine-query debug output.
class_name AnchorDebugHud
extends CanvasLayer

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")
const GameplayAction = preload("res://scripts/gameplay/gameplay_action.gd")

signal mode_requested(mode: int)
signal placement_requested(board_piece_type: int)
signal end_turn_requested
signal pass_requested
signal restart_requested
signal context_option_requested(option_id: int)
signal match_mode_requested(match_mode: int)

enum Mode {
	NONE,
	PLACEMENT,
	MOVEMENT,
	ACTION,
}

enum MatchMode {
	HUMAN_VS_HUMAN,
	HUMAN_VS_AI,
	HUMAN_VS_AI_AS_WHITE,
	AI_VS_AI,
}

const PLACE_ANCHOR := -1

var _turn_label: Label
var _match_mode_label: Label
var _categories_label: Label
var _status_label: Label
var _debug_label: RichTextLabel
var _black_stats_label: Label
var _white_stats_label: Label
var _black_steps_label: RichTextLabel
var _white_steps_label: RichTextLabel
var _placement_button: Button
var _movement_button: Button
var _action_button: Button
var _anchor_button: Button
var _o_button: Button
var _d_button: Button
var _end_turn_button: Button
var _pass_button: Button
var _game_over_panel: PanelContainer
var _game_over_label: Label
var _context_panel: PanelContainer
var _context_content: VBoxContainer
var _match_setup_overlay: Control


func _ready() -> void:
	var canvas := Control.new()
	canvas.name = "DebugCanvas"
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The full-screen layout must not consume board clicks outside its visible panels.
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	_build_controls(canvas)


func refresh(
	state,
	legal_actions: Array,
	status_message: String,
	gameplay_input_enabled: bool = true,
	anchor_deployment_limit: int = 12
) -> void:
	var player_name := _player_name(state.current_player)
	_turn_label.text = "Turn %d  •  %s to play" % [state.turn_number, player_name]
	_categories_label.text = "Used: %s" % _used_categories_text(state.categories_used)
	_status_label.text = status_message
	_refresh_side_summary(state, RuleTypes.Player.BLACK, anchor_deployment_limit, _black_stats_label, _black_steps_label)
	_refresh_side_summary(state, RuleTypes.Player.WHITE, anchor_deployment_limit, _white_stats_label, _white_steps_label)

	var placement_available := _has_category_action(legal_actions, RuleTypes.ActionCategory.PLACEMENT)
	var movement_available := _has_category_action(legal_actions, RuleTypes.ActionCategory.MOVEMENT)
	var action_available := _has_category_action(legal_actions, RuleTypes.ActionCategory.ACTION)
	var input_locked: bool = state.is_game_over or not gameplay_input_enabled
	_placement_button.disabled = input_locked or not placement_available
	_movement_button.disabled = input_locked or not movement_available
	_action_button.disabled = input_locked or not action_available
	_anchor_button.disabled = input_locked or not _has_action_kind(legal_actions, GameplayAction.Kind.PLACE_ANCHOR)
	_o_button.disabled = input_locked or not _has_piece_placement(legal_actions, RuleTypes.BoardPieceType.ORTHOGONAL)
	_d_button.disabled = input_locked or not _has_piece_placement(legal_actions, RuleTypes.BoardPieceType.DIAGONAL)
	_pass_button.disabled = input_locked or not state.categories_used.is_empty()
	_end_turn_button.disabled = input_locked or state.categories_used.is_empty()

	_game_over_panel.visible = state.is_game_over
	if state.is_game_over:
		var result_text := "Draw"
		if state.outcome == RuleTypes.Outcome.BLACK_WIN:
			result_text = "Black wins"
		elif state.outcome == RuleTypes.Outcome.WHITE_WIN:
			result_text = "White wins"
		_game_over_label.text = "%s\nBlack %d  —  White %d" % [result_text, state.black_score, state.white_score]


func set_active_mode(mode: Mode) -> void:
	_placement_button.button_pressed = mode == Mode.PLACEMENT
	_movement_button.button_pressed = mode == Mode.MOVEMENT
	_action_button.button_pressed = mode == Mode.ACTION


func set_match_mode_text(text: String) -> void:
	_match_mode_label.text = text


func show_match_setup() -> void:
	hide_context_menu()
	_match_setup_overlay.visible = true


func hide_match_setup() -> void:
	_match_setup_overlay.visible = false


func show_entity_debug(title: String, lines: Array[String]) -> void:
	_debug_label.text = "[font_size=22][b]%s[/b][/font_size]\n\n%s" % [title, "\n".join(lines)]


func clear_entity_debug() -> void:
	_debug_label.text = "[font_size=22][b]Entity Debug[/b][/font_size]\n\nClick any entity to inspect it."


func show_context_menu(title: String, items: Array[Dictionary], screen_position: Vector2) -> void:
	_clear_children(_context_content)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 17)
	_context_content.add_child(title_label)
	for item: Dictionary in items:
		var option_id: int = item.id
		var button := _make_button(str(item.text), func() -> void: context_option_requested.emit(option_id))
		button.disabled = not bool(item.get("enabled", true))
		button.custom_minimum_size = Vector2(210, 34)
		_context_content.add_child(button)
	var minimum_size := _context_panel.get_combined_minimum_size()
	var estimated_height := 42.0 + float(items.size()) * 40.0
	var menu_size := Vector2(maxf(230.0, minimum_size.x), maxf(estimated_height, minimum_size.y))
	_context_panel.size = menu_size
	var viewport_size := get_viewport().get_visible_rect().size
	var menu_position := screen_position + Vector2(12.0, 12.0)
	if menu_position.x + menu_size.x > viewport_size.x - 8.0:
		menu_position.x = screen_position.x - menu_size.x - 12.0
	if menu_position.y + menu_size.y > viewport_size.y - 8.0:
		menu_position.y = screen_position.y - menu_size.y - 12.0
	_context_panel.position = Vector2(
		clampf(menu_position.x, 8.0, maxf(8.0, viewport_size.x - menu_size.x - 8.0)),
		clampf(menu_position.y, 8.0, maxf(8.0, viewport_size.y - menu_size.y - 8.0))
	)
	_context_panel.visible = true


func hide_context_menu() -> void:
	_context_panel.visible = false


func _build_controls(canvas: Control) -> void:
	var controls_panel := PanelContainer.new()
	controls_panel.name = "ControlsPanel"
	controls_panel.position = Vector2(16, 16)
	controls_panel.size = Vector2(690, 226)
	canvas.add_child(controls_panel)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 7)
	controls_panel.add_child(controls)

	var title_row := HBoxContainer.new()
	controls.add_child(title_row)
	var title := Label.new()
	title.text = "ANCHOR — CORE DEBUG MATCH"
	title.add_theme_font_size_override("font_size", 22)
	title_row.add_child(title)
	_match_mode_label = Label.new()
	_match_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_match_mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_match_mode_label)
	_turn_label = Label.new()
	_turn_label.add_theme_font_size_override("font_size", 18)
	controls.add_child(_turn_label)
	_categories_label = Label.new()
	controls.add_child(_categories_label)

	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 6)
	controls.add_child(modes)
	_placement_button = _make_button("Placement", func() -> void: mode_requested.emit(Mode.PLACEMENT))
	_movement_button = _make_button("Movement", func() -> void: mode_requested.emit(Mode.MOVEMENT))
	_action_button = _make_button("Action", func() -> void: mode_requested.emit(Mode.ACTION))
	for button in [_placement_button, _movement_button, _action_button]:
		button.toggle_mode = true
		modes.add_child(button)

	var placement_choices := HBoxContainer.new()
	placement_choices.add_theme_constant_override("separation", 6)
	controls.add_child(placement_choices)
	var choice_label := Label.new()
	choice_label.text = "Place:"
	placement_choices.add_child(choice_label)
	_anchor_button = _make_button("Anchor", func() -> void: placement_requested.emit(PLACE_ANCHOR))
	_o_button = _make_button("O BoardPiece", func() -> void: placement_requested.emit(RuleTypes.BoardPieceType.ORTHOGONAL))
	_d_button = _make_button("D BoardPiece", func() -> void: placement_requested.emit(RuleTypes.BoardPieceType.DIAGONAL))
	placement_choices.add_child(_anchor_button)
	placement_choices.add_child(_o_button)
	placement_choices.add_child(_d_button)

	var turn_controls := HBoxContainer.new()
	turn_controls.add_theme_constant_override("separation", 6)
	controls.add_child(turn_controls)
	_end_turn_button = _make_button("End Turn", func() -> void: end_turn_requested.emit())
	_pass_button = _make_button("Pass", func() -> void: pass_requested.emit())
	var restart_button := _make_button("Restart", func() -> void: restart_requested.emit())
	turn_controls.add_child(_end_turn_button)
	turn_controls.add_child(_pass_button)
	turn_controls.add_child(restart_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(650, 34)
	controls.add_child(_status_label)

	var debug_panel := PanelContainer.new()
	debug_panel.name = "DebugPanel"
	debug_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	debug_panel.position = Vector2(-466, 16)
	debug_panel.size = Vector2(450, 700)
	canvas.add_child(debug_panel)
	var debug_content := VBoxContainer.new()
	debug_content.add_theme_constant_override("separation", 8)
	debug_panel.add_child(debug_content)
	_debug_label = RichTextLabel.new()
	_debug_label.bbcode_enabled = true
	_debug_label.fit_content = false
	_debug_label.custom_minimum_size = Vector2(426, 275)
	_debug_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	debug_content.add_child(_debug_label)
	clear_entity_debug()

	var separator := HSeparator.new()
	debug_content.add_child(separator)
	var side_summaries := HBoxContainer.new()
	side_summaries.custom_minimum_size = Vector2(426, 350)
	side_summaries.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_summaries.add_theme_constant_override("separation", 8)
	debug_content.add_child(side_summaries)
	_black_stats_label = _add_side_summary(side_summaries, "BLACK", "Black")
	var side_separator := VSeparator.new()
	side_summaries.add_child(side_separator)
	_white_stats_label = _add_side_summary(side_summaries, "WHITE", "White")

	_game_over_panel = PanelContainer.new()
	_game_over_panel.name = "GameOverPanel"
	_game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	_game_over_panel.position = Vector2(-180, -90)
	_game_over_panel.size = Vector2(360, 180)
	canvas.add_child(_game_over_panel)
	var game_over_content := VBoxContainer.new()
	game_over_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_game_over_panel.add_child(game_over_content)
	var heading := Label.new()
	heading.text = "GAME OVER"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	game_over_content.add_child(heading)
	_game_over_label = Label.new()
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.add_theme_font_size_override("font_size", 21)
	game_over_content.add_child(_game_over_label)
	var overlay_restart := _make_button("Restart Match", func() -> void: restart_requested.emit())
	game_over_content.add_child(overlay_restart)
	_game_over_panel.visible = false

	_context_panel = PanelContainer.new()
	_context_panel.name = "ContextMenu"
	_context_panel.z_index = 20
	_context_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(_context_panel)
	_context_content = VBoxContainer.new()
	_context_content.add_theme_constant_override("separation", 5)
	_context_panel.add_child(_context_content)
	_context_panel.visible = false

	_build_match_setup(canvas)


func _build_match_setup(canvas: Control) -> void:
	_match_setup_overlay = Control.new()
	_match_setup_overlay.name = "MatchSetupOverlay"
	_match_setup_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_match_setup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_match_setup_overlay.z_index = 100
	canvas.add_child(_match_setup_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.03, 0.05, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_match_setup_overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "ModePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-230, -220)
	panel.size = Vector2(460, 440)
	_match_setup_overlay.add_child(panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	var heading := Label.new()
	heading.text = "CHOOSE MATCH MODE"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	content.add_child(heading)
	var explanation := Label.new()
	explanation.text = "The AI uses deterministic headless minimax.\nChoose either side for Human vs AI."
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(explanation)

	var human_match := _make_button("Human vs Human", func() -> void: match_mode_requested.emit(MatchMode.HUMAN_VS_HUMAN))
	var computer_black_match := _make_button("Human vs AI  •  Play as Black", func() -> void: match_mode_requested.emit(MatchMode.HUMAN_VS_AI))
	var computer_white_match := _make_button("Human vs AI  •  Play as White", func() -> void: match_mode_requested.emit(MatchMode.HUMAN_VS_AI_AS_WHITE))
	var ai_match := _make_button("AI vs AI", func() -> void: match_mode_requested.emit(MatchMode.AI_VS_AI))
	for button in [human_match, computer_black_match, computer_white_match, ai_match]:
		button.custom_minimum_size = Vector2(390, 48)
		content.add_child(button)


func _add_side_summary(parent: HBoxContainer, heading_text: String, node_prefix: String) -> Label:
	var column := VBoxContainer.new()
	column.name = "%sSummary" % node_prefix
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 5)
	parent.add_child(column)
	var heading := Label.new()
	heading.text = heading_text
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 18)
	column.add_child(heading)
	var stats := Label.new()
	stats.name = "%sStats" % node_prefix
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.custom_minimum_size = Vector2(194, 120)
	stats.add_theme_font_size_override("font_size", 14)
	column.add_child(stats)
	var steps_heading := Label.new()
	steps_heading.text = "STEPS · NEWEST FIRST"
	steps_heading.add_theme_font_size_override("font_size", 12)
	column.add_child(steps_heading)
	var steps := RichTextLabel.new()
	steps.name = "%sSteps" % node_prefix
	steps.fit_content = false
	steps.scroll_active = true
	steps.custom_minimum_size = Vector2(194, 155)
	steps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	steps.add_theme_font_size_override("normal_font_size", 13)
	column.add_child(steps)
	if node_prefix == "Black":
		_black_steps_label = steps
	else:
		_white_steps_label = steps
	return stats


func _refresh_side_summary(
	state,
	player: RuleTypes.Player,
	anchor_deployment_limit: int,
	stats_label: Label,
	steps_label: RichTextLabel
) -> void:
	var current_pieces := 0
	var current_anchors := 0
	for board_piece in state.board_pieces.values():
		if board_piece.player == player:
			current_pieces += 1
	for anchor in state.anchors.values():
		if anchor.player == player:
			current_anchors += 1
	var deployed_pieces := 0
	for record: Dictionary in state.action_log:
		var action: Dictionary = record.get("action", {})
		if int(record.get("player", -1)) == player \
				and int(action.get("kind", -1)) == GameplayAction.Kind.PLACE_BOARD_PIECE:
			deployed_pieces += 1
	var deployed_anchors: int = int(state.anchors_deployed.get(player, 0))
	stats_label.text = "\n".join([
		"Killed pieces: %d" % maxi(0, deployed_pieces - current_pieces),
		"Killed Anchors: %d" % maxi(0, deployed_anchors - current_anchors),
		"Pieces on board: %d" % current_pieces,
		"Anchors on board: %d" % current_anchors,
		"Anchors remaining: %d / %d" % [maxi(0, anchor_deployment_limit - deployed_anchors), anchor_deployment_limit],
	])
	var trace_lines: Array[String] = []
	for index in range(state.action_log.size() - 1, -1, -1):
		var record: Dictionary = state.action_log[index]
		if int(record.get("player", -1)) != player:
			continue
		trace_lines.append("T%d · %s" % [int(record.get("turn", 0)), _action_trace(record.get("action", {}))])
	steps_label.text = "No steps yet." if trace_lines.is_empty() else "\n".join(trace_lines)
	steps_label.scroll_to_line(0)


func _action_trace(action: Dictionary) -> String:
	match int(action.get("kind", -1)):
		GameplayAction.Kind.PLACE_ANCHOR:
			return "Place Anchor %s" % _cell_name(action.get("cell", Vector2i.ZERO))
		GameplayAction.Kind.PLACE_BOARD_PIECE:
			var type_name := "O" if int(action.get("board_piece_type", 0)) == RuleTypes.BoardPieceType.ORTHOGONAL else "D"
			return "Place %s %s" % [type_name, _cell_name(action.get("cell", Vector2i.ZERO))]
		GameplayAction.Kind.MOVE:
			var entity_name := "Anchor" if int(action.get("entity_kind", -1)) == RuleTypes.EntityKind.ANCHOR else "Piece"
			return "Move %s #%d → %s" % [entity_name, int(action.get("entity_id", 0)), _cell_name(action.get("cell", Vector2i.ZERO))]
		GameplayAction.Kind.ATTACK:
			return "Attack with Piece #%d" % int(action.get("entity_id", 0))
		GameplayAction.Kind.RAPID_ACTIVATION:
			return "Rapid Activate Anchor #%d" % int(action.get("entity_id", 0))
		GameplayAction.Kind.END_TURN:
			return "End Turn / Pass"
	return "Unknown action"


func _cell_name(cell: Variant) -> String:
	var resolved_cell := Vector2i.ZERO
	if cell is Vector2i:
		resolved_cell = cell
	elif cell is Array and cell.size() >= 2:
		resolved_cell = Vector2i(int(cell[0]), int(cell[1]))
	return "%s%d" % [String.chr(65 + resolved_cell.x), resolved_cell.y + 1]


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(104, 32)
	button.pressed.connect(callback)
	return button


func _has_category_action(legal_actions: Array, category: RuleTypes.ActionCategory) -> bool:
	for action in legal_actions:
		if action.category() == category:
			return true
	return false


func _has_action_kind(legal_actions: Array, kind: GameplayAction.Kind) -> bool:
	for action in legal_actions:
		if action.kind == kind:
			return true
	return false


func _has_piece_placement(legal_actions: Array, board_piece_type: RuleTypes.BoardPieceType) -> bool:
	for action in legal_actions:
		if action.kind == GameplayAction.Kind.PLACE_BOARD_PIECE and action.board_piece_type == board_piece_type:
			return true
	return false


func _used_categories_text(categories: Array[int]) -> String:
	if categories.is_empty():
		return "none (Pass available)"
	var names: Array[String] = []
	for category: int in categories:
		match category:
			RuleTypes.ActionCategory.PLACEMENT:
				names.append("Placement")
			RuleTypes.ActionCategory.MOVEMENT:
				names.append("Movement")
			RuleTypes.ActionCategory.ACTION:
				names.append("Action")
	return ", ".join(names)


func _player_name(player: RuleTypes.Player) -> String:
	return "Black" if player == RuleTypes.Player.BLACK else "White"


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
