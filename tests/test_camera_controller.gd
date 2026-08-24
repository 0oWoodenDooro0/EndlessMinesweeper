@tool
extends SceneTree

const CameraController = preload("res://scripts/camera_controller.gd")
const GridManager = preload("res://scripts/grid_manager.gd")

func _init():
	print("--- Running Test Suite: Camera Controller ---")
	var success = true

	# Test 1: Camera Initialization & Default Properties
	if not test_camera_initialization():
		success = false

	# Test 2: Camera Zoom Clamping
	if not test_camera_zoom_clamping():
		success = false

	# Test 3: Camera Panning Offset Calculation
	if not test_camera_panning():
		success = false

	# Test 4: Visible World Rect Calculation
	if not test_visible_world_rect_calculation():
		success = false

	# Test 5: GridManager Integration Synchronization
	if not test_grid_manager_integration():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)

func test_camera_initialization() -> bool:
	print("[RUN] Test 1: Camera Initialization")
	var camera = CameraController.new()
	if camera.min_zoom != 0.2:
		print("[FAIL] min_zoom mismatch. Expected: 0.2, Got: ", camera.min_zoom)
		camera.free()
		return false
	if camera.max_zoom != 3.0:
		print("[FAIL] max_zoom mismatch. Expected: 3.0, Got: ", camera.max_zoom)
		camera.free()
		return false
	if camera.target_zoom != Vector2(1.0, 1.0):
		print("[FAIL] target_zoom initial value mismatch. Expected: Vector2(1,1), Got: ", camera.target_zoom)
		camera.free()
		return false
	if camera.is_panning != false:
		print("[FAIL] is_panning initial state should be false")
		camera.free()
		return false
	
	camera.free()
	print("[PASS] Test 1: Camera initialized with correct default properties")
	return true

func test_camera_zoom_clamping() -> bool:
	print("[RUN] Test 2: Camera Zoom Clamping")
	var camera = CameraController.new()
	camera.min_zoom = 0.5
	camera.max_zoom = 2.0
	camera.target_zoom = Vector2(1.0, 1.0)

	# Zoom out beyond min_zoom
	for i in range(20):
		camera.apply_zoom_step(-1)
	
	if camera.target_zoom.x < camera.min_zoom or camera.target_zoom.y < camera.min_zoom:
		print("[FAIL] Zoom out exceeded min_zoom boundary. Target zoom: ", camera.target_zoom)
		camera.free()
		return false

	# Zoom in beyond max_zoom
	for i in range(30):
		camera.apply_zoom_step(1)

	if camera.target_zoom.x > camera.max_zoom or camera.target_zoom.y > camera.max_zoom:
		print("[FAIL] Zoom in exceeded max_zoom boundary. Target zoom: ", camera.target_zoom)
		camera.free()
		return false

	camera.free()
	print("[PASS] Test 2: Camera zoom correctly clamped within boundaries")
	return true

func test_camera_panning() -> bool:
	print("[RUN] Test 3: Camera Panning Offset Calculation")
	var camera = CameraController.new()
	camera.position = Vector2(100, 100)
	camera.target_position = Vector2(100, 100)
	camera.target_zoom = Vector2(2.0, 2.0)
	camera.zoom = Vector2(2.0, 2.0)

	# Simulate dragging mouse by relative (50, -20)
	camera.pan_by(Vector2(50, -20))

	# Under zoom=2.0, relative (50, -20) converts to world delta (25, -10)
	# Target position moves opposite to drag: (100, 100) - (25, -10) = (75, 110)
	var expected_target = Vector2(75, 110)
	if camera.target_position.distance_to(expected_target) > 0.01:
		print("[FAIL] Panning target position mismatch. Expected: ", expected_target, " Got: ", camera.target_position)
		camera.free()
		return false

	camera.free()
	print("[PASS] Test 3: Camera panning offset calculated correctly according to zoom")
	return true

func test_visible_world_rect_calculation() -> bool:
	print("[RUN] Test 4: Visible World Rect Calculation")
	var camera = CameraController.new()
	camera.global_position = Vector2(200, 300)
	camera.zoom = Vector2(2.0, 2.0)
	camera.custom_viewport_size = Vector2(1280, 720)

	var rect = camera.get_visible_world_rect()
	# Viewport 1280x720 under zoom 2.0 -> world size 640x360
	# Centered at (200, 300) -> top-left pos = (200 - 320, 300 - 180) = (-120, 120)
	var expected_size = Vector2(640, 360)
	var expected_pos = Vector2(-120, 120)

	if rect.size.distance_to(expected_size) > 0.01:
		print("[FAIL] Visible rect size mismatch. Expected: ", expected_size, " Got: ", rect.size)
		camera.free()
		return false

	if rect.position.distance_to(expected_pos) > 0.01:
		print("[FAIL] Visible rect position mismatch. Expected: ", expected_pos, " Got: ", rect.position)
		camera.free()
		return false

	camera.free()
	print("[PASS] Test 4: Visible world rect calculated accurately")
	return true

func test_grid_manager_integration() -> bool:
	print("[RUN] Test 5: GridManager Integration Synchronization")
	var grid_manager = GridManager.new()
	var camera = CameraController.new()
	camera.grid_manager = grid_manager
	camera.global_position = Vector2(500, -200)
	camera.target_position = Vector2(500, -200)
	camera.zoom = Vector2(1.0, 1.0)
	camera.target_zoom = Vector2(1.0, 1.0)
	camera.custom_viewport_size = Vector2(1280, 720)

	# Process camera frame update
	camera.update_camera(0.1)

	var expected_rect = camera.get_visible_world_rect()
	if grid_manager.visible_rect != expected_rect:
		print("[FAIL] GridManager visible_rect not synchronized. Expected: ", expected_rect, " Got: ", grid_manager.visible_rect)
		camera.free()
		grid_manager.free()
		return false

	camera.free()
	grid_manager.free()
	print("[PASS] Test 5: GridManager visible area synchronized on camera update")
	return true
