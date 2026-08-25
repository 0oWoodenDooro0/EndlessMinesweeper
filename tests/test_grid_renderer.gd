@tool
extends SceneTree

const GridRenderer = preload("res://scripts/grid_renderer.gd")
const GridManager = preload("res://scripts/grid_manager.gd")
const CellData = preload("res://scripts/cell_data.gd")
const ChunkData = preload("res://scripts/chunk_data.gd")

func _init():
	print("--- Running Test Suite: GridRenderer Visual Adapter ---")
	var success = true

	# Test 1: Initialization & Default Properties
	if not test_grid_renderer_initialization():
		success = false

	# Test 2: GridManager Binding & Signal Routing
	if not test_grid_manager_binding_and_signals():
		success = false

	# Test 3: LOD Zoom Threshold & is_lod_active Transitions
	if not test_lod_zoom_threshold_transitions():
		success = false

	# Test 4: Detail Mode Lazy Drawing (No Phantom CellData Instantiation)
	if not test_detail_mode_lazy_drawing():
		success = false

	# Test 5: LOD Overview Drawing Across Chunk States (No Phantom Chunk Instantiation)
	if not test_lod_overview_drawing_states():
		success = false

	# Test 6: Color Lookups & Text Styling Integrity
	if not test_color_and_styling_lookups():
		success = false

	# Test 7: Null GridManager Safety
	if not test_null_grid_manager_safety():
		success = false

	# Test 8: Font Caching & Custom Font Handling
	if not test_font_caching():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)

func test_grid_renderer_initialization() -> bool:
	print("[RUN] Test 1: Initialization & Default Properties")
	var renderer = GridRenderer.new()

	if renderer.lod_zoom_threshold != 0.9:
		print("[FAIL] Default lod_zoom_threshold mismatch. Expected 0.9, got: ", renderer.lod_zoom_threshold)
		renderer.free()
		return false

	if renderer.current_zoom_level != 1.0:
		print("[FAIL] Default current_zoom_level mismatch. Expected 1.0, got: ", renderer.current_zoom_level)
		renderer.free()
		return false

	if renderer.is_lod_active():
		print("[FAIL] is_lod_active should default to false at zoom 1.0")
		renderer.free()
		return false

	if renderer.grid_manager != null:
		print("[FAIL] Default grid_manager should be null")
		renderer.free()
		return false

	if renderer.custom_font != null:
		print("[FAIL] Default custom_font should be null")
		renderer.free()
		return false

	renderer.free()
	print("[PASS] Test 1: Initialization & default properties verified")
	return true

func test_grid_manager_binding_and_signals() -> bool:
	print("[RUN] Test 2: GridManager Binding & Signal Routing")
	var renderer = GridRenderer.new()
	var grid = GridManager.new()

	renderer.bind_grid_manager(grid)
	if renderer.grid_manager != grid:
		print("[FAIL] bind_grid_manager did not assign grid_manager")
		renderer.free()
		grid.free()
		return false

	# Check signal connections
	if not grid.redraw_requested.is_connected(renderer._request_redraw):
		print("[FAIL] redraw_requested signal not connected")
		renderer.free()
		grid.free()
		return false

	# Re-binding another instance should disconnect old and connect new
	var grid2 = GridManager.new()
	renderer.bind_grid_manager(grid2)
	if grid.redraw_requested.is_connected(renderer._request_redraw):
		print("[FAIL] redraw_requested was not disconnected from previous grid_manager")
		renderer.free()
		grid.free()
		grid2.free()
		return false

	if not grid2.redraw_requested.is_connected(renderer._request_redraw):
		print("[FAIL] redraw_requested was not connected to new grid_manager")
		renderer.free()
		grid.free()
		grid2.free()
		return false

	# Binding null should disconnect gracefully
	renderer.bind_grid_manager(null)
	if renderer.grid_manager != null:
		print("[FAIL] bind_grid_manager(null) did not clear grid_manager")
		renderer.free()
		grid.free()
		grid2.free()
		return false

	renderer.free()
	grid.free()
	grid2.free()
	print("[PASS] Test 2: GridManager binding and signal routing verified")
	return true

func test_lod_zoom_threshold_transitions() -> bool:
	print("[RUN] Test 3: LOD Zoom Threshold & is_lod_active Transitions")
	var renderer = GridRenderer.new()
	var grid = GridManager.new()
	renderer.bind_grid_manager(grid)

	# Above threshold
	renderer.update_visible_area(Rect2(-640, -360, 1280, 720), 0.95)
	if renderer.current_zoom_level != 0.95 or renderer.is_lod_active():
		print("[FAIL] Zoom 0.95 should not trigger LOD. is_lod_active: ", renderer.is_lod_active())
		renderer.free()
		grid.free()
		return false

	# Exactly at threshold
	renderer.update_visible_area(Rect2(-640, -360, 1280, 720), 0.9)
	if not renderer.is_lod_active():
		print("[FAIL] Zoom 0.9 should trigger LOD. is_lod_active: ", renderer.is_lod_active())
		renderer.free()
		grid.free()
		return false

	# Below threshold
	renderer.update_visible_area(Rect2(-640, -360, 1280, 720), 0.3)
	if not renderer.is_lod_active():
		print("[FAIL] Zoom 0.3 should trigger LOD. is_lod_active: ", renderer.is_lod_active())
		renderer.free()
		grid.free()
		return false

	# Custom threshold
	renderer.lod_zoom_threshold = 0.5
	renderer.update_visible_area(Rect2(-640, -360, 1280, 720), 0.6)
	if renderer.is_lod_active():
		print("[FAIL] Zoom 0.6 should not trigger LOD when threshold is 0.5")
		renderer.free()
		grid.free()
		return false

	renderer.update_visible_area(Rect2(-640, -360, 1280, 720), 0.4)
	if not renderer.is_lod_active():
		print("[FAIL] Zoom 0.4 should trigger LOD when threshold is 0.5")
		renderer.free()
		grid.free()
		return false

	renderer.free()
	grid.free()
	print("[PASS] Test 3: LOD zoom threshold transitions verified")
	return true

func test_detail_mode_lazy_drawing() -> bool:
	print("[RUN] Test 4: Detail Mode Lazy Drawing")
	var renderer = GridRenderer.new()
	var grid = GridManager.new()
	grid.world_seed = 42
	renderer.bind_grid_manager(grid)
	renderer.visible_rect = Rect2(-320, -320, 640, 640)
	renderer.current_zoom_level = 1.0

	# Initial state: grid_data must be empty
	if grid.grid_data.size() != 0:
		print("[FAIL] grid_data should initially be empty. Size: ", grid.grid_data.size())
		renderer.free()
		grid.free()
		return false

	# Drawing in detail mode must NOT populate grid_data
	renderer._draw()
	if grid.grid_data.size() != 0:
		print("[FAIL] _draw() populated grid_data with unvisited cells. Size: ", grid.grid_data.size())
		renderer.free()
		grid.free()
		return false

	# Reveal a single cell and redraw
	grid.reveal_cell(Vector2i(0, 0))
	var size_after_reveal = grid.grid_data.size()
	if size_after_reveal == 0:
		print("[FAIL] reveal_cell should add cells to grid_data")
		renderer.free()
		grid.free()
		return false

	renderer._draw()
	if grid.grid_data.size() != size_after_reveal:
		print("[FAIL] _draw() added new cells after reveal. Before: ", size_after_reveal, " After: ", grid.grid_data.size())
		renderer.free()
		grid.free()
		return false

	renderer.free()
	grid.free()
	print("[PASS] Test 4: Detail mode lazy drawing verified")
	return true

func test_lod_overview_drawing_states() -> bool:
	print("[RUN] Test 5: LOD Overview Drawing Across Chunk States")
	var renderer = GridRenderer.new()
	var grid = GridManager.new()
	grid.world_seed = 999
	grid.chunk_size = Vector2i(8, 8)
	renderer.bind_grid_manager(grid)
	renderer.visible_rect = Rect2(-1024, -1024, 2048, 2048)
	renderer.current_zoom_level = 0.3 # LOD mode

	# Initial chunks should be empty
	if grid.chunks.size() != 0:
		print("[FAIL] Chunks should initially be empty")
		renderer.free()
		grid.free()
		return false

	# Draw in LOD mode - must not instantiate unexplored chunks
	renderer._draw()
	if grid.chunks.size() != 0:
		print("[FAIL] LOD _draw() instantiated chunks in chunk_manager. Size: ", grid.chunks.size())
		renderer.free()
		grid.free()
		return false

	# Setup specific chunk states
	var chunk_origin = grid.get_chunk(Vector2i(0, 0))
	chunk_origin.is_cleared = true

	var chunk_locked = grid.get_chunk(Vector2i(1, 0))
	chunk_locked.lock(Vector2i(8, 0))

	var chunk_progress = grid.get_chunk(Vector2i(0, 1))
	chunk_progress.total_safe_cells = 50
	chunk_progress.revealed_safe_cells = 25

	# Execute LOD draw across all active states without errors
	renderer._draw()

	if grid.grid_data.size() != 0:
		print("[FAIL] LOD _draw() inserted cells into grid_data. Size: ", grid.grid_data.size())
		renderer.free()
		grid.free()
		return false

	renderer.free()
	grid.free()
	print("[PASS] Test 5: LOD overview drawing across chunk states verified")
	return true

func test_color_and_styling_lookups() -> bool:
	print("[RUN] Test 6: Color Lookups & Text Styling Integrity")
	var renderer = GridRenderer.new()

	# Verify number colors
	var color_1 = renderer._get_number_color(1)
	if color_1 != Color(0.1, 0.3, 0.9):
		print("[FAIL] Number 1 color mismatch. Got: ", color_1)
		renderer.free()
		return false

	var color_3 = renderer._get_number_color(3)
	if color_3 != Color(0.9, 0.1, 0.1):
		print("[FAIL] Number 3 color mismatch. Got: ", color_3)
		renderer.free()
		return false

	var color_out_of_range = renderer._get_number_color(99)
	if color_out_of_range != Color.BLACK:
		print("[FAIL] Out of range number color should be BLACK. Got: ", color_out_of_range)
		renderer.free()
		return false

	renderer.free()
	print("[PASS] Test 6: Color lookups & styling verified")
	return true

func test_null_grid_manager_safety() -> bool:
	print("[RUN] Test 7: Null GridManager Safety")
	var renderer = GridRenderer.new()

	# Calling methods without grid_manager must not crash
	renderer.update_visible_area(Rect2(0, 0, 100, 100), 1.0)
	renderer._draw()
	renderer._draw_cells_detail()
	renderer._draw_chunk_lod_overview()

	renderer.free()
	print("[PASS] Test 7: Null GridManager safety verified")
	return true

func test_font_caching() -> bool:
	print("[RUN] Test 8: Font Caching & Custom Font Handling (Embedded MSDF Font)")
	var renderer = GridRenderer.new()

	# Verify DEFAULT_FONT_PATH constant
	if renderer.get("DEFAULT_FONT_PATH") != "res://assets/fonts/NotoSans-Bold.ttf":
		print("[FAIL] GridRenderer.DEFAULT_FONT_PATH constant missing or incorrect. Expected 'res://assets/fonts/NotoSans-Bold.ttf', got: ", renderer.get("DEFAULT_FONT_PATH"))
		renderer.free()
		return false

	# Default active font should create and cache MSDF font
	var font1 = renderer._get_active_font()
	if font1 == null:
		print("[FAIL] _get_active_font returned null")
		renderer.free()
		return false

	# Verify MSDF parameters on active font
	if font1 is FontFile:
		var font_file = font1 as FontFile
		if not font_file.multichannel_signed_distance_field:
			print("[FAIL] FontFile.multichannel_signed_distance_field is not true")
			renderer.free()
			return false
		if font_file.msdf_pixel_range != 16:
			print("[FAIL] FontFile.msdf_pixel_range is not 16. Got: ", font_file.msdf_pixel_range)
			renderer.free()
			return false
		if font_file.msdf_size != 48:
			print("[FAIL] FontFile.msdf_size is not 48. Got: ", font_file.msdf_size)
			renderer.free()
			return false
	elif font1 is SystemFont:
		var sys_font = font1 as SystemFont
		if not sys_font.multichannel_signed_distance_field:
			print("[FAIL] SystemFont.multichannel_signed_distance_field is not true")
			renderer.free()
			return false
		if sys_font.msdf_pixel_range != 16:
			print("[FAIL] SystemFont.msdf_pixel_range is not 16. Got: ", sys_font.msdf_pixel_range)
			renderer.free()
			return false
		if sys_font.msdf_size != 48:
			print("[FAIL] SystemFont.msdf_size is not 48. Got: ", sys_font.msdf_size)
			renderer.free()
			return false
	else:
		print("[FAIL] Unexpected font type returned: ", font1.get_class())
		renderer.free()
		return false

	var font2 = renderer._get_active_font()
	if font1 != font2:
		print("[FAIL] _get_active_font did not cache the default font")
		renderer.free()
		return false

	# Custom font should override default font
	var custom_f = SystemFont.new()
	renderer.custom_font = custom_f
	if renderer._get_active_font() != custom_f:
		print("[FAIL] custom_font was not returned by _get_active_font")
		renderer.free()
		return false

	# Resetting custom_font to null should return cached default font again
	renderer.custom_font = null
	if renderer._get_active_font() != font1:
		print("[FAIL] Clearing custom_font did not restore cached default font")
		renderer.free()
		return false

	renderer.free()
	print("[PASS] Test 8: Font caching and custom font handling verified")
	return true
