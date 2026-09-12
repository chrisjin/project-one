# Deterministic direct simulation regressions; no gameplay scenes are loaded.
extends SceneTree
const EngineRules = preload("res://engine/rules_engine.gd")
const State = preload("res://engine/game_state.gd")
const Topology = preload("res://engine/topology.gd")
const Stabilization = preload("res://engine/stabilization.gd")
const Combat = preload("res://engine/combat.gd")
var checks = 0
var failures = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func anchor(state: Dictionary, cell: Vector2i, owner: int = 0, active: bool = true) -> int:
	var id = state.next_id
	state.next_id += 1
	state.anchors[id] = {"id": id, "kind": "Anchor", "cell": cell, "owner": owner, "hp": 3, "active": active}
	state.deployed[owner] += 1
	return id

func piece(state: Dictionary, cell: Vector2i, main: int, owner: int = 0, hp: int = 2, mature: bool = true, kind: String = "O") -> int:
	var id = state.next_id
	state.next_id += 1
	state.board_pieces[id] = {"id": id, "kind": kind, "cell": cell, "owner": owner, "hp": hp, "mature": mature, "main_anchor": main}
	return id

func act(state: Dictionary, action: Dictionary) -> Dictionary:
	var before = var_to_bytes(state)
	var result = EngineRules.apply_action(state, action)
	check(result.ok, "Expected legal action: " + str(action) + " " + result.error)
	check(before == var_to_bytes(state), "Input state mutated")
	return result.state

func _initialize() -> void:
	test_turns()
	test_connections()
	test_rays()
	test_no_liberty()
	test_repetition()
	test_supply_actions()
	test_cascade_precedes_supply()
	print("Headless rules: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func test_turns() -> void:
	var state = EngineRules.new_game()
	check(EngineRules.legal_actions(state).size() == 26, "Opening legal actions")
	check(not EngineRules.apply_action(state, {"type": "deploy_anchor", "cell": Vector2i.ZERO}).ok, "Anchor border rejected")
	state = act(state, {"type": "deploy_anchor", "cell": Vector2i(2, 2)})
	check(not state.anchors[1].active, "New Anchor inactive")
	check(not EngineRules.apply_action(state, {"type": "deploy_anchor", "cell": Vector2i(3, 2)}).ok, "Repeated Placement rejected")
	state = act(state, {"type": "rapid_activation", "id": 1})
	check(state.anchors[1].active, "Rapid Activation")
	check(not EngineRules.apply_action(state, {"type": "move", "id": 1, "cell": Vector2i(2, 3)}).ok, "Third category rejected")
	state = act(state, {"type": "end_turn"})
	state = act(state, {"type": "end_turn"})
	state = act(state, {"type": "deploy_board_piece", "cell": Vector2i(3, 2), "kind": "D", "main_anchor": 1})
	check(not EngineRules.apply_action(state, {"type": "attack", "id": 2, "direction": Vector2i(1, 1)}).ok, "Immature attack rejected")
	state = act(state, {"type": "move", "id": 2, "cell": Vector2i(3, 3)})
	state = act(state, {"type": "end_turn"})
	state = act(state, {"type": "end_turn"})
	check(state.board_pieces[2].mature, "Maturation at next own turn")
	var replay = EngineRules.replay(state.log)
	check(replay.ok and var_to_bytes(replay.state) == var_to_bytes(state), "Exact deterministic replay")
	var restored = EngineRules.import_record(EngineRules.export_record(state))
	check(restored.ok and EngineRules.state_hash(restored.state) == EngineRules.state_hash(state), "JSON replay round trip")
	check(not EngineRules.import_record('{}').ok, "Malformed record rejected")
	check(not EngineRules.import_record('{"version":1,"actions":[{"type":"move","cell":[1.5,2]}]}').ok, "Fractional coordinate rejected")
	state = act(state, {"type": "end_turn"})
	check(state.finished and EngineRules.winner(state) == "Black", "Consecutive passes and scoring")
	check(not EngineRules.apply_action(state, {"type": "end_turn"}).ok, "Finished game rejects actions")
	state = EngineRules.new_game()
	state = act(state, {"type": "end_turn"})
	state = act(state, {"type": "end_turn"})
	check(state.finished and EngineRules.winner(state) == "draw", "Empty game passes do not conflict with repetition")
	state = State.create()
	var main = anchor(state, Vector2i(2, 2), 0, false)
	state.side = 1
	state = act(state, {"type": "end_turn"})
	check(state.anchors[main].active, "Automatic activation")
	for cell in [Vector2i(1, 2), Vector2i(2, 1), Vector2i(3, 2)]:
		piece(state, cell, main)
	var deploy = {"type": "deploy_board_piece", "cell": Vector2i(4, 4), "kind": "O", "main_anchor": main}
	check(not EngineRules.apply_action(state, deploy).ok, "Binding capacity enforced")
	state.board_pieces.erase(2)
	check(EngineRules.apply_action(state, deploy).ok, "True death frees binding slot")
	state.deployed[0] = 12
	check(not EngineRules.apply_action(state, {"type": "deploy_anchor", "cell": Vector2i(4, 4)}).ok, "Lifetime deployment cap")

func test_connections() -> void:
	var state = State.create()
	var main = anchor(state, Vector2i(1, 1))
	var id = piece(state, Vector2i(3, 1), main)
	check(Topology.supply(state, id) and not Topology.unit_chain(state, id), "Empty supply is not damage reduction")
	Combat.damage(state, id)
	check(not state.board_pieces.has(id), "Unconnected takes full lethal damage")
	id = piece(state, Vector2i(3, 1), main)
	var bridge = piece(state, Vector2i(2, 1), main)
	check(Topology.unit_chain(state, id), "Friendly chain grants reduction")
	Combat.damage(state, id)
	check(state.board_pieces[id].hp == 1, "Main chain reduces damage")
	var secondary = anchor(state, Vector2i(4, 1))
	check(Topology.protected(state, id), "Distinct active Secondary protects")
	state.board_pieces[id].hp = 0
	Stabilization.resolve(state)
	check(state.board_pieces.has(id) and EngineRules.score(state)[0] == 2, "Legal zero HP survives and scores")
	check(not EngineRules.apply_action(state, {"type": "move", "id": id, "cell": Vector2i(3, 2)}).ok, "Zero HP cannot move")
	check(not EngineRules.apply_action(state, {"type": "attack", "id": id, "direction": Vector2i.RIGHT}).ok, "Zero HP cannot attack")
	var immature = state.duplicate(true)
	immature.board_pieces[id].mature = false
	Stabilization.resolve(immature)
	check(not immature.board_pieces.has(id), "Immature zero HP dies")
	var inactive = state.duplicate(true)
	inactive.anchors[secondary].active = false
	Stabilization.resolve(inactive)
	check(not inactive.board_pieces.has(id), "Inactive Secondary cannot save zero HP")
	var cascade = state.duplicate(true)
	cascade.anchors[main].hp = 0
	Stabilization.resolve(cascade)
	check(cascade.board_pieces.is_empty(), "Main death kills positive and protected zero HP")
	state.board_pieces.erase(bridge)
	check(Topology.protected(state, id) and not Topology.unit_chain(state, id), "Secondary-only protection without reduction")
	state.anchors[secondary].cell = Vector2i(5, 1)
	Stabilization.resolve(state)
	check(not state.board_pieces.has(id), "Secondary connection loss removes zero HP")
	state = State.create()
	main = anchor(state, Vector2i(1, 1))
	secondary = anchor(state, Vector2i(2, 1))
	id = piece(state, Vector2i(2, 2), main)
	check(not Topology.protected(state, id), "Same Cluster not Secondary")
	state.anchors[secondary].cell = Vector2i(3, 2)
	check(Topology.protected(state, id), "Cluster split changes protection")
	state.anchors[main].cell = Vector2i(2, 1)
	state.board_pieces[id].hp = 0
	state = act(state, {"type": "move", "id": secondary, "cell": Vector2i(3, 1)})
	check(not state.board_pieces.has(id), "Cluster merge kills zero HP")

func test_rays() -> void:
	var state = State.create()
	var main = anchor(state, Vector2i(1, 2))
	var enemy_main = anchor(state, Vector2i(5, 2), 1)
	var attacker = piece(state, Vector2i(0, 0), main)
	var transparent = piece(state, Vector2i(1, 0), main)
	var target = piece(state, Vector2i(3, 0), enemy_main, 1)
	var behind = piece(state, Vector2i(4, 0), enemy_main, 1)
	check(Combat.target(state, attacker, Vector2i.RIGHT) == target, "Friendly positive HP transparent, first enemy selected")
	state.board_pieces[transparent].hp = 0
	check(Combat.target(state, attacker, Vector2i.RIGHT) == -1, "Friendly zero HP blocks")
	state.board_pieces.erase(transparent)
	var blocker = anchor(state, Vector2i(2, 0), 0, false)
	check(Combat.target(state, attacker, Vector2i.RIGHT) == -1, "Inactive friendly Anchor blocks")
	state.anchors.erase(blocker)
	state = act(state, {"type": "attack", "id": attacker, "direction": Vector2i.RIGHT})
	check(not state.board_pieces.has(target) and state.board_pieces[behind].hp == 2, "Destroyed target does not expose next target in same attack")
	state.used.clear()
	state.board_pieces[behind].cell = Vector2i(6, 0)
	check(Combat.target(state, attacker, Vector2i.RIGHT) == behind, "Range includes sixth step")
	check(Combat.target(state, attacker, Vector2i(1, 1)) == -1, "O rejects diagonal")
	state.board_pieces[attacker].kind = "D"
	state.board_pieces[behind].cell = Vector2i(6, 6)
	check(Combat.target(state, attacker, Vector2i(1, 1)) == behind, "D diagonal reaches sixth step")
	check(Combat.target(state, attacker, Vector2i.RIGHT) == -1, "D rejects orthogonal")
	state = State.create()
	main = anchor(state, Vector2i(1, 1))
	attacker = piece(state, Vector2i(1, 0), main)
	var east = anchor(state, Vector2i(3, 0), 1)
	var west = anchor(state, Vector2i(0, 0), 1)
	state = act(state, {"type": "attack", "id": attacker, "direction": Vector2i.RIGHT})
	check(state.anchors[east].hp == 1 and state.anchors[west].hp == 3, "Only selected ray fires")

# Enemy boundary has exterior liberties. The interior is a 2x2 corner region.
func enclosure() -> Dictionary:
	var state = State.create()
	for cell in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2)]:
		anchor(state, cell, 1)
	return state

func test_no_liberty() -> void:
	var state = enclosure()
	var main = anchor(state, Vector2i(1, 1))
	for cell in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		piece(state, cell, main)
	Stabilization.resolve(state)
	check(not state.anchors.has(main) and state.board_pieces.is_empty(), "Entire one-Anchor group dies in same judgment")
	state = enclosure()
	main = anchor(state, Vector2i(4, 4))
	var internal = anchor(state, Vector2i(1, 1))
	for cell in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		piece(state, cell, main)
	Stabilization.resolve(state)
	check(state.board_pieces.is_empty() and state.anchors.has(internal), "Supply deaths open liberties before No-Liberty")
	state = State.create()
	main = anchor(state, Vector2i(2, 2))
	for direction in State.ORTHOGONAL:
		anchor(state, Vector2i(2, 2) + direction, 1)
	Stabilization.resolve(state)
	check(not state.anchors.has(main), "Bare surrounded Anchor dies")
	state = enclosure()
	main = anchor(state, Vector2i(0, 0))
	var secondary = anchor(state, Vector2i(1, 1))
	piece(state, Vector2i(1, 0), main, 0, 0)
	piece(state, Vector2i(0, 1), secondary)
	Stabilization.resolve(state)
	check(state.anchors.has(main) and state.anchors.has(secondary) and state.board_pieces.size() == 2, "Dual-protected zero-liberty structure survives")

func test_repetition() -> void:
	var state = State.create()
	var main = anchor(state, Vector2i(2, 2))
	var action = {"type": "move", "id": main, "cell": Vector2i(3, 2)}
	var next = EngineRules.apply_action(state, action).state
	state.history.append(State.position_key(next))
	var before = var_to_bytes(state)
	check(not EngineRules.apply_action(state, action).ok, "Repeated complete state rejected")
	check(before == var_to_bytes(state), "Repetition rejection atomic")
	var alternate = state.duplicate(true)
	alternate.next_id = 100
	check(State.position_key(state) == State.position_key(alternate), "ID allocator cannot defeat repetition")
	alternate.used.append("Movement")
	check(State.position_key(state) != State.position_key(alternate), "Categories distinguish complete states")

func test_supply_actions() -> void:
	var state = State.create()
	var main = anchor(state, Vector2i(1, 1))
	# Enemy wall has one opening occupied by the Main Anchor.
	for y in range(7):
		if y != 1:
			anchor(state, Vector2i(1, y), 1)
	var id = piece(state, Vector2i(0, 1), main)
	check(Topology.supply(state, id), "Supply reaches Main Anchor in wall opening")
	state = act(state, {"type": "move", "id": main, "cell": Vector2i(2, 1)})
	check(state.board_pieces.has(id), "Moving Anchor leaves an empty supply route")
	state = act(state, {"type": "end_turn"})
	state = act(state, {"type": "deploy_anchor", "cell": Vector2i(1, 1)})
	check(not state.board_pieces.has(id), "Enemy placement cuts supply immediately")
	state = act(state, {"type": "end_turn"})
	state = act(state, {"type": "deploy_board_piece", "cell": Vector2i(0, 1), "kind": "O", "main_anchor": main})
	check(state.board_pieces.is_empty() and "Placement" in state.used, "Unsupplied deployment consumes Placement and dies")
	# A moving Main Anchor crosses a one-cell gate between sealed regions.
	state = State.create()
	main = anchor(state, Vector2i(2, 2))
	id = piece(state, Vector2i(1, 2), main)
	for cell in [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 2), Vector2i(3, 3), Vector2i(2, 3)]:
		anchor(state, cell, 1)
	state = act(state, {"type": "move", "id": main, "cell": Vector2i(3, 2)})
	check(state.board_pieces.has(id), "Orthogonal Anchor move maintains empty-cell supply unless later resolution cuts it")
	# Destroying the first target Anchor cascades to a bound piece elsewhere.
	state = State.create()
	main = anchor(state, Vector2i(1, 1))
	var enemy = anchor(state, Vector2i(4, 1), 1)
	state.anchors[enemy].hp = 1
	var attacker = piece(state, Vector2i(2, 1), main)
	var victim = piece(state, Vector2i(5, 1), enemy, 1)
	state = act(state, {"type": "attack", "id": attacker, "direction": Vector2i.RIGHT})
	check(not state.anchors.has(enemy) and not state.board_pieces.has(victim), "Attack triggers physical Main Anchor cascade")
	check(state.deployed[1] == 1, "Destroyed Anchor does not refund lifetime deployment count")

func test_cascade_precedes_supply() -> void:
	var state = State.create()
	var main = anchor(state, Vector2i(4, 4))
	var trapped = piece(state, Vector2i(0, 0), main)
	var enemy_main = anchor(state, Vector2i(3, 3), 1)
	piece(state, Vector2i(1, 0), enemy_main, 1)
	piece(state, Vector2i(0, 1), enemy_main, 1)
	state.anchors[enemy_main].hp = 0
	Stabilization.resolve(state)
	check(state.board_pieces.has(trapped), "Main death cascade opens supply before checking other BoardPieces")
	state = State.create()
	main = anchor(state, Vector2i(4, 4))
	trapped = piece(state, Vector2i(0, 0), main)
	enemy_main = anchor(state, Vector2i(3, 3), 1)
	var target = piece(state, Vector2i(1, 0), enemy_main, 1, 2, false)
	anchor(state, Vector2i(0, 1), 1)
	Combat.damage(state, target)
	Stabilization.resolve(state)
	check(state.board_pieces.has(trapped), "Direct lethal damage opens supply before stabilization")
