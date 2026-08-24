class_name GridManager
extends Node2D

@export var world_seed: int = 1337
@export var mine_density: float = 0.15
@export var cell_size: Vector2i = Vector2i(32, 32)
@export var safe_zone_radius: int = 1

var has_first_clicked: bool = false
var first_click_pos: Vector2i = Vector2i.ZERO
var grid_data: Dictionary = {} # Vector2i -> CellData
var visible_rect: Rect2 = Rect2(-640, -360, 1280, 720)

func get_cell(pos: Vector2i) -> CellData:
	if grid_data.has(pos):
		return grid_data[pos]
	
	var cell = CellData.new(pos)
	cell.is_mine = is_mine_at(pos)
	grid_data[pos] = cell
	return cell

func is_mine_at(pos: Vector2i) -> bool:
	if is_in_safe_zone(pos):
		return false

	if grid_data.has(pos):
		return grid_data[pos].is_mine

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

	for dx in range(-safe_zone_radius, safe_zone_radius + 1):
		for dy in range(-safe_zone_radius, safe_zone_radius + 1):
			var p = pos + Vector2i(dx, dy)
			var cell = get_cell(p)
			cell.is_mine = false

func set_mine_at(pos: Vector2i, mine_state: bool) -> void:
	var cell = get_cell(pos)
	cell.is_mine = mine_state

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

func update_visible_area(rect: Rect2) -> void:
	visible_rect = rect
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
