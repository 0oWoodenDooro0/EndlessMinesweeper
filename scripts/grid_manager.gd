class_name GridManager
extends Node2D

const GameSession = preload("res://scripts/game_session.gd")
const ChunkManager = preload("res://scripts/chunk_manager.gd")
const ChunkData = preload("res://scripts/chunk_data.gd")

signal cell_revealed(pos: Vector2i, is_mine: bool)
signal cell_flag_changed(pos: Vector2i, is_flagged: bool)
signal game_over(hit_mine_pos: Vector2i)
signal game_reset
signal chunk_locked(chunk_pos: Vector2i, mine_pos: Vector2i)
signal chunk_cleared(chunk_pos: Vector2i)
signal chunk_unlocked(chunk_pos: Vector2i, recovered_flags: Array[Vector2i])

@export var world_seed: int = 1337
@export var mine_density: float = 0.15
@export var cell_size: Vector2i = Vector2i(32, 32)
@export var safe_zone_radius: int = 1
@export var chunk_size: Vector2i = Vector2i(8, 8):
	set(value):
		chunk_size = value
		if chunk_manager != null:
			chunk_manager.chunk_size = value
@export var enable_chunk_lockout: bool = true

var session: GameSession = null
var has_first_clicked: bool = false
var first_click_pos: Vector2i = Vector2i.ZERO
var is_game_over: bool = false
var grid_data: Dictionary = {} # Vector2i -> CellData
var chunk_manager: ChunkManager = null
var chunks: Dictionary:
	get:
		if chunk_manager != null:
			return chunk_manager.chunks
		return {}
var visible_rect: Rect2 = Rect2(-640, -360, 1280, 720)

func _init() -> void:
	_init_chunk_manager()

func _init_chunk_manager() -> void:
	if chunk_manager == null:
		chunk_manager = ChunkManager.new()
		chunk_manager.setup(chunk_size, Callable(self, "is_mine_at"), Callable(self, "_is_cell_revealed_safe"))
		chunk_manager.chunk_locked.connect(_on_chunk_manager_locked)
		chunk_manager.chunk_cleared.connect(_on_chunk_manager_cleared)
		chunk_manager.chunk_unlocked.connect(_on_chunk_manager_unlocked)

func bind_session(sess: GameSession) -> void:
	session = sess

func _is_cell_revealed_safe(p: Vector2i) -> bool:
	return grid_data.has(p) and grid_data[p].is_revealed and not grid_data[p].is_mine

func cell_to_chunk(cell_pos: Vector2i) -> Vector2i:
	return chunk_manager.cell_to_chunk(cell_pos)

func get_chunk(c_pos: Vector2i) -> ChunkData:
	return chunk_manager.get_chunk(c_pos)

func get_chunk_for_cell(cell_pos: Vector2i) -> ChunkData:
	return chunk_manager.get_chunk_for_cell(cell_pos)

func recalculate_chunk_safe_cells(c_pos: Vector2i) -> void:
	chunk_manager.recalculate_chunk_safe_cells(c_pos)

func get_cell(pos: Vector2i) -> CellData:
	if grid_data.has(pos):
		return grid_data[pos]
	
	var cell = CellData.new(pos)
	cell.is_mine = is_mine_at(pos)
	grid_data[pos] = cell
	return cell

func is_mine_at(pos: Vector2i) -> bool:
	if grid_data.has(pos):
		return grid_data[pos].is_mine

	if is_in_safe_zone(pos):
		return false

	return _calc_hash_mine(pos)

func _calc_hash_mine(pos: Vector2i) -> bool:
	var h = hash(Vector3i(pos.x, pos.y, world_seed))
	var positive_h = h & 0x7FFFFFFF
	var rand_val = float(positive_h) / float(0x7FFFFFFF)
	return rand_val < mine_density

func is_in_safe_zone(pos: Vector2i) -> bool:
	if not has_first_clicked:
		return false
	var dx = abs(pos.x - first_click_pos.x)
	var dy = abs(pos.y - first_click_pos.y)
	return max(dx, dy) <= safe_zone_radius

func set_first_click(pos: Vector2i) -> void:
	has_first_clicked = true
	first_click_pos = pos

	var affected_chunks = {}
	for dx in range(-safe_zone_radius, safe_zone_radius + 1):
		for dy in range(-safe_zone_radius, safe_zone_radius + 1):
			var p = pos + Vector2i(dx, dy)
			var cell = get_cell(p)
			cell.is_mine = false
			affected_chunks[chunk_manager.cell_to_chunk(p)] = true

	for c_pos in affected_chunks:
		chunk_manager.recalculate_chunk_safe_cells(c_pos)

func set_mine_at(pos: Vector2i, mine_state: bool) -> void:
	if chunk_manager.is_cell_in_cleared_chunk(pos):
		return
	if not has_first_clicked:
		has_first_clicked = true
		first_click_pos = Vector2i(-999999, -999999)
	var cell = get_cell(pos)
	cell.is_mine = mine_state
	chunk_manager.recalculate_chunk_safe_cells(chunk_manager.cell_to_chunk(pos))

func count_neighbor_mines(pos: Vector2i) -> int:
	var count = 0
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var n_pos = pos + Vector2i(dx, dy)
			if is_mine_at(n_pos):
				count += 1
	return count

func count_neighbor_flags(pos: Vector2i) -> int:
	var count = 0
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var n_pos = pos + Vector2i(dx, dy)
			if get_cell(n_pos).is_flagged:
				count += 1
	return count

func reset_game(new_density: float = -1.0, new_seed: int = -1) -> void:
	has_first_clicked = false
	first_click_pos = Vector2i.ZERO
	is_game_over = false
	if new_density > 0.0:
		mine_density = new_density
	if new_seed >= 0:
		world_seed = new_seed
	else:
		world_seed = randi() & 0x7FFFFFFF
	grid_data.clear()
	chunk_manager.reset(chunk_size)
	if session != null:
		session.reset(new_density)
	game_reset.emit()
	_request_redraw()

func reveal_cell(pos: Vector2i) -> bool:
	if is_game_over:
		return false

	if chunk_manager.is_cell_in_locked_chunk(pos) or chunk_manager.is_cell_in_cleared_chunk(pos):
		return false

	var cell = get_cell(pos)
	if cell.is_revealed or cell.is_flagged:
		return false

	if not has_first_clicked:
		set_first_click(pos)

	# Ensure chunk is initialized before marking cell as revealed
	var chunk = chunk_manager.get_chunk_for_cell(pos)

	cell.is_revealed = true
	cell_revealed.emit(pos, cell.is_mine)
	if session != null:
		session.record_reveal(pos, cell.is_mine)

	var outcome = chunk_manager.register_reveal(pos, cell.is_mine, enable_chunk_lockout)

	if cell.is_mine:
		if not enable_chunk_lockout:
			is_game_over = true
			game_over.emit(pos)
			if session != null:
				session.trigger_game_over(pos)
		_request_redraw()
		return true

	if count_neighbor_mines(pos) == 0:
		_expand_zero_mines_bfs(pos)

	_request_redraw()
	return true

func _expand_zero_mines_bfs(start_pos: Vector2i) -> void:
	var queue: Array[Vector2i] = [start_pos]
	var visited: Dictionary = {start_pos: true}

	while queue.size() > 0:
		var curr_pos = queue.pop_front()
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var n_pos = curr_pos + Vector2i(dx, dy)
				if visited.has(n_pos):
					continue
				visited[n_pos] = true

				if chunk_manager.is_cell_in_locked_chunk(n_pos) or chunk_manager.is_cell_in_cleared_chunk(n_pos):
					continue


				var n_cell = get_cell(n_pos)
				if n_cell.is_flagged or n_cell.is_revealed:
					continue

				var n_chunk = chunk_manager.get_chunk_for_cell(n_pos)

				n_cell.is_revealed = true
				cell_revealed.emit(n_pos, n_cell.is_mine)
				if session != null:
					session.record_reveal(n_pos, n_cell.is_mine)

				if not n_cell.is_mine:
					chunk_manager.register_reveal(n_pos, false, enable_chunk_lockout)
					if count_neighbor_mines(n_pos) == 0:
						queue.append(n_pos)

func _auto_flag_chunk_mines(c_pos: Vector2i) -> void:
	var mine_positions = chunk_manager.get_chunk_mine_positions(c_pos)
	for pos in mine_positions:
		var cell = get_cell(pos)
		if not cell.is_flagged:
			cell.is_flagged = true
			cell_flag_changed.emit(pos, true)
			if session != null:
				session.record_flag_toggle(pos, true)

func _on_chunk_manager_locked(c_pos: Vector2i, m_pos: Vector2i) -> void:
	chunk_locked.emit(c_pos, m_pos)
	if session != null:
		session.record_chunk_locked(c_pos, m_pos)
	_request_redraw()

func _on_chunk_manager_cleared(c_pos: Vector2i) -> void:
	_auto_flag_chunk_mines(c_pos)
	chunk_cleared.emit(c_pos)
	if session != null:
		session.record_chunk_cleared(c_pos)

func _on_chunk_manager_unlocked(c_pos: Vector2i, recovered_mines: Array[Vector2i]) -> void:
	for m_pos in recovered_mines:
		var m_cell = get_cell(m_pos)
		m_cell.is_revealed = false
		m_cell.is_flagged = true
		cell_flag_changed.emit(m_pos, true)
		if session != null:
			session.record_flag_toggle(m_pos, true)
	chunk_unlocked.emit(c_pos, recovered_mines)
	if session != null:
		session.record_chunk_unlocked(c_pos, recovered_mines)
	_request_redraw()

func toggle_flag(pos: Vector2i) -> void:
	if is_game_over:
		return

	if chunk_manager.is_cell_in_locked_chunk(pos) or chunk_manager.is_cell_in_cleared_chunk(pos):
		return

	var cell = get_cell(pos)
	if cell.is_revealed:
		return

	cell.is_flagged = not cell.is_flagged
	cell_flag_changed.emit(pos, cell.is_flagged)
	if session != null:
		session.record_flag_toggle(pos, cell.is_flagged)
	_request_redraw()

func chord_reveal(pos: Vector2i) -> bool:
	if is_game_over:
		return false

	if chunk_manager.is_cell_in_locked_chunk(pos) or chunk_manager.is_cell_in_cleared_chunk(pos):
		return false

	var cell = get_cell(pos)
	if not cell.is_revealed:
		return false

	var neighbor_mines_cnt = count_neighbor_mines(pos)
	var neighbor_flags_cnt = count_neighbor_flags(pos)

	if neighbor_mines_cnt == 0 or neighbor_flags_cnt != neighbor_mines_cnt:
		return false

	var revealed_any = false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var n_pos = pos + Vector2i(dx, dy)
			if chunk_manager.is_cell_in_locked_chunk(n_pos) or chunk_manager.is_cell_in_cleared_chunk(n_pos):
				continue
			var n_cell = get_cell(n_pos)
			if not n_cell.is_revealed and not n_cell.is_flagged:
				if reveal_cell(n_pos):
					revealed_any = true

	return revealed_any

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / float(cell_size.x))), int(floor(world_pos.y / float(cell_size.y))))

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		return

	if event is InputEventMouseButton and event.pressed:
		var cell_pos = world_to_cell(get_global_mouse_position())
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				chord_reveal(cell_pos)
			else:
				reveal_cell(cell_pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			toggle_flag(cell_pos)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			chord_reveal(cell_pos)

func update_visible_area(rect: Rect2) -> void:
	visible_rect = rect
	_request_redraw()

func _request_redraw() -> void:
	if is_inside_tree():
		queue_redraw()

func _draw() -> void:
	var min_tile_x = int(floor(visible_rect.position.x / float(cell_size.x))) - 1
	var min_tile_y = int(floor(visible_rect.position.y / float(cell_size.y))) - 1
	var max_tile_x = int(ceil(visible_rect.end.x / float(cell_size.x))) + 1
	var max_tile_y = int(ceil(visible_rect.end.y / float(cell_size.y))) + 1

	var font = ThemeDB.fallback_font
	var font_size = 16

	for x in range(min_tile_x, max_tile_x):
		for y in range(min_tile_y, max_tile_y):
			var tile_pos = Vector2i(x, y)
			var cell = get_cell(tile_pos)
			var rect = Rect2(Vector2(x * cell_size.x, y * cell_size.y), Vector2(cell_size))

			if cell.is_revealed:
				if cell.is_mine:
					draw_rect(rect, Color(0.9, 0.2, 0.2))
				else:
					draw_rect(rect, Color(0.85, 0.85, 0.85))
			else:
				draw_rect(rect, Color(0.65, 0.65, 0.65))

			draw_rect(rect, Color(0.3, 0.3, 0.3, 0.4), false, 1.0)

			if cell.is_revealed:
				if not cell.is_mine:
					var neighbors = count_neighbor_mines(tile_pos)
					if neighbors > 0:
						var color = _get_number_color(neighbors)
						var text_pos = rect.position + Vector2(cell_size.x * 0.3, cell_size.y * 0.75)
						draw_string(font, text_pos, str(neighbors), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			elif cell.is_flagged:
				var flag_text_pos = rect.position + Vector2(cell_size.x * 0.3, cell_size.y * 0.75)
				draw_string(font, flag_text_pos, "F", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.9, 0.1, 0.1))

	# Draw Chunk overlays and boundaries
	var min_chunk_x = int(floor(float(min_tile_x) / float(chunk_size.x)))
	var min_chunk_y = int(floor(float(min_tile_y) / float(chunk_size.y)))
	var max_chunk_x = int(ceil(float(max_tile_x) / float(chunk_size.x)))
	var max_chunk_y = int(ceil(float(max_tile_y) / float(chunk_size.y)))

	var chunk_pixel_size = Vector2(chunk_size.x * cell_size.x, chunk_size.y * cell_size.y)

	for cx in range(min_chunk_x, max_chunk_x + 1):
		for cy in range(min_chunk_y, max_chunk_y + 1):
			var c_pos = Vector2i(cx, cy)
			var chunk_rect = Rect2(Vector2(cx * chunk_pixel_size.x, cy * chunk_pixel_size.y), chunk_pixel_size)

			# Draw chunk boundary
			draw_rect(chunk_rect, Color(0.2, 0.4, 0.8, 0.5), false, 2.0)

			if chunk_manager.has_chunk(c_pos):
				var chunk_data = chunk_manager.get_chunk(c_pos)
				if chunk_data.is_locked:
					draw_rect(chunk_rect, Color(0.9, 0.1, 0.1, 0.25))
					var lock_label = "[LOCKED]"
					var label_pos = chunk_rect.position + chunk_pixel_size * 0.5 + Vector2(-30, 6)
					draw_string(font, label_pos, lock_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1.0, 0.2, 0.2))
				elif chunk_data.is_cleared:
					draw_rect(chunk_rect, Color(0.2, 0.9, 0.2, 0.12))
					draw_rect(chunk_rect, Color(0.2, 0.9, 0.2, 0.7), false, 2.0)

func _get_number_color(number: int) -> Color:
	match number:
		1: return Color(0.1, 0.3, 0.9)
		2: return Color(0.1, 0.7, 0.2)
		3: return Color(0.9, 0.1, 0.1)
		4: return Color(0.5, 0.1, 0.7)
		5: return Color(0.7, 0.4, 0.1)
		6: return Color(0.1, 0.7, 0.7)
		7: return Color(0.1, 0.1, 0.1)
		8: return Color(0.5, 0.5, 0.5)
		_: return Color.BLACK

func serialize() -> Dictionary:
	var serialized_cells = []
	for p in grid_data:
		var cell = grid_data[p]
		serialized_cells.append({
			"x": p.x,
			"y": p.y,
			"is_mine": cell.is_mine,
			"is_revealed": cell.is_revealed,
			"is_flagged": cell.is_flagged
		})

	return {
		"world_seed": world_seed,
		"mine_density": mine_density,
		"has_first_clicked": has_first_clicked,
		"first_click_pos": [first_click_pos.x, first_click_pos.y],
		"is_game_over": is_game_over,
		"chunk_size": [chunk_size.x, chunk_size.y],
		"safe_zone_radius": safe_zone_radius,
		"enable_chunk_lockout": enable_chunk_lockout,
		"cells": serialized_cells,
		"chunks": chunk_manager.serialize()
	}

func deserialize(data: Dictionary) -> bool:
	if data == null or not data.has("world_seed") or not data.has("mine_density") or not data.has("cells") or not data.has("chunks"):
		return false

	if not (data["cells"] is Array) or not (data["chunks"] is Array):
		return false

	world_seed = int(data["world_seed"])
	mine_density = float(data["mine_density"])
	has_first_clicked = bool(data.get("has_first_clicked", false))
	if data.has("first_click_pos") and data["first_click_pos"] is Array and data["first_click_pos"].size() >= 2:
		first_click_pos = Vector2i(int(data["first_click_pos"][0]), int(data["first_click_pos"][1]))
	else:
		first_click_pos = Vector2i.ZERO

	is_game_over = bool(data.get("is_game_over", false))

	if data.has("chunk_size") and data["chunk_size"] is Array and data["chunk_size"].size() >= 2:
		chunk_size = Vector2i(int(data["chunk_size"][0]), int(data["chunk_size"][1]))

	safe_zone_radius = int(data.get("safe_zone_radius", 1))
	enable_chunk_lockout = bool(data.get("enable_chunk_lockout", true))

	grid_data.clear()
	for c_info in data["cells"]:
		if not (c_info is Dictionary) or not c_info.has("x") or not c_info.has("y"):
			continue
		var p = Vector2i(int(c_info["x"]), int(c_info["y"]))
		var cell = CellData.new(p)
		cell.is_mine = bool(c_info.get("is_mine", false))
		cell.is_revealed = bool(c_info.get("is_revealed", false))
		cell.is_flagged = bool(c_info.get("is_flagged", false))
		grid_data[p] = cell

	chunk_manager.deserialize(data["chunks"])

	_request_redraw()
	return true
