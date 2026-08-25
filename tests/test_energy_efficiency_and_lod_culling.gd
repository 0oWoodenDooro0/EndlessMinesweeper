@tool
extends SceneTree

const GridManager = preload("res://scripts/grid_manager.gd")
const CameraController = preload("res://scripts/camera_controller.gd")
const ChunkManager = preload("res://scripts/chunk_manager.gd")
const ChunkData = preload("res://scripts/chunk_data.gd")
const CellData = preload("res://scripts/cell_data.gd")

# Mock GridManager to count updates and redraw requests
class MockGridManager:
	extends GridManager
	var update_visible_area_calls: int = 0
	var last_received_rect: Rect2
	var last_received_zoom: float = -1.0

	func update_visible_area(rect: Rect2, zoom_level: float = 1.0) -> void:
		update_visible_area_calls += 1
		last_received_rect = rect
		last_received_zoom = zoom_level
		super.update_visible_area(rect, zoom_level)

func _init():
	print("--- Running Test Suite: Energy Efficiency & LOD Culling ---")
	var success = true

	# Test 1: Camera Idle Redraw Suppression
	if not test_camera_idle_redraw_suppression():
		success = false

	# Test 2: Camera Smooth Motion Convergence & Snap to Target
	if not test_camera_motion_convergence_and_snap():
		success = false

	# Test 3: LOD Zoom-Out Zero Chunk Allocation
	if not test_lod_zoom_out_zero_chunk_allocation():
		success = false

	# Test 4: LOD Drawing Non-Allocating State Accuracy
	if not test_lod_draw_non_allocating_state_accuracy():
		success = false

	# Test 5: Zoom-In Detail Restoration & Gameplay Integrity
	if not test_zoom_in_restoration_and_gameplay():
		success = false

	# Test 6: Project Settings Max FPS Cap (60 FPS)
	if not test_project_max_fps_setting():
		success = false

	# Test 7: Neighbor Checks & Chord Reveal Phantom CellData Suppression
	if not test_phantom_celldata_suppression():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)

func test_camera_idle_redraw_suppression() -> bool:
	print("[RUN] Test 1: Camera Idle Redraw Suppression")
	var grid = MockGridManager.new()
	var camera = CameraController.new()
	camera.grid_manager = grid
	camera.custom_viewport_size = Vector2(1280, 720)
	camera.position = Vector2(100, 100)
	camera.target_position = Vector2(100, 100)
	camera.zoom = Vector2(1.0, 1.0)
	camera.target_zoom = Vector2(1.0, 1.0)
	camera._ready()

	# Initial call to sync
	camera.update_camera(0.0)
	var initial_calls = grid.update_visible_area_calls
	if initial_calls != 1:
		print("[FAIL] Expected 1 initial update call, got: ", initial_calls)
		camera.free()
		grid.free()
		return false

	# Idle frames: delta > 0 but position and zoom are stationary at target
	for i in range(10):
		camera.update_camera(0.016)

	if grid.update_visible_area_calls != initial_calls:
		print("[FAIL] Idle frames triggered redundant update_visible_area calls. Expected: ", initial_calls, ", Got: ", grid.update_visible_area_calls)
		camera.free()
		grid.free()
		return false

	camera.free()
	grid.free()
	print("[PASS] Test 1: Camera idle redraw suppression verified")
	return true

func test_camera_motion_convergence_and_snap() -> bool:
	print("[RUN] Test 2: Camera Smooth Motion Convergence & Snap to Target")
	var grid = MockGridManager.new()
	var camera = CameraController.new()
	camera.grid_manager = grid
	camera.custom_viewport_size = Vector2(1280, 720)
	camera.position = Vector2(0, 0)
	camera.target_position = Vector2(0, 0)
	camera.zoom = Vector2(1.0, 1.0)
	camera.target_zoom = Vector2(1.0, 1.0)
	camera._ready()
	camera.update_camera(0.0)

	var calls_before = grid.update_visible_area_calls

	# Set new target position and target zoom
	camera.target_position = Vector2(50, 50)
	camera.target_zoom = Vector2(1.5, 1.5)

	# Simulate moving frames
	var max_frames = 120
	var reached = false
	for i in range(max_frames):
		camera.update_camera(0.016)
		if camera.position == camera.target_position and camera.zoom == camera.target_zoom:
			reached = true
			break

	if not reached:
		print("[FAIL] Camera did not converge and snap to target within ", max_frames, " frames. Pos: ", camera.position, ", Zoom: ", camera.zoom)
		camera.free()
		grid.free()
		return false

	var calls_at_arrival = grid.update_visible_area_calls
	if calls_at_arrival <= calls_before:
		print("[FAIL] Camera motion did not trigger update_visible_area during movement")
		camera.free()
		grid.free()
		return false

	# After arrival, further idle frames must not trigger calls
	for i in range(10):
		camera.update_camera(0.016)

	if grid.update_visible_area_calls != calls_at_arrival:
		print("[FAIL] Camera continued triggering updates after arriving at target. Expected: ", calls_at_arrival, ", Got: ", grid.update_visible_area_calls)
		camera.free()
		grid.free()
		return false

	camera.free()
	grid.free()
	print("[PASS] Test 2: Camera motion convergence and snap verified")
	return true

func test_lod_zoom_out_zero_chunk_allocation() -> bool:
	print("[RUN] Test 3: LOD Zoom-Out Zero Chunk Allocation")
	var grid = GridManager.new()
	grid.world_seed = 12345
	grid.chunk_size = Vector2i(8, 8)
	grid.cell_size = Vector2i(32, 32)
	grid.lod_zoom_threshold = 0.9

	# Verify initial chunks
	if grid.chunk_manager.chunks.size() != 0:
		print("[FAIL] Initial chunks should be empty")
		grid.free()
		return false

	# Update visible area to a huge overview region at LOD zoom (0.25)
	# Covering ~ 10000x10000 px = ~ 39x39 = 1521 chunks!
	var large_rect = Rect2(-5000, -5000, 10000, 10000)
	grid.update_visible_area(large_rect, 0.25)

	if not grid.is_lod_active():
		print("[FAIL] Expected is_lod_active to be true at zoom 0.25")
		grid.free()
		return false

	# In LOD overview mode, preload_chunks_around_viewport should be skipped!
	if grid.chunk_manager.chunks.size() != 0:
		print("[FAIL] LOD zoom-out allocated chunks in chunk_manager. Expected 0, Got: ", grid.chunk_manager.chunks.size())
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 3: LOD zoom-out zero chunk allocation verified")
	return true

func test_lod_draw_non_allocating_state_accuracy() -> bool:
	print("[RUN] Test 4: LOD Drawing Non-Allocating State Accuracy")
	var grid = GridManager.new()
	grid.world_seed = 777
	grid.chunk_size = Vector2i(8, 8)
	grid.cell_size = Vector2i(32, 32)
	grid.visible_rect = Rect2(-2000, -2000, 4000, 4000)
	grid.current_zoom_level = 0.3 # LOD mode

	# Manually setup specific chunks:
	# 1. Cleared chunk at (0, 0)
	var cleared_chunk = grid.get_chunk(Vector2i(0, 0))
	cleared_chunk.is_cleared = true

	# 2. Locked chunk at (1, 1)
	var locked_chunk = grid.get_chunk(Vector2i(1, 1))
	locked_chunk.lock(Vector2i(8, 8))

	# 3. Exploring chunk at (-1, 0)
	var exploring_chunk = grid.get_chunk(Vector2i(-1, 0))
	exploring_chunk.total_safe_cells = 50
	exploring_chunk.revealed_safe_cells = 20

	var expected_chunk_count = grid.chunk_manager.chunks.size()
	if expected_chunk_count != 3:
		print("[FAIL] Expected 3 registered chunks before draw, got: ", expected_chunk_count)
		grid.free()
		return false

	# Execute _draw() in LOD mode
	grid._draw()

	# Verify that drawing does NOT instantiate any new unvisited ChunkData or CellData
	if grid.chunk_manager.chunks.size() != expected_chunk_count:
		print("[FAIL] LOD _draw() instantiated new ChunkData objects. Before: ", expected_chunk_count, ", After: ", grid.chunk_manager.chunks.size())
		grid.free()
		return false

	if grid.grid_data.size() != 0:
		print("[FAIL] LOD _draw() instantiated CellData objects. Size: ", grid.grid_data.size())
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 4: LOD drawing non-allocating state accuracy verified")
	return true

func test_zoom_in_restoration_and_gameplay() -> bool:
	print("[RUN] Test 5: Zoom-In Detail Restoration & Gameplay Integrity")
	var grid = GridManager.new()
	grid.world_seed = 999
	grid.chunk_size = Vector2i(8, 8)
	grid.cell_size = Vector2i(32, 32)
	grid.lod_zoom_threshold = 0.9

	# First zoom out to LOD mode
	grid.update_visible_area(Rect2(-5000, -5000, 10000, 10000), 0.25)
	if grid.chunk_manager.chunks.size() != 0:
		print("[FAIL] Expected 0 chunks in LOD mode, got: ", grid.chunk_manager.chunks.size())
		grid.free()
		return false

	# Zoom back in to detail mode (zoom 1.0) on a normal viewport
	var detail_rect = Rect2(-320, -180, 640, 360)
	grid.update_visible_area(detail_rect, 1.0)

	if grid.is_lod_active():
		print("[FAIL] Expected is_lod_active to be false at zoom 1.0")
		grid.free()
		return false

	# In detail mode, preload_chunks_around_viewport should have loaded chunks around the rect
	if grid.chunk_manager.chunks.size() == 0:
		print("[FAIL] Detail mode did not preload chunks around viewport")
		grid.free()
		return false

	# Verify gameplay works normally
	var success_reveal = grid.reveal_cell(Vector2i(0, 0))
	if not success_reveal:
		print("[FAIL] Failed to reveal cell at (0, 0) after zooming back in")
		grid.free()
		return false

	var c = grid.get_cell(Vector2i(0, 0))
	if not c.is_revealed:
		print("[FAIL] Cell at (0, 0) is not revealed")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 5: Zoom-in restoration and gameplay verified")
	return true

func test_project_max_fps_setting() -> bool:
	print("[RUN] Test 6: Project Settings Max FPS Cap (60 FPS)")
	var max_fps = ProjectSettings.get_setting("application/run/max_fps", 0)
	if max_fps != 60:
		print("[FAIL] application/run/max_fps should be 60. Got: ", max_fps)
		return false

	print("[PASS] Test 6: Project settings max FPS (60 FPS) verified")
	return true

func test_phantom_celldata_suppression() -> bool:
	print("[RUN] Test 7: Neighbor Checks & Chord Reveal Phantom CellData Suppression")
	var grid = GridManager.new()
	grid.world_seed = 555
	grid.chunk_size = Vector2i(8, 8)
	grid.cell_size = Vector2i(32, 32)

	# Initial state
	if grid.grid_data.size() != 0:
		print("[FAIL] grid_data should initially be empty")
		grid.free()
		return false

	# 1. Calling count_neighbor_flags on unvisited cell area must NOT instantiate CellData
	var flags = grid.count_neighbor_flags(Vector2i(5, 5))
	if flags != 0:
		print("[FAIL] Expected 0 neighbor flags, got: ", flags)
		grid.free()
		return false

	if grid.grid_data.size() != 0:
		print("[FAIL] count_neighbor_flags inserted phantom CellData into grid_data. Size: ", grid.grid_data.size())
		grid.free()
		return false

	# 2. Calling chord_reveal on unrevealed cell must safely return false and NOT instantiate phantom cells
	var chord_res = grid.chord_reveal(Vector2i(5, 5))
	if chord_res != false:
		print("[FAIL] chord_reveal on unrevealed cell should return false")
		grid.free()
		return false

	if grid.grid_data.size() != 0:
		print("[FAIL] chord_reveal inserted phantom CellData into grid_data. Size: ", grid.grid_data.size())
		grid.free()
		return false

	# 3. Reveal a cell
	grid.reveal_cell(Vector2i(0, 0))
	var size_after_reveal = grid.grid_data.size()

	# Calling count_neighbor_flags on (0, 0)
	var flags_origin = grid.count_neighbor_flags(Vector2i(0, 0))
	if grid.grid_data.size() != size_after_reveal:
		print("[FAIL] count_neighbor_flags on revealed cell created new CellData. Before: ", size_after_reveal, ", After: ", grid.grid_data.size())
		grid.free()
		return false

	# 4. Serialization check: only revealed / flagged cells are serialized
	var serialized = grid.serialize()
	var cells_list = serialized["cells"]
	for cell_info in cells_list:
		if not cell_info["is_revealed"] and not cell_info["is_flagged"]:
			print("[FAIL] Serialization included unrevealed and unflagged phantom cell: ", cell_info)
			grid.free()
			return false

	grid.free()
	print("[PASS] Test 7: Neighbor checks & chord reveal phantom CellData suppression verified")
	return true

