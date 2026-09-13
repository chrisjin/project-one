## Focused tests for immutable, coexisting gameplay rule configurations.
extends RefCounted

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")
const RuleSet = preload("res://scripts/gameplay/rules_config.gd")
const CoreRuleSet = preload("res://scripts/gameplay/core_rule_set.gd")
const MapDefinition = preload("res://scripts/gameplay/map_definition.gd")
const Anchor = preload("res://scripts/gameplay/anchor_state.gd")
const BoardPiece = preload("res://scripts/gameplay/board_piece_state.gd")
const GameplayAction = preload("res://scripts/gameplay/gameplay_action.gd")
const RulesEngine = preload("res://scripts/gameplay/rules_engine.gd")
const GameplayAi = preload("res://scripts/ai/gameplay_ai.gd")
const MinimaxAi = preload("res://scripts/ai/minimax_ai.gd")

var failures: Array[String] = []
var assertion_count := 0


func run_all() -> bool:
	test_core_rule_set_matches_current_game()
	test_rule_set_collections_are_immutable_copies()
	test_engines_with_different_rule_sets_coexist()
	test_configured_geometry_damage_and_binding_are_authoritative()
	test_ai_instances_use_their_rule_sets()
	if failures.is_empty():
		print("PASS: %d rule-set assertions" % assertion_count)
		return true
	for failure: String in failures:
		push_error(failure)
	print("FAIL: %d rule-set failures across %d assertions" % [failures.size(), assertion_count])
	return false


func test_core_rule_set_matches_current_game() -> void:
	var rules := CoreRuleSet.new()
	var anchor_config = rules.anchor_config()
	var o_config = rules.board_piece_config(RuleTypes.BoardPieceType.ORTHOGONAL)
	var d_config = rules.board_piece_config(RuleTypes.BoardPieceType.DIAGONAL)
	_assert_equal(rules.standard_board_size, Vector2i(7, 7), "core rules retain the standard 7x7 board")
	_assert_equal(rules.max_categories_per_turn, 2, "core rules retain two distinct categories per turn")
	_assert_equal(rules.anchor_deployment_limit, 12, "core rules retain the physical Anchor deployment limit")
	_assert_equal(anchor_config.attack_type, RuleTypes.AttackType.NONE, "core Anchors have no normal attack")
	_assert_equal(anchor_config.movement_type, RuleTypes.MovementType.ORTHOGONAL, "core Anchors move orthogonally")
	_assert_equal(anchor_config.movement_range, 1, "core Anchors move one cell")
	_assert_equal(anchor_config.max_hp, 3, "core Anchors retain 3 maximum HP")
	_assert_equal(anchor_config.defense, 0, "core Anchors retain zero innate defense")
	_assert_equal(anchor_config.binding_limit, 3, "core Anchors retain three binding slots")
	_assert_equal(o_config.attack_type, RuleTypes.AttackType.ORTHOGONAL, "O retains orthogonal attack geometry")
	_assert_equal(d_config.attack_type, RuleTypes.AttackType.DIAGONAL, "D retains diagonal attack geometry")
	for config in [o_config, d_config]:
		_assert_equal(config.attack_range, 6, "base BoardPieces retain attack range 6")
		_assert_equal(config.attack_damage, 2, "base BoardPieces retain attack damage 2")
		_assert_equal(config.movement_type, RuleTypes.MovementType.ORTHOGONAL, "base BoardPieces retain orthogonal movement")
		_assert_equal(config.movement_range, 1, "base BoardPieces retain movement range 1")
		_assert_equal(config.max_hp, 2, "base BoardPieces retain 2 maximum HP")
		_assert_equal(config.defense, 0, "base BoardPieces retain zero innate defense")
		_assert_equal(config.binding_limit, 0, "BoardPieces cannot bind other BoardPieces")
		_assert_equal(
			config.hp_reduction_amount(RuleTypes.HpReductionType.MAIN_ANCHOR_DAMAGE_REDUCTION),
			1,
			"base BoardPieces retain one Main Anchor unit-chain damage reduction"
		)


func test_rule_set_collections_are_immutable_copies() -> void:
	var rules := CoreRuleSet.new()
	var exposed_configs: Dictionary = rules.entity_configs
	exposed_configs.erase(RuleSet.ANCHOR_CONFIG_KEY)
	_assert_true(rules.entity_configs.has(RuleSet.ANCHOR_CONFIG_KEY), "mutating an exposed config map cannot change the rule set")
	var exposed_reductions: Array[Dictionary] = rules.board_piece_config(
		RuleTypes.BoardPieceType.ORTHOGONAL
	).hp_reductions
	exposed_reductions[0].amount = 99
	_assert_equal(
		rules.board_piece_config(RuleTypes.BoardPieceType.ORTHOGONAL).hp_reduction_amount(
			RuleTypes.HpReductionType.MAIN_ANCHOR_DAMAGE_REDUCTION
		),
		1,
		"mutating an exposed reduction list cannot change its entity configuration"
	)


func test_engines_with_different_rule_sets_coexist() -> void:
	var core_rules := CoreRuleSet.new()
	var alternate_rules := _alternate_rule_set()
	var core_engine := RulesEngine.new(core_rules)
	var alternate_engine := RulesEngine.new(alternate_rules)
	var core_state = core_engine.new_game()
	var alternate_state = alternate_engine.new_game()
	_assert_equal(core_state.map_definition.width, 7, "core engine keeps its own standard board width")
	_assert_equal(alternate_state.map_definition.width, 5, "alternate engine uses its configured standard board width")
	_assert_equal(alternate_state.map_definition.height, 4, "alternate engine uses its configured standard board height")
	var core_placement = core_engine.apply_action(core_state, GameplayAction.place_anchor(Vector2i(1, 1)))
	var alternate_placement = alternate_engine.apply_action(alternate_state, GameplayAction.place_anchor(Vector2i(1, 1)))
	_assert_true(core_placement.success and alternate_placement.success, "both engines resolve actions independently")
	_assert_equal(core_placement.state.anchors[1].hp, 3, "core engine deploys its configured Anchor HP")
	_assert_equal(alternate_placement.state.anchors[1].hp, 5, "alternate engine deploys its configured Anchor HP")
	_assert_equal(core_placement.state.current_player, RuleTypes.Player.BLACK, "core Placement consumes only one of two categories")
	_assert_equal(alternate_placement.state.current_player, RuleTypes.Player.WHITE, "alternate one-category limit automatically ends its turn")
	_assert_true(
		core_engine.state_hash(core_state) != alternate_engine.state_hash(core_state),
		"rule-set data participates in deterministic state identity"
	)


func test_configured_geometry_damage_and_binding_are_authoritative() -> void:
	var rules := _alternate_rule_set()
	var configured_engine := RulesEngine.new(rules)
	var attack_state = configured_engine.new_game(MapDefinition.rectangular(5, 4, true))
	_add_anchor(attack_state, rules, 1, RuleTypes.Player.BLACK, Vector2i(0, 1))
	_add_piece(attack_state, rules, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(0, 0), 1)
	_add_anchor(attack_state, rules, 2, RuleTypes.Player.WHITE, Vector2i(2, 1))
	_add_piece(attack_state, rules, 2, RuleTypes.Player.WHITE, RuleTypes.BoardPieceType.DIAGONAL, Vector2i(2, 2), 2)
	attack_state.seen_state_hashes.clear()
	attack_state.seen_state_hashes[configured_engine.state_hash(attack_state)] = true
	_assert_equal(
		configured_engine.trace_ray(attack_state, 1, Vector2i(1, 1)).target.id,
		2,
		"an alternate O uses its configured diagonal attack geometry"
	)
	_assert_true(
		configured_engine.trace_ray(attack_state, 1, Vector2i.RIGHT).target.is_empty(),
		"an alternate O no longer receives static orthogonal attack geometry"
	)
	var attack_result = configured_engine.apply_action(
		attack_state,
		GameplayAction.attack(1, Vector2i(1, 1))
	)
	_assert_true(attack_result.success, "configured diagonal attack is legal")
	_assert_equal(
		attack_result.state.board_pieces[2].hp,
		3,
		"damage applies configured attack 4 minus defense 1 and active unit-chain reduction 2"
	)

	var range_state = attack_state.duplicate_state()
	range_state.board_pieces[2].cell = Vector2i(3, 3)
	_assert_true(
		configured_engine.trace_ray(range_state, 1, Vector2i(1, 1)).target.is_empty(),
		"configured attack range 2 does not reach a target three cells away"
	)
	var movement_state = configured_engine.new_game(MapDefinition.rectangular(5, 4, true))
	_add_anchor(movement_state, rules, 1, RuleTypes.Player.BLACK, Vector2i(0, 1))
	_add_piece(movement_state, rules, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(0, 0), 1)
	movement_state.seen_state_hashes.clear()
	movement_state.seen_state_hashes[configured_engine.state_hash(movement_state)] = true
	_assert_false(
		configured_engine.apply_action(
			movement_state,
			GameplayAction.move(RuleTypes.EntityKind.BOARD_PIECE, 1, Vector2i(1, 0))
		).success,
		"alternate diagonal movement rejects a static orthogonal step"
	)
	var movement_result = configured_engine.apply_action(
		movement_state,
		GameplayAction.move(RuleTypes.EntityKind.BOARD_PIECE, 1, Vector2i(2, 2))
	)
	_assert_true(movement_result.success, "alternate diagonal movement accepts its configured two-cell range")
	_assert_equal(movement_result.state.board_pieces[1].cell, Vector2i(2, 2), "configured movement reaches the exact destination")
	var anchor_movement_state = configured_engine.new_game(MapDefinition.rectangular(5, 4, true))
	_add_anchor(anchor_movement_state, rules, 1, RuleTypes.Player.BLACK, Vector2i(0, 1))
	anchor_movement_state.seen_state_hashes.clear()
	anchor_movement_state.seen_state_hashes[configured_engine.state_hash(anchor_movement_state)] = true
	var anchor_movement_result = configured_engine.apply_action(
		anchor_movement_state,
		GameplayAction.move(RuleTypes.EntityKind.ANCHOR, 1, Vector2i(2, 3))
	)
	_assert_true(anchor_movement_result.success, "Anchor movement also comes from its entity configuration")
	_assert_equal(anchor_movement_result.state.anchors[1].cell, Vector2i(2, 3), "configured Anchor diagonal range is authoritative")

	var binding_state = configured_engine.new_game(MapDefinition.rectangular(5, 4, true))
	_add_anchor(binding_state, rules, 1, RuleTypes.Player.BLACK, Vector2i(0, 1))
	_add_piece(binding_state, rules, 1, RuleTypes.Player.BLACK, RuleTypes.BoardPieceType.ORTHOGONAL, Vector2i(0, 0), 1)
	binding_state.seen_state_hashes.clear()
	binding_state.seen_state_hashes[configured_engine.state_hash(binding_state)] = true
	_assert_false(
		configured_engine.apply_action(
			binding_state,
			GameplayAction.place_board_piece(RuleTypes.BoardPieceType.DIAGONAL, Vector2i(1, 1), 1)
		).success,
		"alternate Anchor binding limit 1 rejects a second bound BoardPiece"
	)


func test_ai_instances_use_their_rule_sets() -> void:
	var core_rules := CoreRuleSet.new()
	var alternate_rules := _alternate_rule_set()
	var core_ai := MinimaxAi.new(core_rules, 1, 4)
	var alternate_ai := MinimaxAi.new(alternate_rules, 1, 4)
	_assert_true(core_ai is GameplayAi, "minimax implements the common headless AI interface")
	_assert_true(core_ai.rule_set == core_rules, "one AI instance retains the injected core rules")
	_assert_true(alternate_ai.rule_set == alternate_rules, "a second AI instance retains its alternate rules")
	var alternate_engine := RulesEngine.new(alternate_rules)
	var action = alternate_ai.choose_action(alternate_engine.new_game())
	_assert_true(action != null, "AI can choose an action under an alternate ruleset")
	_assert_true(
		alternate_engine.apply_action(alternate_engine.new_game(), action).success,
		"alternate-rules AI returns an action accepted by the matching headless engine"
	)


func _alternate_rule_set() -> RuleSet:
	var anchor_config := RuleSet.EntityConfig.new({
		"attack_type": RuleTypes.AttackType.NONE,
		"movement_type": RuleTypes.MovementType.DIAGONAL,
		"movement_range": 2,
		"max_hp": 5,
		"defense": 1,
		"binding_limit": 1,
	})
	var shared_piece_values := {
		"attack_range": 2,
		"attack_damage": 4,
		"movement_type": RuleTypes.MovementType.DIAGONAL,
		"movement_range": 2,
		"max_hp": 4,
		"defense": 1,
		"binding_limit": 0,
		"hp_reductions": [{
			"type": RuleTypes.HpReductionType.MAIN_ANCHOR_DAMAGE_REDUCTION,
			"amount": 2,
		}],
	}
	var alternate_o := shared_piece_values.duplicate(true)
	alternate_o.attack_type = RuleTypes.AttackType.DIAGONAL
	var alternate_d := shared_piece_values.duplicate(true)
	alternate_d.attack_type = RuleTypes.AttackType.ORTHOGONAL
	return RuleSet.new({
		"standard_board_size": Vector2i(5, 4),
		"max_categories_per_turn": 1,
		"anchor_deployment_limit": 4,
		"anchor_config": anchor_config,
		"board_piece_configs": {
			RuleTypes.BoardPieceType.ORTHOGONAL: RuleSet.EntityConfig.new(alternate_o),
			RuleTypes.BoardPieceType.DIAGONAL: RuleSet.EntityConfig.new(alternate_d),
		},
	})


func _add_anchor(
	state,
	rules,
	id: int,
	player: RuleTypes.Player,
	cell: Vector2i
) -> void:
	var anchor = Anchor.new(id, player, cell, 0, id, rules.anchor_config().max_hp)
	anchor.is_active = true
	state.anchors[id] = anchor
	state.next_anchor_id = maxi(state.next_anchor_id, id + 1)
	state.anchors_deployed[player] += 1


func _add_piece(
	state,
	rules,
	id: int,
	player: RuleTypes.Player,
	type: RuleTypes.BoardPieceType,
	cell: Vector2i,
	main_anchor_id: int
) -> void:
	var board_piece = BoardPiece.new(
		id,
		player,
		type,
		cell,
		main_anchor_id,
		0,
		rules.board_piece_config(type).max_hp
	)
	board_piece.is_mature = true
	state.board_pieces[id] = board_piece
	state.next_board_piece_id = maxi(state.next_board_piece_id, id + 1)


func _assert_true(condition: bool, message: String) -> void:
	assertion_count += 1
	if not condition:
		failures.append(message)


func _assert_false(condition: bool, message: String) -> void:
	_assert_true(not condition, message)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	assertion_count += 1
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
