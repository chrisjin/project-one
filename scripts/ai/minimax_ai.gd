## Deterministic bounded minimax player operating only through the headless rules engine.
class_name AnchorMinimaxAi
extends RefCounted

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")
const GameplayAction = preload("res://scripts/gameplay/gameplay_action.gd")
const RulesEngine = preload("res://scripts/gameplay/rules_engine.gd")

const TERMINAL_SCORE := 1_000_000
const MIN_SCORE := -2_000_000_000
const MAX_SCORE := 2_000_000_000

const ANCHOR_BASE_VALUE := 50
const ANCHOR_HP_VALUE := 20
const ACTIVE_ANCHOR_BONUS := 10
const MAIN_ANCHOR_HP_VALUE_PER_BOUND_BOARD_PIECE := 8
const ANCHOR_ATTACK_THREAT_PENALTY := 40
const LETHAL_ANCHOR_THREAT_PENALTY := 80
const ANCHOR_THREAT_PENALTY_PER_BOUND_BOARD_PIECE := 25
const BOARD_PIECE_BASE_VALUE := 120
const BOARD_PIECE_HP_VALUE := 12
const MATURE_BOARD_PIECE_BONUS := 5
const DAMAGE_REDUCTION_BONUS := 18
const DUAL_ANCHOR_PROTECTION_BONUS := 20
const LIBERTY_VALUE := 2
const MAX_SCORED_LIBERTIES_PER_GROUP := 6

var rules_engine
var search_depth: int
var max_actions_per_node: int


func _init(engine = null, depth: int = 3, action_limit: int = 8) -> void:
	rules_engine = engine if engine != null else RulesEngine.new()
	search_depth = maxi(1, depth)
	max_actions_per_node = maxi(2, action_limit)


func choose_action(state):
	if state == null or state.is_game_over:
		return null
	var root_player: RuleTypes.Player = state.current_player
	var candidates := _expanded_candidates(state, root_player, true)
	var best_action = null
	var best_score := MIN_SCORE
	var best_key := ""
	for candidate: Dictionary in candidates:
		var score := _minimax(candidate.state, search_depth - 1, root_player, MIN_SCORE, MAX_SCORE)
		var choice_key := _choice_key(candidate.action)
		if best_action == null or score > best_score or (score == best_score and choice_key < best_key):
			best_action = candidate.action
			best_score = score
			best_key = choice_key
	return best_action


func evaluate_state(state, perspective: RuleTypes.Player) -> int:
	if state.is_game_over:
		if state.outcome == RuleTypes.Outcome.DRAW:
			return 0
		var perspective_won: bool = (
			perspective == RuleTypes.Player.BLACK and state.outcome == RuleTypes.Outcome.BLACK_WIN
		) or (
			perspective == RuleTypes.Player.WHITE and state.outcome == RuleTypes.Outcome.WHITE_WIN
		)
		return TERMINAL_SCORE if perspective_won else -TERMINAL_SCORE
	var opponent: RuleTypes.Player = RuleTypes.opponent(perspective)
	return _side_value(state, perspective) - _side_value(state, opponent)


func _minimax(
	state,
	depth: int,
	root_player: RuleTypes.Player,
	alpha: int,
	beta: int
) -> int:
	if depth <= 0 or state.is_game_over:
		return evaluate_state(state, root_player)
	var maximizing: bool = state.current_player == root_player
	var candidates := _expanded_candidates(state, root_player, maximizing)
	if candidates.is_empty():
		return evaluate_state(state, root_player)
	if maximizing:
		var best := MIN_SCORE
		for candidate: Dictionary in candidates:
			best = maxi(best, _minimax(candidate.state, depth - 1, root_player, alpha, beta))
			alpha = maxi(alpha, best)
			if beta <= alpha:
				break
		return best
	var best := MAX_SCORE
	for candidate: Dictionary in candidates:
		best = mini(best, _minimax(candidate.state, depth - 1, root_player, alpha, beta))
		beta = mini(beta, best)
		if beta <= alpha:
			break
	return best


func _expanded_candidates(
	state,
	root_player: RuleTypes.Player,
	maximizing: bool
) -> Array[Dictionary]:
	var expanded: Array[Dictionary] = []
	for action in rules_engine.get_legal_actions(state):
		var result = rules_engine.apply_action(state, action)
		if result.success:
			expanded.append({
				"action": action,
				"state": result.state,
				"ordering_score": evaluate_state(result.state, root_player),
			})
	expanded.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		if first.ordering_score == second.ordering_score:
			return _search_order_key(first.action) < _search_order_key(second.action)
		return first.ordering_score > second.ordering_score if maximizing else first.ordering_score < second.ordering_score
	)
	return _bounded_candidates(expanded)


func _bounded_candidates(expanded: Array[Dictionary]) -> Array[Dictionary]:
	if expanded.size() <= max_actions_per_node:
		return expanded
	var bounded: Array[Dictionary] = []
	for index in range(max_actions_per_node):
		bounded.append(expanded[index])
	var end_turn_candidate: Dictionary = {}
	for candidate: Dictionary in expanded:
		if candidate.action.kind == GameplayAction.Kind.END_TURN:
			end_turn_candidate = candidate
			break
	if not end_turn_candidate.is_empty() and not _contains_action(bounded, end_turn_candidate.action):
		bounded[bounded.size() - 1] = end_turn_candidate
	return bounded


func _contains_action(candidates: Array[Dictionary], expected_action) -> bool:
	var expected_key := _action_data_key(expected_action)
	for candidate: Dictionary in candidates:
		if _action_data_key(candidate.action) == expected_key:
			return true
	return false


func _side_value(state, player: RuleTypes.Player) -> int:
	var value := 0
	var bound_board_piece_counts: Dictionary = {}
	for board_piece in state.board_pieces.values():
		if board_piece.player == player:
			bound_board_piece_counts[board_piece.main_anchor_id] = int(
				bound_board_piece_counts.get(board_piece.main_anchor_id, 0)
			) + 1
	var anchor_threat_damage := _anchor_threat_damage(state, player)
	for anchor in state.anchors.values():
		if anchor.player != player:
			continue
		var bound_count: int = bound_board_piece_counts.get(anchor.id, 0)
		value += ANCHOR_BASE_VALUE + anchor.hp * ANCHOR_HP_VALUE
		value += ACTIVE_ANCHOR_BONUS if anchor.is_active else 0
		value += anchor.hp * bound_count * MAIN_ANCHOR_HP_VALUE_PER_BOUND_BOARD_PIECE
		if anchor_threat_damage.has(anchor.id):
			value -= ANCHOR_ATTACK_THREAT_PENALTY
			value -= bound_count * ANCHOR_THREAT_PENALTY_PER_BOUND_BOARD_PIECE
			if int(anchor_threat_damage[anchor.id]) >= anchor.hp:
				value -= LETHAL_ANCHOR_THREAT_PENALTY
	for board_piece in state.board_pieces.values():
		if board_piece.player != player:
			continue
		value += BOARD_PIECE_BASE_VALUE + board_piece.hp * BOARD_PIECE_HP_VALUE
		value += MATURE_BOARD_PIECE_BONUS if board_piece.is_mature else 0
		if rules_engine.compute_unit_chain_connection(state, board_piece.id):
			value += DAMAGE_REDUCTION_BONUS
		if rules_engine.has_dual_anchor_protection(state, board_piece.id):
			value += DUAL_ANCHOR_PROTECTION_BONUS
	for group: Dictionary in rules_engine.compute_friendly_groups(state, player):
		var liberty_count: int = rules_engine.compute_liberties(state, group).size()
		value += mini(liberty_count, MAX_SCORED_LIBERTIES_PER_GROUP) * LIBERTY_VALUE
	return value


func _anchor_threat_damage(state, defending_player: RuleTypes.Player) -> Dictionary:
	var threat_damage: Dictionary = {}
	var attacking_player := RuleTypes.opponent(defending_player)
	for threat: Dictionary in rules_engine.compute_attack_threats(state, attacking_player):
		var target: Dictionary = threat.target
		if target.kind != RuleTypes.EntityKind.ANCHOR or not state.anchors.has(target.id):
			continue
		if state.anchors[target.id].player != defending_player:
			continue
		threat_damage[target.id] = maxi(
			int(threat_damage.get(target.id, 0)),
			int(threat.damage)
		)
	return threat_damage


func _choice_key(action) -> String:
	# Prefer ending the turn over a strategically identical move to avoid aimless cycles.
	var tie_rank: int = 0 if action.kind == GameplayAction.Kind.END_TURN else action.kind + 1
	return "%02d|%s" % [tie_rank, _action_data_key(action)]


func _search_order_key(action) -> String:
	var search_rank := 0
	match action.kind:
		GameplayAction.Kind.ATTACK:
			search_rank = 0
		GameplayAction.Kind.RAPID_ACTIVATION:
			search_rank = 1
		GameplayAction.Kind.PLACE_BOARD_PIECE:
			search_rank = 2
		GameplayAction.Kind.PLACE_ANCHOR:
			search_rank = 3
		GameplayAction.Kind.MOVE:
			search_rank = 4
		_:
			search_rank = 5
	return "%02d|%s" % [search_rank, _action_data_key(action)]


func _action_data_key(action) -> String:
	return "%d|%d,%d|%d|%d|%d|%d|%d,%d" % [
		action.kind,
		action.cell.x,
		action.cell.y,
		action.board_piece_type,
		action.main_anchor_id,
		action.entity_kind,
		action.entity_id,
		action.direction.x,
		action.direction.y,
	]
