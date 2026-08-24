@tool
extends SceneTree

const GridManager = preload("res://scripts/grid_manager.gd")
const CellData = preload("res://scripts/cell_data.gd")

func _init():
	print("--- Running Test Suite: Gameplay Mechanics ---")
	var success = true

	# Test 1: Single Cell Reveal & Adjacent Reveal
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

	# Test 7: Adjacency Restrictions (Issue #25)
	if not test_adjacency_restrictions():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)

func test_reveal_single_cell() -> bool:
	print("[RUN] Test 1: Single Cell Reveal & Adjacent Reveal")
	var grid = GridManager.new()
	grid.safe_zone_radius = 0 # Only clear the single clicked cell to prevent wide BFS
	
	var pos = Vector2i(5, 5)
	# Surround pos with a mine at (4, 5) so pos has 1 neighbor mine and does not auto-reveal (5, 6)
	grid.set_mine_at(Vector2i(4, 5), true)
	grid.set_mine_at(Vector2i(5, 6), false)
	grid.set_mine_at(Vector2i(4, 6), true) # prevent (5, 6) from auto BFS

	var cell = grid.get_cell(pos)
	if cell.is_revealed:
		print("[FAIL] Cell should not be revealed initially")
		grid.free()
		return false

	# Initial reveal (first click) should succeed
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

	# Reveal an adjacent cell (5, 6)
	var adj_pos = Vector2i(5, 6)
	var adj_result = grid.reveal_cell(adj_pos)
	if not adj_result or not grid.get_cell(adj_pos).is_revealed:
		print("[FAIL] Adjacent cell reveal failed")
		grid.free()
		return false

	# Attempt to reveal a distant disconnected cell (50, 50)
	var distant_pos = Vector2i(50, 50)
	grid.set_mine_at(distant_pos, false)
	var distant_result = grid.reveal_cell(distant_pos)
	if distant_result or grid.get_cell(distant_pos).is_revealed:
		print("[FAIL] Distant non-adjacent cell reveal should be rejected")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 1: Single Cell Reveal verified")
	return true

func test_first_click_safety_integration() -> bool:
	print("[RUN] Test 2: First-Click Safety Integration")
	var grid = GridManager.new()
	grid.world_seed = 999

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
	grid.enable_chunk_lockout = false
	grid.safe_zone_radius = 0 # Only clear (0, 1)

	# Setup safe anchor cell at (0, 1) and mine at (0, 0)
	var anchor_pos = Vector2i(0, 1)
	var mine_pos = Vector2i(0, 0)

	grid.set_mine_at(mine_pos, true)
	grid.reveal_cell(anchor_pos) # First click anchor at (0, 1)
	grid.set_mine_at(mine_pos, true) # Ensure mine_pos is mine

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
	var other_pos = Vector2i(1, 1)
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

	# Clear a 5x5 region from (-2,-2) to (2,2) with no mines
	for x in range(-2, 3):
		for y in range(-2, 3):
			grid.set_mine_at(Vector2i(x, y), false)

	# Place a wall of mines at x = 3 from y = -3 to 3
	for y in range(-3, 4):
		grid.set_mine_at(Vector2i(3, y), true)

	# First reveal at (0, 0)
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

	# Mines at x=3 should NOT be revealed
	if grid.get_cell(Vector2i(3, 0)).is_revealed:
		print("[FAIL] Mine cell at (3, 0) was incorrectly revealed by BFS expansion")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 4: BFS Flood Fill zero-mine expansion verified")
	return true

func test_flag_toggling() -> bool:
	print("[RUN] Test 5: Flag Toggling Logic & Adjacency")
	var grid = GridManager.new()
	grid.safe_zone_radius = 0

	# 1. Flagging before first click should be blocked
	grid.toggle_flag(Vector2i(1, 1))
	if grid.get_cell(Vector2i(1, 1)).is_flagged:
		print("[FAIL] Flagging prior to first reveal should be prohibited")
		grid.free()
		return false

	# 2. First reveal at (0, 0)
	grid.set_mine_at(Vector2i(0, 0), false)
	# Surround (0, 0) with a mine at (1, 0) to avoid auto-revealing all neighbors via BFS
	grid.set_mine_at(Vector2i(1, 0), true)
	grid.reveal_cell(Vector2i(0, 0))

	# 3. Flagging a distant non-adjacent cell (10, 10) should be blocked
	grid.toggle_flag(Vector2i(10, 10))
	if grid.get_cell(Vector2i(10, 10)).is_flagged:
		print("[FAIL] Flagging distant non-adjacent cell should be prohibited")
		grid.free()
		return false

	# 4. Flagging an adjacent cell (0, 1) should succeed
	var adj_pos = Vector2i(0, 1)
	var flag_signal_data = {
		"received": false,
		"state": false
	}
	grid.connect("cell_flag_changed", func(p: Vector2i, is_flagged: bool):
		if p == adj_pos:
			flag_signal_data["received"] = true
			flag_signal_data["state"] = is_flagged
	)

	grid.toggle_flag(adj_pos)
	var adj_cell = grid.get_cell(adj_pos)
	if not adj_cell.is_flagged or not flag_signal_data["received"] or not flag_signal_data["state"]:
		print("[FAIL] Adjacent cell flag not enabled or signal not emitted")
		grid.free()
		return false

	# Try to reveal flagged cell - should fail and remain unrevealed
	var reveal_result = grid.reveal_cell(adj_pos)
	if reveal_result or adj_cell.is_revealed:
		print("[FAIL] Flagged cell was revealed by reveal_cell")
		grid.free()
		return false

	# Toggle OFF
	grid.toggle_flag(adj_pos)
	if adj_cell.is_flagged or flag_signal_data["state"] != false:
		print("[FAIL] Cell flag not disabled by second toggle")
		grid.free()
		return false

	# Cannot flag an already revealed cell (0, 0)
	grid.toggle_flag(Vector2i(0, 0))
	if grid.get_cell(Vector2i(0, 0)).is_flagged:
		print("[FAIL] Revealed cell was flagged")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 5: Flag toggling logic verified")
	return true

func test_chord_reveal() -> bool:
	print("[RUN] Test 6: Chord Reveal Logic")
	var grid = GridManager.new()
	grid.safe_zone_radius = 0

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

	# Case 2: Flag the mine cell (1, 0) (valid because (1, 0) is adjacent to revealed (0, 0))
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

func test_adjacency_restrictions() -> bool:
	print("[RUN] Test 7: Adjacency Restrictions for Reveals and Flags (Issue #25)")
	var grid = GridManager.new()
	grid.safe_zone_radius = 0

	# 1. has_revealed_neighbor helper validation
	var origin = Vector2i(20, 20)
	if grid.has_revealed_neighbor(origin):
		print("[FAIL] has_revealed_neighbor returned true when grid is empty")
		grid.free()
		return false

	# 2. Before first click, all flag attempts must be blocked
	grid.toggle_flag(Vector2i(10, 10))
	grid.toggle_flag(Vector2i(0, 0))
	if grid.get_cell(Vector2i(10, 10)).is_flagged or grid.get_cell(Vector2i(0, 0)).is_flagged:
		print("[FAIL] Flagging prior to first reveal must be blocked")
		grid.free()
		return false

	# 3. First click anywhere is allowed
	var first_click = Vector2i(5, 5)
	# Surround (5, 5) with a mine so it doesn't auto-expand all 8 neighbors immediately
	grid.set_mine_at(Vector2i(6, 5), true)
	var res1 = grid.reveal_cell(first_click)
	if not res1 or not grid.get_cell(first_click).is_revealed or not grid.has_first_clicked:
		print("[FAIL] First click reveal failed")
		grid.free()
		return false

	# 4. Distant reveals & flags are blocked
	var distant = Vector2i(100, 100)
	var distant_reveal = grid.reveal_cell(distant)
	if distant_reveal or grid.get_cell(distant).is_revealed:
		print("[FAIL] Distant reveal was allowed")
		grid.free()
		return false

	grid.toggle_flag(distant)
	if grid.get_cell(distant).is_flagged:
		print("[FAIL] Distant flag was allowed")
		grid.free()
		return false

	# 5. All 8-directional neighbors of (5, 5) satisfy adjacency
	var offsets = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1,  0),                  Vector2i(1,  0),
		Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)
	]

	for offset in offsets:
		var neighbor = first_click + offset
		if not grid.has_revealed_neighbor(neighbor):
			print("[FAIL] has_revealed_neighbor returned false for 8-way neighbor: ", neighbor)
			grid.free()
			return false

	# 6. Flag and unflag an adjacent neighbor
	var flag_target = first_click + Vector2i(0, 1)
	grid.toggle_flag(flag_target)
	if not grid.get_cell(flag_target).is_flagged:
		print("[FAIL] Flagging 8-way neighbor failed")
		grid.free()
		return false
	grid.toggle_flag(flag_target)
	if grid.get_cell(flag_target).is_flagged:
		print("[FAIL] Unflagging 8-way neighbor failed")
		grid.free()
		return false

	# 7. Reveal an adjacent safe neighbor
	var safe_neighbor = first_click + Vector2i(-1, 0)
	grid.set_mine_at(safe_neighbor, false)
	grid.set_mine_at(safe_neighbor + Vector2i(-1, 0), true) # prevent runaway BFS
	var reveal_adj = grid.reveal_cell(safe_neighbor)
	if not reveal_adj or not grid.get_cell(safe_neighbor).is_revealed:
		print("[FAIL] Revealing 8-way adjacent safe cell failed")
		grid.free()
		return false

	# 8. Frontier expansion: cell adjacent to newly revealed safe_neighbor (e.g. safe_neighbor + (-1, 0)) is now playable
	var next_frontier = safe_neighbor + Vector2i(-1, 0)
	if not grid.has_revealed_neighbor(next_frontier):
		print("[FAIL] Frontier neighbor should have revealed neighbor after adjacent reveal")
		grid.free()
		return false

	grid.toggle_flag(next_frontier)
	if not grid.get_cell(next_frontier).is_flagged:
		print("[FAIL] Flagging on expanded frontier failed")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 7: Adjacency Restrictions verified")
	return true

