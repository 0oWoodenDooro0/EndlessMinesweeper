@tool
extends SceneTree

const GridManager = preload("res://scripts/grid_manager.gd")
const CameraController = preload("res://scripts/camera_controller.gd")
const CellData = preload("res://scripts/cell_data.gd")
const ChunkData = preload("res://scripts/chunk_data.gd")

func _init():
	print("--- Running Test Suite: Chunk LOD Rendering & Lazy Drawing ---")
	var success = true

	# Test 1: LOD Zoom Threshold & is_lod_active State Transitions
	if not test_lod_zoom_threshold():
		success = false

	# Test 2: Lazy Cell Rendering Memory Protection (No Phantom CellData on Draw)
	if not test_lazy_cell_rendering():
		success = false

	# Test 3: Macro Chunk LOD Overview State & Non-allocating Drawing
	if not test_lod_chunk_overview_states():
		success = false

	# Test 4: CameraController & GridManager Zoom Synchronization
	if not test_camera_zoom_synchronization():
		success = false

	# Test 5: World Coordinate Mapping & Gameplay Integrity in LOD Mode
	if not test_lod_gameplay_integrity():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)

func test_lod_zoom_threshold() -> bool:
	print("[RUN] Test 1: LOD Zoom Threshold & is_lod_active State Transitions")
	var grid = GridManager.new()

	if grid.lod_zoom_threshold != 0.9:
		print("[FAIL] Default lod_zoom_threshold mismatch. Expected: 0.9, Got: ", grid.lod_zoom_threshold)
		grid.free()
		return false

	if grid.current_zoom_level != 1.0:
		print("[FAIL] Default current_zoom_level mismatch. Expected: 1.0, Got: ", grid.current_zoom_level)
		grid.free()
		return false

	if grid.is_lod_active():
		print("[FAIL] is_lod_active should be false by default at zoom 1.0")
		grid.free()
		return false

	# Test above threshold
	grid.update_visible_area(Rect2(-640, -360, 1280, 720), 0.95)
	if grid.current_zoom_level != 0.95 or grid.is_lod_active():
		print("[FAIL] Zoom 0.95 should not trigger LOD. is_lod_active: ", grid.is_lod_active())
		grid.free()
		return false

	# Test exactly at threshold
	grid.update_visible_area(Rect2(-640, -360, 1280, 720), 0.9)
	if not grid.is_lod_active():
		print("[FAIL] Zoom 0.9 should trigger LOD")
		grid.free()
		return false

	# Test below threshold
	grid.update_visible_area(Rect2(-640, -360, 1280, 720), 0.25)
	if not grid.is_lod_active():
		print("[FAIL] Zoom 0.25 should trigger LOD")
		grid.free()
		return false

	# Test custom threshold
	grid.lod_zoom_threshold = 0.6
	grid.update_visible_area(Rect2(-640, -360, 1280, 720), 0.55)
	if not grid.is_lod_active():
		print("[FAIL] Zoom 0.55 should trigger LOD when threshold is 0.6")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 1: LOD zoom threshold and state transitions verified")
	return true

func test_lazy_cell_rendering() -> bool:
	print("[RUN] Test 2: Lazy Cell Rendering Memory Protection")
	var grid = GridManager.new()
	grid.world_seed = 42
	grid.visible_rect = Rect2(-320, -320, 640, 640) # 20x20 = 400 cells
	grid.current_zoom_level = 1.0

	# Initial state: grid_data must be empty
	if grid.grid_data.size() != 0:
		print("[FAIL] grid_data should initially be empty. Got size: ", grid.grid_data.size())
		grid.free()
		return false

	# Execute _draw() in normal detail mode
	grid._draw()

	# Lazy rendering check: grid_data should NOT have had phantom CellData objects inserted
	if grid.grid_data.size() != 0:
		print("[FAIL] Lazy rendering failed: _draw() populated grid_data with unvisited cells. Size: ", grid.grid_data.size())
		grid.free()
		return false

	# Reveal a single cell
	grid.reveal_cell(Vector2i(0, 0))
	var size_after_reveal = grid.grid_data.size()
	if size_after_reveal == 0:
		print("[FAIL] reveal_cell should add cells to grid_data")
		grid.free()
		return false

	# Redraw again in detail mode
	grid._draw()

	# Verify grid_data size did not increase due to _draw()
	if grid.grid_data.size() != size_after_reveal:
		print("[FAIL] _draw() added new cells to grid_data after reveal. Before: ", size_after_reveal, " After: ", grid.grid_data.size())
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 2: Lazy cell rendering verified without phantom CellData instantiation")
	return true

func test_lod_chunk_overview_states() -> bool:
	print("[RUN] Test 3: Macro Chunk LOD Overview State & Non-allocating Drawing")
	var grid = GridManager.new()
	grid.world_seed = 999
	grid.chunk_size = Vector2i(8, 8)
	grid.visible_rect = Rect2(-1024, -1024, 2048, 2048) # Covers multiple chunks
	grid.current_zoom_level = 0.3 # LOD overview mode

	# Initial chunks should be empty
	if grid.chunks.size() != 0:
		print("[FAIL] Chunks should initially be empty")
		grid.free()
		return false

	# Drawing in LOD mode should not allocate chunks in chunk_manager for unexplored areas
	grid._draw()
	if grid.chunks.size() != 0:
		print("[FAIL] _draw() in LOD mode allocated chunks in chunk_manager. Size: ", grid.chunks.size())
		grid.free()
		return false

	# Setup a cleared chunk at (0, 0)
	var chunk_origin = grid.get_chunk(Vector2i(0, 0))
	chunk_origin.is_cleared = true

	# Setup a locked chunk at (1, 0)
	var chunk_locked = grid.get_chunk(Vector2i(1, 0))
	chunk_locked.lock(Vector2i(8, 0))

	# Setup an in-progress chunk at (0, 1)
	var chunk_progress = grid.get_chunk(Vector2i(0, 1))
	chunk_progress.total_safe_cells = 50
	chunk_progress.revealed_safe_cells = 25

	if chunk_progress.get_progress() != 0.5:
		print("[FAIL] Chunk progress calculation mismatch. Expected: 0.5, Got: ", chunk_progress.get_progress())
		grid.free()
		return false

	# Ensure _draw() executes across all these chunk states without errors
	grid._draw()

	# Ensure grid_data has no phantom cells created by LOD overview draw
	if grid.grid_data.size() != 0:
		print("[FAIL] LOD _draw() inserted cells into grid_data. Size: ", grid.grid_data.size())
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 3: Macro Chunk LOD overview states verified")
	return true

func test_camera_zoom_synchronization() -> bool:
	print("[RUN] Test 4: CameraController & GridManager Zoom Synchronization")
	var grid = GridManager.new()
	var camera = CameraController.new()
	camera.grid_manager = grid
	camera.custom_viewport_size = Vector2(1280, 720)
	camera.global_position = Vector2.ZERO
	camera.target_position = Vector2.ZERO

	# Normal zoom
	camera.zoom = Vector2(1.0, 1.0)
	camera.target_zoom = Vector2(1.0, 1.0)
	camera.update_camera(0.0) # Instant update
	if grid.current_zoom_level != 1.0 or grid.is_lod_active():
		print("[FAIL] Zoom 1.0 sync mismatch. current_zoom: ", grid.current_zoom_level, " is_lod_active: ", grid.is_lod_active())
		camera.free()
		grid.free()
		return false

	# Zoomed out to LOD mode
	camera.zoom = Vector2(0.35, 0.35)
	camera.target_zoom = Vector2(0.35, 0.35)
	camera.update_camera(0.0)
	if abs(grid.current_zoom_level - 0.35) > 0.001 or not grid.is_lod_active():
		print("[FAIL] Zoom 0.35 sync mismatch. current_zoom: ", grid.current_zoom_level, " is_lod_active: ", grid.is_lod_active())
		camera.free()
		grid.free()
		return false

	# Zoomed in to close detail
	camera.zoom = Vector2(2.5, 2.5)
	camera.target_zoom = Vector2(2.5, 2.5)
	camera.update_camera(0.0)
	if abs(grid.current_zoom_level - 2.5) > 0.001 or grid.is_lod_active():
		print("[FAIL] Zoom 2.5 sync mismatch. current_zoom: ", grid.current_zoom_level, " is_lod_active: ", grid.is_lod_active())
		camera.free()
		grid.free()
		return false

	camera.free()
	grid.free()
	print("[PASS] Test 4: Camera zoom synchronization verified")
	return true

func test_lod_gameplay_integrity() -> bool:
	print("[RUN] Test 5: World Coordinate Mapping & Gameplay Integrity in LOD Mode")
	var grid = GridManager.new()
	grid.cell_size = Vector2i(32, 32)
	grid.update_visible_area(Rect2(-1000, -1000, 2000, 2000), 0.25)

	# Verify world_to_cell conversions
	var cell_0 = grid.world_to_cell(Vector2(10, 10))
	if cell_0 != Vector2i(0, 0):
		print("[FAIL] world_to_cell(10, 10) mismatch. Expected: (0,0), Got: ", cell_0)
		grid.free()
		return false

	var cell_neg = grid.world_to_cell(Vector2(-35, -10))
	if cell_neg != Vector2i(-2, -1):
		print("[FAIL] world_to_cell(-35, -10) mismatch. Expected: (-2,-1), Got: ", cell_neg)
		grid.free()
		return false

	# Gameplay action in LOD mode
	var target_cell = Vector2i(5, 5)
	grid.get_cell(Vector2i(5, 4)).is_revealed = true # Anchor
	grid.toggle_flag(target_cell)
	var c_data = grid.get_cell(target_cell)
	if not c_data.is_flagged:
		print("[FAIL] Flag toggle failed in LOD mode")
		grid.free()
		return false

	grid.toggle_flag(target_cell)
	if c_data.is_flagged:
		print("[FAIL] Flag un-toggle failed in LOD mode")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 5: Gameplay integrity in LOD mode verified")
	return true
