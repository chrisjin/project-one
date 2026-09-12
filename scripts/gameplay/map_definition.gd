## Data-owned board topology, passability, ray blocking, and Anchor-valid cells.
class_name AnchorMapDefinition
extends RefCounted

const RulesConfig = preload("res://scripts/gameplay/rules_config.gd")

var width: int
var height: int
var playable_cells: Dictionary = {}
var impassable_cells: Dictionary = {}
var ray_blocking_cells: Dictionary = {}
var anchor_valid_cells: Dictionary = {}


func _init(map_width: int = 7, map_height: int = 7) -> void:
	width = map_width
	height = map_height
	for y in range(height):
		for x in range(width):
			playable_cells[Vector2i(x, y)] = true


static func standard_7x7() -> AnchorMapDefinition:
	var map_definition := AnchorMapDefinition.new(
		RulesConfig.STANDARD_BOARD_SIZE.x,
		RulesConfig.STANDARD_BOARD_SIZE.y
	)
	for y in range(1, 6):
		for x in range(1, 6):
			map_definition.anchor_valid_cells[Vector2i(x, y)] = true
	return map_definition


static func rectangular(map_width: int, map_height: int, all_cells_anchor_valid: bool = false) -> AnchorMapDefinition:
	var map_definition := AnchorMapDefinition.new(map_width, map_height)
	if all_cells_anchor_valid:
		map_definition.anchor_valid_cells = map_definition.playable_cells.duplicate()
	return map_definition


func duplicate_definition() -> AnchorMapDefinition:
	var copy := AnchorMapDefinition.new(width, height)
	copy.playable_cells = playable_cells.duplicate()
	copy.impassable_cells = impassable_cells.duplicate()
	copy.ray_blocking_cells = ray_blocking_cells.duplicate()
	copy.anchor_valid_cells = anchor_valid_cells.duplicate()
	return copy


func is_on_map(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height and playable_cells.has(cell)


func is_passable(cell: Vector2i) -> bool:
	return is_on_map(cell) and not impassable_cells.has(cell)


func blocks_ray(cell: Vector2i) -> bool:
	return not is_on_map(cell) or ray_blocking_cells.has(cell)


func is_anchor_valid(cell: Vector2i) -> bool:
	return is_passable(cell) and anchor_valid_cells.has(cell)


func set_playable(cell: Vector2i, is_playable: bool) -> void:
	if is_playable:
		playable_cells[cell] = true
	else:
		playable_cells.erase(cell)
		impassable_cells.erase(cell)
		ray_blocking_cells.erase(cell)
		anchor_valid_cells.erase(cell)


func set_impassable(cell: Vector2i, is_impassable: bool, blocks_attacks: bool = true) -> void:
	if is_impassable:
		impassable_cells[cell] = true
		if blocks_attacks:
			ray_blocking_cells[cell] = true
		else:
			ray_blocking_cells.erase(cell)
		anchor_valid_cells.erase(cell)
	else:
		impassable_cells.erase(cell)
		ray_blocking_cells.erase(cell)


func set_anchor_valid(cell: Vector2i, is_valid: bool) -> void:
	if is_valid and is_passable(cell):
		anchor_valid_cells[cell] = true
	else:
		anchor_valid_cells.erase(cell)


func canonical_data() -> Array:
	return [
		width,
		height,
		_sorted_cell_keys(playable_cells),
		_sorted_cell_keys(impassable_cells),
		_sorted_cell_keys(ray_blocking_cells),
		_sorted_cell_keys(anchor_valid_cells),
	]


func _sorted_cell_keys(cells: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for cell: Vector2i in cells:
		keys.append("%d,%d" % [cell.x, cell.y])
	keys.sort()
	return keys
