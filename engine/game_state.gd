# Serializable simulation state. Anchors and BoardPieces have separate registries.
extends RefCounted

const SIZE = 7
const ANCHOR_HP = 3
const BOARD_PIECE_HP = 2
const ATTACK = 2
const RANGE = 6
const CAPACITY = 3
const ANCHOR_LIMIT = 12
const ORTHOGONAL = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAGONAL = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

static func create() -> Dictionary:
	return {"anchors": {}, "board_pieces": {}, "side": 0, "used": [],
		"deployed": [0, 0], "next_id": 1, "passes": 0, "finished": false,
		"history": [], "log": []}

static func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE

static func anchor_valid(cell: Vector2i) -> bool:
	return inside(cell) and cell.x > 0 and cell.y > 0 and cell.x < SIZE - 1 and cell.y < SIZE - 1

static func entities(state: Dictionary) -> Dictionary:
	var result = state.anchors.duplicate()
	result.merge(state.board_pieces)
	return result

static func at(state: Dictionary, cell: Vector2i) -> int:
	for registry in [state.anchors, state.board_pieces]:
		for id in registry:
			if registry[id].cell == cell:
				return id
	return -1

# Canonical board identity excludes logging, ID allocation, and turn counters.
# Anchor references are represented by their current cells, preserving binding
# relationships without making interchangeable physical labels defeat repetition.
static func position_key(state: Dictionary) -> String:
	var rows: Array = []
	for entity in entities(state).values():
		var row = [entity.cell.x, entity.cell.y, entity.owner, entity.kind, entity.hp]
		if entity.kind == "Anchor":
			row.append(entity.active)
		else:
			row.append(entity.mature)
			var main = state.anchors.get(entity.main_anchor, {})
			row.append([main.cell.x, main.cell.y] if not main.is_empty() else [])
		rows.append(JSON.stringify(row))
	rows.sort()
	var categories = state.used.duplicate()
	categories.sort()
	return JSON.stringify([rows, state.side, categories, state.deployed, state.passes, state.finished])
