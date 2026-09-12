# Pure connectivity queries shared by damage, protection, and stabilization.
extends RefCounted
const State = preload("res://engine/game_state.gd")

static func network(state: Dictionary, start: Vector2i, owner: int, empty: bool = false, anchors_only: bool = false) -> Array:
	var pending = [start]
	var visited: Array = []
	var all = State.entities(state)
	while not pending.is_empty():
		var cell = pending.pop_back()
		if cell in visited or not State.inside(cell):
			continue
		var id = State.at(state, cell)
		if id == -1:
			if not empty:
				continue
		elif all[id].owner != owner or (anchors_only and all[id].kind != "Anchor"):
			continue
		visited.append(cell)
		for direction in State.ORTHOGONAL:
			pending.append(cell + direction)
	return visited

static func supply(state: Dictionary, id: int) -> bool:
	var piece = state.board_pieces[id]
	if not state.anchors.has(piece.main_anchor):
		return false
	return state.anchors[piece.main_anchor].cell in network(state, piece.cell, piece.owner, true)

static func unit_chain(state: Dictionary, id: int) -> bool:
	var piece = state.board_pieces[id]
	return state.anchors.has(piece.main_anchor) and state.anchors[piece.main_anchor].cell in network(state, piece.cell, piece.owner)

static func protected(state: Dictionary, id: int) -> bool:
	var piece = state.board_pieces[id]
	if not piece.mature or not supply(state, id):
		return false
	var main = state.anchors[piece.main_anchor]
	var cluster = network(state, main.cell, piece.owner, false, true)
	var connected = network(state, piece.cell, piece.owner)
	for anchor in state.anchors.values():
		if anchor.owner == piece.owner and anchor.active and anchor.cell in connected and anchor.cell not in cluster:
			return true
	return false

static func groups(state: Dictionary) -> Array:
	var result: Array = []
	var visited: Array = []
	for entity in State.entities(state).values():
		if entity.cell not in visited:
			var cells = network(state, entity.cell, entity.owner)
			visited.append_array(cells)
			result.append(cells)
	return result

static func liberties(state: Dictionary, cells: Array) -> Array:
	var result: Array = []
	for cell in cells:
		for direction in State.ORTHOGONAL:
			var adjacent = cell + direction
			if State.inside(adjacent) and State.at(state, adjacent) == -1 and adjacent not in result:
				result.append(adjacent)
	return result
