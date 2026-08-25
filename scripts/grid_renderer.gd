class_name GridRenderer
extends Node2D

const GridManager = preload("res://scripts/grid_manager.gd")
const ChunkManager = preload("res://scripts/chunk_manager.gd")
const ChunkData = preload("res://scripts/chunk_data.gd")
const CellData = preload("res://scripts/cell_data.gd")

@export var grid_manager: GridManager
@export var custom_font: Font = null
@export var lod_zoom_threshold: float = 0.9

var current_zoom_level: float = 1.0
var visible_rect: Rect2 = Rect2(-640, -360, 1280, 720)
var _default_msdf_font: Font = null

const DEFAULT_FONT_PATH: String = "res://assets/fonts/NotoSans-Bold.ttf"

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

func _ready() -> void:
	if grid_manager != null:
		bind_grid_manager(grid_manager)

func bind_grid_manager(grid: GridManager) -> void:
	if grid_manager != null and is_instance_valid(grid_manager):
		if grid_manager.redraw_requested.is_connected(_request_redraw):
			grid_manager.redraw_requested.disconnect(_request_redraw)
		if grid_manager.cell_revealed.is_connected(_on_cell_revealed):
			grid_manager.cell_revealed.disconnect(_on_cell_revealed)
		if grid_manager.cell_flag_changed.is_connected(_on_cell_flag_changed):
			grid_manager.cell_flag_changed.disconnect(_on_cell_flag_changed)
		if grid_manager.chunk_locked.is_connected(_on_chunk_locked):
			grid_manager.chunk_locked.disconnect(_on_chunk_locked)
		if grid_manager.chunk_cleared.is_connected(_on_chunk_cleared):
			grid_manager.chunk_cleared.disconnect(_on_chunk_cleared)
		if grid_manager.chunk_unlocked.is_connected(_on_chunk_unlocked):
			grid_manager.chunk_unlocked.disconnect(_on_chunk_unlocked)
		if grid_manager.game_reset.is_connected(_on_game_reset):
			grid_manager.game_reset.disconnect(_on_game_reset)

	grid_manager = grid
	if grid_manager == null:
		return

	if not grid_manager.redraw_requested.is_connected(_request_redraw):
		grid_manager.redraw_requested.connect(_request_redraw)
	if not grid_manager.cell_revealed.is_connected(_on_cell_revealed):
		grid_manager.cell_revealed.connect(_on_cell_revealed)
	if not grid_manager.cell_flag_changed.is_connected(_on_cell_flag_changed):
		grid_manager.cell_flag_changed.connect(_on_cell_flag_changed)
	if not grid_manager.chunk_locked.is_connected(_on_chunk_locked):
		grid_manager.chunk_locked.connect(_on_chunk_locked)
	if not grid_manager.chunk_cleared.is_connected(_on_chunk_cleared):
		grid_manager.chunk_cleared.connect(_on_chunk_cleared)
	if not grid_manager.chunk_unlocked.is_connected(_on_chunk_unlocked):
		grid_manager.chunk_unlocked.connect(_on_chunk_unlocked)
	if not grid_manager.game_reset.is_connected(_on_game_reset):
		grid_manager.game_reset.connect(_on_game_reset)

	_request_redraw()

func _on_cell_revealed(_pos: Vector2i, _is_mine: bool) -> void:
	_request_redraw()

func _on_cell_flag_changed(_pos: Vector2i, _is_flagged: bool) -> void:
	_request_redraw()

func _on_chunk_locked(_c_pos: Vector2i, _m_pos: Vector2i) -> void:
	_request_redraw()

func _on_chunk_cleared(_c_pos: Vector2i) -> void:
	_request_redraw()

func _on_chunk_unlocked(_c_pos: Vector2i, _recovered: Array[Vector2i]) -> void:
	_request_redraw()

func _on_game_reset() -> void:
	_request_redraw()

func is_lod_active() -> bool:
	return current_zoom_level <= lod_zoom_threshold

func update_visible_area(rect: Rect2, zoom_level: float = 1.0) -> void:
	visible_rect = rect
	current_zoom_level = zoom_level
	if grid_manager != null:
		grid_manager.update_visible_area(rect, zoom_level)
	_request_redraw()

func _request_redraw() -> void:
	if is_inside_tree():
		queue_redraw()

func _get_active_font() -> Font:
	if custom_font != null:
		return custom_font
	if _default_msdf_font == null:
		if ResourceLoader.exists(DEFAULT_FONT_PATH):
			var font_file = load(DEFAULT_FONT_PATH) as FontFile
			if font_file != null:
				font_file.multichannel_signed_distance_field = true
				font_file.msdf_pixel_range = 16
				font_file.msdf_size = 48
				_default_msdf_font = font_file
		if _default_msdf_font == null:
			var sys_font = SystemFont.new()
			sys_font.font_names = PackedStringArray(["Sans-Serif", "Segoe UI", "Arial", "Roboto", "Helvetica", "Noto Sans"])
			sys_font.multichannel_signed_distance_field = true
			sys_font.msdf_pixel_range = 16
			sys_font.msdf_size = 48
			_default_msdf_font = sys_font
	return _default_msdf_font

func _get_number_color(number: int) -> Color:
	if number >= 0 and number < NUMBER_COLORS.size():
		return NUMBER_COLORS[number]
	return Color.BLACK

func _draw() -> void:
	if grid_manager == null:
		return
	if is_lod_active():
		_draw_chunk_lod_overview()
	else:
		_draw_cells_detail()

func _draw_cells_detail() -> void:
	if grid_manager == null:
		return

	var cell_size = grid_manager.cell_size
	var chunk_size = grid_manager.chunk_size
	var grid_data = grid_manager.grid_data
	var chunk_manager = grid_manager.chunk_manager

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
						var neighbors = grid_manager.count_neighbor_mines(tile_pos)
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
	if grid_manager == null:
		return

	var cell_size = grid_manager.cell_size
	var chunk_size = grid_manager.chunk_size
	var chunk_manager = grid_manager.chunk_manager

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
