@tool
extends SceneTree

const GridManager = preload("res://scripts/grid_manager.gd")
const CellData = preload("res://scripts/cell_data.gd")

func _init():
	print("--- Running Test Suite: Gameplay Mechanics ---")
	var success = true

	# Test 1: Single Cell Reveal & Flagged Protection
	if not test_reveal_single_cell():
		success = false

	# Test 2: First-Click Safety Integration
	if not test_first_click_safety_integration():
		success = false

	# Test 3: Mine Explosion & Game Over Trigger
	if not test_mine_explosion_game_over():
		success = false

	# Test 4: BFS Flood Fill Zero-Mine Expansion
	if not test_bfs_flood_fill():
		success = false

	# Test 5: Flag Toggling Logic
	if not test_flag_toggling():
		success = false

	# Test 6: Chord Reveal Logic
	if not test_chord_reveal():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)

func test_reveal_single_cell() -> bool:
	print("[RUN] Test 1: Single Cell Reveal & Flagged Protection")
	var grid = GridManager.new()
	grid.set_first_click(Vector2i(100, 100)) # prevent random first-click reset
	
	var pos = Vector2i(5, 5)
	grid.set_mine_at(pos, false)
	
	var cell = grid.get_cell(pos)
	if cell.is_revealed:
		print("[FAIL] Cell should not be revealed initially")
		grid.free()
		return false

	var result = grid.reveal_cell(pos)
	if not result or not cell.is_revealed:
		print("[FAIL] Cell was not revealed by reveal_cell()")
		grid.free()
		return false

	# Reveal again should return false (no action)
	var second_result = grid.reveal_cell(pos)
	if second_result:
		print("[FAIL] Revealing already revealed cell should return false")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 1: Single Cell Reveal verified")
	return true

func test_first_click_safety_integration() -> bool:
	print("[RUN] Test 2: First-Click Safety Integration")
	var grid = GridManager.new()
	grid.world_seed = 999
	grid.mine_density = 0.5 # High density to guarantee mines everywhere normally

	var first_pos = Vector2i(10, 10)
	if grid.has_first_clicked:
		print("[FAIL] Grid should not have first_clicked initially")
		grid.free()
		return false

	grid.reveal_cell(first_pos)

	if not grid.has_first_clicked:
		print("[FAIL] reveal_cell should set has_first_clicked to true")
		grid.free()
		return false

	if grid.first_click_pos != first_pos:
		print("[FAIL] first_click_pos mismatch")
		grid.free()
		return false

	# Check safe zone 3x3
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var p = first_pos + Vector2i(dx, dy)
			if grid.get_cell(p).is_mine:
				print("[FAIL] Mine found in first-click safe zone at ", p)
				grid.free()
				return false

	grid.free()
	print("[PASS] Test 2: First-click safety integration verified")
	return true

func test_mine_explosion_game_over() -> bool:
	print("[RUN] Test 3: Mine Explosion & Game Over Trigger")
	var grid = GridManager.new()
	grid.set_first_click(Vector2i(100, 100))

	var mine_pos = Vector2i(0, 0)
	grid.set_mine_at(mine_pos, true)

	var signal_data = {
		"received": false,
		"pos": Vector2i(-999, -999)
	}
	grid.connect("game_over", func(pos: Vector2i):
		signal_data["received"] = true
		signal_data["pos"] = pos
	)

	grid.reveal_cell(mine_pos)

	if not grid.is_game_over:
		print("[FAIL] is_game_over should be true after hitting mine")
		grid.free()
		return false

	if not signal_data["received"] or signal_data["pos"] != mine_pos:
		print("[FAIL] game_over signal not emitted or pos mismatch")
		grid.free()
		return false

	# Attempts to reveal other cells during game over should be blocked
	var other_pos = Vector2i(2, 2)
	grid.set_mine_at(other_pos, false)
	var reveal_after_game_over = grid.reveal_cell(other_pos)
	if reveal_after_game_over or grid.get_cell(other_pos).is_revealed:
		print("[FAIL] reveal_cell allowed action when is_game_over is true")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 3: Mine explosion & Game Over trigger verified")
	return true

func test_bfs_flood_fill() -> bool:
	print("[RUN] Test 4: BFS Flood Fill Zero-Mine Expansion")
	var grid = GridManager.new()
	grid.set_first_click(Vector2i(100, 100))

	# Clear a 5x5 region from (-2,-2) to (2,2) with no mines
	for x in range(-2, 3):
		for y in range(-2, 3):
			grid.set_mine_at(Vector2i(x, y), false)

	# Place a wall of mines at x = 3 from y = -3 to 3
	for y in range(-3, 4):
		grid.set_mine_at(Vector2i(3, y), true)

	# Place a flag at Vector2i(0, 1) within zero region to test flag protection in BFS
	grid.toggle_flag(Vector2i(0, 1))

	# Reveal origin Vector2i(0, 0) which has 0 neighbor mines
	grid.reveal_cell(Vector2i(0, 0))

	# Vector2i(0, 0) should be revealed
	if not grid.get_cell(Vector2i(0, 0)).is_revealed:
		print("[FAIL] Origin cell not revealed")
		grid.free()
		return false

	# Vector2i(1, 0) should be revealed (0 neighbor mines or border number cell)
	if not grid.get_cell(Vector2i(1, 0)).is_revealed:
		print("[FAIL] Adjacent cell (1, 0) not revealed by BFS")
		grid.free()
		return false

	# Flagged cell (0, 1) should remain unrevealed and flagged
	var flagged_cell = grid.get_cell(Vector2i(0, 1))
	if flagged_cell.is_revealed or not flagged_cell.is_flagged:
		print("[FAIL] Flagged cell was incorrectly revealed by BFS expansion")
		grid.free()
		return false

	# Mines at x=3 should NOT be revealed
	if grid.get_cell(Vector2i(3, 0)).is_revealed:
		print("[FAIL] Mine cell at (3, 0) was incorrectly revealed by BFS expansion")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 4: BFS Flood Fill zero-mine expansion verified")
	return true

func test_flag_toggling() -> bool:
	print("[RUN] Test 5: Flag Toggling Logic")
	var grid = GridManager.new()
	grid.set_first_click(Vector2i(100, 100))

	var pos = Vector2i(1, 1)
	grid.set_mine_at(pos, false)
	var cell = grid.get_cell(pos)

	var flag_signal_data = {
		"received": false,
		"state": false
	}
	grid.connect("cell_flag_changed", func(p: Vector2i, is_flagged: bool):
		if p == pos:
			flag_signal_data["received"] = true
			flag_signal_data["state"] = is_flagged
	)

	# Toggle ON
	grid.toggle_flag(pos)
	if not cell.is_flagged or not flag_signal_data["received"] or not flag_signal_data["state"]:
		print("[FAIL] Cell flag not enabled or signal not emitted")
		grid.free()
		return false

	# Try to reveal flagged cell - should fail and remain unrevealed
	var reveal_result = grid.reveal_cell(pos)
	if reveal_result or cell.is_revealed:
		print("[FAIL] Flagged cell was revealed by reveal_cell")
		grid.free()
		return false

	# Toggle OFF
	grid.toggle_flag(pos)
	if cell.is_flagged or flag_signal_data["state"] != false:
		print("[FAIL] Cell flag not disabled by second toggle")
		grid.free()
		return false

	# Cannot flag an already revealed cell
	grid.reveal_cell(pos)
	grid.toggle_flag(pos)
	if cell.is_flagged:
		print("[FAIL] Revealed cell was flagged")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 5: Flag toggling logic verified")
	return true

func test_chord_reveal() -> bool:
	print("[RUN] Test 6: Chord Reveal Logic")
	var grid = GridManager.new()
	grid.set_first_click(Vector2i(100, 100))

	# Setup target cell (0, 0) with exactly 1 mine neighbor at (1, 0)
	var target = Vector2i(0, 0)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			grid.set_mine_at(target + Vector2i(dx, dy), false)

	var mine_pos = Vector2i(1, 0)
	grid.set_mine_at(mine_pos, true)

	grid.reveal_cell(target) # Target is revealed, has 1 neighbor mine

	# Case 1: Chord with 0 flags (neighbor flags = 0, neighbor mines = 1 -> mismatch)
	var chord_res1 = grid.chord_reveal(target)
	if chord_res1:
		print("[FAIL] Chord succeeded when neighbor flags (0) != neighbor mines (1)")
		grid.free()
		return false
	if grid.get_cell(Vector2i(-1, 0)).is_revealed:
		print("[FAIL] Cells revealed on mismatched chord")
		grid.free()
		return false

	# Case 2: Flag the mine cell (1, 0)
	grid.toggle_flag(mine_pos)

	# Case 3: Chord with 1 flag (neighbor flags = 1, neighbor mines = 1 -> match!)
	var chord_res2 = grid.chord_reveal(target)
	if not chord_res2:
		print("[FAIL] Chord failed when neighbor flags == neighbor mines")
		grid.free()
		return false

	# Verify all other 7 neighbors are revealed
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var n = target + Vector2i(dx, dy)
			if n == target:
				continue
			var c = grid.get_cell(n)
			if n == mine_pos:
				if not c.is_flagged or c.is_revealed:
					print("[FAIL] Flagged mine cell was affected during chord")
					grid.free()
					return false
			else:
				if not c.is_revealed:
					print("[FAIL] Neighbor cell ", n, " was not revealed by chord")
					grid.free()
					return false

	grid.free()
	print("[PASS] Test 6: Chord reveal logic verified")
	return true
