# One selected discrete ray, stopping at the original first blocking entity.
extends RefCounted
const State = preload("res://engine/game_state.gd")
const Topology = preload("res://engine/topology.gd")

static func target(state: Dictionary, id: int, direction: Vector2i) -> int:
	if not state.board_pieces.has(id):
		return -1
	var attacker = state.board_pieces[id]
	var directions = State.ORTHOGONAL if attacker.kind == "O" else State.DIAGONAL
	if direction not in directions:
		return -1
	var all = State.entities(state)
	for distance in range(1, State.RANGE + 1):
		var cell = attacker.cell + direction * distance
		if not State.inside(cell):
			break
		var other = State.at(state, cell)
		if other == -1:
			continue
		if all[other].owner != attacker.owner:
			return other
		if all[other].kind == "Anchor" or all[other].hp <= 0:
			break
	return -1

static func damage(state: Dictionary, id: int) -> void:
	var amount = State.ATTACK
	if state.board_pieces.has(id) and Topology.unit_chain(state, id):
		amount -= 1
	var entity = State.entities(state)[id]
	entity.hp = maxi(0, entity.hp - amount)

	# Direct lethal damage resolves before topology-dependent supply deaths.
	if entity.hp == 0 and state.board_pieces.has(id) and not Topology.protected(state, id):
		state.board_pieces.erase(id)
