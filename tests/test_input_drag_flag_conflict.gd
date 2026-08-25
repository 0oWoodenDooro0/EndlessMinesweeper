@tool
extends SceneTree

const InputRouter = preload("res://scripts/input_router.gd")
const GridManager = preload("res://scripts/grid_manager.gd")
const CellData = preload("res://scripts/cell_data.gd")

func _init():
	print("--- Running Test Suite: Input Drag & Flag Conflict Disambiguation ---")
	var success = true

	# Test 1: Quick Right-Click Tap (No Drag) -> Flag Toggled on Release
	if not test_quick_right_click_tap():
		success = false

	# Test 2: Right-Click Drag (Camera Pan) -> Flag Toggle Suppressed
	if not test_right_click_drag_suppression():
		success = false

	# Test 3: Drag Threshold Boundary Behavior (Small Jitter vs Real Drag)
	if not test_drag_threshold_boundary():
		success = false

	# Test 4: Middle-Click Tap (No Drag) -> Chord Reveal on Release
	if not test_middle_click_tap_chord():
		success = false

	# Test 5: Middle-Click Drag (Camera Pan) -> Chord Reveal Suppressed
	if not test_middle_click_drag_suppression():
		success = false

	# Test 6: Left-Click Immediate Responsiveness (LMB on Press Integrity)
	if not test_left_click_immediate_responsiveness():
		success = false

	# Test 7: State Reset Cleanup on Game Reset
	if not test_input_state_reset_cleanup():
		success = false

	# Test 8: Drag Pan Immediately After Touch Chord Reveal
	if not test_drag_immediately_after_touch_chord():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)

func _create_mouse_button_event(button: MouseButton, pressed: bool, pos: Vector2, double_click: bool = false) -> InputEventMouseButton:
	var event = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	event.double_click = double_click
	return event

func _create_mouse_motion_event(pos: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event = InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.relative = relative
	return event

func test_quick_right_click_tap() -> bool:
	print("[RUN] Test 1: Quick Right-Click Tap (No Drag)")
	var router = InputRouter.new()
	var grid = GridManager.new()
	root.add_child(router)
	root.add_child(grid)
	router.bind_grid_manager(grid)
	grid.safe_zone_radius = 0

	# First reveal anchor at (0, 0)
	grid.set_mine_at(Vector2i(0, 0), false)
	grid.set_mine_at(Vector2i(1, 0), true) # Block full BFS
	grid.reveal_cell(Vector2i(0, 0))

	var target_cell_pos = Vector2i(0, 1)
	var screen_pos = Vector2(0 * grid.cell_size.x + 16, 1 * grid.cell_size.y + 16) # (16, 48)

	# 1. Mouse down (RMB Press)
	var press_event = _create_mouse_button_event(MOUSE_BUTTON_RIGHT, true, screen_pos)
	router.process_input(press_event)

	# Verification: Should NOT toggle flag on mouse down
	if grid.get_cell(target_cell_pos).is_flagged:
		print("[FAIL] Flag was toggled immediately on mouse down instead of waiting for mouse release")
		router.queue_free()
		grid.queue_free()
		return false

	# 2. Mouse up (RMB Release at same position)
	var release_event = _create_mouse_button_event(MOUSE_BUTTON_RIGHT, false, screen_pos)
	router.process_input(release_event)

	# Verification: Flag SHOULD be toggled on mouse up
	if not grid.get_cell(target_cell_pos).is_flagged:
		print("[FAIL] Flag was not toggled on mouse release after clean tap")
		router.queue_free()
		grid.queue_free()
		return false

	# 3. Second tap to unflag
	router.process_input(press_event)
	router.process_input(release_event)
	if grid.get_cell(target_cell_pos).is_flagged:
		print("[FAIL] Flag was not removed on second tap release")
		router.queue_free()
		grid.queue_free()
		return false

	router.queue_free()
	grid.queue_free()
	print("[PASS] Test 1: Quick Right-Click Tap verified")
	return true

func test_right_click_drag_suppression() -> bool:
	print("[RUN] Test 2: Right-Click Drag (Camera Pan)")
	var router = InputRouter.new()
	var grid = GridManager.new()
	root.add_child(router)
	root.add_child(grid)
	router.bind_grid_manager(grid)
	grid.safe_zone_radius = 0

	# First reveal anchor at (0, 0)
	grid.set_mine_at(Vector2i(0, 0), false)
	grid.set_mine_at(Vector2i(1, 0), true)
	grid.reveal_cell(Vector2i(0, 0))

	var target_cell_pos = Vector2i(0, 1)
	var start_pos = Vector2(16, 48)
	var drag_pos = start_pos + Vector2(50, 30) # Distance ~58.3px > drag_threshold (6.0px)

	# 1. Mouse down
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, true, start_pos))
	if grid.get_cell(target_cell_pos).is_flagged:
		print("[FAIL] Flag was toggled immediately on mouse down")
		router.queue_free()
		grid.queue_free()
		return false

	# 2. Mouse motion (drag/pan)
	router.process_input(_create_mouse_motion_event(drag_pos, drag_pos - start_pos))

	# 3. Mouse release
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, false, drag_pos))

	# Verification: Flag should NOT be toggled because drag exceeded threshold
	if grid.get_cell(target_cell_pos).is_flagged:
		print("[FAIL] Flag was incorrectly placed after a right-click drag pan gesture")
		router.queue_free()
		grid.queue_free()
		return false

	router.queue_free()
	grid.queue_free()
	print("[PASS] Test 2: Right-Click Drag Suppression verified")
	return true

func test_drag_threshold_boundary() -> bool:
	print("[RUN] Test 3: Drag Threshold Boundary Behavior")
	var router = InputRouter.new()
	var grid = GridManager.new()
	root.add_child(router)
	root.add_child(grid)
	router.bind_grid_manager(grid)
	grid.safe_zone_radius = 0
	router.drag_threshold = 6.0

	grid.set_mine_at(Vector2i(0, 0), false)
	grid.set_mine_at(Vector2i(1, 0), true)
	grid.reveal_cell(Vector2i(0, 0))

	var target_cell_pos = Vector2i(0, 1)
	var start_pos = Vector2(16, 48)

	# Case A: Small micro-movement / hand jitter within threshold (e.g. 3.0px <= 6.0px)
	var jitter_pos = start_pos + Vector2(2.0, 2.0) # distance = ~2.83px <= 6.0px
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, true, start_pos))
	router.process_input(_create_mouse_motion_event(jitter_pos, jitter_pos - start_pos))
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, false, jitter_pos))

	if not grid.get_cell(target_cell_pos).is_flagged:
		print("[FAIL] Flag should be toggled when mouse motion is within drag_threshold (jitter tolerance)")
		router.queue_free()
		grid.queue_free()
		return false

	# Unflag with clean tap
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, true, start_pos))
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, false, start_pos))
	if grid.get_cell(target_cell_pos).is_flagged:
		print("[FAIL] Failed to unflag cell")
		router.queue_free()
		grid.queue_free()
		return false

	# Case B: Movement strictly exceeding threshold (e.g. 8.0px > 6.0px)
	var over_threshold_pos = start_pos + Vector2(8.0, 0.0) # distance = 8.0px > 6.0px
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, true, start_pos))
	router.process_input(_create_mouse_motion_event(over_threshold_pos, over_threshold_pos - start_pos))
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, false, over_threshold_pos))

	if grid.get_cell(target_cell_pos).is_flagged:
		print("[FAIL] Flag should NOT be toggled when movement exceeds drag_threshold")
		router.queue_free()
		grid.queue_free()
		return false

	router.queue_free()
	grid.queue_free()
	print("[PASS] Test 3: Drag Threshold Boundary Behavior verified")
	return true

func test_middle_click_tap_chord() -> bool:
	print("[RUN] Test 4: Middle-Click Tap (Chord Reveal on Release)")
	var router = InputRouter.new()
	var grid = GridManager.new()
	root.add_child(router)
	root.add_child(grid)
	router.bind_grid_manager(grid)
	grid.safe_zone_radius = 0

	# Setup target cell (0, 0) with exactly 1 mine neighbor at (1, 0)
	var target = Vector2i(0, 0)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			grid.set_mine_at(target + Vector2i(dx, dy), false)
	grid.set_mine_at(Vector2i(1, 0), true)

	grid.reveal_cell(target) # Reveal (0, 0)
	grid.toggle_flag(Vector2i(1, 0)) # Flag (1, 0) -> satisfies chord condition

	var screen_pos = Vector2(16, 16) # Center of cell (0, 0)

	# 1. Middle mouse down
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_MIDDLE, true, screen_pos))

	# Verification: Chord should not execute on mouse down
	if grid.get_cell(Vector2i(0, 1)).is_revealed:
		print("[FAIL] Chord reveal triggered on mouse down instead of release")
		router.queue_free()
		grid.queue_free()
		return false

	# 2. Middle mouse up (tap release)
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_MIDDLE, false, screen_pos))

	# Verification: Neighbors should now be revealed on release
	if not grid.get_cell(Vector2i(0, 1)).is_revealed:
		print("[FAIL] Chord reveal was not triggered on middle-click release")
		router.queue_free()
		grid.queue_free()
		return false

	router.queue_free()
	grid.queue_free()
	print("[PASS] Test 4: Middle-Click Tap verified")
	return true

func test_middle_click_drag_suppression() -> bool:
	print("[RUN] Test 5: Middle-Click Drag (Camera Pan)")
	var router = InputRouter.new()
	var grid = GridManager.new()
	root.add_child(router)
	root.add_child(grid)
	router.bind_grid_manager(grid)
	grid.safe_zone_radius = 0

	var target = Vector2i(0, 0)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			grid.set_mine_at(target + Vector2i(dx, dy), false)
	grid.set_mine_at(Vector2i(1, 0), true)

	grid.reveal_cell(target)
	grid.toggle_flag(Vector2i(1, 0))

	var start_pos = Vector2(16, 16)
	var drag_pos = start_pos + Vector2(40, 40) # Distance ~56.5px > drag_threshold

	# 1. MMB Down
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_MIDDLE, true, start_pos))
	# 2. Motion (Pan)
	router.process_input(_create_mouse_motion_event(drag_pos, drag_pos - start_pos))
	# 3. MMB Up
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_MIDDLE, false, drag_pos))

	# Verification: Chord reveal should be suppressed
	if grid.get_cell(Vector2i(0, 1)).is_revealed:
		print("[FAIL] Chord reveal was triggered despite middle-click drag pan gesture")
		router.queue_free()
		grid.queue_free()
		return false

	router.queue_free()
	grid.queue_free()
	print("[PASS] Test 5: Middle-Click Drag Suppression verified")
	return true

func test_left_click_immediate_responsiveness() -> bool:
	print("[RUN] Test 6: Left-Click Immediate Responsiveness (LMB on Press Integrity)")
	var router = InputRouter.new()
	var grid = GridManager.new()
	root.add_child(router)
	root.add_child(grid)
	router.bind_grid_manager(grid)
	grid.safe_zone_radius = 0

	grid.set_mine_at(Vector2i(0, 0), false)
	grid.set_mine_at(Vector2i(1, 0), true)

	var screen_pos = Vector2(16, 16) # cell (0, 0)

	# Left-click down should immediately reveal (0, 0) without waiting for release
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_LEFT, true, screen_pos))

	if not grid.get_cell(Vector2i(0, 0)).is_revealed:
		print("[FAIL] Left-click did not reveal cell immediately on press")
		router.queue_free()
		grid.queue_free()
		return false

	router.queue_free()
	grid.queue_free()
	print("[PASS] Test 6: Left-Click Immediate Responsiveness verified")
	return true

func test_input_state_reset_cleanup() -> bool:
	print("[RUN] Test 7: State Reset Cleanup on Game Reset")
	var router = InputRouter.new()
	var grid = GridManager.new()
	root.add_child(router)
	root.add_child(grid)
	router.bind_grid_manager(grid)
	grid.safe_zone_radius = 0

	var screen_pos = Vector2(16, 16)
	# Simulate half-completed press
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, true, screen_pos))

	# Reset game and router
	grid.reset_game()
	router.reset_state()

	# Check that internal state is clean (properties exist and are reset)
	if "_is_right_mouse_down" in router:
		if router.get("_is_right_mouse_down") != false:
			print("[FAIL] _is_right_mouse_down not reset to false after reset_state()")
			router.queue_free()
			grid.queue_free()
			return false

	if "_right_mouse_dragged" in router:
		if router.get("_right_mouse_dragged") != false:
			print("[FAIL] _right_mouse_dragged not reset to false after reset_state()")
			router.queue_free()
			grid.queue_free()
			return false

	router.queue_free()
	grid.queue_free()
	print("[PASS] Test 7: State Reset Cleanup verified")
	return true

func test_drag_immediately_after_touch_chord() -> bool:
	print("[RUN] Test 8: Drag Pan Immediately After Touch Chord Reveal")
	var router = InputRouter.new()
	var grid = GridManager.new()
	var camera = CameraController.new()
	root.add_child(router)
	root.add_child(grid)
	root.add_child(camera)
	router.bind_grid_manager(grid)
	router.bind_camera_controller(camera)
	camera.position = Vector2(0, 0)
	camera.target_position = Vector2(0, 0)
	grid.safe_zone_radius = 0
	router.drag_threshold = 6.0

	var target = Vector2i(0, 0)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			grid.set_mine_at(target + Vector2i(dx, dy), false)
	grid.set_mine_at(Vector2i(1, 0), true)

	grid.reveal_cell(target)
	grid.toggle_flag(Vector2i(1, 0))

	# 1. Touch chord on (0, 0)
	var screen_pos = Vector2(16, 16)
	var touch_down = InputEventScreenTouch.new()
	touch_down.index = 0
	touch_down.pressed = true
	touch_down.position = screen_pos
	router.process_input(touch_down)

	var touch_up = InputEventScreenTouch.new()
	touch_up.index = 0
	touch_up.pressed = false
	touch_up.position = screen_pos
	router.process_input(touch_up)

	# Verify neighbor cell revealed via chord
	if not grid.get_cell(Vector2i(0, 1)).is_revealed:
		print("[FAIL] Touch chord did not reveal neighbor cell")
		router.queue_free()
		grid.queue_free()
		camera.queue_free()
		return false

	# 2. Right-click drag immediately (< 250ms)
	var prev_cam_pos = camera.target_position
	var start_pos = Vector2(16, 16)
	var drag_pos = start_pos + Vector2(40, 20)

	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, true, start_pos))
	router.process_input(_create_mouse_motion_event(drag_pos, Vector2(40, 20)))
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, false, drag_pos))

	var expected_cam_pos = prev_cam_pos - Vector2(40, 20)
	if camera.target_position.distance_to(expected_cam_pos) > 0.01:
		print("[FAIL] Camera did not pan after right-click drag. Got: ", camera.target_position, " expected: ", expected_cam_pos)
		router.queue_free()
		grid.queue_free()
		camera.queue_free()
		return false

	if grid.get_cell(Vector2i(0, 0)).is_flagged or grid.get_cell(Vector2i(1, 1)).is_flagged:
		print("[FAIL] Unintended flag placed during right-click drag")
		router.queue_free()
		grid.queue_free()
		camera.queue_free()
		return false

	# 3. Middle-click drag immediately (< 250ms)
	prev_cam_pos = camera.target_position
	var mmb_drag_pos = start_pos + Vector2(-30, 50)
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_MIDDLE, true, start_pos))
	router.process_input(_create_mouse_motion_event(mmb_drag_pos, Vector2(-30, 50)))
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_MIDDLE, false, mmb_drag_pos))

	expected_cam_pos = prev_cam_pos - Vector2(-30, 50)
	if camera.target_position.distance_to(expected_cam_pos) > 0.01:
		print("[FAIL] Camera did not pan after middle-click drag. Got: ", camera.target_position, " expected: ", expected_cam_pos)
		router.queue_free()
		grid.queue_free()
		camera.queue_free()
		return false

	router.queue_free()
	grid.queue_free()
	camera.queue_free()
	print("[PASS] Test 8: Drag Pan Immediately After Touch Chord Reveal verified")
	return true

