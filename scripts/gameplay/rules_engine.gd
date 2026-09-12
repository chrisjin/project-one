## Authoritative deterministic resolver for the current headless core rules.
class_name AnchorRulesEngine
extends RefCounted

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")
const RulesConfig = preload("res://scripts/gameplay/rules_config.gd")
const MapDefinition = preload("res://scripts/gameplay/map_definition.gd")
const Anchor = preload("res://scripts/gameplay/anchor_state.gd")
const BoardPiece = preload("res://scripts/gameplay/board_piece_state.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const GameplayAction = preload("res://scripts/gameplay/gameplay_action.gd")
const ActionResult = preload("res://scripts/gameplay/action_result.gd")


func new_game(board_map: MapDefinition = null, random_seed: int = 0) -> GameState:
	var state := GameState.new(board_map, random_seed)
	state.seen_state_hashes[state_hash(state)] = true
	return state


func apply_action(state: GameState, action: GameplayAction) -> ActionResult:
	if state.is_game_over:
		return ActionResult.new(false, state, "The game is already over.")
	if action.kind == GameplayAction.Kind.END_TURN:
		return _end_turn(state, action)

	var category := action.category()
	if category < 0:
		return ActionResult.new(false, state, "The action has no core action category.")
	if state.categories_used.has(category):
		return ActionResult.new(false, state, "That action category was already used this turn.")
	if state.categories_used.size() >= RulesConfig.MAX_CATEGORIES_PER_TURN:
		return ActionResult.new(false, state, "At most two action categories may be used per turn.")

	var candidate := state.duplicate_state()
	var events: Array[Dictionary] = []
	var error := _execute_action(candidate, action, events)
	if not error.is_empty():
		return ActionResult.new(false, state, error)

	candidate.categories_used.append(category)
	candidate.consecutive_passes = 0
	_stabilize_in_place(candidate, events)
	if candidate.categories_used.size() >= RulesConfig.MAX_CATEGORIES_PER_TURN:
		_advance_turn_in_place(candidate, events, false, true)
	return _complete_transition(state, candidate, action, events)


func stabilize(state: GameState) -> GameState:
	var candidate := state.duplicate_state()
	_stabilize_in_place(candidate, [])
	return candidate


func replay(initial_state: GameState, records: Array) -> ActionResult:
	var replay_state := initial_state.duplicate_state()
	for record: Variant in records:
		var action_data: Dictionary = record.action if record is Dictionary and record.has("action") else record
		var result := apply_action(replay_state, GameplayAction.from_dictionary(action_data))
		if not result.success:
			return ActionResult.new(false, replay_state, "Replay failed: %s" % result.error)
		replay_state = result.state
	return ActionResult.new(true, replay_state)


func get_legal_actions(state: GameState) -> Array[GameplayAction]:
	var legal_actions: Array[GameplayAction] = []
	for transition: Dictionary in get_legal_transitions(state):
		legal_actions.append(transition.action)
	return legal_actions


func get_legal_transitions(state: GameState) -> Array[Dictionary]:
	# Return each legal action with its already-resolved state to avoid duplicate simulation.
	var candidates: Array[GameplayAction] = []
	var transitions: Array[Dictionary] = []
	if state.is_game_over:
		return transitions

	candidates.append(GameplayAction.end_turn())
	if state.categories_used.size() < RulesConfig.MAX_CATEGORIES_PER_TURN:
		if not state.categories_used.has(RuleTypes.ActionCategory.PLACEMENT):
			_append_placement_actions(state, candidates)
		if not state.categories_used.has(RuleTypes.ActionCategory.MOVEMENT):
			_append_movement_actions(state, candidates)
		if not state.categories_used.has(RuleTypes.ActionCategory.ACTION):
			_append_core_actions(state, candidates)
	for action: GameplayAction in candidates:
		var result := apply_action(state, action)
		if result.success:
			transitions.append({
				"action": action,
				"state": result.state,
				"events": result.events,
			})
	return transitions


func trace_ray(state: GameState, board_piece_id: int, direction: Vector2i) -> Dictionary:
	var result := {"cells": [], "target": {}}
	if not state.board_pieces.has(board_piece_id):
		return result
	var board_piece: BoardPiece = state.board_pieces[board_piece_id]
	if not RuleTypes.board_piece_directions(board_piece.board_piece_type).has(direction):
		return result

	for distance in range(1, RulesConfig.BOARD_PIECE_MAX_RANGE + 1):
		var cell := board_piece.cell + direction * distance
		if not state.map_definition.is_on_map(cell):
			break
		result.cells.append(cell)
		if state.map_definition.blocks_ray(cell):
			break
		var entity := state.entity_at(cell)
		if entity.is_empty():
			continue
		if state.entity_player(entity) != board_piece.player:
			result.target = entity
			break
		if entity.kind == RuleTypes.EntityKind.ANCHOR:
			break
		var friendly_piece: BoardPiece = state.board_pieces[entity.id]
		if friendly_piece.hp <= 0:
			break
	return result


func compute_attack_threats(state: GameState, attacking_player: RuleTypes.Player) -> Array[Dictionary]:
	# This turn-independent query lets headless controllers inspect exact attack rays.
	var threats: Array[Dictionary] = []
	if state.is_game_over:
		return threats
	for board_piece_id: int in _sorted_int_keys(state.board_pieces):
		var attacker: BoardPiece = state.board_pieces[board_piece_id]
		if attacker.player != attacking_player or attacker.hp <= 0 or not attacker.is_mature:
			continue
		for direction: Vector2i in RuleTypes.board_piece_directions(attacker.board_piece_type):
			var ray := trace_ray(state, board_piece_id, direction)
			if ray.target.is_empty():
				continue
			threats.append({
				"attacker_id": board_piece_id,
				"direction": direction,
				"target": ray.target.duplicate(),
				"damage": _attack_damage_to_target(state, ray.target),
			})
	return threats


func compute_supply(state: GameState, board_piece_id: int) -> bool:
	if not state.board_pieces.has(board_piece_id):
		return false
	var board_piece: BoardPiece = state.board_pieces[board_piece_id]
	if not state.anchors.has(board_piece.main_anchor_id):
		return false
	var main_anchor: Anchor = state.anchors[board_piece.main_anchor_id]
	if main_anchor.player != board_piece.player:
		return false

	var visited := {board_piece.cell: true}
	var frontier: Array[Vector2i] = [board_piece.cell]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == main_anchor.cell:
			return true
		for direction: Vector2i in RuleTypes.ORTHOGONAL_DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if visited.has(neighbor) or not _is_supply_traversable(state, neighbor, board_piece.player):
				continue
			visited[neighbor] = true
			frontier.append(neighbor)
	return false


func compute_unit_chain_connection(state: GameState, board_piece_id: int) -> bool:
	if not state.board_pieces.has(board_piece_id):
		return false
	var board_piece: BoardPiece = state.board_pieces[board_piece_id]
	if not state.anchors.has(board_piece.main_anchor_id):
		return false
	var main_anchor: Anchor = state.anchors[board_piece.main_anchor_id]
	if main_anchor.player != board_piece.player:
		return false
	return _friendly_entity_cells_reachable(state, board_piece.cell, board_piece.player).has(main_anchor.cell)


func compute_anchor_clusters(state: GameState, player: RuleTypes.Player) -> Array[Array]:
	var clusters: Array[Array] = []
	var visited: Dictionary = {}
	var sorted_anchor_ids := _sorted_int_keys(state.anchors)
	for anchor_id: int in sorted_anchor_ids:
		var anchor: Anchor = state.anchors[anchor_id]
		if anchor.player != player or visited.has(anchor_id):
			continue
		var cluster: Array[int] = []
		var frontier: Array[int] = [anchor_id]
		visited[anchor_id] = true
		while not frontier.is_empty():
			var current_id: int = frontier.pop_front()
			var current_anchor: Anchor = state.anchors[current_id]
			cluster.append(current_id)
			for neighbor_id: int in sorted_anchor_ids:
				if visited.has(neighbor_id):
					continue
				var neighbor_anchor: Anchor = state.anchors[neighbor_id]
				if neighbor_anchor.player == player and _is_orthogonally_adjacent(current_anchor.cell, neighbor_anchor.cell):
					visited[neighbor_id] = true
					frontier.append(neighbor_id)
		cluster.sort()
		clusters.append(cluster)
	return clusters


func compute_friendly_groups(state: GameState, player: RuleTypes.Player) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var visited_cells: Dictionary = {}
	var occupied_cells: Array[Vector2i] = []
	for anchor_id: int in _sorted_int_keys(state.anchors):
		var anchor: Anchor = state.anchors[anchor_id]
		if anchor.player == player:
			occupied_cells.append(anchor.cell)
	for board_piece_id: int in _sorted_int_keys(state.board_pieces):
		var board_piece: BoardPiece = state.board_pieces[board_piece_id]
		if board_piece.player == player:
			occupied_cells.append(board_piece.cell)
	_sort_cells(occupied_cells)

	for start: Vector2i in occupied_cells:
		if visited_cells.has(start):
			continue
		var group_entities: Array[Dictionary] = []
		var frontier: Array[Vector2i] = [start]
		visited_cells[start] = true
		while not frontier.is_empty():
			var current: Vector2i = frontier.pop_front()
			group_entities.append(state.entity_at(current))
			for direction: Vector2i in RuleTypes.ORTHOGONAL_DIRECTIONS:
				var neighbor: Vector2i = current + direction
				if visited_cells.has(neighbor):
					continue
				var entity := state.entity_at(neighbor)
				if not entity.is_empty() and state.entity_player(entity) == player:
					visited_cells[neighbor] = true
					frontier.append(neighbor)
		groups.append({"player": player, "entities": group_entities})
	return groups


func compute_liberties(state: GameState, group: Dictionary) -> Array[Vector2i]:
	var liberties: Dictionary = {}
	for entity: Dictionary in group.entities:
		var cell := state.entity_cell(entity)
		for direction: Vector2i in RuleTypes.ORTHOGONAL_DIRECTIONS:
			var neighbor := cell + direction
			if state.map_definition.is_passable(neighbor) and state.is_cell_empty(neighbor):
				liberties[neighbor] = true
	var result: Array[Vector2i] = []
	result.assign(liberties.keys())
	_sort_cells(result)
	return result


func secondary_anchor_cluster_ids(state: GameState, board_piece_id: int) -> Array[int]:
	var secondary_ids: Array[int] = []
	if not state.board_pieces.has(board_piece_id):
		return secondary_ids
	var board_piece: BoardPiece = state.board_pieces[board_piece_id]
	if not state.anchors.has(board_piece.main_anchor_id):
		return secondary_ids
	var clusters := compute_anchor_clusters(state, board_piece.player)
	var main_cluster_index := _cluster_index_containing(clusters, board_piece.main_anchor_id)
	var reachable_cells := _friendly_entity_cells_reachable(state, board_piece.cell, board_piece.player)
	for cluster_index in range(clusters.size()):
		if cluster_index == main_cluster_index:
			continue
		var is_reachable := false
		var has_active_anchor := false
		for anchor_id: int in clusters[cluster_index]:
			var anchor: Anchor = state.anchors[anchor_id]
			is_reachable = is_reachable or reachable_cells.has(anchor.cell)
			has_active_anchor = has_active_anchor or anchor.is_active
		if is_reachable and has_active_anchor:
			secondary_ids.append(clusters[cluster_index][0])
	secondary_ids.sort()
	return secondary_ids


func has_dual_anchor_protection(state: GameState, board_piece_id: int) -> bool:
	if not state.board_pieces.has(board_piece_id):
		return false
	var board_piece: BoardPiece = state.board_pieces[board_piece_id]
	return (
		board_piece.is_mature
		and state.anchors.has(board_piece.main_anchor_id)
		and compute_supply(state, board_piece_id)
		and not secondary_anchor_cluster_ids(state, board_piece_id).is_empty()
	)


func board_piece_debug(state: GameState, board_piece_id: int) -> Dictionary:
	if not state.board_pieces.has(board_piece_id):
		return {}
	var board_piece: BoardPiece = state.board_pieces[board_piece_id]
	var group_data := _group_debug_data(state, RuleTypes.EntityKind.BOARD_PIECE, board_piece_id)
	return {
		"board_piece_id": board_piece.id,
		"board_piece_type": board_piece.board_piece_type,
		"owner": board_piece.player,
		"hp": board_piece.hp,
		"is_mature": board_piece.is_mature,
		"main_anchor_id": board_piece.main_anchor_id,
		"main_anchor_alive": state.anchors.has(board_piece.main_anchor_id),
		"supply_valid": compute_supply(state, board_piece_id),
		"unit_chain_connected": compute_unit_chain_connection(state, board_piece_id),
		"damage_reduction_active": compute_unit_chain_connection(state, board_piece_id),
		"secondary_anchor_cluster_ids": secondary_anchor_cluster_ids(state, board_piece_id),
		"dual_anchor_protection": has_dual_anchor_protection(state, board_piece_id),
		"zero_hp_protection_valid": board_piece.hp <= 0 and has_dual_anchor_protection(state, board_piece_id),
		"friendly_group_id": group_data.id,
		"liberty_count": group_data.liberty_count,
	}


func anchor_debug(state: GameState, anchor_id: int) -> Dictionary:
	if not state.anchors.has(anchor_id):
		return {}
	var anchor: Anchor = state.anchors[anchor_id]
	var clusters := compute_anchor_clusters(state, anchor.player)
	var cluster_index := _cluster_index_containing(clusters, anchor_id)
	var group_data := _group_debug_data(state, RuleTypes.EntityKind.ANCHOR, anchor_id)
	var bound_board_piece_ids: Array[int] = []
	for board_piece: BoardPiece in state.board_pieces.values():
		if board_piece.main_anchor_id == anchor_id:
			bound_board_piece_ids.append(board_piece.id)
	bound_board_piece_ids.sort()
	return {
		"anchor_id": anchor.id,
		"owner": anchor.player,
		"hp": anchor.hp,
		"is_active": anchor.is_active,
		"anchor_cluster_id": clusters[cluster_index][0] if cluster_index >= 0 else -1,
		"bound_board_piece_ids": bound_board_piece_ids,
		"bound_board_piece_count": bound_board_piece_ids.size(),
		"binding_capacity": RulesConfig.ANCHOR_BINDING_CAPACITY,
		"deployment_index": anchor.deployment_index,
		"zero_liberty": group_data.liberty_count == 0,
		"protected_group_membership": group_data.has_protected_board_piece,
	}


func state_hash(state: GameState) -> String:
	var anchor_data: Array = []
	for anchor_id: int in _sorted_int_keys(state.anchors):
		anchor_data.append(state.anchors[anchor_id].canonical_data())
	var board_piece_data: Array = []
	for board_piece_id: int in _sorted_int_keys(state.board_pieces):
		board_piece_data.append(state.board_pieces[board_piece_id].canonical_data())
	var cluster_data: Array = []
	for player in [RuleTypes.Player.BLACK, RuleTypes.Player.WHITE]:
		cluster_data.append(compute_anchor_clusters(state, player))
	var categories := state.categories_used.duplicate()
	categories.sort()
	var canonical := [
		state.map_definition.canonical_data(),
		anchor_data,
		board_piece_data,
		state.current_player,
		categories,
		[state.anchors_deployed[RuleTypes.Player.BLACK], state.anchors_deployed[RuleTypes.Player.WHITE]],
		state.consecutive_passes,
		state.is_game_over,
		state.outcome,
		state.black_score,
		state.white_score,
		state.random_seed,
		cluster_data,
	]
	return JSON.stringify(canonical).sha256_text()


func score(state: GameState) -> Dictionary:
	var black := 0
	var white := 0
	for board_piece: BoardPiece in state.board_pieces.values():
		if board_piece.player == RuleTypes.Player.BLACK:
			black += 1
		else:
			white += 1
	return {"black": black, "white": white}


func _execute_action(state: GameState, action: GameplayAction, events: Array[Dictionary]) -> String:
	match action.kind:
		GameplayAction.Kind.PLACE_ANCHOR:
			return _place_anchor(state, action, events)
		GameplayAction.Kind.PLACE_BOARD_PIECE:
			return _place_board_piece(state, action, events)
		GameplayAction.Kind.MOVE:
			return _move_entity(state, action, events)
		GameplayAction.Kind.ATTACK:
			return _attack(state, action, events)
		GameplayAction.Kind.RAPID_ACTIVATION:
			return _rapid_activation(state, action, events)
	return "Unsupported action."


func _place_anchor(state: GameState, action: GameplayAction, events: Array[Dictionary]) -> String:
	if state.anchors_deployed[state.current_player] >= RulesConfig.ANCHOR_DEPLOYMENT_LIMIT:
		return "The player has reached the 12-Anchor deployment limit."
	if not state.map_definition.is_anchor_valid(action.cell):
		return "An Anchor may only be deployed on an Anchor-valid passable cell."
	if not state.is_cell_empty(action.cell):
		return "The deployment cell is occupied."
	var anchor_id := state.next_anchor_id
	state.next_anchor_id += 1
	state.anchors_deployed[state.current_player] += 1
	var anchor := Anchor.new(
		anchor_id,
		state.current_player,
		action.cell,
		state.turn_number,
		state.anchors_deployed[state.current_player]
	)
	state.anchors[anchor_id] = anchor
	events.append({"type": "anchor_deployed", "anchor_id": anchor_id, "cell": action.cell})
	return ""


func _place_board_piece(state: GameState, action: GameplayAction, events: Array[Dictionary]) -> String:
	if action.board_piece_type not in [RuleTypes.BoardPieceType.ORTHOGONAL, RuleTypes.BoardPieceType.DIAGONAL]:
		return "Only base O and D BoardPieces are available in the core engine."
	if not state.map_definition.is_passable(action.cell):
		return "A BoardPiece must be deployed on a passable cell."
	if not state.is_cell_empty(action.cell):
		return "The deployment cell is occupied."
	if not state.anchors.has(action.main_anchor_id):
		return "The selected physical Main Anchor does not exist."
	var main_anchor: Anchor = state.anchors[action.main_anchor_id]
	if main_anchor.player != state.current_player:
		return "The selected Main Anchor is not friendly."
	if _bound_board_piece_count(state, action.main_anchor_id) >= RulesConfig.ANCHOR_BINDING_CAPACITY:
		return "The selected physical Main Anchor has no available binding slot."
	var board_piece_id := state.next_board_piece_id
	state.next_board_piece_id += 1
	state.board_pieces[board_piece_id] = BoardPiece.new(
		board_piece_id,
		state.current_player,
		action.board_piece_type,
		action.cell,
		action.main_anchor_id,
		state.turn_number
	)
	events.append({
		"type": "board_piece_deployed",
		"board_piece_id": board_piece_id,
		"cell": action.cell,
		"main_anchor_id": action.main_anchor_id,
	})
	return ""


func _move_entity(state: GameState, action: GameplayAction, events: Array[Dictionary]) -> String:
	if not state.map_definition.is_passable(action.cell) or not state.is_cell_empty(action.cell):
		return "Movement requires an empty passable destination."
	if action.entity_kind == RuleTypes.EntityKind.ANCHOR:
		if not state.anchors.has(action.entity_id):
			return "The Anchor does not exist."
		var anchor: Anchor = state.anchors[action.entity_id]
		if anchor.player != state.current_player:
			return "Only a friendly Anchor may move."
		if not _is_orthogonally_adjacent(anchor.cell, action.cell):
			return "An Anchor moves exactly one orthogonal cell."
		if not state.map_definition.is_anchor_valid(action.cell):
			return "An Anchor must remain on an Anchor-valid cell."
		var origin := anchor.cell
		anchor.cell = action.cell
		events.append({"type": "anchor_moved", "anchor_id": anchor.id, "from": origin, "to": action.cell})
		return ""
	if action.entity_kind == RuleTypes.EntityKind.BOARD_PIECE:
		if not state.board_pieces.has(action.entity_id):
			return "The BoardPiece does not exist."
		var board_piece: BoardPiece = state.board_pieces[action.entity_id]
		if board_piece.player != state.current_player:
			return "Only a friendly BoardPiece may move."
		if board_piece.hp <= 0:
			return "A 0-HP BoardPiece cannot move."
		if not _is_orthogonally_adjacent(board_piece.cell, action.cell):
			return "A BoardPiece moves exactly one orthogonal cell."
		var origin := board_piece.cell
		board_piece.cell = action.cell
		events.append({"type": "board_piece_moved", "board_piece_id": board_piece.id, "from": origin, "to": action.cell})
		return ""
	return "Unknown movable entity kind."


func _attack(state: GameState, action: GameplayAction, events: Array[Dictionary]) -> String:
	if not state.board_pieces.has(action.entity_id):
		return "The attacking BoardPiece does not exist."
	var attacker: BoardPiece = state.board_pieces[action.entity_id]
	if attacker.player != state.current_player:
		return "Only a friendly BoardPiece may attack."
	if attacker.hp <= 0:
		return "A 0-HP BoardPiece cannot attack."
	if not attacker.is_mature:
		return "A newly deployed BoardPiece cannot attack until it matures."
	if not RuleTypes.board_piece_directions(attacker.board_piece_type).has(action.direction):
		return "The attack direction is invalid for this BoardPiece type."
	var ray := trace_ray(state, attacker.id, action.direction)
	if ray.target.is_empty():
		return "The attack ray does not reach an enemy board entity."

	var target: Dictionary = ray.target
	var actual_damage := _attack_damage_to_target(state, target)
	if target.kind == RuleTypes.EntityKind.BOARD_PIECE:
		var target_piece: BoardPiece = state.board_pieces[target.id]
		target_piece.hp = maxi(0, target_piece.hp - actual_damage)
	else:
		var target_anchor: Anchor = state.anchors[target.id]
		target_anchor.hp -= actual_damage
	events.append({
		"type": "attack_resolved",
		"attacker_id": attacker.id,
		"target": target.duplicate(),
		"damage": actual_damage,
	})
	return ""


func _attack_damage_to_target(state: GameState, target: Dictionary) -> int:
	var damage := RulesConfig.BOARD_PIECE_ATTACK
	if target.kind == RuleTypes.EntityKind.BOARD_PIECE \
			and compute_unit_chain_connection(state, target.id):
		damage = maxi(0, damage - RulesConfig.MAIN_ANCHOR_DAMAGE_REDUCTION)
	return damage


func _rapid_activation(state: GameState, action: GameplayAction, events: Array[Dictionary]) -> String:
	if not state.anchors.has(action.entity_id):
		return "The Anchor does not exist."
	var anchor: Anchor = state.anchors[action.entity_id]
	if anchor.player != state.current_player:
		return "Only a friendly Anchor may be rapidly activated."
	if anchor.deployed_turn != state.turn_number:
		return "Rapid Activation only targets an Anchor deployed this turn."
	if anchor.is_active:
		return "The Anchor is already active."
	anchor.is_active = true
	events.append({"type": "anchor_activated", "anchor_id": anchor.id, "rapid": true})
	return ""


func _end_turn(state: GameState, action: GameplayAction) -> ActionResult:
	var candidate := state.duplicate_state()
	var events: Array[Dictionary] = []
	var was_pass := candidate.categories_used.is_empty()
	_advance_turn_in_place(candidate, events, was_pass, false)
	return _complete_transition(state, candidate, action, events)


func _advance_turn_in_place(
	candidate: GameState,
	events: Array[Dictionary],
	was_pass: bool,
	was_automatic: bool
) -> void:
	var ending_player := candidate.current_player
	candidate.consecutive_passes = candidate.consecutive_passes + 1 if was_pass else 0
	if candidate.consecutive_passes >= 2:
		candidate.is_game_over = true
		_finalize_score(candidate)
		events.append({"type": "game_ended", "reason": "consecutive_passes"})
	else:
		candidate.current_player = RuleTypes.opponent(candidate.current_player)
		candidate.turn_number += 1
		candidate.categories_used.clear()
		events.append({
			"type": "turn_ended",
			"player": ending_player,
			"automatic": was_automatic,
		})
		_process_start_of_turn(candidate, events)
		_stabilize_in_place(candidate, events)


func _process_start_of_turn(state: GameState, events: Array[Dictionary]) -> void:
	for board_piece: BoardPiece in state.board_pieces.values():
		if board_piece.player == state.current_player and not board_piece.is_mature and board_piece.deployed_turn < state.turn_number:
			board_piece.is_mature = true
			events.append({"type": "board_piece_matured", "board_piece_id": board_piece.id})
	for anchor: Anchor in state.anchors.values():
		if anchor.player == state.current_player and not anchor.is_active and anchor.deployed_turn < state.turn_number:
			anchor.is_active = true
			events.append({"type": "anchor_activated", "anchor_id": anchor.id, "rapid": false})


func _stabilize_in_place(state: GameState, events: Array[Dictionary]) -> void:
	var changed := true
	while changed:
		changed = false
		if _remove_destroyed_anchors_and_bound_board_pieces(state, events):
			changed = true
		if _remove_supply_disconnected_board_pieces(state, events):
			changed = true
		# Protection is topology-dependent and is resolved after all current Supply deaths.
		if _remove_unprotected_zero_hp_board_pieces(state, events):
			changed = true
		if changed:
			continue
		if _resolve_zero_liberty_groups(state, events):
			changed = true


func _remove_destroyed_anchors_and_bound_board_pieces(state: GameState, events: Array[Dictionary]) -> bool:
	var destroyed_anchor_ids: Array[int] = []
	for anchor_id: int in _sorted_int_keys(state.anchors):
		if state.anchors[anchor_id].hp <= 0:
			destroyed_anchor_ids.append(anchor_id)
	if destroyed_anchor_ids.is_empty():
		return false

	var cascading_board_piece_ids: Array[int] = []
	for board_piece_id: int in _sorted_int_keys(state.board_pieces):
		if destroyed_anchor_ids.has(state.board_pieces[board_piece_id].main_anchor_id):
			cascading_board_piece_ids.append(board_piece_id)
	for anchor_id: int in destroyed_anchor_ids:
		state.anchors.erase(anchor_id)
		events.append({"type": "anchor_removed", "anchor_id": anchor_id, "cause": "destroyed"})
	for board_piece_id: int in cascading_board_piece_ids:
		state.board_pieces.erase(board_piece_id)
		events.append({"type": "board_piece_removed", "board_piece_id": board_piece_id, "cause": "main_anchor_death"})
	return true


func _remove_supply_disconnected_board_pieces(state: GameState, events: Array[Dictionary]) -> bool:
	var removed_ids: Array[int] = []
	for board_piece_id: int in _sorted_int_keys(state.board_pieces):
		if not compute_supply(state, board_piece_id):
			removed_ids.append(board_piece_id)
	for board_piece_id: int in removed_ids:
		state.board_pieces.erase(board_piece_id)
		events.append({"type": "board_piece_removed", "board_piece_id": board_piece_id, "cause": "supply"})
	return not removed_ids.is_empty()


func _remove_unprotected_zero_hp_board_pieces(state: GameState, events: Array[Dictionary]) -> bool:
	var removed_ids: Array[int] = []
	for board_piece_id: int in _sorted_int_keys(state.board_pieces):
		var board_piece: BoardPiece = state.board_pieces[board_piece_id]
		if board_piece.hp <= 0 and not has_dual_anchor_protection(state, board_piece_id):
			removed_ids.append(board_piece_id)
	for board_piece_id: int in removed_ids:
		state.board_pieces.erase(board_piece_id)
		events.append({"type": "board_piece_removed", "board_piece_id": board_piece_id, "cause": "zero_hp"})
	return not removed_ids.is_empty()


func _resolve_zero_liberty_groups(state: GameState, events: Array[Dictionary]) -> bool:
	var anchors_to_remove: Dictionary = {}
	var board_pieces_to_remove: Dictionary = {}
	for player in [RuleTypes.Player.BLACK, RuleTypes.Player.WHITE]:
		for group: Dictionary in compute_friendly_groups(state, player):
			if not compute_liberties(state, group).is_empty():
				continue
			var protected_piece_exists := false
			for entity: Dictionary in group.entities:
				if entity.kind == RuleTypes.EntityKind.BOARD_PIECE and has_dual_anchor_protection(state, entity.id):
					protected_piece_exists = true
					break
			for entity: Dictionary in group.entities:
				if entity.kind == RuleTypes.EntityKind.BOARD_PIECE:
					if not has_dual_anchor_protection(state, entity.id):
						board_pieces_to_remove[entity.id] = true
				elif not protected_piece_exists:
					anchors_to_remove[entity.id] = true
	if anchors_to_remove.is_empty() and board_pieces_to_remove.is_empty():
		return false
	for board_piece_id: int in _sorted_int_keys(board_pieces_to_remove):
		state.board_pieces.erase(board_piece_id)
		events.append({"type": "board_piece_removed", "board_piece_id": board_piece_id, "cause": "no_liberty"})
	var cascading_board_piece_ids: Dictionary = {}
	for board_piece_id: int in _sorted_int_keys(state.board_pieces):
		if anchors_to_remove.has(state.board_pieces[board_piece_id].main_anchor_id):
			cascading_board_piece_ids[board_piece_id] = true
	for anchor_id: int in _sorted_int_keys(anchors_to_remove):
		state.anchors.erase(anchor_id)
		events.append({"type": "anchor_removed", "anchor_id": anchor_id, "cause": "no_liberty"})
	for board_piece_id: int in _sorted_int_keys(cascading_board_piece_ids):
		state.board_pieces.erase(board_piece_id)
		events.append({"type": "board_piece_removed", "board_piece_id": board_piece_id, "cause": "main_anchor_death"})
	return true


func _complete_transition(
	previous_state: GameState,
	candidate: GameState,
	action: GameplayAction,
	events: Array[Dictionary]
) -> ActionResult:
	var hash := state_hash(candidate)
	if previous_state.seen_state_hashes.has(hash):
		return ActionResult.new(false, previous_state, "The transition would recreate a previously seen complete state.")
	candidate.seen_state_hashes[hash] = true
	candidate.action_log.append({
		"turn": previous_state.turn_number,
		"player": previous_state.current_player,
		"action": action.to_dictionary(),
		"resulting_state_hash": hash,
	})
	return ActionResult.new(true, candidate, "", events)


func _finalize_score(state: GameState) -> void:
	var scores := score(state)
	state.black_score = scores.black
	state.white_score = scores.white
	if state.black_score > state.white_score:
		state.outcome = RuleTypes.Outcome.BLACK_WIN
	elif state.white_score > state.black_score:
		state.outcome = RuleTypes.Outcome.WHITE_WIN
	else:
		state.outcome = RuleTypes.Outcome.DRAW


func _is_supply_traversable(state: GameState, cell: Vector2i, player: RuleTypes.Player) -> bool:
	if not state.map_definition.is_passable(cell):
		return false
	var entity := state.entity_at(cell)
	return entity.is_empty() or state.entity_player(entity) == player


func _friendly_entity_cells_reachable(
	state: GameState,
	start: Vector2i,
	player: RuleTypes.Player
) -> Dictionary:
	var start_entity := state.entity_at(start)
	if start_entity.is_empty() or state.entity_player(start_entity) != player:
		return {}
	var visited := {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for direction: Vector2i in RuleTypes.ORTHOGONAL_DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if visited.has(neighbor):
				continue
			var entity := state.entity_at(neighbor)
			if not entity.is_empty() and state.entity_player(entity) == player:
				visited[neighbor] = true
				frontier.append(neighbor)
	return visited


func _append_placement_actions(state: GameState, actions: Array[GameplayAction]) -> void:
	var friendly_anchors: Array[int] = []
	for anchor_id: int in _sorted_int_keys(state.anchors):
		var anchor: Anchor = state.anchors[anchor_id]
		if anchor.player == state.current_player and _bound_board_piece_count(state, anchor_id) < RulesConfig.ANCHOR_BINDING_CAPACITY:
			friendly_anchors.append(anchor_id)
	for y in range(state.map_definition.height):
		for x in range(state.map_definition.width):
			var cell := Vector2i(x, y)
			if not state.map_definition.is_passable(cell) or not state.is_cell_empty(cell):
				continue
			if state.map_definition.is_anchor_valid(cell) and state.anchors_deployed[state.current_player] < RulesConfig.ANCHOR_DEPLOYMENT_LIMIT:
				actions.append(GameplayAction.place_anchor(cell))
			for anchor_id: int in friendly_anchors:
				actions.append(GameplayAction.place_board_piece(RuleTypes.BoardPieceType.ORTHOGONAL, cell, anchor_id))
				actions.append(GameplayAction.place_board_piece(RuleTypes.BoardPieceType.DIAGONAL, cell, anchor_id))


func _append_movement_actions(state: GameState, actions: Array[GameplayAction]) -> void:
	for anchor_id: int in _sorted_int_keys(state.anchors):
		var anchor: Anchor = state.anchors[anchor_id]
		if anchor.player != state.current_player:
			continue
		for direction: Vector2i in RuleTypes.ORTHOGONAL_DIRECTIONS:
			var destination := anchor.cell + direction
			if state.map_definition.is_anchor_valid(destination) and state.is_cell_empty(destination):
				actions.append(GameplayAction.move(RuleTypes.EntityKind.ANCHOR, anchor_id, destination))
	for board_piece_id: int in _sorted_int_keys(state.board_pieces):
		var board_piece: BoardPiece = state.board_pieces[board_piece_id]
		if board_piece.player != state.current_player or board_piece.hp <= 0:
			continue
		for direction: Vector2i in RuleTypes.ORTHOGONAL_DIRECTIONS:
			var destination := board_piece.cell + direction
			if state.map_definition.is_passable(destination) and state.is_cell_empty(destination):
				actions.append(GameplayAction.move(RuleTypes.EntityKind.BOARD_PIECE, board_piece_id, destination))


func _append_core_actions(state: GameState, actions: Array[GameplayAction]) -> void:
	for anchor_id: int in _sorted_int_keys(state.anchors):
		var anchor: Anchor = state.anchors[anchor_id]
		if anchor.player == state.current_player and not anchor.is_active and anchor.deployed_turn == state.turn_number:
			actions.append(GameplayAction.rapid_activation(anchor_id))
	for board_piece_id: int in _sorted_int_keys(state.board_pieces):
		var board_piece: BoardPiece = state.board_pieces[board_piece_id]
		if board_piece.player != state.current_player or board_piece.hp <= 0 or not board_piece.is_mature:
			continue
		for direction: Vector2i in RuleTypes.board_piece_directions(board_piece.board_piece_type):
			if not trace_ray(state, board_piece_id, direction).target.is_empty():
				actions.append(GameplayAction.attack(board_piece_id, direction))


func _bound_board_piece_count(state: GameState, anchor_id: int) -> int:
	var count := 0
	for board_piece: BoardPiece in state.board_pieces.values():
		if board_piece.main_anchor_id == anchor_id:
			count += 1
	return count


func _cluster_index_containing(clusters: Array[Array], anchor_id: int) -> int:
	for index in range(clusters.size()):
		if clusters[index].has(anchor_id):
			return index
	return -1


func _group_debug_data(state: GameState, entity_kind: RuleTypes.EntityKind, entity_id: int) -> Dictionary:
	var entity := {"kind": entity_kind, "id": entity_id}
	var player := state.entity_player(entity)
	var groups := compute_friendly_groups(state, player)
	for group_index in range(groups.size()):
		var group: Dictionary = groups[group_index]
		for member: Dictionary in group.entities:
			if member.kind == entity_kind and member.id == entity_id:
				var has_protected_piece := false
				for possible_piece: Dictionary in group.entities:
					if possible_piece.kind == RuleTypes.EntityKind.BOARD_PIECE and has_dual_anchor_protection(state, possible_piece.id):
						has_protected_piece = true
				return {
					"id": "%d:%d" % [player, group_index],
					"liberty_count": compute_liberties(state, group).size(),
					"has_protected_board_piece": has_protected_piece,
				}
	return {"id": "", "liberty_count": 0, "has_protected_board_piece": false}


func _is_orthogonally_adjacent(first: Vector2i, second: Vector2i) -> bool:
	var delta := first - second
	return absi(delta.x) + absi(delta.y) == 1


func _sorted_int_keys(dictionary: Dictionary) -> Array[int]:
	var keys: Array[int] = []
	keys.assign(dictionary.keys())
	keys.sort()
	return keys


func _sort_cells(cells: Array[Vector2i]) -> void:
	cells.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
		return first.y < second.y or (first.y == second.y and first.x < second.x)
	)
