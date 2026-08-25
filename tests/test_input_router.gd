@tool
extends SceneTree

const InputRouter = preload("res://scripts/input_router.gd")
const GridManager = preload("res://scripts/grid_manager.gd")
const CameraController = preload("res://scripts/camera_controller.gd")

func _init():
	print("--- Running Test Suite: InputRouter Deep Module ---")
	_setup_input_actions()

	var success = true

	# Test 1: Initialization & Default Properties
	if not test_initialization():
		success = false

	# Test 2: Left-Click Immediate Reveal & Double-Click Chord
	if not test_left_click_reveal_and_double_click_chord():
		success = false

	# Test 3: Right-Click Tap vs Drag Disambiguation
	if not test_right_click_tap_vs_drag():
		success = false

	# Test 4: Middle-Click Tap vs Drag Disambiguation
	if not test_middle_click_tap_vs_drag():
		success = false

	# Test 5: Mouse Wheel Zoom Actions
	if not test_mouse_wheel_zoom():
		success = false

	# Test 6: Keyboard Shortcuts & Echo Suppression
	if not test_keyboard_shortcuts():
		success = false

	# Test 7: Single-Touch Tap & Long Press Hold to Flag
	if not test_touch_tap_and_long_press():
		success = false

	# Test 8: Single-Touch Drag Pan & Suppression
	if not test_touch_drag_pan_and_suppression():
		success = false

	# Test 9: Two-Finger Pinch Zoom & Dual-Finger Pan
	if not test_two_finger_pinch_zoom_and_pan():
		success = false

	# Test 10: State Reset & Game Over Constraints
	if not test_reset_and_game_over():
		success = false

	# Test 11: Binding Helpers Integration
	if not test_binding_helpers():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)

func _setup_input_actions() -> void:
	if not InputMap.has_action("reveal_cell"):
		InputMap.add_action("reveal_cell")
		var space_event = InputEventKey.new()
		space_event.physical_keycode = KEY_SPACE
		space_event.unicode = 32
		InputMap.action_add_event("reveal_cell", space_event)

	if not InputMap.has_action("flag_cell"):
		InputMap.add_action("flag_cell")
		var f_event = InputEventKey.new()
		f_event.physical_keycode = KEY_F
		f_event.unicode = 102
		InputMap.action_add_event("flag_cell", f_event)

	if not InputMap.has_action("zoom_in"):
		InputMap.add_action("zoom_in")
	if not InputMap.has_action("zoom_out"):
		InputMap.add_action("zoom_out")

func _create_mouse_button_event(button: MouseButton, pressed: bool, pos: Vector2, double_click: bool = false) -> InputEventMouseButton:
	var event = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	event.double_click = double_click
	return event

func _create_mouse_motion_event(pos: Vector2, relative: Vector2 = Vector2.ZERO) -> InputEventMouseMotion:
	var event = InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.relative = relative
	return event

func _create_touch_event(index: int, pressed: bool, pos: Vector2, double_tap: bool = false) -> InputEventScreenTouch:
	var event = InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = pos
	event.double_tap = double_tap
	return event

func _create_drag_event(index: int, pos: Vector2, relative: Vector2) -> InputEventScreenDrag:
	var event = InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	event.relative = relative
	return event

func _create_key_event(action_name: String, keycode: Key, pressed: bool, echo: bool = false) -> InputEventKey:
	var event = InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	return event

func test_initialization() -> bool:
	print("[RUN] Test 1: Initialization & Default Properties")
	var router = InputRouter.new()
	if router.cell_size != Vector2i(32, 32):
		print("[FAIL] Default cell_size mismatch: ", router.cell_size)
		router.free()
		return false
	if router.drag_threshold != 16.0:
		print("[FAIL] Default drag_threshold mismatch: ", router.drag_threshold)
		router.free()
		return false
	if router.long_press_duration != 0.15:
		print("[FAIL] Default long_press_duration mismatch: ", router.long_press_duration)
		router.free()
		return false
	if router.is_enabled != true or router.is_game_over != false:
		print("[FAIL] Initial state flags incorrect")
		router.free()
		return false
	router.free()
	print("[PASS] Test 1: Initialization verified")
	return true

func test_left_click_reveal_and_double_click_chord() -> bool:
	print("[RUN] Test 2: Left-Click Immediate Reveal & Double-Click Chord")
	var router = InputRouter.new()
	var revealed_positions: Array[Vector2i] = []
	var chord_positions: Array[Vector2i] = []

	router.cell_reveal_requested.connect(func(pos: Vector2i): revealed_positions.append(pos))
	router.cell_chord_requested.connect(func(pos: Vector2i): chord_positions.append(pos))

	# 1. Single Left Click Press
	var cell_pos = Vector2i(2, 3)
	var screen_pos = Vector2(2 * 32 + 16, 3 * 32 + 16)
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_LEFT, true, screen_pos, false))

	if revealed_positions.size() != 1 or revealed_positions[0] != cell_pos:
		print("[FAIL] Left-click press did not emit cell_reveal_requested: ", revealed_positions)
		router.free()
		return false

	# 2. Left Click Double Click
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_LEFT, true, screen_pos, true))
	if chord_positions.size() != 1 or chord_positions[0] != cell_pos:
		print("[FAIL] Double click did not emit cell_chord_requested: ", chord_positions)
		router.free()
		return false

	router.free()
	print("[PASS] Test 2: Left-click and double click verified")
	return true

func test_right_click_tap_vs_drag() -> bool:
	print("[RUN] Test 3: Right-Click Tap vs Drag Disambiguation")
	var router = InputRouter.new()
	router.drag_threshold = 6.0
	var flag_positions: Array[Vector2i] = []
	var pan_offsets: Array[Vector2] = []

	router.cell_flag_toggled.connect(func(pos: Vector2i): flag_positions.append(pos))
	router.camera_pan_requested.connect(func(rel: Vector2): pan_offsets.append(rel))

	var cell_pos = Vector2i(1, 1)
	var start_pos = Vector2(1 * 32 + 16, 1 * 32 + 16)

	# Case A: Tap (Press -> Release at same pos)
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, true, start_pos))
	if flag_positions.size() != 0:
		print("[FAIL] Flag emitted on press instead of release")
		router.free()
		return false

	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, false, start_pos))
	if flag_positions.size() != 1 or flag_positions[0] != cell_pos:
		print("[FAIL] Flag not emitted on tap release: ", flag_positions)
		router.free()
		return false

	# Case B: Jitter within threshold (distance ~2.83px <= 6.0px)
	flag_positions.clear()
	var jitter_pos = start_pos + Vector2(2, 2)
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, true, start_pos))
	router.process_input(_create_mouse_motion_event(jitter_pos, Vector2(2, 2)))
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, false, jitter_pos))
	if flag_positions.size() != 1:
		print("[FAIL] Flag should be emitted for micro-jitter within threshold")
		router.free()
		return false

	# Case C: Drag exceeding threshold (distance 50px > 6.0px)
	flag_positions.clear()
	pan_offsets.clear()
	var drag_pos = start_pos + Vector2(50, 0)
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, true, start_pos))
	router.process_input(_create_mouse_motion_event(drag_pos, Vector2(50, 0)))
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_RIGHT, false, drag_pos))

	if pan_offsets.size() == 0:
		print("[FAIL] Drag did not emit camera_pan_requested")
		router.free()
		return false
	if flag_positions.size() != 0:
		print("[FAIL] Flag was erroneously emitted after drag")
		router.free()
		return false

	router.free()
	print("[PASS] Test 3: Right-click tap vs drag disambiguation verified")
	return true

func test_middle_click_tap_vs_drag() -> bool:
	print("[RUN] Test 4: Middle-Click Tap vs Drag Disambiguation")
	var router = InputRouter.new()
	router.drag_threshold = 6.0
	var chord_positions: Array[Vector2i] = []
	var pan_offsets: Array[Vector2] = []

	router.cell_chord_requested.connect(func(pos: Vector2i): chord_positions.append(pos))
	router.camera_pan_requested.connect(func(rel: Vector2): pan_offsets.append(rel))

	var start_pos = Vector2(32 + 16, 32 + 16) # (1, 1)

	# Case A: Tap (Press -> Release)
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_MIDDLE, true, start_pos))
	if chord_positions.size() != 0:
		print("[FAIL] Chord emitted on press instead of release")
		router.free()
		return false
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_MIDDLE, false, start_pos))
	if chord_positions.size() != 1 or chord_positions[0] != Vector2i(1, 1):
		print("[FAIL] Chord not emitted on tap release")
		router.free()
		return false

	# Case B: Drag exceeding threshold
	chord_positions.clear()
	pan_offsets.clear()
	var drag_pos = start_pos + Vector2(30, 30)
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_MIDDLE, true, start_pos))
	router.process_input(_create_mouse_motion_event(drag_pos, Vector2(30, 30)))
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_MIDDLE, false, drag_pos))

	if pan_offsets.size() == 0:
		print("[FAIL] Middle drag did not emit camera_pan_requested")
		router.free()
		return false
	if chord_positions.size() != 0:
		print("[FAIL] Chord was erroneously emitted after middle drag")
		router.free()
		return false

	router.free()
	print("[PASS] Test 4: Middle-click tap vs drag disambiguation verified")
	return true

func test_mouse_wheel_zoom() -> bool:
	print("[RUN] Test 5: Mouse Wheel Zoom Actions")
	var router = InputRouter.new()
	var zoom_steps: Array[int] = []
	router.camera_zoom_step_requested.connect(func(dir: int): zoom_steps.append(dir))

	var zoom_in_event = InputEventAction.new()
	zoom_in_event.action = "zoom_in"
	zoom_in_event.pressed = true
	router.process_input(zoom_in_event)

	var zoom_out_event = InputEventAction.new()
	zoom_out_event.action = "zoom_out"
	zoom_out_event.pressed = true
	router.process_input(zoom_out_event)

	if zoom_steps.size() != 2 or zoom_steps[0] != 1 or zoom_steps[1] != -1:
		print("[FAIL] Zoom steps mismatch: ", zoom_steps)
		router.free()
		return false

	router.free()
	print("[PASS] Test 5: Mouse wheel zoom actions verified")
	return true

func test_keyboard_shortcuts() -> bool:
	print("[RUN] Test 6: Keyboard Shortcuts & Echo Suppression")
	var router = InputRouter.new()
	var revealed_positions: Array[Vector2i] = []
	var chord_positions: Array[Vector2i] = []
	var flag_positions: Array[Vector2i] = []

	router.cell_reveal_requested.connect(func(pos: Vector2i): revealed_positions.append(pos))
	router.cell_chord_requested.connect(func(pos: Vector2i): chord_positions.append(pos))
	router.cell_flag_toggled.connect(func(pos: Vector2i): flag_positions.append(pos))

	var revealed_map: Dictionary = {Vector2i(0, 0): true}
	router.is_cell_revealed_query = func(pos: Vector2i) -> bool:
		return revealed_map.get(pos, false)

	# 1. Hover at (0, 1) and press Space -> reveal (unrevealed)
	router.process_input(_create_mouse_motion_event(Vector2(16, 48))) # (0, 1)
	router.process_input(_create_key_event("reveal_cell", KEY_SPACE, true, false))
	if revealed_positions.size() != 1 or revealed_positions[0] != Vector2i(0, 1):
		print("[FAIL] Space did not reveal hovered cell (0, 1): ", revealed_positions)
		router.free()
		return false

	# 2. Hover at (0, 0) and press Space -> chord (revealed)
	router.process_input(_create_mouse_motion_event(Vector2(16, 16))) # (0, 0)
	router.process_input(_create_key_event("reveal_cell", KEY_SPACE, true, false))
	if chord_positions.size() != 1 or chord_positions[0] != Vector2i(0, 0):
		print("[FAIL] Space did not chord revealed cell (0, 0): ", chord_positions)
		router.free()
		return false

	# 3. Hover at (0, 1) and press F -> flag
	router.process_input(_create_mouse_motion_event(Vector2(16, 48)))
	router.process_input(_create_key_event("flag_cell", KEY_F, true, false))
	if flag_positions.size() != 1 or flag_positions[0] != Vector2i(0, 1):
		print("[FAIL] F did not toggle flag on hovered cell: ", flag_positions)
		router.free()
		return false

	# 4. Echo suppression: F echo should be ignored
	router.process_input(_create_key_event("flag_cell", KEY_F, true, true))
	if flag_positions.size() != 1:
		print("[FAIL] Echo key event was not suppressed")
		router.free()
		return false

	router.free()
	print("[PASS] Test 6: Keyboard shortcuts & echo suppression verified")
	return true

func test_touch_tap_and_long_press() -> bool:
	print("[RUN] Test 7: Single-Touch Tap & Long Press Hold to Flag")
	var router = InputRouter.new()
	router.long_press_duration = 0.35
	var revealed_positions: Array[Vector2i] = []
	var chord_positions: Array[Vector2i] = []
	var flag_positions: Array[Vector2i] = []

	router.cell_reveal_requested.connect(func(pos: Vector2i): revealed_positions.append(pos))
	router.cell_chord_requested.connect(func(pos: Vector2i): chord_positions.append(pos))
	router.cell_flag_toggled.connect(func(pos: Vector2i): flag_positions.append(pos))

	var revealed_map: Dictionary = {Vector2i(0, 0): true}
	router.is_cell_revealed_query = func(pos: Vector2i) -> bool:
		return revealed_map.get(pos, false)

	# Case A: Quick tap on unrevealed cell (0, 1) -> reveal
	var pos_0_1 = Vector2(16, 48)
	router.process_input(_create_touch_event(0, true, pos_0_1))
	if revealed_positions.size() != 0:
		print("[FAIL] Cell revealed on touch down instead of tap release")
		router.free()
		return false
	router.process_input(_create_touch_event(0, false, pos_0_1))
	if revealed_positions.size() != 1 or revealed_positions[0] != Vector2i(0, 1):
		print("[FAIL] Quick tap failed to emit cell_reveal_requested")
		router.free()
		return false

	# Case B: Quick tap on revealed cell (0, 0) -> chord
	var pos_0_0 = Vector2(16, 16)
	router.process_input(_create_touch_event(0, true, pos_0_0))
	router.process_input(_create_touch_event(0, false, pos_0_0))
	if chord_positions.size() != 1 or chord_positions[0] != Vector2i(0, 0):
		print("[FAIL] Quick tap on revealed cell failed to emit cell_chord_requested")
		router.free()
		return false

	# Case C: Long press on unrevealed cell (1, 1)
	revealed_positions.clear()
	var pos_1_1 = Vector2(48, 48)
	router.process_input(_create_touch_event(0, true, pos_1_1))
	router.process_frame(0.36) # exceeds long_press_duration
	if flag_positions.size() != 1 or flag_positions[0] != Vector2i(1, 1):
		print("[FAIL] Long press failed to emit cell_flag_toggled after 0.36s")
		router.free()
		return false

	# Touch release after long press should NOT reveal
	router.process_input(_create_touch_event(0, false, pos_1_1))
	if revealed_positions.size() != 0:
		print("[FAIL] Release after long press erroneously emitted reveal")
		router.free()
		return false

	router.free()
	print("[PASS] Test 7: Single-touch tap and long press verified")
	return true

func test_touch_drag_pan_and_suppression() -> bool:
	print("[RUN] Test 8: Single-Touch Drag Pan & Suppression")
	var router = InputRouter.new()
	router.drag_threshold = 6.0
	router.long_press_duration = 0.35
	var revealed_positions: Array[Vector2i] = []
	var flag_positions: Array[Vector2i] = []
	var pan_offsets: Array[Vector2] = []

	router.cell_reveal_requested.connect(func(pos: Vector2i): revealed_positions.append(pos))
	router.cell_flag_toggled.connect(func(pos: Vector2i): flag_positions.append(pos))
	router.camera_pan_requested.connect(func(rel: Vector2): pan_offsets.append(rel))

	var start_pos = Vector2(16, 48)
	var drag_pos = start_pos + Vector2(50, 30)

	router.process_input(_create_touch_event(0, true, start_pos))
	router.process_input(_create_drag_event(0, drag_pos, Vector2(50, 30)))

	if pan_offsets.size() == 0 or pan_offsets[0] != Vector2(50, 30):
		print("[FAIL] Single finger drag did not emit camera_pan_requested")
		router.free()
		return false

	router.process_frame(0.4) # advance time past long press
	router.process_input(_create_touch_event(0, false, drag_pos))

	if flag_positions.size() != 0:
		print("[FAIL] Long press flag was not suppressed during drag")
		router.free()
		return false
	if revealed_positions.size() != 0:
		print("[FAIL] Tap reveal was not suppressed after drag")
		router.free()
		return false

	router.free()
	print("[PASS] Test 8: Single-touch drag pan & suppression verified")
	return true

func test_two_finger_pinch_zoom_and_pan() -> bool:
	print("[RUN] Test 9: Two-Finger Pinch Zoom & Dual-Finger Pan")
	var router = InputRouter.new()
	var pinch_factors: Array[float] = []
	var pan_offsets: Array[Vector2] = []
	var revealed_positions: Array[Vector2i] = []
	var flag_positions: Array[Vector2i] = []

	router.camera_pinch_zoom_requested.connect(func(factor: float): pinch_factors.append(factor))
	router.camera_pan_requested.connect(func(rel: Vector2): pan_offsets.append(rel))
	router.cell_reveal_requested.connect(func(pos: Vector2i): revealed_positions.append(pos))
	router.cell_flag_toggled.connect(func(pos: Vector2i): flag_positions.append(pos))

	# Touch 0 & Touch 1 down at dist = 100px
	var p0_start = Vector2(100, 200)
	var p1_start = Vector2(200, 200)
	router.process_input(_create_touch_event(0, true, p0_start))
	router.process_input(_create_touch_event(1, true, p1_start))

	# Pinch outward (dist = 200px -> factor = 2.0 across 2 touch events: 1.5 * 1.333 = 2.0)
	var p0_pinch = Vector2(50, 200)
	var p1_pinch = Vector2(250, 200)
	router.process_input(_create_drag_event(0, p0_pinch, Vector2(-50, 0)))
	router.process_input(_create_drag_event(1, p1_pinch, Vector2(50, 0)))

	var total_pinch_factor = 1.0
	for f in pinch_factors:
		total_pinch_factor *= f

	if pinch_factors.size() == 0 or abs(total_pinch_factor - 2.0) > 0.01:
		print("[FAIL] Pinch zoom factor mismatch. Got total factor: ", total_pinch_factor, " steps: ", pinch_factors)
		router.free()
		return false

	# Dual finger pan
	pan_offsets.clear()
	var p0_pan = p0_pinch + Vector2(30, 40)
	var p1_pan = p1_pinch + Vector2(30, 40)
	router.process_input(_create_drag_event(0, p0_pan, Vector2(30, 40)))
	router.process_input(_create_drag_event(1, p1_pan, Vector2(30, 40)))

	var total_pan = Vector2.ZERO
	for p in pan_offsets:
		total_pan += p

	if pan_offsets.size() == 0 or total_pan.distance_to(Vector2(30, 40)) > 0.01:
		print("[FAIL] Dual finger pan offset mismatch. Got total pan: ", total_pan, " steps: ", pan_offsets)
		router.free()
		return false

	router.process_input(_create_touch_event(0, false, p0_pan))
	router.process_input(_create_touch_event(1, false, p1_pan))

	if revealed_positions.size() != 0 or flag_positions.size() != 0:
		print("[FAIL] Multi-touch generated accidental reveal or flag")
		router.free()
		return false

	router.free()
	print("[PASS] Test 9: Two-finger pinch zoom & dual-finger pan verified")
	return true

func test_reset_and_game_over() -> bool:
	print("[RUN] Test 10: State Reset & Game Over Constraints")
	var router = InputRouter.new()
	var revealed_positions: Array[Vector2i] = []
	router.cell_reveal_requested.connect(func(pos: Vector2i): revealed_positions.append(pos))

	# 1. State reset
	router.process_input(_create_touch_event(0, true, Vector2(50, 50)))
	router.reset_state()
	# Touch up after reset should not trigger anything
	router.process_input(_create_touch_event(0, false, Vector2(50, 50)))
	if revealed_positions.size() != 0:
		print("[FAIL] Input processed after reset_state()")
		router.free()
		return false

	# 2. Game over constraint
	router.is_game_over = true
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_LEFT, true, Vector2(16, 16)))
	if revealed_positions.size() != 0:
		print("[FAIL] Input processed while is_game_over = true")
		router.free()
		return false

	router.free()
	print("[PASS] Test 10: State reset & game over constraints verified")
	return true

func test_binding_helpers() -> bool:
	print("[RUN] Test 11: Binding Helpers Integration")
	var router = InputRouter.new()
	var grid = GridManager.new()
	var camera = CameraController.new()

	router.bind_grid_manager(grid)
	router.bind_camera_controller(camera)

	# Reveal anchor cell at (0, 0) via router
	grid.set_mine_at(Vector2i(0, 0), false)
	grid.set_mine_at(Vector2i(1, 0), true)
	router.process_input(_create_mouse_button_event(MOUSE_BUTTON_LEFT, true, Vector2(16, 16)))

	if not grid.get_cell(Vector2i(0, 0)).is_revealed:
		print("[FAIL] bind_grid_manager failed to connect cell_reveal_requested to grid.reveal_cell")
		router.free()
		grid.free()
		camera.free()
		return false

	# Pan camera via router
	var initial_cam_pos = camera.target_position
	router.camera_pan_requested.emit(Vector2(40, 20))
	if camera.target_position == initial_cam_pos:
		print("[FAIL] bind_camera_controller failed to connect camera_pan_requested to camera.pan_by")
		router.free()
		grid.free()
		camera.free()
		return false

	router.free()
	grid.free()
	camera.free()
	print("[PASS] Test 11: Binding helpers integration verified")
	return true
