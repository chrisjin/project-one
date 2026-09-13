## 3D projection of GameState, engine-approved highlights, bindings, and attack threats.
class_name AnchorDebugBoardView
extends Node3D

const RuleTypes = preload("res://scripts/gameplay/rule_types.gd")

const CELL_SIZE := 1.2
const BOARD_SURFACE_Y := 0.0

var map_definition
var _map_signature := ""
var _board_root: Node3D
var _binding_flow_root: Node3D
var _threat_flow_root: Node3D
var _highlight_root: Node3D
var _entity_root: Node3D
var _black_material: StandardMaterial3D
var _white_material: StandardMaterial3D
var _black_zero_hp_material: StandardMaterial3D
var _white_zero_hp_material: StandardMaterial3D
var _binding_dot_mesh: SphereMesh
var _binding_dot_material: StandardMaterial3D
var _warning_badge_mesh: ArrayMesh
var _shield_badge_mesh: ArrayMesh
var _warning_badge_material: StandardMaterial3D
var _friendly_shield_badge_material: StandardMaterial3D
var _enemy_shield_badge_material: StandardMaterial3D
var _friendly_threat_line_material: StandardMaterial3D
var _enemy_threat_line_material: StandardMaterial3D
var _friendly_threat_arrow_material: StandardMaterial3D
var _enemy_threat_arrow_material: StandardMaterial3D
var _binding_paths: Array[Dictionary] = []
var _binding_flow_distance := 0.0
var _threat_paths: Array[Dictionary] = []
var _threat_flow_distance := 0.0


func _ready() -> void:
	_board_root = Node3D.new()
	_board_root.name = "BoardGeometry"
	add_child(_board_root)
	_binding_flow_root = Node3D.new()
	_binding_flow_root.name = "BindingFlow"
	add_child(_binding_flow_root)
	_threat_flow_root = Node3D.new()
	_threat_flow_root.name = "ThreatFlow"
	add_child(_threat_flow_root)
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
	_binding_dot_mesh = SphereMesh.new()
	_binding_dot_mesh.radius = 0.065
	_binding_dot_mesh.height = 0.13
	_binding_dot_mesh.radial_segments = 8
	_binding_dot_mesh.rings = 4
	_binding_dot_material = _make_material(Color(1.0, 0.93, 0.55, 0.94), true)
	_warning_badge_mesh = _make_flat_mesh(
		PackedVector2Array([Vector2(0.0, -0.16), Vector2(-0.15, 0.14), Vector2(0.15, 0.14)]),
		PackedInt32Array([0, 1, 2])
	)
	_shield_badge_mesh = _make_flat_mesh(
		PackedVector2Array([
			Vector2(-0.14, -0.14),
			Vector2(0.14, -0.14),
			Vector2(0.14, 0.03),
			Vector2(0.0, 0.18),
			Vector2(-0.14, 0.03),
		]),
		PackedInt32Array([0, 2, 1, 0, 3, 2, 0, 4, 3])
	)
	_warning_badge_material = _make_status_material(Color("ff263b"))
	_friendly_shield_badge_material = _make_status_material(Color("ffc928"))
	_enemy_shield_badge_material = _make_status_material(Color("287cff"))
	_friendly_threat_line_material = _make_status_material(Color(0.12, 0.92, 0.34, 0.28))
	_enemy_threat_line_material = _make_status_material(Color(1.0, 0.12, 0.18, 0.28))
	_friendly_threat_arrow_material = _make_status_material(Color(0.18, 1.0, 0.42, 0.78))
	_enemy_threat_arrow_material = _make_status_material(Color(1.0, 0.18, 0.22, 0.78))


func _process(delta: float) -> void:
	if not _binding_paths.is_empty():
		_binding_flow_distance += delta * 0.42
		_update_binding_flow_positions()
	if not _threat_paths.is_empty():
		_threat_flow_distance += delta * 0.72
		_update_threat_flow_positions()


func refresh_from_state(
	state,
	cell_highlights: Dictionary = {},
	selected_entity: Dictionary = {},
	binding_visual: Dictionary = {},
	entity_statuses: Dictionary = {},
	threat_visuals: Array = []
) -> void:
	map_definition = state.map_definition
	var signature := JSON.stringify(map_definition.canonical_data())
	if signature != _map_signature:
		_map_signature = signature
		_rebuild_board()
	_render_binding_flow(state, binding_visual)
	_render_threat_flow(state, threat_visuals)
	_clear_children(_highlight_root)
	_clear_children(_entity_root)
	for cell: Vector2i in cell_highlights:
		_add_cell_highlight(cell, str(cell_highlights[cell]))
	if not selected_entity.is_empty():
		_add_selection_marker(state.entity_cell(selected_entity))
	for anchor_id: int in state.anchors:
		_render_anchor(
			state.anchors[anchor_id],
			entity_statuses.get(_entity_status_key(RuleTypes.EntityKind.ANCHOR, anchor_id), {})
		)
	for board_piece_id: int in state.board_pieces:
		_render_board_piece(
			state.board_pieces[board_piece_id],
			entity_statuses.get(_entity_status_key(RuleTypes.EntityKind.BOARD_PIECE, board_piece_id), {})
		)


func _render_binding_flow(state, binding_visual: Dictionary) -> void:
	_clear_children(_binding_flow_root)
	_binding_paths.clear()
	_binding_flow_distance = 0.0
	if binding_visual.is_empty():
		return
	var anchor_id: int = int(binding_visual.get("anchor_id", 0))
	if not state.anchors.has(anchor_id):
		return
	var anchor_position := cell_to_world(state.anchors[anchor_id].cell) + Vector3(0.0, 0.15, 0.0)
	for board_piece_id: int in binding_visual.get("board_piece_ids", []):
		if not state.board_pieces.has(board_piece_id):
			continue
		var board_piece_position := cell_to_world(state.board_pieces[board_piece_id].cell) + Vector3(0.0, 0.15, 0.0)
		_add_binding_path(anchor_id, board_piece_id, anchor_position, board_piece_position)
	_update_binding_flow_positions()


func _add_binding_path(
	anchor_id: int,
	board_piece_id: int,
	start: Vector3,
	end: Vector3
) -> void:
	var distance := start.distance_to(end)
	if distance <= 0.01:
		return
	var path_root := Node3D.new()
	path_root.name = "Anchor_%d_To_BoardPiece_%d" % [anchor_id, board_piece_id]
	_binding_flow_root.add_child(path_root)
	var dot_count := maxi(3, ceili(distance / 0.34))
	var dots: Array[MeshInstance3D] = []
	for dot_index in range(dot_count):
		var dot := MeshInstance3D.new()
		dot.name = "Dot_%d" % dot_index
		dot.mesh = _binding_dot_mesh
		dot.material_override = _binding_dot_material
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		path_root.add_child(dot)
		dots.append(dot)
	_binding_paths.append({
		"start": start,
		"direction": start.direction_to(end),
		"distance": distance,
		"spacing": distance / float(dot_count),
		"dots": dots,
	})


func _update_binding_flow_positions() -> void:
	for path: Dictionary in _binding_paths:
		var path_distance: float = path.distance
		var dots: Array = path.dots
		for dot_index in range(dots.size()):
			var distance_along := fposmod(float(dot_index) * float(path.spacing) + _binding_flow_distance, path_distance)
			dots[dot_index].position = path.start + path.direction * distance_along


func _render_threat_flow(state, threat_visuals: Array) -> void:
	_clear_children(_threat_flow_root)
	_threat_paths.clear()
	_threat_flow_distance = 0.0
	for visual_index in range(threat_visuals.size()):
		var visual: Dictionary = threat_visuals[visual_index]
		var attacker_id := int(visual.get("attacker_id", 0))
		var target: Dictionary = visual.get("target", {})
		if not state.board_pieces.has(attacker_id) or target.is_empty():
			continue
		var source_cell: Vector2i = state.board_pieces[attacker_id].cell
		var target_cell: Vector2i = state.entity_cell(target)
		if target_cell.x < 0:
			continue
		_add_threat_path(
			visual_index,
			cell_to_world(source_cell),
			cell_to_world(target_cell),
			bool(visual.get("is_enemy", false))
		)
	_update_threat_flow_positions()


func _add_threat_path(path_index: int, source: Vector3, target: Vector3, is_enemy: bool) -> void:
	var full_direction := source.direction_to(target)
	var start := source + full_direction * 0.34 + Vector3.UP * 0.82
	var end := target - full_direction * 0.34 + Vector3.UP * 0.82
	var distance := start.distance_to(end)
	if distance <= 0.01:
		return

	var path_root := Node3D.new()
	path_root.name = "Threat_%d" % path_index
	_threat_flow_root.add_child(path_root)
	var line := MeshInstance3D.new()
	line.name = "Line"
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(0.055, 0.018, distance)
	line.mesh = line_mesh
	line.material_override = _enemy_threat_line_material if is_enemy else _friendly_threat_line_material
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	path_root.add_child(line)
	line.position = start.lerp(end, 0.5)
	line.look_at(end, Vector3.UP)

	var arrow := MeshInstance3D.new()
	arrow.name = "Arrow"
	arrow.mesh = _warning_badge_mesh
	arrow.material_override = _enemy_threat_arrow_material if is_enemy else _friendly_threat_arrow_material
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	path_root.add_child(arrow)
	arrow.position = start
	arrow.look_at(end, Vector3.UP)
	_threat_paths.append({
		"start": start,
		"direction": start.direction_to(end),
		"distance": distance,
		"phase": fposmod(float(path_index) * 0.37, 1.0),
		"arrow": arrow,
		"is_enemy": is_enemy,
	})


func _update_threat_flow_positions() -> void:
	for path: Dictionary in _threat_paths:
		var path_distance: float = path.distance
		var distance_along := fposmod(
			_threat_flow_distance + float(path.phase) * path_distance,
			path_distance
		)
		path.arrow.position = path.start + path.direction * distance_along


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
	var light_tile := _make_material(Color("cce8f7"))
	var dark_tile := _make_material(Color("b7d8ec"))
	var edge_material := _make_material(Color("10151d"))
	var grid_backing := MeshInstance3D.new()
	grid_backing.name = "GridBacking"
	var backing_mesh := BoxMesh.new()
	backing_mesh.size = Vector3(
		float(map_definition.width) * CELL_SIZE + 0.25,
		0.10,
		float(map_definition.height) * CELL_SIZE + 0.25
	)
	grid_backing.mesh = backing_mesh
	grid_backing.material_override = edge_material
	grid_backing.position.y = -0.13
	_board_root.add_child(grid_backing)
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


func _render_anchor(anchor, statuses: Dictionary = {}) -> void:
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
	_add_status_icons(root, statuses)
	_entity_root.add_child(root)


func _render_board_piece(board_piece, statuses: Dictionary = {}) -> void:
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
	_add_status_icons(root, statuses)
	_entity_root.add_child(root)


func _add_status_icons(entity_root: Node3D, statuses: Dictionary) -> void:
	var status_kinds: Array[String] = []
	if bool(statuses.get("attack_threat", false)):
		status_kinds.append("attack_threat")
	if bool(statuses.get("dual_anchor_protection", false)):
		status_kinds.append("dual_anchor_protection")
	if status_kinds.is_empty():
		return

	var icons_root := Node3D.new()
	icons_root.name = "StatusIcons"
	entity_root.add_child(icons_root)
	for index in range(status_kinds.size()):
		var icon: Node3D
		if status_kinds[index] == "attack_threat":
			icon = _make_warning_icon()
		else:
			icon = _make_shield_icon(bool(statuses.get("enemy_dual_anchor_protection", false)))
		# From the fixed top-down camera, -Z is screen-up and +X is screen-right.
		icon.position = Vector3(0.43 - float(index) * 0.31, 1.02, -0.43)
		icons_root.add_child(icon)


func _make_warning_icon() -> Node3D:
	var root := Node3D.new()
	root.name = "ThreatWarning"
	var badge := MeshInstance3D.new()
	badge.name = "Badge"
	badge.mesh = _warning_badge_mesh
	badge.material_override = _warning_badge_material
	badge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(badge)
	var symbol := _make_world_label("!", Color.WHITE, 34)
	symbol.name = "Symbol"
	symbol.position.y = 0.025
	root.add_child(symbol)
	return root


func _make_shield_icon(is_enemy: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "DualProtectionShield"
	var badge := MeshInstance3D.new()
	badge.name = "Badge"
	badge.mesh = _shield_badge_mesh
	badge.material_override = _enemy_shield_badge_material if is_enemy else _friendly_shield_badge_material
	badge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(badge)
	return root


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
	return Color("a9c7ff") if player == RuleTypes.Player.BLACK else Color("51472f")


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


func _make_status_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.2
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _make_flat_mesh(points: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for point: Vector2 in points:
		vertices.append(Vector3(point.x, 0.0, point.y))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


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


func _entity_status_key(entity_kind: RuleTypes.EntityKind, entity_id: int) -> String:
	return "%d:%d" % [entity_kind, entity_id]


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
