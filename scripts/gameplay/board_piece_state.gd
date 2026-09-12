## Mutable simulation data for one scoring BoardPiece and its permanent Main Anchor binding.
class_name BoardPieceState
extends RefCounted

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")
const RulesConfig = preload("res://scripts/gameplay/rules_config.gd")

var id: int
var player: RuleTypes.Player
var board_piece_type: RuleTypes.BoardPieceType
var cell: Vector2i
var hp: int = RulesConfig.BOARD_PIECE_STARTING_HP
var is_mature: bool = false
var main_anchor_id: int
var deployed_turn: int


func _init(
	board_piece_id: int = 0,
	owner: RuleTypes.Player = RuleTypes.Player.BLACK,
	type: RuleTypes.BoardPieceType = RuleTypes.BoardPieceType.ORTHOGONAL,
	position: Vector2i = Vector2i.ZERO,
	bound_anchor_id: int = 0,
	turn_deployed: int = 0
) -> void:
	id = board_piece_id
	player = owner
	board_piece_type = type
	cell = position
	main_anchor_id = bound_anchor_id
	deployed_turn = turn_deployed


func duplicate_state() -> BoardPieceState:
	var copy := BoardPieceState.new(id, player, board_piece_type, cell, main_anchor_id, deployed_turn)
	copy.hp = hp
	copy.is_mature = is_mature
	return copy


func canonical_data() -> Array:
	return [id, player, board_piece_type, cell.x, cell.y, hp, is_mature, main_anchor_id, deployed_turn]
