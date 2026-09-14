## Bounded minimax player with optional random tie-breaking between equally scored moves.
class_name AnchorMinimaxAi
extends "res://scripts/ai/gameplay_ai.gd"

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")
const CoreRuleSet = preload("res://scripts/gameplay/core_rule_set.gd")
const GameplayAction = preload("res://scripts/gameplay/gameplay_action.gd")
const RulesEngine = preload("res://scripts/gameplay/rules_engine.gd")

const TERMINAL_SCORE := 1_000_000
const MIN_SCORE := -2_000_000_000
const MAX_SCORE := 2_000_000_000
const SEARCH_NODE_LIMIT := 240
const MID_GAME_ENTITY_THRESHOLD := 8
const LATE_GAME_ENTITY_THRESHOLD := 12
const LATE_GAME_SEARCH_DEPTH := 2
const MID_GAME_CHILD_ACTION_LIMIT := 6
const LATE_GAME_ROOT_ACTION_LIMIT := 6
const LATE_GAME_CHILD_ACTION_LIMIT := 4

const SAME_TURN_RELOCATION_PENALTY := 20

const ANCHOR_BASE_VALUE := 50
const ANCHOR_HP_VALUE := 20
const ACTIVE_ANCHOR_BONUS := 10
const MAIN_ANCHOR_CASCADE_VALUE_PER_BOUND_BOARD_PIECE := 120
const MAIN_ANCHOR_HP_VALUE_PER_BOUND_BOARD_PIECE := 8
const ANCHOR_ATTACK_THREAT_PENALTY := 40
const LETHAL_ANCHOR_THREAT_PENALTY := 80
const ANCHOR_THREAT_PENALTY_PER_BOUND_BOARD_PIECE := 25
const BOARD_PIECE_BASE_VALUE := 120
const BOARD_PIECE_HP_VALUE := 12
const MATURE_BOARD_PIECE_BONUS := 5
const DAMAGE_REDUCTION_BONUS := 18
const DUAL_ANCHOR_PROTECTION_BONUS := 20
const ATTACK_OPPORTUNITY_VALUE := 16
const ANCHOR_ATTACK_OPPORTUNITY_BONUS := 24
const LETHAL_ATTACK_OPPORTUNITY_BONUS := 40
const LETHAL_MAIN_ANCHOR_CASCADE_VALUE_PER_BOUND_BOARD_PIECE := 60
const LIBERTY_VALUE := 2
const MAX_SCORED_LIBERTIES_PER_GROUP := 6

var rules_engine
var search_depth: int
var max_actions_per_node: int
var randomize_ties: bool
var last_search_node_count := 0
var _search_node_count := 0
var _evaluation_cache: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init(
	configured_rule_set: RuleSet = null,
	depth: int = 3,
	action_limit: int = 8,
	should_randomize_ties: bool = true
) -> void:
	super(configured_rule_set if configured_rule_set != null else CoreRuleSet.new())
	rules_engine = RulesEngine.new(rule_set)
	search_depth = maxi(1, depth)
	max_actions_per_node = maxi(2, action_limit)
	randomize_ties = should_randomize_ties
	_rng.randomize()


func choose_action(state):
	if state == null or state.is_game_over:
		return null
	_search_node_count = 0
	last_search_node_count = 0
	_evaluation_cache.clear()
	var root_player: RuleTypes.Player = state.current_player
	var effective_depth := _search_depth_for_state(state)
	var candidates := _expanded_candidates(state, root_player, true, true)
	var best_actions: Array = []
	var best_score := MIN_SCORE
	for candidate: Dictionary in candidates:
		var score := _candidate_score(candidate, effective_depth - 1, root_player, MIN_SCORE, MAX_SCORE)
		if best_actions.is_empty() or score > best_score:
			best_actions = [candidate.action]
			best_score = score
		elif score == best_score:
			best_actions.append(candidate.action)
	last_search_node_count = _search_node_count
	if best_actions.is_empty():
		return null
	# Preserve End Turn as the safe choice over an equally valued aimless action.
	for action in best_actions:
		if action.kind == GameplayAction.Kind.END_TURN:
			return action
	if randomize_ties and best_actions.size() > 1:
		return best_actions[_rng.randi_range(0, best_actions.size() - 1)]
	best_actions.sort_custom(func(first, second) -> bool:
		return _choice_key(first) < _choice_key(second)
	)
	return best_actions[0]


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
	_search_node_count += 1
	if depth <= 0 or state.is_game_over or _search_node_count >= SEARCH_NODE_LIMIT:
		return _evaluate_for_search(state, root_player)
	var maximizing: bool = state.current_player == root_player
	var candidates := _expanded_candidates(state, root_player, maximizing, false)
	if candidates.is_empty():
		return _evaluate_for_search(state, root_player)
	if maximizing:
		var best := MIN_SCORE
		for candidate: Dictionary in candidates:
			best = maxi(best, _candidate_score(candidate, depth - 1, root_player, alpha, beta))
			alpha = maxi(alpha, best)
			if beta <= alpha:
				break
		return best
	var best := MAX_SCORE
	for candidate: Dictionary in candidates:
		best = mini(best, _candidate_score(candidate, depth - 1, root_player, alpha, beta))
		beta = mini(beta, best)
		if beta <= alpha:
			break
	return best


# Carry action costs through the search, including shifted alpha-beta bounds.
func _candidate_score(candidate: Dictionary, depth: int, root_player: RuleTypes.Player, alpha: int, beta: int) -> int:
	var adjustment: int = candidate.adjustment
	return adjustment + _minimax(candidate.state, depth, root_player, alpha - adjustment, beta - adjustment)


# A small preference, never a legality restriction: useful relocation can still win.
func _relocation_adjustment(state, action, perspective: RuleTypes.Player) -> int:
	if action.kind != GameplayAction.Kind.MOVE:
		return 0
	var entities: Dictionary = state.anchors if action.entity_kind == RuleTypes.EntityKind.ANCHOR else state.board_pieces
	if not entities.has(action.entity_id):
		return 0
	var entity = entities[action.entity_id]
	if entity.deployed_turn != state.turn_number:
		return 0
	# Edge cells may be reachable only by moving after deployment.
	if action.entity_kind == RuleTypes.EntityKind.ANCHOR and not state.map_definition.is_anchor_valid(action.cell):
		return 0
	return -SAME_TURN_RELOCATION_PENALTY if entity.player == perspective else SAME_TURN_RELOCATION_PENALTY


func _expanded_candidates(
	state,
	root_player: RuleTypes.Player,
	maximizing: bool,
	is_root: bool
) -> Array[Dictionary]:
	var expanded: Array[Dictionary] = []
	for transition: Dictionary in rules_engine.get_legal_transitions(state):
		var adjustment := _relocation_adjustment(state, transition.action, root_player)
		expanded.append({
			"action": transition.action,
			"state": transition.state,
			"ordering_score": _evaluate_for_search(transition.state, root_player) + adjustment,
			"adjustment": adjustment,
		})
	expanded.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		if first.ordering_score == second.ordering_score:
			return _search_order_key(first.action) < _search_order_key(second.action)
		return first.ordering_score > second.ordering_score if maximizing else first.ordering_score < second.ordering_score
	)
	return _bounded_candidates(expanded, _candidate_limit(state, is_root))


func _bounded_candidates(expanded: Array[Dictionary], action_limit: int) -> Array[Dictionary]:
	if expanded.size() <= action_limit:
		return expanded
	var bounded: Array[Dictionary] = []
	for index in range(action_limit):
		bounded.append(expanded[index])
	var end_turn_candidate: Dictionary = {}
	for candidate: Dictionary in expanded:
		if candidate.action.kind == GameplayAction.Kind.END_TURN:
			end_turn_candidate = candidate
			break
	if not end_turn_candidate.is_empty() and not _contains_action(bounded, end_turn_candidate.action):
		bounded[bounded.size() - 1] = end_turn_candidate
	return bounded


func _candidate_limit(state, is_root: bool) -> int:
	var entity_count: int = state.anchors.size() + state.board_pieces.size()
	if entity_count >= LATE_GAME_ENTITY_THRESHOLD:
		return mini(
			max_actions_per_node,
			LATE_GAME_ROOT_ACTION_LIMIT if is_root else LATE_GAME_CHILD_ACTION_LIMIT
		)
	if entity_count >= MID_GAME_ENTITY_THRESHOLD and not is_root:
		return mini(max_actions_per_node, MID_GAME_CHILD_ACTION_LIMIT)
	return max_actions_per_node


func _search_depth_for_state(state) -> int:
	var entity_count: int = state.anchors.size() + state.board_pieces.size()
	if entity_count >= LATE_GAME_ENTITY_THRESHOLD:
		return mini(search_depth, LATE_GAME_SEARCH_DEPTH)
	return search_depth


func _evaluate_for_search(state, perspective: RuleTypes.Player) -> int:
	var cache_key: int = state.get_instance_id()
	if _evaluation_cache.has(cache_key):
		return _evaluation_cache[cache_key]
	var score := evaluate_state(state, perspective)
	_evaluation_cache[cache_key] = score
	return score


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
		bound_board_piece_counts[board_piece.main_anchor_id] = int(
			bound_board_piece_counts.get(board_piece.main_anchor_id, 0)
		) + 1
	var anchor_threat_damage := _anchor_threat_damage(state, player)
	for anchor in state.anchors.values():
		if anchor.player != player:
			continue
		var bound_count: int = bound_board_piece_counts.get(anchor.id, 0)
		value += _anchor_value(anchor, bound_count, int(anchor_threat_damage.get(anchor.id, -1)))
	for board_piece in state.board_pieces.values():
		if board_piece.player != player:
			continue
		value += BOARD_PIECE_BASE_VALUE + board_piece.hp * BOARD_PIECE_HP_VALUE
		value += MATURE_BOARD_PIECE_BONUS if board_piece.is_mature else 0
		if rules_engine.compute_unit_chain_connection(state, board_piece.id):
			value += DAMAGE_REDUCTION_BONUS
		if rules_engine.has_dual_anchor_protection(state, board_piece.id):
			value += DUAL_ANCHOR_PROTECTION_BONUS
	value += _attack_opportunity_value(state, player, bound_board_piece_counts)
	for group: Dictionary in rules_engine.compute_friendly_groups(state, player):
		var liberty_count: int = rules_engine.compute_liberties(state, group).size()
		value += mini(liberty_count, MAX_SCORED_LIBERTIES_PER_GROUP) * LIBERTY_VALUE
	return value


func _attack_opportunity_value(
	state,
	player: RuleTypes.Player,
	bound_board_piece_counts: Dictionary
) -> int:
	# Score O or D by the first enemy its engine-defined rays can actually reach.
	var value := 0
	for opportunity: Dictionary in rules_engine.compute_attack_opportunities(state, player):
		var target: Dictionary = opportunity.target
		if target.kind == RuleTypes.EntityKind.BOARD_PIECE:
			if not state.board_pieces.has(target.id) or state.board_pieces[target.id].hp <= 0:
				continue
			value += ATTACK_OPPORTUNITY_VALUE
			var target_piece = state.board_pieces[target.id]
			if int(opportunity.damage) >= target_piece.hp \
				and not rules_engine.has_dual_anchor_protection(state, target.id):
				value += LETHAL_ATTACK_OPPORTUNITY_BONUS
			continue
		if target.kind != RuleTypes.EntityKind.ANCHOR or not state.anchors.has(target.id):
			continue
		value += ATTACK_OPPORTUNITY_VALUE + ANCHOR_ATTACK_OPPORTUNITY_BONUS
		var target_anchor = state.anchors[target.id]
		if int(opportunity.damage) >= target_anchor.hp:
			value += LETHAL_ATTACK_OPPORTUNITY_BONUS
			value += int(bound_board_piece_counts.get(target.id, 0)) \
				* LETHAL_MAIN_ANCHOR_CASCADE_VALUE_PER_BOUND_BOARD_PIECE
	return value


func _anchor_value(anchor, bound_count: int, threat_damage: int = -1) -> int:
	var value: int = ANCHOR_BASE_VALUE + anchor.hp * ANCHOR_HP_VALUE
	value += ACTIVE_ANCHOR_BONUS if anchor.is_active else 0
	value += bound_count * MAIN_ANCHOR_CASCADE_VALUE_PER_BOUND_BOARD_PIECE
	value += anchor.hp * bound_count * MAIN_ANCHOR_HP_VALUE_PER_BOUND_BOARD_PIECE
	if threat_damage >= 0:
		value -= ANCHOR_ATTACK_THREAT_PENALTY
		value -= bound_count * ANCHOR_THREAT_PENALTY_PER_BOUND_BOARD_PIECE
		if threat_damage >= anchor.hp:
			value -= LETHAL_ANCHOR_THREAT_PENALTY
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
