## Mutable simulation data for one physical Anchor.
class_name AnchorState
extends RefCounted

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")

var id: int
var player: RuleTypes.Player
var cell: Vector2i
var hp: int
var is_active: bool = false
var deployed_turn: int
var deployment_index: int


func _init(
	anchor_id: int = 0,
	owner: RuleTypes.Player = RuleTypes.Player.BLACK,
	position: Vector2i = Vector2i.ZERO,
	turn_deployed: int = 0,
	owner_deployment_index: int = 0,
	starting_hp: int = 0
) -> void:
	id = anchor_id
	player = owner
	cell = position
	deployed_turn = turn_deployed
	deployment_index = owner_deployment_index
	hp = starting_hp


func duplicate_state() -> AnchorState:
	var copy := AnchorState.new(id, player, cell, deployed_turn, deployment_index, hp)
	copy.is_active = is_active
	return copy


func canonical_data() -> Array:
	return [id, player, cell.x, cell.y, hp, is_active, deployed_turn, deployment_index]
