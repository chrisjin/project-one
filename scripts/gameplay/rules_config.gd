## Immutable gameplay configuration shared by rules engines and headless controllers.
class_name AnchorRuleSet
extends RefCounted

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")

const ANCHOR_CONFIG_KEY := -1


class EntityConfig extends RefCounted:
	var _attack_range: int
	var _attack_type: RuleTypes.AttackType
	var _attack_damage: int
	var _attack_blocking_type: RuleTypes.AttackBlockingType
	var _targetable: bool
	var _movement_range: int
	var _movement_type: RuleTypes.MovementType
	var _max_hp: int
	var _defense: int
	var _binding_limit: int
	var _hp_reductions: Array[Dictionary] = []

	var attack_range: int:
		get:
			return _attack_range
	var attack_type: RuleTypes.AttackType:
		get:
			return _attack_type
	var attack_damage: int:
		get:
			return _attack_damage
	var attack_blocking_type: RuleTypes.AttackBlockingType:
		get:
			return _attack_blocking_type
	var targetable: bool:
		get:
			return _targetable
	var movement_range: int:
		get:
			return _movement_range
	var movement_type: RuleTypes.MovementType:
		get:
			return _movement_type
	var max_hp: int:
		get:
			return _max_hp
	var defense: int:
		get:
			return _defense
	var binding_limit: int:
		get:
			return _binding_limit
	var hp_reductions: Array[Dictionary]:
		get:
			return _hp_reductions.duplicate(true)


	func _init(values: Dictionary) -> void:
		_attack_range = int(values.get("attack_range", 0))
		_attack_type = values.get("attack_type", RuleTypes.AttackType.NONE)
		_attack_damage = int(values.get("attack_damage", 0))
		_attack_blocking_type = values.get("attack_blocking_type", RuleTypes.AttackBlockingType.BOTH)
		_targetable = bool(values.get("targetable", true))
		_movement_range = int(values.get("movement_range", 1))
		_movement_type = values.get("movement_type", RuleTypes.MovementType.ORTHOGONAL)
		_max_hp = int(values.get("max_hp", 1))
		_defense = int(values.get("defense", 0))
		_binding_limit = int(values.get("binding_limit", 0))
		assert(_attack_range >= 0 and _attack_damage >= 0)
		assert(_movement_range >= 0 and _max_hp >= 0)
		assert(_defense >= 0 and _binding_limit >= 0)
		for reduction: Dictionary in values.get("hp_reductions", []):
			assert(reduction.has("type") and reduction.has("amount"))
			assert(int(reduction.amount) >= 0)
			_hp_reductions.append({
				"type": int(reduction.type),
				"amount": int(reduction.amount),
			})


	func hp_reduction_amount(reduction_type: RuleTypes.HpReductionType) -> int:
		var amount := 0
		for reduction: Dictionary in _hp_reductions:
			if reduction.type == reduction_type:
				amount += int(reduction.amount)
		return amount


	func canonical_data() -> Array:
		var reductions := _hp_reductions.duplicate(true)
		reductions.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
			if first.type == second.type:
				return first.amount < second.amount
			return first.type < second.type
		)
		return [
			_attack_type,
			_attack_range,
			_attack_damage,
			_attack_blocking_type,
			_targetable,
			_movement_type,
			_movement_range,
			_max_hp,
			_defense,
			_binding_limit,
			reductions,
		]


var _standard_board_size: Vector2i
var _max_categories_per_turn: int
var _anchor_deployment_limit: int
var _entity_configs: Dictionary = {}

var standard_board_size: Vector2i:
	get:
		return _standard_board_size
var max_categories_per_turn: int:
	get:
		return _max_categories_per_turn
var anchor_deployment_limit: int:
	get:
		return _anchor_deployment_limit
var entity_configs: Dictionary:
	get:
		return _entity_configs.duplicate()


func _init(values: Dictionary) -> void:
	_standard_board_size = values.get("standard_board_size", Vector2i(7, 7))
	_max_categories_per_turn = int(values.get("max_categories_per_turn", 2))
	_anchor_deployment_limit = int(values.get("anchor_deployment_limit", 12))
	assert(_standard_board_size.x > 0 and _standard_board_size.y > 0)
	assert(_max_categories_per_turn > 0 and _max_categories_per_turn <= RuleTypes.ActionCategory.size())
	assert(_anchor_deployment_limit >= 0)
	var configured_anchor = values.get("anchor_config")
	assert(configured_anchor is EntityConfig)
	_entity_configs[ANCHOR_CONFIG_KEY] = configured_anchor
	var configured_board_pieces: Dictionary = values.get("board_piece_configs", {})
	assert(not configured_board_pieces.is_empty())
	for board_piece_type: Variant in configured_board_pieces:
		assert(configured_board_pieces[board_piece_type] is EntityConfig)
		_entity_configs[int(board_piece_type)] = configured_board_pieces[board_piece_type]


func anchor_config() -> EntityConfig:
	return _entity_configs[ANCHOR_CONFIG_KEY]


func has_board_piece_config(board_piece_type: int) -> bool:
	return _entity_configs.has(board_piece_type) and board_piece_type != ANCHOR_CONFIG_KEY


func board_piece_config(board_piece_type: int) -> EntityConfig:
	assert(has_board_piece_config(board_piece_type))
	return _entity_configs[board_piece_type]


func board_piece_types() -> Array[int]:
	var result: Array[int] = []
	for config_key: int in _entity_configs:
		if config_key != ANCHOR_CONFIG_KEY:
			result.append(config_key)
	result.sort()
	return result


func canonical_data() -> Array:
	var board_piece_data: Array = []
	for board_piece_type: int in board_piece_types():
		board_piece_data.append([
			board_piece_type,
			board_piece_config(board_piece_type).canonical_data(),
		])
	return [
		_standard_board_size.x,
		_standard_board_size.y,
		_max_categories_per_turn,
		_anchor_deployment_limit,
		anchor_config().canonical_data(),
		board_piece_data,
	]
