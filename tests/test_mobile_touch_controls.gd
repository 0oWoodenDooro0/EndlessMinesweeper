@tool
extends SceneTree

const InputRouter = preload("res://scripts/input_router.gd")
const GridManager = preload("res://scripts/grid_manager.gd")
const CameraController = preload("res://scripts/camera_controller.gd")
const CellData = preload("res://scripts/cell_data.gd")

func _init():
	print("--- Running Test Suite: Mobile Touch Controls & Portrait Settings ---")
	var success = true

	# Test 1: Project Settings (Mobile Portrait & Touch Emulation)
	if not test_project_mobile_and_touch_settings():
		success = false

	# Test 2: Quick Single-Finger Tap Reveal
	if not test_touch_quick_tap_reveal():
		success = false

	# Test 3: Quick Single-Finger Tap Chord Reveal
	if not test_touch_quick_tap_chord_reveal():
		success = false

	# Test 4: Single-Finger Long Press (Hold to Flag)
	if not test_touch_long_press_hold_to_flag():
		success = false

	# Test 5: Single-Finger Drag Pan & Tap/Hold Suppression
	if not test_touch_single_finger_drag_pan_and_suppression():
		success = false

	# Test 6: Drag Threshold Jitter Tolerance (< drag_threshold)
	if not test_touch_drag_threshold_jitter_tolerance():
		success = false

	# Test 7: Two-Finger Pinch to Zoom & Pan
	if not test_touch_two_finger_pinch_zoom_and_pan():
		success = false

	# Test 8: Desktop Compatibility & State Reset Cleanup
	if not test_desktop_compatibility_and_state_reset():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)

func _create_touch_event(index: int, pressed: bool, pos: Vector2, double_tap: bool = false) -> InputEventScreenTouch:
	var event = InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = pos
	event.double_tap = double_tap
	return event

func _create_drag_event(index: int, pos: Vector2, relative: Vector2, velocity: Vector2 = Vector2.ZERO) -> InputEventScreenDrag:
	var event = InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	event.relative = relative
	event.velocity = velocity
	return event

func _create_mouse_button_event(button: MouseButton, pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var event = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	return event

func test_project_mobile_and_touch_settings() -> bool:
	print("[RUN] Test 1: Project Settings (Mobile Portrait & Touch Emulation)")

	var handheld_orientation = ProjectSettings.get_setting("display/window/handheld/orientation")
	if handheld_orientation != 1:
		print("[FAIL] display/window/handheld/orientation is not 1 (Portrait). Got: ", handheld_orientation)
		return false

	var stretch_mode = ProjectSettings.get_setting("display/window/stretch/mode")
	if stretch_mode != "canvas_items":
		print("[FAIL] display/window/stretch/mode is not 'canvas_items'. Got: ", stretch_mode)
		return false

	var stretch_aspect = ProjectSettings.get_setting("display/window/stretch/aspect")
	if stretch_aspect != "expand":
		print("[FAIL] display/window/stretch/aspect is not 'expand'. Got: ", stretch_aspect)
		return false

	var emulate_touch = ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse")
	if emulate_touch != true:
		print("[FAIL] input_devices/pointing/emulate_touch_from_mouse is not true. Got: ", emulate_touch)
		return false

	print("[PASS] Test 1: Project mobile portrait and touch settings verified")
	return true

func test_touch_quick_tap_reveal() -> bool:
	print("[RUN] Test 2: Quick Single-Finger Tap Reveal")
	var router = InputRouter.new()
	var grid = GridManager.new()
	root.add_child(router)
	root.add_child(grid)
	router.bind_grid_manager(grid)
	grid.safe_zone_radius = 0

	var target_cell_pos = Vector2i(0, 0)
	var screen_pos = Vector2(16, 16)

	grid.set_mine_at(target_cell_pos, false)
	grid.set_mine_at(Vector2i(1, 0), true) # Block BFS

	# 1. Touch press
	var touch_down = _create_touch_event(0, true, screen_pos)
	router.process_input(touch_down)

	# Verify: should NOT reveal immediately on touch down
	if grid.get_cell(target_cell_pos).is_revealed:
		print("[FAIL] Cell was revealed immediately on touch down instead of waiting for tap release")
		router.queue_free()
		grid.queue_free()
		return false

	# 2. Touch release (< long_press_duration, no drag)
	var touch_up = _create_touch_event(0, false, screen_pos)
	router.process_input(touch_up)

	# Verify: should reveal on clean tap release
	if not grid.get_cell(target_cell_pos).is_revealed:
		print("[FAIL] Cell was not revealed after quick touch tap release")
		router.queue_free()
		grid.queue_free()
		return false

	router.queue_free()
	grid.queue_free()
	print("[PASS] Test 2: Quick single-finger tap reveal verified")
	return true

func test_touch_quick_tap_chord_reveal() -> bool:
	print("[RUN] Test 3: Quick Single-Finger Tap Chord Reveal")
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

	grid.reveal_cell(target) # (0, 0) is revealed
	grid.toggle_flag(Vector2i(1, 0)) # (1, 0) is flagged

	var screen_pos = Vector2(16, 16)

	# 1. Touch press on already revealed cell (0, 0)
	router.process_input(_create_touch_event(0, true, screen_pos))

	# Verification: Chord should not trigger on press
	if grid.get_cell(Vector2i(0, 1)).is_revealed:
		print("[FAIL] Chord reveal triggered immediately on touch down")
		router.queue_free()
		grid.queue_free()
		return false

	# 2. Touch release (quick tap)
	router.process_input(_create_touch_event(0, false, screen_pos))

	# Verification: Neighbor cells should be chord-revealed
	if not grid.get_cell(Vector2i(0, 1)).is_revealed:
		print("[FAIL] Chord reveal was not triggered on quick tap release on revealed cell")
		router.queue_free()
		grid.queue_free()
		return false

	router.queue_free()
	grid.queue_free()
	print("[PASS] Test 3: Quick single-finger tap chord reveal verified")
	return true

func test_touch_long_press_hold_to_flag() -> bool:
	print("[RUN] Test 4: Single-Finger Long Press (Hold to Flag)")
	var router = InputRouter.new()
	var grid = GridManager.new()
	root.add_child(router)
	root.add_child(grid)
	router.bind_grid_manager(grid)
	grid.safe_zone_radius = 0
	router.long_press_duration = 0.35

	# Reveal anchor cell at (0, 0)
	grid.set_mine_at(Vector2i(0, 0), false)
	grid.set_mine_at(Vector2i(1, 0), true)
	grid.reveal_cell(Vector2i(0, 0))

	var target_cell_pos = Vector2i(0, 1)
	var screen_pos = Vector2(16, 48)

	# 1. Touch press
	router.process_input(_create_touch_event(0, true, screen_pos))

	if grid.get_cell(target_cell_pos).is_flagged:
		print("[FAIL] Cell was flagged immediately on touch down")
		router.queue_free()
		grid.queue_free()
		return false

	# 2. Advance time past long_press_duration (0.36s >= 0.35s)
	router.process_frame(0.36)

	# Verification: Cell SHOULD now be flagged via long press
	if not grid.get_cell(target_cell_pos).is_flagged:
		print("[FAIL] Cell was not flagged after holding touch for 0.36s")
		router.queue_free()
		grid.queue_free()
		return false

	# 3. Touch release after long press triggered
	router.process_input(_create_touch_event(0, false, screen_pos))

	# Verification: Cell must REMAIN flagged and must NOT be revealed
	if not grid.get_cell(target_cell_pos).is_flagged or grid.get_cell(target_cell_pos).is_revealed:
		print("[FAIL] Touch release after long press improperly modified cell state")
		router.queue_free()
		grid.queue_free()
		return false

	# 4. Second long press to unflag
	router.process_input(_create_touch_event(0, true, screen_pos))
	router.process_frame(0.36)
	router.process_input(_create_touch_event(0, false, screen_pos))

	if grid.get_cell(target_cell_pos).is_flagged:
		print("[FAIL] Second long press did not unflag the cell")
		router.queue_free()
		grid.queue_free()
		return false

	router.queue_free()
	grid.queue_free()
	print("[PASS] Test 4: Single-finger long press hold to flag verified")
	return true

func test_touch_single_finger_drag_pan_and_suppression() -> bool:
	print("[RUN] Test 5: Single-Finger Drag Pan & Tap/Hold Suppression")
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
	camera.zoom = Vector2(1.0, 1.0)
	camera.target_zoom = Vector2(1.0, 1.0)
	grid.safe_zone_radius = 0
	router.drag_threshold = 6.0

	grid.set_mine_at(Vector2i(0, 0), false)
	grid.set_mine_at(Vector2i(1, 0), true)
	grid.reveal_cell(Vector2i(0, 0))

	var target_cell_pos = Vector2i(0, 1)
	var start_pos = Vector2(16, 48)
	var drag_pos = start_pos + Vector2(50, 30) # Distance ~58.3px > 6.0px

	# 1. Touch press
	router.process_input(_create_touch_event(0, true, start_pos))

	# 2. Touch drag
	router.process_input(_create_drag_event(0, drag_pos, Vector2(50, 30)))

	# Verification: Camera should have panned
	var expected_target_pos = Vector2(-50, -30)
	if camera.target_position.distance_to(expected_target_pos) > 0.01:
		print("[FAIL] Camera did not pan by drag relative offset. Expected: ", expected_target_pos, " Got: ", camera.target_position)
		router.queue_free()
		grid.queue_free()
		camera.queue_free()
		return false

	# 3. Simulate hold duration elapsed (0.4s) while dragging
	router.process_frame(0.4)

	# Verification: Long press flag MUST be suppressed
	if grid.get_cell(target_cell_pos).is_flagged:
		print("[FAIL] Long press flag was triggered during drag pan gesture")
		router.queue_free()
		grid.queue_free()
		camera.queue_free()
		return false

	# 4. Touch release
	router.process_input(_create_touch_event(0, false, drag_pos))

	# Verification: Tap reveal MUST be suppressed
	if grid.get_cell(target_cell_pos).is_revealed:
		print("[FAIL] Tap reveal was triggered after drag pan gesture")
		router.queue_free()
		grid.queue_free()
		camera.queue_free()
		return false

	router.queue_free()
	grid.queue_free()
	camera.queue_free()
	print("[PASS] Test 5: Single-finger drag pan & tap/hold suppression verified")
	return true

func test_touch_drag_threshold_jitter_tolerance() -> bool:
	print("[RUN] Test 6: Drag Threshold Jitter Tolerance (< drag_threshold)")
	var router = InputRouter.new()
	var grid = GridManager.new()
	root.add_child(router)
	root.add_child(grid)
	router.bind_grid_manager(grid)
	grid.safe_zone_radius = 0
	router.drag_threshold = 6.0
	router.long_press_duration = 0.35

	grid.set_mine_at(Vector2i(0, 0), false)
	grid.set_mine_at(Vector2i(1, 0), true)
	grid.reveal_cell(Vector2i(0, 0))

	var target_cell_pos = Vector2i(0, 1)
	var start_pos = Vector2(16, 48)
	var jitter_pos = start_pos + Vector2(2.0, 2.0) # distance ~2.83px <= 6.0px

	# Case A: Jitter on quick tap reveal
	grid.set_mine_at(Vector2i(0, -1), false)
	var tap_cell_pos = Vector2i(0, -1)
	var tap_start_pos = Vector2(16, -16)
	var tap_jitter_pos = tap_start_pos + Vector2(1.5, 1.5)

	router.process_input(_create_touch_event(0, true, tap_start_pos))
	router.process_input(_create_drag_event(0, tap_jitter_pos, Vector2(1.5, 1.5)))
	router.process_input(_create_touch_event(0, false, tap_jitter_pos))

	if not grid.get_cell(tap_cell_pos).is_revealed:
		print("[FAIL] Tap reveal failed when micro-jitter was within drag_threshold")
		router.queue_free()
		grid.queue_free()
		return false

	# Case B: Jitter on long press hold
	router.process_input(_create_touch_event(0, true, start_pos))
	router.process_input(_create_drag_event(0, jitter_pos, Vector2(2.0, 2.0)))
	router.process_frame(0.36)
	router.process_input(_create_touch_event(0, false, jitter_pos))

	if not grid.get_cell(target_cell_pos).is_flagged:
		print("[FAIL] Long press flag failed when micro-jitter was within drag_threshold")
		router.queue_free()
		grid.queue_free()
		return false

	router.queue_free()
	grid.queue_free()
	print("[PASS] Test 6: Drag threshold jitter tolerance verified")
	return true

func test_touch_two_finger_pinch_zoom_and_pan() -> bool:
	print("[RUN] Test 7: Two-Finger Pinch to Zoom & Pan")
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
	camera.zoom = Vector2(1.0, 1.0)
	camera.target_zoom = Vector2(1.0, 1.0)
	grid.safe_zone_radius = 0

	# 1. Touch 0 and Touch 1 down at dist = 100px
	var p0_start = Vector2(100, 200)
	var p1_start = Vector2(200, 200) # distance = 100px, center = (150, 200)

	router.process_input(_create_touch_event(0, true, p0_start))
	router.process_input(_create_touch_event(1, true, p1_start))

	# 2. Pinch outward: Touch 0 moves to (50, 200), Touch 1 moves to (250, 200) (dist = 200px, center = (150, 200))
	var p0_pinch = Vector2(50, 200)
	var p1_pinch = Vector2(250, 200)

	router.process_input(_create_drag_event(0, p0_pinch, Vector2(-50, 0)))
	router.process_input(_create_drag_event(1, p1_pinch, Vector2(50, 0)))

	# Verification: Zoom should increase (target_zoom > 1.0)
	if camera.target_zoom.x <= 1.0:
		print("[FAIL] Pinch out did not increase camera target_zoom. Got: ", camera.target_zoom)
		router.queue_free()
		grid.queue_free()
		camera.queue_free()
		return false

	var zoomed_in_val = camera.target_zoom.x

	# 3. Pinch inward: Touch 0 moves to (120, 200), Touch 1 moves to (180, 200) (dist = 60px)
	var p0_in = Vector2(120, 200)
	var p1_in = Vector2(180, 200)
	router.process_input(_create_drag_event(0, p0_in, Vector2(70, 0)))
	router.process_input(_create_drag_event(1, p1_in, Vector2(-70, 0)))

	# Verification: Zoom should decrease
	if camera.target_zoom.x >= zoomed_in_val:
		print("[FAIL] Pinch in did not decrease camera target_zoom. Got: ", camera.target_zoom)
		router.queue_free()
		grid.queue_free()
		camera.queue_free()
		return false

	# 4. Simultaneous dual-finger pan: Both fingers shift by (30, 40)
	var prev_pan_target = camera.target_position
	var p0_pan = p0_in + Vector2(30, 40)
	var p1_pan = p1_in + Vector2(30, 40)
	router.process_input(_create_drag_event(0, p0_pan, Vector2(30, 40)))
	router.process_input(_create_drag_event(1, p1_pan, Vector2(30, 40)))

	if camera.target_position == prev_pan_target:
		print("[FAIL] Dual finger pan did not move camera target_position")
		router.queue_free()
		grid.queue_free()
		camera.queue_free()
		return false

	# 5. Release touches
	router.process_input(_create_touch_event(0, false, p0_pan))
	router.process_input(_create_touch_event(1, false, p1_pan))

	# Verify: No cell at touch positions was revealed or flagged
	var touched_cell_0 = grid.world_to_cell(p0_pan)
	var touched_cell_1 = grid.world_to_cell(p1_pan)
	if grid.grid_data.has(touched_cell_0) and (grid.grid_data[touched_cell_0].is_revealed or grid.grid_data[touched_cell_0].is_flagged):
		print("[FAIL] Two-finger pinch caused accidental cell reveal or flag at touched_cell_0")
		router.queue_free()
		grid.queue_free()
		camera.queue_free()
		return false

	router.queue_free()
	grid.queue_free()
	camera.queue_free()
	print("[PASS] Test 7: Two-finger pinch to zoom & pan verified")
	return true

func test_desktop_compatibility_and_state_reset() -> bool:
	print("[RUN] Test 8: Desktop Compatibility & State Reset Cleanup")
	var router = InputRouter.new()
	var grid = GridManager.new()
	root.add_child(router)
	root.add_child(grid)
	router.bind_grid_manager(grid)
	grid.safe_zone_radius = 0

	grid.set_mine_at(Vector2i(0, 0), false)
	grid.set_mine_at(Vector2i(1, 0), true)

	# 1. Desktop LMB immediate reveal on press
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_LEFT, true, Vector2(16, 16)))
	if not grid.get_cell(Vector2i(0, 0)).is_revealed:
		print("[FAIL] Desktop LMB immediate reveal failed")
		router.queue_free()
		grid.queue_free()
		return false

	# 2. Desktop RMB tap flag on release
	var rmb_pos = Vector2(16, 48) # (0, 1)
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, true, rmb_pos))
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, false, rmb_pos))
	if not grid.get_cell(Vector2i(0, 1)).is_flagged:
		print("[FAIL] Desktop RMB tap flag failed")
		router.queue_free()
		grid.queue_free()
		return false

	# 3. Simulate half-completed touch and reset
	router.process_input(_create_touch_event(0, true, Vector2(50, 50)))
	grid.reset_game()
	router.reset_state()

	# Verify touch states cleaned
	if "_touch_points" in router and router.get("_touch_points").size() != 0:
		print("[FAIL] _touch_points not cleared after reset_state()")
		router.queue_free()
		grid.queue_free()
		return false

	if "_is_single_touch_active" in router and router.get("_is_single_touch_active") != false:
		print("[FAIL] _is_single_touch_active not reset to false after reset_state()")
		router.queue_free()
		grid.queue_free()
		return false

	router.queue_free()
	grid.queue_free()
	print("[PASS] Test 8: Desktop compatibility & state reset cleanup verified")
	return true
