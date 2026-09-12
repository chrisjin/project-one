# Headless authoritative entry point. Public transitions never mutate their input.
extends RefCounted
const State = preload("res://engine/game_state.gd")
const Topology = preload("res://engine/topology.gd")
const Stabilization = preload("res://engine/stabilization.gd")
const Combat = preload("res://engine/combat.gd")

static func new_game() -> Dictionary:
	var state = State.create()
	state.history.append(State.position_key(state))
	return state

static func category(action: Dictionary) -> String:
	match action.get("type", ""):
		"deploy_anchor", "deploy_board_piece": return "Placement"
		"move": return "Movement"
		"attack", "rapid_activation": return "Action"
	return ""

static func validate(state: Dictionary, action: Dictionary) -> String:
	if state.finished:
		return "Game has ended."
	if action.get("type", "") == "end_turn":
		return ""
	var used_category = category(action)
	if used_category == "":
		return "Unknown action."
	if used_category in state.used or state.used.size() >= 2:
		return "Action category unavailable."
	var kind = action.type
	if kind in ["deploy_anchor", "deploy_board_piece", "move"]:
		if typeof(action.get("cell")) != TYPE_VECTOR2I:
			return "Expected a Vector2i destination."
		if not State.inside(action.cell) or State.at(state, action.cell) != -1:
			return "Destination must be an empty board cell."
	if kind == "deploy_anchor":
		if not State.anchor_valid(action.cell) or state.deployed[state.side] >= State.ANCHOR_LIMIT:
			return "Anchor area or deployment limit violation."
		return ""
	if kind == "deploy_board_piece":
		if action.get("kind", "") not in ["O", "D"]:
			return "Unknown BoardPiece type."
		var main_id = action.get("main_anchor", -1)
		if not state.anchors.has(main_id) or state.anchors[main_id].owner != state.side:
			return "Choose a surviving friendly Main Anchor."
		var bound = 0
		for piece in state.board_pieces.values():
			if piece.main_anchor == main_id:
				bound += 1
		return "Main Anchor is full." if bound >= State.CAPACITY else ""
	var id = action.get("id", -1)
	var all = State.entities(state)
	if not all.has(id) or all[id].owner != state.side:
		return "Choose a surviving friendly entity."
	var entity = all[id]
	if kind == "move":
		if entity.hp <= 0 or action.cell - entity.cell not in State.ORTHOGONAL:
			return "Movement requires positive HP and one orthogonal step."
		if entity.kind == "Anchor" and not State.anchor_valid(action.cell):
			return "Destination is not Anchor-valid."
	elif kind == "rapid_activation":
		if entity.kind != "Anchor" or entity.active:
			return "Choose an inactive Anchor deployed this turn."
	elif kind == "attack":
		if entity.kind == "Anchor" or entity.hp <= 0 or not entity.mature:
			return "Only mature positive-HP BoardPieces attack."
		var directions = State.ORTHOGONAL if entity.kind == "O" else State.DIAGONAL
		if action.get("direction") not in directions:
			return "Choose one allowed ray direction."
	return ""

static func apply_action(state: Dictionary, action: Dictionary) -> Dictionary:
	var error = validate(state, action)
	if error != "":
		return {"ok": false, "error": error, "state": state}
	var next = state.duplicate(true)
	if action.type == "end_turn":
		finish_turn(next)
	else:
		execute(next, action)
		next.used.append(category(action))
		Stabilization.resolve(next)
	var key = State.position_key(next)
	if key in state.history:
		return {"ok": false, "error": "Repeated complete state.", "state": state}
	next.history.append(key)
	next.log.append(action.duplicate(true))
	return {"ok": true, "error": "", "state": next}

static func execute(state: Dictionary, action: Dictionary) -> void:
	match action.type:
		"deploy_anchor", "deploy_board_piece":
			var id = state.next_id
			state.next_id += 1
			var entity = {"id": id, "owner": state.side, "cell": action.cell}
			if action.type == "deploy_anchor":
				entity.merge({"kind": "Anchor", "hp": State.ANCHOR_HP, "active": false})
				state.anchors[id] = entity
				state.deployed[state.side] += 1
			else:
				entity.merge({"kind": action.kind, "hp": State.BOARD_PIECE_HP,
					"mature": false, "main_anchor": action.main_anchor})
				state.board_pieces[id] = entity
		"move":
			State.entities(state)[action.id].cell = action.cell
		"rapid_activation":
			state.anchors[action.id].active = true
		"attack":
			var target = Combat.target(state, action.id, action.direction)
			if target != -1:
				Combat.damage(state, target)

static func finish_turn(state: Dictionary) -> void:
	state.passes = state.passes + 1 if state.used.is_empty() else 0
	if state.passes == 2:
		state.finished = true
		return
	state.side = 1 - state.side
	state.used.clear()
	for anchor in state.anchors.values():
		if anchor.owner == state.side:
			anchor.active = true
	for piece in state.board_pieces.values():
		if piece.owner == state.side:
			piece.mature = true
	Stabilization.resolve(state)

static func score(state: Dictionary) -> Array:
	var scores = [0, 0]
	for piece in state.board_pieces.values():
		scores[piece.owner] += 1
	return scores

static func winner(state: Dictionary) -> String:
	if not state.finished:
		return "ongoing"
	var scores = score(state)
	return "draw" if scores[0] == scores[1] else ("Black" if scores[0] > scores[1] else "White")

static func legal_actions(state: Dictionary) -> Array:
	var candidates: Array = [{"type": "end_turn"}]
	for y in range(State.SIZE):
		for x in range(State.SIZE):
			var cell = Vector2i(x, y)
			if State.at(state, cell) != -1:
				continue
			candidates.append({"type": "deploy_anchor", "cell": cell})
			for id in state.anchors:
				for kind in ["O", "D"]:
					candidates.append({"type": "deploy_board_piece", "cell": cell, "kind": kind, "main_anchor": id})
	for id in State.entities(state):
		var entity = State.entities(state)[id]
		for direction in State.ORTHOGONAL:
			candidates.append({"type": "move", "id": id, "cell": entity.cell + direction})
		if entity.kind == "Anchor":
			candidates.append({"type": "rapid_activation", "id": id})
		else:
			for direction in (State.ORTHOGONAL if entity.kind == "O" else State.DIAGONAL):
				candidates.append({"type": "attack", "id": id, "direction": direction})
	var legal: Array = []
	for action in candidates:
		if apply_action(state, action).ok:
			legal.append(action)
	return legal

static func replay(actions: Array) -> Dictionary:
	var state = new_game()
	for action in actions:
		var result = apply_action(state, action)
		if not result.ok:
			return result
		state = result.state
	return {"ok": true, "error": "", "state": state}

static func state_hash(state: Dictionary) -> String:
	return State.position_key(state).sha256_text()

# JSON records contain commands only; replay reconstructs state and repetition history.
static func export_record(state: Dictionary) -> String:
	var actions = state.log.duplicate(true)
	for action in actions:
		for field in ["cell", "direction"]:
			if action.has(field):
				action[field] = [action[field].x, action[field].y]
	return JSON.stringify({"version": 1, "actions": actions})

static func import_record(record: String) -> Dictionary:
	var parsed = JSON.parse_string(record)
	if typeof(parsed) != TYPE_DICTIONARY or parsed.get("version") != 1 or typeof(parsed.get("actions")) != TYPE_ARRAY:
		return {"ok": false, "error": "Invalid game record.", "state": new_game()}
	for action in parsed.actions:
		if typeof(action) != TYPE_DICTIONARY:
			return {"ok": false, "error": "Invalid command.", "state": new_game()}
		for field in ["cell", "direction"]:
			if action.has(field):
				var value = action[field]
				if typeof(value) != TYPE_ARRAY or value.size() != 2:
					return {"ok": false, "error": "Invalid coordinate.", "state": new_game()}
				for coordinate in value:
					if typeof(coordinate) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(coordinate) or coordinate != floor(coordinate):
						return {"ok": false, "error": "Invalid coordinate.", "state": new_game()}
				action[field] = Vector2i(int(value[0]), int(value[1]))
		for field in ["id", "main_anchor"]:
			if action.has(field):
				if typeof(action[field]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(action[field]) or action[field] != floor(action[field]):
					return {"ok": false, "error": "Invalid entity ID.", "state": new_game()}
				action[field] = int(action[field])
	return replay(parsed.actions)
