@tool
extends SceneTree

const GridManager = preload("res://scripts/grid_manager.gd")
const CellData = preload("res://scripts/cell_data.gd")

func _init():
	print("--- Running Test Suite: Keyboard Shortcuts for Cell Reveal & Flag ---")
	_setup_input_actions()

	var success = true

	# Test 1: Space Key Press Reveals Hovered Cell
	if not test_keyboard_reveal_cell():
		success = false

	# Test 2: F Key Press Toggles Flag on Hovered Cell
	if not test_keyboard_flag_cell():
		success = false

	# Test 3: Space Key on Revealed Cell Triggers Chord Reveal
	if not test_keyboard_chord_reveal():
		success = false

	# Test 4: Echo Key Events are Suppressed
	if not test_keyboard_echo_suppression():
		success = false

	# Test 5: Mouse Motion Updates Target Cell for Keyboard Shortcuts
	if not test_mouse_motion_target_tracking():
		success = false

	# Test 6: Keyboard Actions Respect Game Over Constraint
	if not test_keyboard_game_over_constraint():
		success = false

	# Test 7: Keyboard Actions Respect Locked Chunk and Frontier Adjacency Restrictions
	if not test_keyboard_chunk_and_frontier_restrictions():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)

func _setup_input_actions() -> void:
	# Ensure actions exist in InputMap during standalone headless runs
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
		f_event.unicode = 102 # 'f'
		InputMap.action_add_event("flag_cell", f_event)

func _create_key_event(action_name: String, keycode: Key, pressed: bool, echo: bool = false) -> InputEventKey:
	var event = InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	return event

func _create_mouse_motion_event(pos: Vector2) -> InputEventMouseMotion:
	var event = InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.relative = Vector2.ZERO
	return event

func test_keyboard_reveal_cell() -> bool:
	print("[RUN] Test 1: Space Key Press Reveals Hovered Cell")
	var grid = GridManager.new()
	root.add_child(grid)
	grid.safe_zone_radius = 0

	# Configure cells
	grid.set_mine_at(Vector2i(0, 0), false)
	grid.set_mine_at(Vector2i(1, 0), true) # Block full BFS

	# Hover mouse at cell (0, 0) (world pos: 16, 16)
	var screen_pos = Vector2(16, 16)
	grid._unhandled_input(_create_mouse_motion_event(screen_pos))

	# Press Space (reveal_cell)
	var space_event = _create_key_event("reveal_cell", KEY_SPACE, true, false)
	grid._unhandled_input(space_event)

	if not grid.get_cell(Vector2i(0, 0)).is_revealed:
		print("[FAIL] Cell (0, 0) was not revealed upon Space key press")
		grid.queue_free()
		return false

	if grid.get_cell(Vector2i(1, 0)).is_revealed:
		print("[FAIL] Cell (1, 0) should remain unrevealed")
		grid.queue_free()
		return false

	grid.queue_free()
	print("[PASS] Test 1: Space Key Press Reveal verified")
	return true

func test_keyboard_flag_cell() -> bool:
	print("[RUN] Test 2: F Key Press Toggles Flag on Hovered Cell")
	var grid = GridManager.new()
	root.add_child(grid)
	grid.safe_zone_radius = 0

	# Reveal anchor cell at (0, 0)
	grid.set_mine_at(Vector2i(0, 0), false)
	grid.set_mine_at(Vector2i(1, 0), true)
	grid.reveal_cell(Vector2i(0, 0))

	# Hover over adjacent cell (0, 1) (world pos: 16, 48)
	var target_cell_pos = Vector2i(0, 1)
	var screen_pos = Vector2(16, 48)
	grid._unhandled_input(_create_mouse_motion_event(screen_pos))

	# Press F (flag_cell) -> flag cell
	var f_event = _create_key_event("flag_cell", KEY_F, true, false)
	grid._unhandled_input(f_event)

	if not grid.get_cell(target_cell_pos).is_flagged:
		print("[FAIL] Cell (0, 1) was not flagged upon F key press")
		grid.queue_free()
		return false

	# Press F again -> unflag cell
	grid._unhandled_input(f_event)

	if grid.get_cell(target_cell_pos).is_flagged:
		print("[FAIL] Cell (0, 1) was not unflagged upon second F key press")
		grid.queue_free()
		return false

	grid.queue_free()
	print("[PASS] Test 2: F Key Flag Toggle verified")
	return true

func test_keyboard_chord_reveal() -> bool:
	print("[RUN] Test 3: Space Key on Revealed Cell Triggers Chord Reveal")
	var grid = GridManager.new()
	root.add_child(grid)
	grid.safe_zone_radius = 0

	# Setup target cell (0, 0) with exactly 1 mine neighbor at (1, 0)
	var target = Vector2i(0, 0)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			grid.set_mine_at(target + Vector2i(dx, dy), false)
	grid.set_mine_at(Vector2i(1, 0), true)

	grid.reveal_cell(target) # Reveal (0, 0)
	grid.toggle_flag(Vector2i(1, 0)) # Flag (1, 0) -> satisfies chord condition

	# Hover over cell (0, 0)
	var screen_pos = Vector2(16, 16)
	grid._unhandled_input(_create_mouse_motion_event(screen_pos))

	# Press Space on already revealed cell (0, 0)
	var space_event = _create_key_event("reveal_cell", KEY_SPACE, true, false)
	grid._unhandled_input(space_event)

	# Verify neighbor (0, 1) is revealed via chord
	if not grid.get_cell(Vector2i(0, 1)).is_revealed:
		print("[FAIL] Chord reveal was not triggered by Space key on revealed cell")
		grid.queue_free()
		return false

	grid.queue_free()
	print("[PASS] Test 3: Space Key Chord Reveal verified")
	return true

func test_keyboard_echo_suppression() -> bool:
	print("[RUN] Test 4: Echo Key Events are Suppressed")
	var grid = GridManager.new()
	root.add_child(grid)
	grid.safe_zone_radius = 0

	# Reveal anchor cell at (0, 0)
	grid.set_mine_at(Vector2i(0, 0), false)
	grid.set_mine_at(Vector2i(1, 0), true)
	grid.reveal_cell(Vector2i(0, 0))

	# Hover over adjacent cell (0, 1)
	var target_cell_pos = Vector2i(0, 1)
	var screen_pos = Vector2(16, 48)
	grid._unhandled_input(_create_mouse_motion_event(screen_pos))

	# Send normal press F -> flags cell
	var f_press = _create_key_event("flag_cell", KEY_F, true, false)
	grid._unhandled_input(f_press)

	if not grid.get_cell(target_cell_pos).is_flagged:
		print("[FAIL] Initial F press failed to flag cell")
		grid.queue_free()
		return false

	# Send echo press F -> should NOT unflag cell
	var f_echo = _create_key_event("flag_cell", KEY_F, true, true)
	grid._unhandled_input(f_echo)

	if not grid.get_cell(target_cell_pos).is_flagged:
		print("[FAIL] Echo F event was processed and erroneously unflagged the cell")
		grid.queue_free()
		return false

	grid.queue_free()
	print("[PASS] Test 4: Echo Suppression verified")
	return true

func test_mouse_motion_target_tracking() -> bool:
	print("[RUN] Test 5: Mouse Motion Updates Target Cell for Keyboard Shortcuts")
	var grid = GridManager.new()
	root.add_child(grid)
	grid.safe_zone_radius = 0

	# Reveal anchor cell at (0, 0)
	grid.set_mine_at(Vector2i(0, 0), false)
	grid.set_mine_at(Vector2i(1, 0), true)
	grid.reveal_cell(Vector2i(0, 0))

	# 1. Hover at cell (5, 5)
	grid._unhandled_input(_create_mouse_motion_event(Vector2(5 * 32 + 16, 5 * 32 + 16)))

	# 2. Move mouse to cell (0, 1) (valid adjacent cell)
	grid._unhandled_input(_create_mouse_motion_event(Vector2(16, 48)))

	# 3. Press F
	var f_press = _create_key_event("flag_cell", KEY_F, true, false)
	grid._unhandled_input(f_press)

	# (0, 1) should be flagged
	if not grid.get_cell(Vector2i(0, 1)).is_flagged:
		print("[FAIL] Cell (0, 1) was not flagged after mouse motion update")
		grid.queue_free()
		return false

	# (5, 5) should NOT be flagged
	if grid.grid_data.has(Vector2i(5, 5)) and grid.grid_data[Vector2i(5, 5)].is_flagged:
		print("[FAIL] Old mouse position (5, 5) was incorrectly flagged")
		grid.queue_free()
		return false

	grid.queue_free()
	print("[PASS] Test 5: Mouse Motion Target Tracking verified")
	return true

func test_keyboard_game_over_constraint() -> bool:
	print("[RUN] Test 6: Keyboard Actions Respect Game Over Constraint")
	var grid = GridManager.new()
	root.add_child(grid)
	grid.safe_zone_radius = 0
	grid.is_game_over = true

	# Hover at cell (0, 0)
	grid._unhandled_input(_create_mouse_motion_event(Vector2(16, 16)))

	# Press Space
	var space_event = _create_key_event("reveal_cell", KEY_SPACE, true, false)
	grid._unhandled_input(space_event)

	if grid.grid_data.has(Vector2i(0, 0)) and grid.grid_data[Vector2i(0, 0)].is_revealed:
		print("[FAIL] Space reveal succeeded while game was over")
		grid.queue_free()
		return false

	# Press F
	var f_event = _create_key_event("flag_cell", KEY_F, true, false)
	grid._unhandled_input(f_event)

	if grid.grid_data.has(Vector2i(0, 0)) and grid.grid_data[Vector2i(0, 0)].is_flagged:
		print("[FAIL] F flag toggle succeeded while game was over")
		grid.queue_free()
		return false

	grid.queue_free()
	print("[PASS] Test 6: Game Over Constraint verified")
	return true

func test_keyboard_chunk_and_frontier_restrictions() -> bool:
	print("[RUN] Test 7: Keyboard Actions Respect Locked Chunk and Frontier Adjacency Restrictions")
	var grid = GridManager.new()
	root.add_child(grid)
	grid.safe_zone_radius = 0

	# Reveal anchor at (0, 0)
	grid.set_mine_at(Vector2i(0, 0), false)
	grid.set_mine_at(Vector2i(1, 0), true)
	grid.reveal_cell(Vector2i(0, 0))

	# Case A: Frontier restriction on distant cell (10, 10)
	var distant_cell = Vector2i(10, 10)
	var distant_pos = Vector2(10 * 32 + 16, 10 * 32 + 16)
	grid._unhandled_input(_create_mouse_motion_event(distant_pos))

	# Try Space on distant cell
	grid._unhandled_input(_create_key_event("reveal_cell", KEY_SPACE, true, false))
	if grid.grid_data.has(distant_cell) and grid.grid_data[distant_cell].is_revealed:
		print("[FAIL] Distant unattached cell was revealed violating frontier restriction")
		grid.queue_free()
		return false

	# Try F on distant cell
	grid._unhandled_input(_create_key_event("flag_cell", KEY_F, true, false))
	if grid.grid_data.has(distant_cell) and grid.grid_data[distant_cell].is_flagged:
		print("[FAIL] Distant unattached cell was flagged violating frontier restriction")
		grid.queue_free()
		return false

	# Case B: Locked chunk restriction
	# Manually lock chunk (0, 0)
	var chunk_pos = Vector2i(0, 0)
	var chunk_data = grid.chunk_manager.get_chunk(chunk_pos)
	chunk_data.is_locked = true

	# Try to toggle flag on cell (0, 1) in locked chunk
	grid._unhandled_input(_create_mouse_motion_event(Vector2(16, 48)))
	grid._unhandled_input(_create_key_event("flag_cell", KEY_F, true, false))
	if grid.get_cell(Vector2i(0, 1)).is_flagged:
		print("[FAIL] Cell in locked chunk was flagged")
		grid.queue_free()
		return false

	grid.queue_free()
	print("[PASS] Test 7: Chunk and Frontier Restrictions verified")
	return true
