# Fixed-point deaths; each phase judges an unchanged topology before removal.
extends RefCounted
const Topology = preload("res://engine/topology.gd")
const State = preload("res://engine/game_state.gd")

static func remove(state: Dictionary, ids: Array) -> void:
	for id in ids:
		state.anchors.erase(id)
		state.board_pieces.erase(id)

static func resolve(state: Dictionary) -> void:
	while true:
		var dead: Array = []
		for id in state.anchors:
			if state.anchors[id].hp <= 0:
				dead.append(id)
		remove(state, dead)
		# Main Anchor deaths remove their bound BoardPieces before supply queries.
		dead = []
		for id in state.board_pieces:
			if not state.anchors.has(state.board_pieces[id].main_anchor):
				dead.append(id)
		remove(state, dead)
		dead = []
		for id in state.board_pieces:
			if not Topology.supply(state, id):
				dead.append(id)
		if not dead.is_empty():
			remove(state, dead)
			continue
		for id in state.board_pieces:
			if state.board_pieces[id].hp <= 0 and not Topology.protected(state, id):
				dead.append(id)
		if not dead.is_empty():
			remove(state, dead)
			continue
		# All zero-liberty groups are judged before any of their deaths open cells.
		for group in Topology.groups(state):
			if not Topology.liberties(state, group).is_empty():
				continue
			var immortal = false
			for cell in group:
				var id = State.at(state, cell)
				if state.board_pieces.has(id):
					if Topology.protected(state, id):
						immortal = true
					else:
						dead.append(id)
			if not immortal:
				for cell in group:
					var id = State.at(state, cell)
					if state.anchors.has(id):
						dead.append(id)
		if dead.is_empty():
			return
		remove(state, dead)
