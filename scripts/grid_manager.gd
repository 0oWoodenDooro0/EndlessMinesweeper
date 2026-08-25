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

@export var world_seed: int = 1337:
	set(value):
		world_seed = value
		_chunk_mine_cache.clear()
@export var cell_size: Vector2i = Vector2i(32, 32)
@export var safe_zone_radius: int = 1
@export var chunk_size: Vector2i = Vector2i(8, 8):
	set(value):
		chunk_size = value
		_chunk_mine_cache.clear()
		if chunk_manager != null:
			chunk_manager.chunk_size = value
@export var enable_chunk_lockout: bool = true
@export var lod_zoom_threshold: float = 0.9
@export var custom_font: Font = null

var _default_msdf_font: Font = null
var current_zoom_level: float = 1.0
var session: GameSession = null
var has_first_clicked: bool = false
var first_click_pos: Vector2i = Vector2i.ZERO
var is_game_over: bool = false
var grid_data: Dictionary = {} # Vector2i -> CellData
var _chunk_mine_cache: Dictionary = {} # Vector2i -> Dictionary[Vector2i, bool]
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var chunk_manager: ChunkManager = null
var chunks: Dictionary:
	get:
		if chunk_manager != null:
			return chunk_manager.chunks
		return {}
var visible_rect: Rect2 = Rect2(-640, -360, 1280, 720)

func _init() -> void:
	_init_chunk_manager()

func is_cell_revealed(pos: Vector2i) -> bool:
	return grid_data.has(pos) and grid_data[pos].is_revealed

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

	return _is_mine_generated_at(pos)

func _get_or_generate_chunk_mine_mask(c_pos: Vector2i) -> int:
	if _chunk_mine_cache.has(c_pos):
		return _chunk_mine_cache[c_pos]
	var mask = _generate_chunk_mine_mask(c_pos)
	_chunk_mine_cache[c_pos] = mask
	return mask

func _generate_chunk_mine_mask(c_pos: Vector2i) -> int:
	var chunk_seed = hash(Vector3i(c_pos.x, c_pos.y, world_seed))
	_rng.seed = chunk_seed

	var w = chunk_size.x
	var h = chunk_size.y
	if w <= 0 or h <= 0:
		w = 8
		h = 8
	var total_cells = w * h

	var mine_count = 0
	if total_cells == 64:
		var u1 = _rng.randf()
		var u2 = _rng.randf()
		var t = (u1 + u2) / 2.0
		mine_count = 10 + int(floor(11.0 * t))
		mine_count = clampi(mine_count, 10, 20)
	else:
		var u1 = _rng.randf()
		var u2 = _rng.randf()
		var t = (u1 + u2) / 2.0
		var min_m = maxi(1, int(total_cells * (10.0 / 64.0)))
		var max_m = mini(total_cells - 1, int(total_cells * (20.0 / 64.0)))
		var range_m = max_m - min_m + 1
		mine_count = min_m + int(floor(float(range_m) * t))
		mine_count = clampi(mine_count, min_m, max_m)

	var picked: Dictionary = {}
	var mask: int = 0
	for i in range(mine_count):
		var j = _rng.randi_range(i, total_cells - 1)
		var val_j = picked.get(j, j)
		var val_i = picked.get(i, i)
		picked[j] = val_i
		picked[i] = val_j
		if val_j < 64:
			mask |= (1 << val_j)

	return mask

func _generate_chunk_mines(c_pos: Vector2i) -> Array[Vector2i]:
	var mask = _get_or_generate_chunk_mine_mask(c_pos)
	var arr: Array[Vector2i] = []
	var w = chunk_size.x
	var h = chunk_size.y
	var min_x = c_pos.x * w
	var min_y = c_pos.y * h
	var total_cells = mini(w * h, 64)
	for idx in range(total_cells):
		if (mask & (1 << idx)) != 0:
			var lx = idx % w
			var ly = idx / w
			arr.append(Vector2i(min_x + lx, min_y + ly))
	return arr

func _is_mine_generated_at(pos: Vector2i) -> bool:
	var c_pos = cell_to_chunk(pos)
	var mask = _get_or_generate_chunk_mine_mask(c_pos)
	var lx = pos.x - c_pos.x * chunk_size.x
	var ly = pos.y - c_pos.y * chunk_size.y
	var idx = ly * chunk_size.x + lx
	if idx >= 0 and idx < 64:
		return (mask & (1 << idx)) != 0
	return false

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

	# Invalidate neighbor mines cache for safe zone and its immediate perimeter
	for dx in range(-safe_zone_radius - 1, safe_zone_radius + 2):
		for dy in range(-safe_zone_radius - 1, safe_zone_radius + 2):
			var p = pos + Vector2i(dx, dy)
			if grid_data.has(p):
				grid_data[p].neighbor_mines_cached = false

	for c_pos in affected_chunks:
		chunk_manager.recalculate_chunk_safe_cells(c_pos)

	preload_surrounding_chunks(chunk_manager.cell_to_chunk(pos), 1)

func set_mine_at(pos: Vector2i, mine_state: bool) -> void:
	if chunk_manager.is_cell_in_cleared_chunk(pos):
		return
	var cell = get_cell(pos)
	cell.is_mine = mine_state

	# Invalidate neighbor mines cache for pos and its 8-neighbors
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var p = pos + Vector2i(dx, dy)
			if grid_data.has(p):
				grid_data[p].neighbor_mines_cached = false

	chunk_manager.recalculate_chunk_safe_cells(chunk_manager.cell_to_chunk(pos))

func preload_surrounding_chunks(center_chunk_pos: Vector2i, radius: int = 1) -> void:
	var min_c = center_chunk_pos - Vector2i(radius, radius)
	var max_c = center_chunk_pos + Vector2i(radius, radius)
	chunk_manager.preload_chunks_in_rect(min_c, max_c)

func preload_chunks_around_viewport(buffer_chunks: int = 1) -> void:
	var chunk_pixel_size = Vector2(chunk_size.x * cell_size.x, chunk_size.y * cell_size.y)
	if chunk_pixel_size.x <= 0 or chunk_pixel_size.y <= 0:
		return
	var min_chunk_x = int(floor(visible_rect.position.x / chunk_pixel_size.x)) - buffer_chunks
	var min_chunk_y = int(floor(visible_rect.position.y / chunk_pixel_size.y)) - buffer_chunks
	var max_chunk_x = int(ceil(visible_rect.end.x / chunk_pixel_size.x)) + buffer_chunks
	var max_chunk_y = int(ceil(visible_rect.end.y / chunk_pixel_size.y)) + buffer_chunks
	chunk_manager.preload_chunks_in_rect(Vector2i(min_chunk_x, min_chunk_y), Vector2i(max_chunk_x, max_chunk_y))

func count_neighbor_mines(pos: Vector2i) -> int:
	var cell: CellData
	if grid_data.has(pos):
		cell = grid_data[pos]
	else:
		cell = get_cell(pos)

	if cell.neighbor_mines_cached:
		return cell.neighbor_mines

	var count = 0
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var n_pos = pos + Vector2i(dx, dy)
			if is_mine_at(n_pos):
				count += 1

	cell.neighbor_mines = count
	cell.neighbor_mines_cached = true
	return count

func count_neighbor_flags(pos: Vector2i) -> int:
	var count = 0
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var n_pos = pos + Vector2i(dx, dy)
			if grid_data.has(n_pos) and grid_data[n_pos].is_flagged:
				count += 1
	return count

func reset_game(new_seed: int = -1) -> void:
	has_first_clicked = false
	first_click_pos = Vector2i.ZERO
	is_game_over = false
	if new_seed >= 0:
		world_seed = new_seed
	else:
		world_seed = randi() & 0x7FFFFFFF
	_chunk_mine_cache.clear()
	grid_data.clear()
	chunk_manager.reset(chunk_size)
	if session != null:
		session.reset()
	game_reset.emit()
	_request_redraw()

func has_revealed_neighbor(pos: Vector2i) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var n_pos = pos + Vector2i(dx, dy)
			if grid_data.has(n_pos) and grid_data[n_pos].is_revealed:
				return true
	return false

func reveal_cell(pos: Vector2i) -> bool:
	if is_game_over:
		return false

	if chunk_manager.is_cell_in_locked_chunk(pos) or chunk_manager.is_cell_in_cleared_chunk(pos):
		return false

	var cell = get_cell(pos)
	if cell.is_revealed or cell.is_flagged:
		return false

	if has_first_clicked and not has_revealed_neighbor(pos):
		return false

	if not has_first_clicked:
		set_first_click(pos)

	preload_surrounding_chunks(chunk_manager.cell_to_chunk(pos), 1)

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
	var batch_reveals: Array[Vector2i] = []

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

				n_cell.is_revealed = true
				cell_revealed.emit(n_pos, n_cell.is_mine)
				batch_reveals.append(n_pos)

				if not n_cell.is_mine:
					chunk_manager.register_reveal(n_pos, false, enable_chunk_lockout)
					if count_neighbor_mines(n_pos) == 0:
						queue.append(n_pos)

	if session != null and batch_reveals.size() > 0:
		session.record_reveals_batch(batch_reveals, 0)

func _auto_reveal_chunk_safe_cells(c_pos: Vector2i) -> void:
	if chunk_manager == null:
		return
	var safe_positions = chunk_manager.get_chunk_safe_positions(c_pos)
	for pos in safe_positions:
		var cell = get_cell(pos)
		if cell.is_flagged:
			cell.is_flagged = false
			cell_flag_changed.emit(pos, false)
			if session != null:
				session.record_flag_toggle(pos, false)
		if not cell.is_revealed:
			cell.is_revealed = true
			cell_revealed.emit(pos, false)
			if session != null:
				session.record_reveal(pos, false)
			if count_neighbor_mines(pos) == 0:
				_expand_zero_mines_bfs(pos)

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
	_auto_reveal_chunk_safe_cells(c_pos)
	_auto_flag_chunk_mines(c_pos)
	chunk_cleared.emit(c_pos)
	if session != null:
		session.record_chunk_cleared(c_pos)
	_request_redraw()

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

	if not has_revealed_neighbor(pos):
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

	if chunk_manager.is_cell_in_locked_chunk(pos):
		return false

	if not grid_data.has(pos):
		return false

	var cell = grid_data[pos]
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
			if grid_data.has(n_pos):
				var n_cell = grid_data[n_pos]
				if not n_cell.is_revealed and not n_cell.is_flagged:
					if reveal_cell(n_pos):
						revealed_any = true
			else:
				if reveal_cell(n_pos):
					revealed_any = true

	return revealed_any

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / float(cell_size.x))), int(floor(world_pos.y / float(cell_size.y))))

func is_lod_active() -> bool:
	return current_zoom_level <= lod_zoom_threshold

func update_visible_area(rect: Rect2, zoom_level: float = 1.0) -> void:
	visible_rect = rect
	current_zoom_level = zoom_level
	if not is_lod_active():
		preload_chunks_around_viewport(1)
	_request_redraw()

func _request_redraw() -> void:
	if is_inside_tree():
		queue_redraw()

func _draw() -> void:
	if is_lod_active():
		_draw_chunk_lod_overview()
	else:
		_draw_cells_detail()

const NUMBER_STRINGS: Array[String] = ["0", "1", "2", "3", "4", "5", "6", "7", "8"]
const NUMBER_COLORS: Array[Color] = [
	Color.BLACK,
	Color(0.1, 0.3, 0.9),   # 1: Blue
	Color(0.1, 0.7, 0.2),   # 2: Green
	Color(0.9, 0.1, 0.1),   # 3: Red
	Color(0.5, 0.1, 0.7),   # 4: Purple
	Color(0.7, 0.4, 0.1),   # 5: Maroon
	Color(0.1, 0.7, 0.7),   # 6: Turquoise
	Color(0.1, 0.1, 0.1),   # 7: Black
	Color(0.5, 0.5, 0.5)    # 8: Gray
]

const STRING_FLAG: String = "F"
const STRING_LOCKED: String = "[LOCKED]"

const COLOR_TILE_BG: Color = Color(0.65, 0.65, 0.65)
const COLOR_TILE_GRID: Color = Color(0.3, 0.3, 0.3, 0.4)
const COLOR_TILE_REVEALED: Color = Color(0.85, 0.85, 0.85)
const COLOR_TILE_MINE: Color = Color(0.9, 0.2, 0.2)
const COLOR_TILE_FLAG: Color = Color(0.9, 0.1, 0.1)
const COLOR_CHUNK_BORDER: Color = Color(0.2, 0.4, 0.8, 0.5)

const COLOR_LOD_BG: Color = Color(0.18, 0.18, 0.18, 0.6)
const COLOR_LOD_GRID: Color = Color(0.3, 0.3, 0.3, 0.4)

const COLOR_CHUNK_LOCKED_FILL: Color = Color(0.9, 0.1, 0.1, 0.25)
const COLOR_CHUNK_LOCKED_TEXT: Color = Color(1.0, 0.2, 0.2)
const COLOR_CHUNK_CLEARED_FILL: Color = Color(0.2, 0.9, 0.2, 0.12)
const COLOR_CHUNK_CLEARED_BORDER: Color = Color(0.2, 0.9, 0.2, 0.7)

const COLOR_LOD_CLEARED_FILL: Color = Color(0.2, 0.8, 0.2, 0.35)
const COLOR_LOD_CLEARED_BORDER: Color = Color(0.2, 0.9, 0.2, 0.8)
const COLOR_LOD_LOCKED_FILL: Color = Color(0.9, 0.1, 0.1, 0.4)
const COLOR_LOD_LOCKED_BORDER: Color = Color(0.9, 0.2, 0.2, 0.8)
const COLOR_LOD_EXPLORING_BORDER: Color = Color(0.3, 0.6, 0.9, 0.7)

func _get_active_font() -> Font:
	if custom_font != null:
		return custom_font
	if _default_msdf_font == null:
		var sys_font = SystemFont.new()
		sys_font.font_names = PackedStringArray(["Sans-Serif", "Segoe UI", "Arial", "Roboto", "Helvetica", "Noto Sans"])
		sys_font.multichannel_signed_distance_field = true
		sys_font.msdf_pixel_range = 16
		sys_font.msdf_size = 48
		_default_msdf_font = sys_font
	return _default_msdf_font

func _draw_cells_detail() -> void:
	var min_tile_x = int(floor(visible_rect.position.x / float(cell_size.x))) - 1
	var min_tile_y = int(floor(visible_rect.position.y / float(cell_size.y))) - 1
	var max_tile_x = int(ceil(visible_rect.end.x / float(cell_size.x))) + 1
	var max_tile_y = int(ceil(visible_rect.end.y / float(cell_size.y))) + 1

	var font = _get_active_font()
	var font_size = 16

	var world_tile_min = Vector2(min_tile_x * cell_size.x, min_tile_y * cell_size.y)
	var world_tile_max = Vector2(max_tile_x * cell_size.x, max_tile_y * cell_size.y)
	var bg_rect = Rect2(world_tile_min, world_tile_max - world_tile_min)

	# 1. Base background for entire visible tile area (1 draw call)
	draw_rect(bg_rect, COLOR_TILE_BG)

	# 2. Draw revealed cell background fills underneath the grid lines
	for x in range(min_tile_x, max_tile_x):
		for y in range(min_tile_y, max_tile_y):
			var tile_pos = Vector2i(x, y)
			if grid_data.has(tile_pos):
				var cell = grid_data[tile_pos]
				if cell.is_revealed:
					var rect = Rect2(Vector2(x * cell_size.x, y * cell_size.y), Vector2(cell_size))
					if cell.is_mine:
						draw_rect(rect, COLOR_TILE_MINE)
					else:
						draw_rect(rect, COLOR_TILE_REVEALED)

	# 3. Batched tile grid lines drawn ON TOP of all cell fills (1 draw call with draw_multiline)
	var grid_lines = PackedVector2Array()
	for x in range(min_tile_x, max_tile_x + 1):
		var x_pos = x * cell_size.x
		grid_lines.append(Vector2(x_pos, world_tile_min.y))
		grid_lines.append(Vector2(x_pos, world_tile_max.y))
	for y in range(min_tile_y, max_tile_y + 1):
		var y_pos = y * cell_size.y
		grid_lines.append(Vector2(world_tile_min.x, y_pos))
		grid_lines.append(Vector2(world_tile_max.x, y_pos))
	draw_multiline(grid_lines, COLOR_TILE_GRID, 1.0)

	# 4. Draw numbers and flags on top of grid lines
	for x in range(min_tile_x, max_tile_x):
		for y in range(min_tile_y, max_tile_y):
			var tile_pos = Vector2i(x, y)
			if grid_data.has(tile_pos):
				var cell = grid_data[tile_pos]
				var rect = Rect2(Vector2(x * cell_size.x, y * cell_size.y), Vector2(cell_size))

				if cell.is_revealed:
					if not cell.is_mine:
						var neighbors = count_neighbor_mines(tile_pos)
						if neighbors > 0 and neighbors < NUMBER_STRINGS.size():
							var color = _get_number_color(neighbors)
							var text_pos = rect.position + Vector2(cell_size.x * 0.3, cell_size.y * 0.75)
							draw_char(font, text_pos, NUMBER_STRINGS[neighbors], font_size, color)
				elif cell.is_flagged:
					var flag_text_pos = rect.position + Vector2(cell_size.x * 0.3, cell_size.y * 0.75)
					draw_char(font, flag_text_pos, STRING_FLAG, font_size, COLOR_TILE_FLAG)

	# 5. Draw Chunk overlays and boundaries
	var min_chunk_x = int(floor(float(min_tile_x) / float(chunk_size.x)))
	var min_chunk_y = int(floor(float(min_tile_y) / float(chunk_size.y)))
	var max_chunk_x = int(ceil(float(max_tile_x) / float(chunk_size.x)))
	var max_chunk_y = int(ceil(float(max_tile_y) / float(chunk_size.y)))

	var chunk_pixel_size = Vector2(chunk_size.x * cell_size.x, chunk_size.y * cell_size.y)

	# Batched chunk boundary lines (1 draw call)
	var chunk_lines = PackedVector2Array()
	var world_chunk_start_x = min_chunk_x * chunk_pixel_size.x
	var world_chunk_end_x = (max_chunk_x + 1) * chunk_pixel_size.x
	var world_chunk_start_y = min_chunk_y * chunk_pixel_size.y
	var world_chunk_end_y = (max_chunk_y + 1) * chunk_pixel_size.y

	for cx in range(min_chunk_x, max_chunk_x + 2):
		var x_pos = cx * chunk_pixel_size.x
		chunk_lines.append(Vector2(x_pos, world_chunk_start_y))
		chunk_lines.append(Vector2(x_pos, world_chunk_end_y))
	for cy in range(min_chunk_y, max_chunk_y + 2):
		var y_pos = cy * chunk_pixel_size.y
		chunk_lines.append(Vector2(world_chunk_start_x, y_pos))
		chunk_lines.append(Vector2(world_chunk_end_x, y_pos))
	draw_multiline(chunk_lines, COLOR_CHUNK_BORDER, 2.0)

	# Active chunk status overlays
	if chunk_manager != null:
		for c_pos in chunk_manager.chunks:
			if c_pos.x >= min_chunk_x and c_pos.x <= max_chunk_x and c_pos.y >= min_chunk_y and c_pos.y <= max_chunk_y:
				var chunk_data = chunk_manager.chunks[c_pos]
				var chunk_rect = Rect2(Vector2(c_pos.x * chunk_pixel_size.x, c_pos.y * chunk_pixel_size.y), chunk_pixel_size)
				if chunk_data.is_locked:
					draw_rect(chunk_rect, COLOR_CHUNK_LOCKED_FILL)
					var label_pos = chunk_rect.position + chunk_pixel_size * 0.5 + Vector2(-30, 6)
					draw_string(font, label_pos, STRING_LOCKED, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, COLOR_CHUNK_LOCKED_TEXT)
				elif chunk_data.is_cleared:
					draw_rect(chunk_rect, COLOR_CHUNK_CLEARED_FILL)
					draw_rect(chunk_rect, COLOR_CHUNK_CLEARED_BORDER, false, 2.0)

func _draw_chunk_lod_overview() -> void:
	var chunk_pixel_size = Vector2(chunk_size.x * cell_size.x, chunk_size.y * cell_size.y)
	if chunk_pixel_size.x <= 0 or chunk_pixel_size.y <= 0:
		return

	var min_chunk_x = int(floor(visible_rect.position.x / chunk_pixel_size.x)) - 1
	var min_chunk_y = int(floor(visible_rect.position.y / chunk_pixel_size.y)) - 1
	var max_chunk_x = int(ceil(visible_rect.end.x / chunk_pixel_size.x)) + 1
	var max_chunk_y = int(ceil(visible_rect.end.y / chunk_pixel_size.y)) + 1

	var world_chunk_min = Vector2(min_chunk_x * chunk_pixel_size.x, min_chunk_y * chunk_pixel_size.y)
	var world_chunk_max = Vector2((max_chunk_x + 1) * chunk_pixel_size.x, (max_chunk_y + 1) * chunk_pixel_size.y)
	var bg_rect = Rect2(world_chunk_min, world_chunk_max - world_chunk_min)

	# 1. Batched background for entire visible chunk overview (1 draw call)
	draw_rect(bg_rect, COLOR_LOD_BG)

	# 2. Batched chunk grid lines (1 draw call with draw_multiline)
	var chunk_grid_lines = PackedVector2Array()
	for cx in range(min_chunk_x, max_chunk_x + 2):
		var x_pos = cx * chunk_pixel_size.x
		chunk_grid_lines.append(Vector2(x_pos, world_chunk_min.y))
		chunk_grid_lines.append(Vector2(x_pos, world_chunk_max.y))
	for cy in range(min_chunk_y, max_chunk_y + 2):
		var y_pos = cy * chunk_pixel_size.y
		chunk_grid_lines.append(Vector2(world_chunk_min.x, y_pos))
		chunk_grid_lines.append(Vector2(world_chunk_max.x, y_pos))
	draw_multiline(chunk_grid_lines, COLOR_LOD_GRID, 1.0)

	# 3. Only draw instantiated chunks with active states within visible rect
	if chunk_manager != null:
		for c_pos in chunk_manager.chunks:
			if c_pos.x >= min_chunk_x and c_pos.x <= max_chunk_x and c_pos.y >= min_chunk_y and c_pos.y <= max_chunk_y:
				var chunk_data = chunk_manager.chunks[c_pos]
				var chunk_rect = Rect2(Vector2(c_pos.x * chunk_pixel_size.x, c_pos.y * chunk_pixel_size.y), chunk_pixel_size)
				if chunk_data.is_cleared:
					# 🟩 Cleared Chunk
					draw_rect(chunk_rect, COLOR_LOD_CLEARED_FILL)
					draw_rect(chunk_rect, COLOR_LOD_CLEARED_BORDER, false, 2.0)
				elif chunk_data.is_locked:
					# 🟥 Locked Chunk
					draw_rect(chunk_rect, COLOR_LOD_LOCKED_FILL)
					draw_rect(chunk_rect, COLOR_LOD_LOCKED_BORDER, false, 2.0)
				elif chunk_data.revealed_safe_cells > 0:
					# 🟦 Exploring Chunk with progress tint
					var progress = chunk_data.get_progress()
					draw_rect(chunk_rect, Color(0.2, 0.5, 0.9, lerp(0.15, 0.5, progress)))
					draw_rect(chunk_rect, COLOR_LOD_EXPLORING_BORDER, false, 2.0)

func _get_number_color(number: int) -> Color:
	if number >= 0 and number < NUMBER_COLORS.size():
		return NUMBER_COLORS[number]
	return Color.BLACK

func serialize() -> Dictionary:
	var serialized_cells = []
	for p in grid_data:
		var cell = grid_data[p]
		if cell.is_revealed or cell.is_flagged:
			serialized_cells.append({
				"x": p.x,
				"y": p.y,
				"is_mine": cell.is_mine,
				"is_revealed": cell.is_revealed,
				"is_flagged": cell.is_flagged
			})

	return {
		"world_seed": world_seed,
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
	if data == null or not data.has("world_seed") or not data.has("cells") or not data.has("chunks"):
		return false

	if not (data["cells"] is Array) or not (data["chunks"] is Array):
		return false

	world_seed = int(data["world_seed"])
	_chunk_mine_cache.clear()
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
