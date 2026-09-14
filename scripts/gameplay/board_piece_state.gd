## Mutable simulation data for one scoring BoardPiece and its permanent Main Anchor binding.
class_name BoardPieceState
extends RefCounted

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")

var id: int
var player: RuleTypes.Player
var board_piece_type: RuleTypes.BoardPieceType
var cell: Vector2i
var hp: int
var is_mature: bool = false
var main_anchor_id: int
var deployed_turn: int
# Populated only after an O or D BoardPiece becomes a PieceSpirit.
var original_board_piece_type: int = -1


func _init(
	board_piece_id: int = 0,
	owner: RuleTypes.Player = RuleTypes.Player.BLACK,
	type: RuleTypes.BoardPieceType = RuleTypes.BoardPieceType.ORTHOGONAL,
	position: Vector2i = Vector2i.ZERO,
	bound_anchor_id: int = 0,
	turn_deployed: int = 0,
	starting_hp: int = 0
) -> void:
	id = board_piece_id
	player = owner
	board_piece_type = type
	cell = position
	main_anchor_id = bound_anchor_id
	deployed_turn = turn_deployed
	hp = starting_hp


func duplicate_state() -> BoardPieceState:
	var copy := BoardPieceState.new(id, player, board_piece_type, cell, main_anchor_id, deployed_turn, hp)
	copy.is_mature = is_mature
	copy.original_board_piece_type = original_board_piece_type
	return copy


func canonical_data() -> Array:
	return [
		id,
		player,
		board_piece_type,
		original_board_piece_type,
		cell.x,
		cell.y,
		hp,
		is_mature,
		main_anchor_id,
		deployed_turn,
	]
