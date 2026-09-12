## Stateless 3D projection of GameState plus engine-approved interaction highlights.
class_name AnchorDebugBoardView
extends Node3D

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")

const CELL_SIZE := 1.2
const BOARD_SURFACE_Y := 0.0

var map_definition
var _map_signature := ""
var _board_root: Node3D
var _highlight_root: Node3D
var _entity_root: Node3D
var _black_material: StandardMaterial3D
var _white_material: StandardMaterial3D
var _black_zero_hp_material: StandardMaterial3D
var _white_zero_hp_material: StandardMaterial3D


func _ready() -> void:
	_board_root = Node3D.new()
	_board_root.name = "BoardGeometry"
	add_child(_board_root)
	_highlight_root = Node3D.new()
	_highlight_root.name = "Highlights"
	add_child(_highlight_root)
	_entity_root = Node3D.new()
	_entity_root.name = "Entities"
	add_child(_entity_root)
	_black_material = _make_material(Color("263248"))
	_white_material = _make_material(Color("f2ead7"))
	_black_zero_hp_material = _make_material(Color(0.15, 0.20, 0.29, 0.48), false)
	_white_zero_hp_material = _make_material(Color(0.95, 0.91, 0.82, 0.52), false)


func refresh_from_state(state, cell_highlights: Dictionary = {}, selected_entity: Dictionary = {}) -> void:
	map_definition = state.map_definition
	var signature := JSON.stringify(map_definition.canonical_data())
	if signature != _map_signature:
		_map_signature = signature
		_rebuild_board()
	_clear_children(_highlight_root)
	_clear_children(_entity_root)
	for cell: Vector2i in cell_highlights:
		_add_cell_highlight(cell, str(cell_highlights[cell]))
	if not selected_entity.is_empty():
		_add_selection_marker(state.entity_cell(selected_entity))
	for anchor_id: int in state.anchors:
		_render_anchor(state.anchors[anchor_id])
	for board_piece_id: int in state.board_pieces:
		_render_board_piece(state.board_pieces[board_piece_id])


func cell_to_world(cell: Vector2i) -> Vector3:
	if map_definition == null:
		return Vector3.ZERO
	var half_width := float(map_definition.width - 1) * 0.5
	var half_height := float(map_definition.height - 1) * 0.5
	return Vector3(
		(float(cell.x) - half_width) * CELL_SIZE,
		BOARD_SURFACE_Y,
		(float(cell.y) - half_height) * CELL_SIZE
	)


func world_to_cell(world_position: Vector3) -> Vector2i:
	if map_definition == null:
		return Vector2i(-1, -1)
	var half_width := float(map_definition.width - 1) * 0.5
	var half_height := float(map_definition.height - 1) * 0.5
	var cell := Vector2i(
		roundi(world_position.x / CELL_SIZE + half_width),
		roundi(world_position.z / CELL_SIZE + half_height)
	)
	return cell if map_definition.is_on_map(cell) else Vector2i(-1, -1)


func pick_cell(camera: Camera3D, mouse_position: Vector2) -> Vector2i:
	if map_definition == null:
		return Vector2i(-1, -1)
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var intersection: Variant = Plane(Vector3.UP, BOARD_SURFACE_Y).intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		return Vector2i(-1, -1)
	return world_to_cell(intersection)


func _rebuild_board() -> void:
	_clear_children(_board_root)
	var light_tile := _make_material(Color("d8d2c0"))
	var dark_tile := _make_material(Color("aaa48f"))
	var edge_material := _make_material(Color("4b5361"))
	for y in range(map_definition.height):
		for x in range(map_definition.width):
			var cell := Vector2i(x, y)
			if not map_definition.is_on_map(cell):
				continue
			var tile := MeshInstance3D.new()
			tile.name = "Cell_%d_%d" % [x, y]
			var tile_mesh := BoxMesh.new()
			tile_mesh.size = Vector3(CELL_SIZE - 0.045, 0.12, CELL_SIZE - 0.045)
			tile.mesh = tile_mesh
			tile.material_override = light_tile if (x + y) % 2 == 0 else dark_tile
			tile.position = cell_to_world(cell) + Vector3(0.0, -0.07, 0.0)
			_board_root.add_child(tile)
	_add_board_border(edge_material)
	_add_coordinate_labels()


func _add_board_border(material: StandardMaterial3D) -> void:
	var board_width := float(map_definition.width) * CELL_SIZE
	var board_height := float(map_definition.height) * CELL_SIZE
	for data in [
		[Vector3(board_width + 0.25, 0.14, 0.16), Vector3(0.0, -0.06, -board_height * 0.5 - 0.12)],
		[Vector3(board_width + 0.25, 0.14, 0.16), Vector3(0.0, -0.06, board_height * 0.5 + 0.12)],
		[Vector3(0.16, 0.14, board_height + 0.25), Vector3(-board_width * 0.5 - 0.12, -0.06, 0.0)],
		[Vector3(0.16, 0.14, board_height + 0.25), Vector3(board_width * 0.5 + 0.12, -0.06, 0.0)],
	]:
		var border := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = data[0]
		border.mesh = mesh
		border.material_override = material
		border.position = data[1]
		_board_root.add_child(border)


func _add_coordinate_labels() -> void:
	for x in range(map_definition.width):
		var label := _make_world_label(String.chr(65 + x), Color("d9e3f2"), 70)
		label.position = cell_to_world(Vector2i(x, 0)) + Vector3(0.0, 0.08, -CELL_SIZE * 0.67)
		_board_root.add_child(label)
	for y in range(map_definition.height):
		var label := _make_world_label(str(y + 1), Color("d9e3f2"), 70)
		label.position = cell_to_world(Vector2i(0, y)) + Vector3(-CELL_SIZE * 0.67, 0.08, 0.0)
		_board_root.add_child(label)


func _render_anchor(anchor) -> void:
	var root := Node3D.new()
	root.name = "Anchor_%d" % anchor.id
	root.position = cell_to_world(anchor.cell)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.37
	mesh.bottom_radius = 0.46
	mesh.height = 0.72
	mesh.radial_segments = 10
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.38
	mesh_instance.material_override = _owner_material(anchor.player, false)
	if not anchor.is_active:
		mesh_instance.scale = Vector3(0.74, 0.74, 0.74)
		mesh_instance.material_override = _inactive_material(anchor.player)
	root.add_child(mesh_instance)
	var status := "" if anchor.is_active else "\nINACTIVE"
	var label := _make_world_label("A%d  HP %d%s" % [anchor.id, anchor.hp, status], _label_color(anchor.player), 34)
	label.position = Vector3(0.0, 0.92, 0.0)
	root.add_child(label)
	_entity_root.add_child(root)


func _render_board_piece(board_piece) -> void:
	var root := Node3D.new()
	root.name = "BoardPiece_%d" % board_piece.id
	root.position = cell_to_world(board_piece.cell)
	var mesh_instance := MeshInstance3D.new()
	if board_piece.board_piece_type == RuleTypes.BoardPieceType.ORTHOGONAL:
		var box := BoxMesh.new()
		box.size = Vector3(0.66, 0.66, 0.66)
		mesh_instance.mesh = box
	else:
		var pyramid := CylinderMesh.new()
		pyramid.top_radius = 0.0
		pyramid.bottom_radius = 0.48
		pyramid.height = 0.78
		pyramid.radial_segments = 3
		mesh_instance.mesh = pyramid
	mesh_instance.position.y = 0.38
	mesh_instance.material_override = _owner_material(board_piece.player, board_piece.hp <= 0)
	if board_piece.hp <= 0:
		mesh_instance.scale = Vector3(0.64, 0.64, 0.64)
		mesh_instance.position.y = 0.27
	root.add_child(mesh_instance)
	var type_label := "O" if board_piece.board_piece_type == RuleTypes.BoardPieceType.ORTHOGONAL else "D"
	var maturity := "" if board_piece.is_mature else "  NEW"
	var label := _make_world_label("%s%d  HP %d%s" % [type_label, board_piece.id, board_piece.hp, maturity], _label_color(board_piece.player), 34)
	label.position = Vector3(0.0, 0.9, 0.0)
	root.add_child(label)
	_entity_root.add_child(root)


func _add_cell_highlight(cell: Vector2i, highlight_kind: String) -> void:
	var colors := {
		"placement": Color(0.20, 0.82, 0.40, 0.56),
		"movement": Color(0.20, 0.62, 1.0, 0.58),
		"attack": Color(1.0, 0.25, 0.20, 0.63),
		"source": Color(0.96, 0.72, 0.18, 0.60),
		"anchor_choice": Color(0.72, 0.34, 1.0, 0.64),
	}
	var marker := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL_SIZE - 0.13, 0.035, CELL_SIZE - 0.13)
	marker.mesh = mesh
	marker.position = cell_to_world(cell) + Vector3(0.0, 0.015, 0.0)
	marker.material_override = _make_material(colors.get(highlight_kind, Color(1.0, 0.8, 0.1, 0.55)), true)
	_highlight_root.add_child(marker)


func _add_selection_marker(cell: Vector2i) -> void:
	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.56
	mesh.bottom_radius = 0.56
	mesh.height = 0.045
	mesh.radial_segments = 24
	marker.mesh = mesh
	marker.position = cell_to_world(cell) + Vector3(0.0, 0.055, 0.0)
	marker.material_override = _make_material(Color(1.0, 0.84, 0.12, 0.74), true)
	_highlight_root.add_child(marker)


func _owner_material(player: RuleTypes.Player, zero_hp: bool) -> StandardMaterial3D:
	if player == RuleTypes.Player.BLACK:
		return _black_zero_hp_material if zero_hp else _black_material
	return _white_zero_hp_material if zero_hp else _white_material


func _inactive_material(player: RuleTypes.Player) -> StandardMaterial3D:
	var color := Color(0.15, 0.20, 0.29, 0.42) if player == RuleTypes.Player.BLACK else Color(0.95, 0.91, 0.82, 0.48)
	return _make_material(color, false)


func _label_color(player: RuleTypes.Player) -> Color:
	return Color("a9c7ff") if player == RuleTypes.Player.BLACK else Color("fff4ca")


func _make_material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = 0.55
	return material


func _make_world_label(text: String, color: Color, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.005
	label.outline_size = 7
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	return label


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
