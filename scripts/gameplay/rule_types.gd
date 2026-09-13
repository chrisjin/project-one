## Shared gameplay enums and deterministic direction helpers.
class_name AnchorRuleTypes
extends RefCounted

enum Player {
	BLACK,
	WHITE,
}

enum BoardPieceType {
	ORTHOGONAL,
	DIAGONAL,
}

enum AttackType {
	NONE,
	ORTHOGONAL,
	DIAGONAL,
}

enum MovementType {
	NONE,
	ORTHOGONAL,
	DIAGONAL,
}

enum HpReductionType {
	MAIN_ANCHOR_DAMAGE_REDUCTION,
}

enum EntityKind {
	ANCHOR,
	BOARD_PIECE,
}

enum ActionCategory {
	PLACEMENT,
	MOVEMENT,
	ACTION,
}

enum Outcome {
	ONGOING = -1,
	BLACK_WIN,
	WHITE_WIN,
	DRAW,
}

const ORTHOGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]

const DIAGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
]


static func opponent(player: Player) -> Player:
	return Player.WHITE if player == Player.BLACK else Player.BLACK


static func attack_directions(attack_type: AttackType) -> Array[Vector2i]:
	if attack_type == AttackType.ORTHOGONAL:
		return ORTHOGONAL_DIRECTIONS.duplicate()
	if attack_type == AttackType.DIAGONAL:
		return DIAGONAL_DIRECTIONS.duplicate()
	var no_directions: Array[Vector2i] = []
	return no_directions


static func movement_directions(movement_type: MovementType) -> Array[Vector2i]:
	if movement_type == MovementType.ORTHOGONAL:
		return ORTHOGONAL_DIRECTIONS.duplicate()
	if movement_type == MovementType.DIAGONAL:
		return DIAGONAL_DIRECTIONS.duplicate()
	var no_directions: Array[Vector2i] = []
	return no_directions
