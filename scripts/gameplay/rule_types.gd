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


static func board_piece_directions(board_piece_type: BoardPieceType) -> Array[Vector2i]:
	if board_piece_type == BoardPieceType.ORTHOGONAL:
		return ORTHOGONAL_DIRECTIONS.duplicate()
	return DIAGONAL_DIRECTIONS.duplicate()
