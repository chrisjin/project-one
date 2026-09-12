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

enum Mode {
	NONE,
	PLACEMENT,
	MOVEMENT,
	ACTION,
}

const PLACE_ANCHOR := -1

var _turn_label: Label
var _categories_label: Label
var _status_label: Label
var _debug_label: RichTextLabel
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


func _ready() -> void:
	var canvas := Control.new()
	canvas.name = "DebugCanvas"
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The full-screen layout must not consume board clicks outside its visible panels.
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	_build_controls(canvas)


func refresh(state, legal_actions: Array, status_message: String) -> void:
	var player_name := _player_name(state.current_player)
	_turn_label.text = "Turn %d  •  %s to play" % [state.turn_number, player_name]
	_categories_label.text = "Used: %s" % _used_categories_text(state.categories_used)
	_status_label.text = status_message

	var placement_available := _has_category_action(legal_actions, RuleTypes.ActionCategory.PLACEMENT)
	var movement_available := _has_category_action(legal_actions, RuleTypes.ActionCategory.MOVEMENT)
	var action_available := _has_category_action(legal_actions, RuleTypes.ActionCategory.ACTION)
	_placement_button.disabled = state.is_game_over or not placement_available
	_movement_button.disabled = state.is_game_over or not movement_available
	_action_button.disabled = state.is_game_over or not action_available
	_anchor_button.disabled = state.is_game_over or not _has_action_kind(legal_actions, GameplayAction.Kind.PLACE_ANCHOR)
	_o_button.disabled = state.is_game_over or not _has_piece_placement(legal_actions, RuleTypes.BoardPieceType.ORTHOGONAL)
	_d_button.disabled = state.is_game_over or not _has_piece_placement(legal_actions, RuleTypes.BoardPieceType.DIAGONAL)
	_pass_button.disabled = state.is_game_over or not state.categories_used.is_empty()
	_end_turn_button.disabled = state.is_game_over or state.categories_used.is_empty()

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
	var menu_height := 42.0 + float(items.size()) * 40.0
	_context_panel.size = Vector2(230, menu_height)
	var viewport_size := get_viewport().get_visible_rect().size
	_context_panel.position = Vector2(
		clampf(screen_position.x + 12.0, 8.0, viewport_size.x - 238.0),
		clampf(screen_position.y + 12.0, 8.0, viewport_size.y - menu_height - 8.0)
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

	var title := Label.new()
	title.text = "ANCHOR — CORE DEBUG MATCH"
	title.add_theme_font_size_override("font_size", 22)
	controls.add_child(title)
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
	debug_panel.position = Vector2(-350, 16)
	debug_panel.size = Vector2(334, 610)
	canvas.add_child(debug_panel)
	_debug_label = RichTextLabel.new()
	_debug_label.bbcode_enabled = true
	_debug_label.fit_content = false
	_debug_label.custom_minimum_size = Vector2(310, 580)
	debug_panel.add_child(_debug_label)
	clear_entity_debug()

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
