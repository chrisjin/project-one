## Complete presentation-free match state; copied before every attempted transition.
class_name AnchorGameState
extends RefCounted

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")
const MapDefinition = preload("res://scripts/gameplay/map_definition.gd")

var map_definition: MapDefinition
var anchors: Dictionary = {}
var board_pieces: Dictionary = {}
var current_player: RuleTypes.Player = RuleTypes.Player.BLACK
var turn_number: int = 1
var categories_used: Array[int] = []
var anchors_deployed: Dictionary = {
	RuleTypes.Player.BLACK: 0,
	RuleTypes.Player.WHITE: 0,
}
var next_anchor_id: int = 1
var next_board_piece_id: int = 1
var consecutive_passes: int = 0
var is_game_over: bool = false
var outcome: RuleTypes.Outcome = RuleTypes.Outcome.ONGOING
var black_score: int = 0
var white_score: int = 0
var random_seed: int = 0
var action_log: Array[Dictionary] = []
var seen_state_hashes: Dictionary = {}


func _init(board_map: MapDefinition = null, seed: int = 0) -> void:
	map_definition = board_map.duplicate_definition() if board_map != null else MapDefinition.standard_7x7()
	random_seed = seed


func duplicate_state() -> AnchorGameState:
	var copy := AnchorGameState.new(map_definition, random_seed)
	for anchor_id: int in anchors:
		copy.anchors[anchor_id] = anchors[anchor_id].duplicate_state()
	for board_piece_id: int in board_pieces:
		copy.board_pieces[board_piece_id] = board_pieces[board_piece_id].duplicate_state()
	copy.current_player = current_player
	copy.turn_number = turn_number
	copy.categories_used = categories_used.duplicate()
	copy.anchors_deployed = anchors_deployed.duplicate()
	copy.next_anchor_id = next_anchor_id
	copy.next_board_piece_id = next_board_piece_id
	copy.consecutive_passes = consecutive_passes
	copy.is_game_over = is_game_over
	copy.outcome = outcome
	copy.black_score = black_score
	copy.white_score = white_score
	copy.action_log = action_log.duplicate(true)
	copy.seen_state_hashes = seen_state_hashes.duplicate()
	return copy


func entity_at(cell: Vector2i) -> Dictionary:
	for anchor_id: int in anchors:
		if anchors[anchor_id].cell == cell:
			return {"kind": RuleTypes.EntityKind.ANCHOR, "id": anchor_id}
	for board_piece_id: int in board_pieces:
		if board_pieces[board_piece_id].cell == cell:
			return {"kind": RuleTypes.EntityKind.BOARD_PIECE, "id": board_piece_id}
	return {}


func is_cell_empty(cell: Vector2i) -> bool:
	return entity_at(cell).is_empty()


func entity_player(entity: Dictionary) -> RuleTypes.Player:
	if entity.kind == RuleTypes.EntityKind.ANCHOR:
		return anchors[entity.id].player
	return board_pieces[entity.id].player


func entity_cell(entity: Dictionary) -> Vector2i:
	if entity.kind == RuleTypes.EntityKind.ANCHOR:
		return anchors[entity.id].cell
	return board_pieces[entity.id].cell
