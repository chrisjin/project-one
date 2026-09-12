## Serializable command objects accepted by the headless rules engine.
class_name AnchorGameplayAction
extends RefCounted

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")

enum Kind {
	PLACE_ANCHOR,
	PLACE_BOARD_PIECE,
	MOVE,
	ATTACK,
	RAPID_ACTIVATION,
	END_TURN,
}

var kind: Kind
var cell: Vector2i = Vector2i.ZERO
var board_piece_type: RuleTypes.BoardPieceType = RuleTypes.BoardPieceType.ORTHOGONAL
var main_anchor_id: int = 0
var entity_kind: RuleTypes.EntityKind = RuleTypes.EntityKind.BOARD_PIECE
var entity_id: int = 0
var direction: Vector2i = Vector2i.ZERO


static func place_anchor(at: Vector2i) -> AnchorGameplayAction:
	var action := AnchorGameplayAction.new()
	action.kind = Kind.PLACE_ANCHOR
	action.cell = at
	return action


static func place_board_piece(
	type: RuleTypes.BoardPieceType,
	at: Vector2i,
	bound_anchor_id: int
) -> AnchorGameplayAction:
	var action := AnchorGameplayAction.new()
	action.kind = Kind.PLACE_BOARD_PIECE
	action.board_piece_type = type
	action.cell = at
	action.main_anchor_id = bound_anchor_id
	return action


static func move(entity_type: RuleTypes.EntityKind, id: int, to: Vector2i) -> AnchorGameplayAction:
	var action := AnchorGameplayAction.new()
	action.kind = Kind.MOVE
	action.entity_kind = entity_type
	action.entity_id = id
	action.cell = to
	return action


static func attack(board_piece_id: int, ray_direction: Vector2i) -> AnchorGameplayAction:
	var action := AnchorGameplayAction.new()
	action.kind = Kind.ATTACK
	action.entity_id = board_piece_id
	action.direction = ray_direction
	return action


static func rapid_activation(anchor_id: int) -> AnchorGameplayAction:
	var action := AnchorGameplayAction.new()
	action.kind = Kind.RAPID_ACTIVATION
	action.entity_kind = RuleTypes.EntityKind.ANCHOR
	action.entity_id = anchor_id
	return action


static func end_turn() -> AnchorGameplayAction:
	var action := AnchorGameplayAction.new()
	action.kind = Kind.END_TURN
	return action


func category() -> int:
	match kind:
		Kind.PLACE_ANCHOR, Kind.PLACE_BOARD_PIECE:
			return RuleTypes.ActionCategory.PLACEMENT
		Kind.MOVE:
			return RuleTypes.ActionCategory.MOVEMENT
		Kind.ATTACK, Kind.RAPID_ACTIVATION:
			return RuleTypes.ActionCategory.ACTION
		_:
			return -1


func to_dictionary() -> Dictionary:
	return {
		"kind": kind,
		"cell": [cell.x, cell.y],
		"board_piece_type": board_piece_type,
		"main_anchor_id": main_anchor_id,
		"entity_kind": entity_kind,
		"entity_id": entity_id,
		"direction": [direction.x, direction.y],
	}


static func from_dictionary(data: Dictionary) -> AnchorGameplayAction:
	var action := AnchorGameplayAction.new()
	action.kind = int(data.kind) as Kind
	action.cell = Vector2i(int(data.cell[0]), int(data.cell[1]))
	action.board_piece_type = int(data.board_piece_type) as RuleTypes.BoardPieceType
	action.main_anchor_id = int(data.main_anchor_id)
	action.entity_kind = int(data.entity_kind) as RuleTypes.EntityKind
	action.entity_id = int(data.entity_id)
	action.direction = Vector2i(int(data.direction[0]), int(data.direction[1]))
	return action
