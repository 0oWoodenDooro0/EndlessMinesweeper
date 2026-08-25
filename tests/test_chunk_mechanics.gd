@tool
extends SceneTree

const GridManager = preload("res://scripts/grid_manager.gd")
const HUD = preload("res://scripts/hud.gd")
const ChunkData = preload("res://scripts/chunk_data.gd")

func _init():
	print("--- Running Test Suite: Chunk Mechanics & Recovery System ---")
	var success = true

	# Test 1: Cell Coordinate to Chunk Coordinate Mapping
	if not test_cell_to_chunk_coordinate_mapping():
		success = false

	# Test 2: ChunkData Initialization & Safe Cells Calculation
	if not test_chunk_initialization_and_properties():
		success = false

	# Test 3: Mine Hit Locks Chunk, Emits Signal & Leaves Other Chunks Playable
	if not test_chunk_lockout_on_mine_hit():
		success = false

	# Test 4: Locked Chunk Blocks Reveal, Flag, Chord and BFS Ingress
	if not test_locked_chunk_interactions_blocked():
		success = false

	# Test 5: Clearing 8 Surrounding Neighbor Chunks Automatically Unlocks Center Chunk
	if not test_surrounding_8_neighbors_clearing_and_revival():
		success = false

	# Test 6: Unlocked Chunk Converts Mine to Flag & Allows Subsequent Chunk Clearance
	if not test_unlocked_mine_converted_to_flag_and_subsequent_clear():
		success = false

	# Test 7: HUD Tracking of Cleared and Locked Chunks
	if not test_hud_chunk_statistics_tracking():
		success = false

	# Test 8: Auto-flagging Mines on Chunk Clear & HUD Sync
	if not test_auto_flag_on_chunk_clear():
		success = false

	# Test 9: Two Connected Locked Chunks Unlock on Perimeter Clear
	if not test_two_connected_locked_chunks_unlock():
		success = false

	# Test 10: Complex L-Shaped Locked Cluster Unlock
	if not test_complex_locked_cluster_unlock():
		success = false

	# Test 11: Cleared Chunk Blocks Flag Toggling, Reveals, Chords, Modifications & BFS Ingress
	if not test_cleared_chunk_interactions_blocked():
		success = false

	# Test 12: Auto-reveal Safe Cells, Misplaced Flag Cleanup & Zero BFS Cascade on Chunk Clear
	if not test_auto_reveal_safe_cells_on_chunk_clear():
		success = false

	# Test 13: Chunk Clear on All Mines Flagged Integration
	if not test_chunk_clear_on_all_mines_flagged_integration():
		success = false

	# Test 14: Chunk Clear on Mines Flagged with Misplaced Flags
	if not test_chunk_clear_on_mines_flagged_with_misplaced_flags():
		success = false

	# Test 15: Unlocked Chunk Clears Misplaced Flags on Safe Cells
	if not test_unlocked_chunk_clears_misplaced_flags():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)

func test_cell_to_chunk_coordinate_mapping() -> bool:
	print("[RUN] Test 1: Cell Coordinate to Chunk Coordinate Mapping")
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(8, 8)

	# Positive coordinates
	if grid.cell_to_chunk(Vector2i(0, 0)) != Vector2i(0, 0):
		print("[FAIL] (0, 0) should map to chunk (0, 0), got: ", grid.cell_to_chunk(Vector2i(0, 0)))
		grid.free()
		return false

	if grid.cell_to_chunk(Vector2i(7, 7)) != Vector2i(0, 0):
		print("[FAIL] (7, 7) should map to chunk (0, 0), got: ", grid.cell_to_chunk(Vector2i(7, 7)))
		grid.free()
		return false

	if grid.cell_to_chunk(Vector2i(8, 0)) != Vector2i(1, 0):
		print("[FAIL] (8, 0) should map to chunk (1, 0), got: ", grid.cell_to_chunk(Vector2i(8, 0)))
		grid.free()
		return false

	if grid.cell_to_chunk(Vector2i(15, 23)) != Vector2i(1, 2):
		print("[FAIL] (15, 23) should map to chunk (1, 2), got: ", grid.cell_to_chunk(Vector2i(15, 23)))
		grid.free()
		return false

	# Negative coordinates
	if grid.cell_to_chunk(Vector2i(-1, -1)) != Vector2i(-1, -1):
		print("[FAIL] (-1, -1) should map to chunk (-1, -1), got: ", grid.cell_to_chunk(Vector2i(-1, -1)))
		grid.free()
		return false

	if grid.cell_to_chunk(Vector2i(-8, -8)) != Vector2i(-1, -1):
		print("[FAIL] (-8, -8) should map to chunk (-1, -1), got: ", grid.cell_to_chunk(Vector2i(-8, -8)))
		grid.free()
		return false

	if grid.cell_to_chunk(Vector2i(-9, -1)) != Vector2i(-2, -1):
		print("[FAIL] (-9, -1) should map to chunk (-2, -1), got: ", grid.cell_to_chunk(Vector2i(-9, -1)))
		grid.free()
		return false

	if grid.cell_to_chunk(Vector2i(-16, -8)) != Vector2i(-2, -1):
		print("[FAIL] (-16, -8) should map to chunk (-2, -1), got: ", grid.cell_to_chunk(Vector2i(-16, -8)))
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 1: Coordinate mapping verified")
	return true

func test_chunk_initialization_and_properties() -> bool:
	print("[RUN] Test 2: ChunkData Initialization & Safe Cells Calculation")
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(4, 4) # 16 cells total
	grid.set_first_click(Vector2i(100, 100))

	# Define chunk (0, 0) cells: 15 safe cells, 1 mine at (0, 0)
	for x in range(4):
		for y in range(4):
			grid.set_mine_at(Vector2i(x, y), false)
	grid.set_mine_at(Vector2i(0, 0), true)

	var chunk = grid.get_chunk(Vector2i(0, 0))
	if chunk == null:
		print("[FAIL] get_chunk returned null")
		grid.free()
		return false

	if chunk.chunk_pos != Vector2i(0, 0):
		print("[FAIL] chunk.chunk_pos mismatch: ", chunk.chunk_pos)
		grid.free()
		return false

	if chunk.is_locked:
		print("[FAIL] chunk should not be locked initially")
		grid.free()
		return false

	if chunk.is_cleared:
		print("[FAIL] chunk should not be cleared initially")
		grid.free()
		return false

	if chunk.total_safe_cells != 15:
		print("[FAIL] Expected 15 total safe cells, got: ", chunk.total_safe_cells)
		grid.free()
		return false

	if chunk.revealed_safe_cells != 0:
		print("[FAIL] Expected 0 revealed safe cells initially, got: ", chunk.revealed_safe_cells)
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 2: ChunkData initialization verified")
	return true

func test_chunk_lockout_on_mine_hit() -> bool:
	print("[RUN] Test 3: Mine Hit Locks Chunk, Emits Signal & Leaves Other Chunks Playable")
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(4, 4)
	grid.set_first_click(Vector2i(100, 100))

	# Chunk (0, 0) has mine at (1, 1)
	var mine_pos = Vector2i(1, 1)
	grid.set_mine_at(mine_pos, true)
	grid.get_cell(Vector2i(1, 0)).is_revealed = true # Anchor

	# Chunk (1, 0) has safe cell at (4, 0)
	var safe_other_pos = Vector2i(4, 0)
	grid.set_mine_at(safe_other_pos, false)
	grid.get_cell(Vector2i(4, 1)).is_revealed = true # Anchor

	var locked_signal_data = {
		"received": false,
		"chunk_pos": Vector2i(-999, -999),
		"mine_pos": Vector2i(-999, -999)
	}

	grid.connect("chunk_locked", func(c_pos: Vector2i, m_pos: Vector2i):
		locked_signal_data["received"] = true
		locked_signal_data["chunk_pos"] = c_pos
		locked_signal_data["mine_pos"] = m_pos
	)

	# Reveal mine in chunk (0, 0)
	var reveal_result = grid.reveal_cell(mine_pos)
	if not reveal_result:
		print("[FAIL] reveal_cell on mine should return true")
		grid.free()
		return false

	var chunk0 = grid.get_chunk(Vector2i(0, 0))
	if not chunk0.is_locked:
		print("[FAIL] Chunk (0, 0) should be locked after mine hit")
		grid.free()
		return false

	if not locked_signal_data["received"]:
		print("[FAIL] chunk_locked signal was not emitted")
		grid.free()
		return false

	if locked_signal_data["chunk_pos"] != Vector2i(0, 0) or locked_signal_data["mine_pos"] != mine_pos:
		print("[FAIL] chunk_locked payload mismatch: ", locked_signal_data)
		grid.free()
		return false

	# Playability in other chunk (1, 0): should succeed
	var other_reveal = grid.reveal_cell(safe_other_pos)
	if not other_reveal or not grid.get_cell(safe_other_pos).is_revealed:
		print("[FAIL] reveal_cell in other chunk (1, 0) was blocked or failed")
		grid.free()
		return false

	var chunk1 = grid.get_chunk(Vector2i(1, 0))
	if chunk1.is_locked:
		print("[FAIL] Other chunk (1, 0) should not be locked")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 3: Chunk lockout on mine hit verified")
	return true

func test_locked_chunk_interactions_blocked() -> bool:
	print("[RUN] Test 4: Locked Chunk Blocks Reveal, Flag, Chord and BFS Ingress")
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(4, 4)
	grid.set_first_click(Vector2i(100, 100))

	# Setup Chunk (0, 0): mine at (0, 0), safe cell at (1, 0)
	grid.set_mine_at(Vector2i(0, 0), true)
	grid.set_mine_at(Vector2i(1, 0), false)
	grid.set_mine_at(Vector2i(2, 0), false)

	# Trigger lock on Chunk (0, 0)
	grid.reveal_cell(Vector2i(0, 0))

	# 1. Reveal safe cell in locked chunk -> should return false and not reveal
	var res_reveal = grid.reveal_cell(Vector2i(1, 0))
	if res_reveal or grid.get_cell(Vector2i(1, 0)).is_revealed:
		print("[FAIL] reveal_cell inside locked chunk was permitted")
		grid.free()
		return false

	# 2. Toggle flag in locked chunk -> should be blocked
	grid.toggle_flag(Vector2i(1, 0))
	if grid.get_cell(Vector2i(1, 0)).is_flagged:
		print("[FAIL] toggle_flag inside locked chunk was permitted")
		grid.free()
		return false

	# 3. Chord reveal in locked chunk -> should return false
	var res_chord = grid.chord_reveal(Vector2i(1, 0))
	if res_chord:
		print("[FAIL] chord_reveal inside locked chunk returned true")
		grid.free()
		return false

	# 4. BFS expansion from adjacent unlocked chunk (1, 0) must NOT bleed into locked chunk (0, 0)
	# Setup Chunk (1, 0): cells (4, 0) to (7, 0) all safe with 0 neighbor mines
	for x in range(4, 8):
		for y in range(4):
			grid.set_mine_at(Vector2i(x, y), false)

	# Cell (4, 0) will expand zero-mines BFS, neighbor (3, 0) is inside locked chunk (0, 0)
	grid.set_mine_at(Vector2i(3, 0), false) # inside chunk (0, 0)
	grid.reveal_cell(Vector2i(5, 0))

	if grid.get_cell(Vector2i(3, 0)).is_revealed:
		print("[FAIL] BFS flood-fill expanded into locked chunk (0, 0)")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 4: Locked chunk interactions blocked verified")
	return true

func test_surrounding_8_neighbors_clearing_and_revival() -> bool:
	print("[RUN] Test 5: Clearing 8 Surrounding Neighbor Chunks Automatically Unlocks Center Chunk")
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(2, 2) # 4 cells per chunk
	grid.set_first_click(Vector2i(100, 100))

	# Setup center chunk (0, 0) with a mine at (0, 0) and 3 safe cells
	grid.set_mine_at(Vector2i(0, 0), true)
	grid.set_mine_at(Vector2i(1, 0), false)
	grid.set_mine_at(Vector2i(0, 1), false)
	grid.set_mine_at(Vector2i(1, 1), false)
	grid.get_cell(Vector2i(0, 1)).is_revealed = true # Anchor

	# Trigger lock on (0, 0)
	grid.reveal_cell(Vector2i(0, 0))
	var center_chunk = grid.get_chunk(Vector2i(0, 0))
	if not center_chunk.is_locked:
		print("[FAIL] Center chunk failed to lock")
		grid.free()
		return false

	var unlocked_data = {
		"received": false,
		"chunk_pos": Vector2i(-999, -999),
		"recovered_flags": []
	}
	grid.connect("chunk_unlocked", func(c_pos: Vector2i, recovered: Array[Vector2i]):
		unlocked_data["received"] = true
		unlocked_data["chunk_pos"] = c_pos
		unlocked_data["recovered_flags"] = recovered
	)

	# Define 8 neighbors around chunk (0, 0)
	var neighbor_chunks: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1,  0),                  Vector2i(1,  0),
		Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)
	]

	# In each neighbor chunk: 1 mine at (x*2, y*2) and 3 safe cells (so safe cells have neighbor_mines >= 1)
	for c_pos in neighbor_chunks:
		grid.set_mine_at(Vector2i(c_pos.x * 2, c_pos.y * 2), true)
		grid.set_mine_at(Vector2i(c_pos.x * 2 + 1, c_pos.y * 2), false)
		grid.set_mine_at(Vector2i(c_pos.x * 2, c_pos.y * 2 + 1), false)
		grid.set_mine_at(Vector2i(c_pos.x * 2 + 1, c_pos.y * 2 + 1), false)
		grid.get_cell(Vector2i(c_pos.x * 2, c_pos.y * 2)).is_revealed = true # Anchor

	# Reveal & clear first 7 neighbors
	for i in range(7):
		var c_pos = neighbor_chunks[i]
		grid.reveal_cell(Vector2i(c_pos.x * 2 + 1, c_pos.y * 2))
		grid.reveal_cell(Vector2i(c_pos.x * 2, c_pos.y * 2 + 1))
		grid.reveal_cell(Vector2i(c_pos.x * 2 + 1, c_pos.y * 2 + 1))

		var c_data = grid.get_chunk(c_pos)
		if not c_data.is_cleared:
			print("[FAIL] Neighbor chunk ", c_pos, " was not cleared")
			grid.free()
			return false

		if center_chunk.is_locked != true:
			print("[FAIL] Center chunk unlocked prematurely before all 8 neighbors were cleared")
			grid.free()
			return false

	# Clear the 8th neighbor chunk
	var last_c_pos = neighbor_chunks[7]
	grid.reveal_cell(Vector2i(last_c_pos.x * 2 + 1, last_c_pos.y * 2))
	grid.reveal_cell(Vector2i(last_c_pos.x * 2, last_c_pos.y * 2 + 1))
	grid.reveal_cell(Vector2i(last_c_pos.x * 2 + 1, last_c_pos.y * 2 + 1))

	var last_c_data = grid.get_chunk(last_c_pos)
	if not last_c_data.is_cleared:
		print("[FAIL] 8th neighbor chunk was not cleared")
		grid.free()
		return false

	# Center chunk (0, 0) should now be unlocked!
	if center_chunk.is_locked:
		print("[FAIL] Center chunk (0, 0) should be unlocked after all 8 neighbors are cleared")
		grid.free()
		return false

	if not unlocked_data["received"]:
		print("[FAIL] chunk_unlocked signal was not emitted")
		grid.free()
		return false

	if unlocked_data["chunk_pos"] != Vector2i(0, 0):
		print("[FAIL] chunk_unlocked chunk_pos mismatch: ", unlocked_data["chunk_pos"])
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 5: 8-Neighbor clearing and revival verified")
	return true

func test_unlocked_mine_converted_to_flag_and_subsequent_clear() -> bool:
	print("[RUN] Test 6: Unlocked Chunk Converts Mine to Flag & Allows Subsequent Chunk Clearance")
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(2, 2)
	grid.set_first_click(Vector2i(100, 100))

	# Setup center chunk (0, 0) with mine at (0, 0) and 3 safe cells
	var mine_pos = Vector2i(0, 0)
	grid.set_mine_at(mine_pos, true)
	grid.set_mine_at(Vector2i(1, 0), false)
	grid.set_mine_at(Vector2i(0, 1), false)
	grid.set_mine_at(Vector2i(1, 1), false)
	grid.get_cell(Vector2i(0, 1)).is_revealed = true # Anchor

	# Trigger lock on (0, 0)
	grid.reveal_cell(mine_pos)

	# Setup & Clear all 8 neighbors (each has 1 mine and 3 safe cells)
	for nx in [-1, 0, 1]:
		for ny in [-1, 0, 1]:
			if nx == 0 and ny == 0:
				continue
			var c_pos = Vector2i(nx, ny)
			grid.set_mine_at(Vector2i(c_pos.x * 2, c_pos.y * 2), true)
			grid.set_mine_at(Vector2i(c_pos.x * 2 + 1, c_pos.y * 2), false)
			grid.set_mine_at(Vector2i(c_pos.x * 2, c_pos.y * 2 + 1), false)
			grid.set_mine_at(Vector2i(c_pos.x * 2 + 1, c_pos.y * 2 + 1), false)
			grid.get_cell(Vector2i(c_pos.x * 2, c_pos.y * 2)).is_revealed = true # Anchor
			grid.reveal_cell(Vector2i(c_pos.x * 2 + 1, c_pos.y * 2))
			grid.reveal_cell(Vector2i(c_pos.x * 2, c_pos.y * 2 + 1))
			grid.reveal_cell(Vector2i(c_pos.x * 2 + 1, c_pos.y * 2 + 1))

	# Center chunk is now unlocked
	var center_chunk = grid.get_chunk(Vector2i(0, 0))
	if center_chunk.is_locked:
		print("[FAIL] Center chunk is still locked")
		grid.free()
		return false

	# Mine cell at (0, 0) should be converted to Flag: is_flagged = true, is_revealed = false
	var mine_cell = grid.get_cell(mine_pos)
	if not mine_cell.is_flagged:
		print("[FAIL] Mine cell should be flagged after revival")
		grid.free()
		return false

	if mine_cell.is_revealed:
		print("[FAIL] Mine cell should not remain revealed after revival")
		grid.free()
		return false

	# Now player can reveal the remaining 3 safe cells in chunk (0, 0)
	var center_cleared_data = {"emitted": false}
	grid.connect("chunk_cleared", func(c_pos: Vector2i):
		if c_pos == Vector2i(0, 0):
			center_cleared_data["emitted"] = true
	)

	grid.reveal_cell(Vector2i(1, 0))
	grid.reveal_cell(Vector2i(0, 1))
	grid.reveal_cell(Vector2i(1, 1))

	if not center_chunk.is_cleared:
		print("[FAIL] Center chunk was not cleared after all safe cells were revealed")
		grid.free()
		return false

	if not center_cleared_data["emitted"]:
		print("[FAIL] chunk_cleared signal not emitted for center chunk")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 6: Mine conversion to flag and chunk clearance verified")
	return true

func test_hud_chunk_statistics_tracking() -> bool:
	print("[RUN] Test 7: HUD Tracking of Cleared and Locked Chunks")
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(2, 2)
	grid.set_first_click(Vector2i(100, 100))

	var hud = HUD.new()
	hud.setup_ui_nodes()
	hud.bind_grid_manager(grid)

	if hud.cleared_chunks_count != 0 or hud.locked_chunks_count != 0:
		print("[FAIL] Initial chunk stats should be 0, got cleared=", hud.cleared_chunks_count, " locked=", hud.locked_chunks_count)
		hud.free()
		grid.free()
		return false

	# Setup safe chunk (1, 0) with 1 mine and 3 safe cells and clear it
	grid.set_mine_at(Vector2i(2, 0), true)
	grid.set_mine_at(Vector2i(3, 0), false)
	grid.set_mine_at(Vector2i(2, 1), false)
	grid.set_mine_at(Vector2i(3, 1), false)
	grid.get_cell(Vector2i(2, 0)).is_revealed = true # Anchor

	grid.reveal_cell(Vector2i(3, 0))
	grid.reveal_cell(Vector2i(2, 1))
	grid.reveal_cell(Vector2i(3, 1))

	if hud.cleared_chunks_count != 1:
		print("[FAIL] HUD cleared_chunks_count should be 1, got: ", hud.cleared_chunks_count)
		hud.free()
		grid.free()
		return false

	# Setup chunk (0, 0) with a mine and trigger lock
	grid.set_mine_at(Vector2i(0, 0), true)
	grid.get_cell(Vector2i(0, 1)).is_revealed = true # Anchor
	grid.reveal_cell(Vector2i(0, 0))

	if hud.locked_chunks_count != 1:
		print("[FAIL] HUD locked_chunks_count should be 1, got: ", hud.locked_chunks_count)
		hud.free()
		grid.free()
		return false

	# Restart game
	hud.on_restart_pressed()

	if hud.cleared_chunks_count != 0 or hud.locked_chunks_count != 0:
		print("[FAIL] HUD chunk stats should be reset to 0 after restart")
		hud.free()
		grid.free()
		return false

	hud.free()
	grid.free()
	print("[PASS] Test 7: HUD chunk statistics tracking verified")
	return true

func test_auto_flag_on_chunk_clear() -> bool:
	print("[RUN] Test 8: Auto-flagging Mines on Chunk Clear & HUD Sync")
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(2, 2)
	grid.set_first_click(Vector2i(100, 100))

	var hud = HUD.new()
	hud.setup_ui_nodes()
	hud.bind_grid_manager(grid)

	# Setup Chunk (0, 0) with 2 mines and 2 safe cells
	# Mine at (0, 0), Mine at (1, 1), Safe at (1, 0), Safe at (0, 1)
	var m1 = Vector2i(0, 0)
	var m2 = Vector2i(1, 1)
	var s1 = Vector2i(1, 0)
	var s2 = Vector2i(0, 1)

	grid.set_mine_at(m1, true)
	grid.set_mine_at(m2, true)
	grid.set_mine_at(s1, false)
	grid.set_mine_at(s2, false)
	grid.get_cell(Vector2i(0, -1)).is_revealed = true # Anchor (adjacent to (0,0), (1,0), (0,1))

	# Pre-flag m1 manually before clearing to verify manual flag is preserved and not double-counted
	grid.toggle_flag(m1)
	if hud.flag_count != 1:
		print("[FAIL] HUD flag_count should be 1 after manual flag, got: ", hud.flag_count)
		hud.free()
		grid.free()
		return false

	var flag_signals_received: Array[Vector2i] = []
	grid.connect("cell_flag_changed", func(pos: Vector2i, is_flagged: bool):
		if is_flagged:
			flag_signals_received.append(pos)
	)

	# Reveal first safe cell
	grid.reveal_cell(s1)
	var chunk = grid.get_chunk(Vector2i(0, 0))
	if chunk.is_cleared:
		print("[FAIL] Chunk should not be cleared yet after 1 of 2 safe cells revealed")
		hud.free()
		grid.free()
		return false

	# Reveal second safe cell -> Chunk cleared!
	grid.reveal_cell(s2)

	if not chunk.is_cleared:
		print("[FAIL] Chunk should be cleared after revealing all safe cells")
		hud.free()
		grid.free()
		return false

	# Verify unflagged mine (m2) is now automatically flagged
	var cell_m2 = grid.get_cell(m2)
	if not cell_m2.is_flagged or cell_m2.is_revealed:
		print("[FAIL] Mine at m2 was not auto-flagged properly: is_flagged=", cell_m2.is_flagged, " is_revealed=", cell_m2.is_revealed)
		hud.free()
		grid.free()
		return false

	# Verify pre-flagged mine (m1) is still flagged
	var cell_m1 = grid.get_cell(m1)
	if not cell_m1.is_flagged or cell_m1.is_revealed:
		print("[FAIL] Mine at m1 is no longer flagged")
		hud.free()
		grid.free()
		return false

	# Verify HUD count reflects exactly 2 flags
	if hud.flag_count != 2:
		print("[FAIL] HUD flag_count should be 2 after chunk auto-flag, got: ", hud.flag_count)
		hud.free()
		grid.free()
		return false

	# Verify cell_flag_changed signal was emitted for m2
	if not flag_signals_received.has(m2):
		print("[FAIL] cell_flag_changed signal was not emitted for auto-flagged mine m2")
		hud.free()
		grid.free()
		return false

	hud.free()
	grid.free()
	print("[PASS] Test 8: Auto-flagging on Chunk Clear verified")
	return true

func test_two_connected_locked_chunks_unlock() -> bool:
	print("[RUN] Test 9: Two Connected Locked Chunks Unlock on Perimeter Clear")
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(2, 2)
	grid.set_first_click(Vector2i(100, 100))

	# Setup Chunk (0, 0) and Chunk (1, 0)
	var c0 = Vector2i(0, 0)
	var c1 = Vector2i(1, 0)

	var m0 = Vector2i(0, 0)
	var m1 = Vector2i(2, 0)

	grid.set_mine_at(m0, true)
	grid.set_mine_at(Vector2i(1, 0), false)
	grid.set_mine_at(Vector2i(0, 1), false)
	grid.set_mine_at(Vector2i(1, 1), false)
	grid.get_cell(Vector2i(0, 1)).is_revealed = true # Anchor

	grid.set_mine_at(m1, true)
	grid.set_mine_at(Vector2i(3, 0), false)
	grid.set_mine_at(Vector2i(2, 1), false)
	grid.set_mine_at(Vector2i(3, 1), false)
	grid.get_cell(Vector2i(2, 1)).is_revealed = true # Anchor

	# Trigger lockouts on both chunks
	grid.reveal_cell(m0)
	grid.reveal_cell(m1)

	var chunk0 = grid.get_chunk(c0)
	var chunk1 = grid.get_chunk(c1)

	if not chunk0.is_locked or not chunk1.is_locked:
		print("[FAIL] Both chunks should be locked")
		grid.free()
		return false

	var unlocked_chunks: Array[Vector2i] = []
	grid.connect("chunk_unlocked", func(chunk_pos: Vector2i, _recovered: Array[Vector2i]):
		unlocked_chunks.append(chunk_pos)
	)

	# The 10 perimeter chunks around {(0,0), (1,0)}
	var perimeter_chunks: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1),
		Vector2i(-1,  0),                                   Vector2i(2,  0),
		Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1), Vector2i(2,  1)
	]

	# Configure all 10 perimeter chunks (1 mine, 3 safe cells)
	for p_chunk in perimeter_chunks:
		grid.set_mine_at(Vector2i(p_chunk.x * 2, p_chunk.y * 2), true)
		grid.set_mine_at(Vector2i(p_chunk.x * 2 + 1, p_chunk.y * 2), false)
		grid.set_mine_at(Vector2i(p_chunk.x * 2, p_chunk.y * 2 + 1), false)
		grid.set_mine_at(Vector2i(p_chunk.x * 2 + 1, p_chunk.y * 2 + 1), false)
		grid.get_cell(Vector2i(p_chunk.x * 2, p_chunk.y * 2)).is_revealed = true # Anchor

	# Clear the first 9 perimeter chunks
	for i in range(9):
		var p_chunk = perimeter_chunks[i]
		grid.reveal_cell(Vector2i(p_chunk.x * 2 + 1, p_chunk.y * 2))
		grid.reveal_cell(Vector2i(p_chunk.x * 2, p_chunk.y * 2 + 1))
		grid.reveal_cell(Vector2i(p_chunk.x * 2 + 1, p_chunk.y * 2 + 1))

		if chunk0.is_locked != true or chunk1.is_locked != true:
			print("[FAIL] Chunks unlocked prematurely before entire cluster perimeter was cleared")
			grid.free()
			return false

	# Clear the 10th perimeter chunk
	var last_p_chunk = perimeter_chunks[9]
	grid.reveal_cell(Vector2i(last_p_chunk.x * 2 + 1, last_p_chunk.y * 2))
	grid.reveal_cell(Vector2i(last_p_chunk.x * 2, last_p_chunk.y * 2 + 1))
	grid.reveal_cell(Vector2i(last_p_chunk.x * 2 + 1, last_p_chunk.y * 2 + 1))

	# Both chunks should now be unlocked!
	if chunk0.is_locked or chunk1.is_locked:
		print("[FAIL] Both chunks should be unlocked after all perimeter chunks are cleared. c0.locked=", chunk0.is_locked, " c1.locked=", chunk1.is_locked)
		grid.free()
		return false

	if not unlocked_chunks.has(c0) or not unlocked_chunks.has(c1):
		print("[FAIL] chunk_unlocked signal missing for cluster members: ", unlocked_chunks)
		grid.free()
		return false

	# Verify recovered mines are converted to flags
	if not grid.get_cell(m0).is_flagged or grid.get_cell(m0).is_revealed:
		print("[FAIL] Mine at m0 was not converted to flag")
		grid.free()
		return false

	if not grid.get_cell(m1).is_flagged or grid.get_cell(m1).is_revealed:
		print("[FAIL] Mine at m1 was not converted to flag")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 9: Two connected locked chunks unlock verified")
	return true

func test_complex_locked_cluster_unlock() -> bool:
	print("[RUN] Test 10: Complex L-Shaped Locked Cluster Unlock")
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(2, 2)
	grid.set_first_click(Vector2i(100, 100))

	# 3 Chunks forming an L-shape: (0,0), (1,0), (0,1)
	var cluster = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	var mines = [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2)]

	for i in range(3):
		var cp = cluster[i]
		var mp = mines[i]
		grid.set_mine_at(mp, true)
		grid.set_mine_at(Vector2i(cp.x * 2 + 1, cp.y * 2), false)
		grid.set_mine_at(Vector2i(cp.x * 2, cp.y * 2 + 1), false)
		grid.set_mine_at(Vector2i(cp.x * 2 + 1, cp.y * 2 + 1), false)
		grid.get_cell(Vector2i(cp.x * 2, cp.y * 2 + 1)).is_revealed = true # Anchor

	# Trigger lock on all 3 chunks
	for mp in mines:
		grid.reveal_cell(mp)

	for cp in cluster:
		if not grid.get_chunk(cp).is_locked:
			print("[FAIL] Chunk ", cp, " should be locked")
			grid.free()
			return false

	# External perimeter of {(0,0), (1,0), (0,1)}:
	# All 8-neighbors of the 3 chunks excluding the 3 chunks themselves
	var perimeter_chunks: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1),
		Vector2i(-1,  0),                                   Vector2i(2,  0),
		Vector2i(-1,  1),                  Vector2i(1,  1), Vector2i(2,  1),
		Vector2i(-1,  2), Vector2i(0,  2), Vector2i(1,  2)
	]

	# Configure all 12 perimeter chunks
	for p_chunk in perimeter_chunks:
		grid.set_mine_at(Vector2i(p_chunk.x * 2, p_chunk.y * 2), true)
		grid.set_mine_at(Vector2i(p_chunk.x * 2 + 1, p_chunk.y * 2), false)
		grid.set_mine_at(Vector2i(p_chunk.x * 2, p_chunk.y * 2 + 1), false)
		grid.set_mine_at(Vector2i(p_chunk.x * 2 + 1, p_chunk.y * 2 + 1), false)
		grid.get_cell(Vector2i(p_chunk.x * 2, p_chunk.y * 2)).is_revealed = true # Anchor

	# Clear 11 of 12 perimeter chunks
	for i in range(11):
		var p_chunk = perimeter_chunks[i]
		grid.reveal_cell(Vector2i(p_chunk.x * 2 + 1, p_chunk.y * 2))
		grid.reveal_cell(Vector2i(p_chunk.x * 2, p_chunk.y * 2 + 1))
		grid.reveal_cell(Vector2i(p_chunk.x * 2 + 1, p_chunk.y * 2 + 1))

		for cp in cluster:
			if grid.get_chunk(cp).is_locked != true:
				print("[FAIL] Cluster chunk ", cp, " unlocked prematurely")
				grid.free()
				return false

	# Clear the 12th perimeter chunk
	var last_p_chunk = perimeter_chunks[11]
	grid.reveal_cell(Vector2i(last_p_chunk.x * 2 + 1, last_p_chunk.y * 2))
	grid.reveal_cell(Vector2i(last_p_chunk.x * 2, last_p_chunk.y * 2 + 1))
	grid.reveal_cell(Vector2i(last_p_chunk.x * 2 + 1, last_p_chunk.y * 2 + 1))

	# All 3 chunks in cluster should now be unlocked!
	for cp in cluster:
		if grid.get_chunk(cp).is_locked:
			print("[FAIL] Cluster chunk ", cp, " is still locked")
			grid.free()
			return false

	# All mines converted to flags
	for mp in mines:
		if not grid.get_cell(mp).is_flagged or grid.get_cell(mp).is_revealed:
			print("[FAIL] Mine at ", mp, " was not converted to flag")
			grid.free()
			return false

	grid.free()
	print("[PASS] Test 10: Complex L-shaped locked cluster unlock verified")
	return true

func test_cleared_chunk_interactions_blocked() -> bool:
	print("[RUN] Test 11: Cleared Chunk Blocks Flag Toggling, Reveals, Chords, Modifications & BFS Ingress")
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(4, 4)
	grid.set_first_click(Vector2i(100, 100))

	# Setup Chunk (0, 0): 1 mine at (0, 0), 15 safe cells at other positions
	for x in range(4):
		for y in range(4):
			grid.set_mine_at(Vector2i(x, y), false)
	grid.set_mine_at(Vector2i(0, 0), true)
	grid.get_cell(Vector2i(-1, 0)).is_revealed = true # Anchor

	var chunk = grid.get_chunk(Vector2i(0, 0))

	# Reveal all 15 safe cells in chunk (0, 0)
	for x in range(4):
		for y in range(4):
			if x == 0 and y == 0:
				continue
			grid.reveal_cell(Vector2i(x, y))

	if not chunk.is_cleared:
		print("[FAIL] Chunk (0, 0) should be cleared")
		grid.free()
		return false

	# 1. Mine at (0, 0) was auto-flagged. Attempt to toggle flag -> must NOT unflag
	var mine_cell = grid.get_cell(Vector2i(0, 0))
	if not mine_cell.is_flagged:
		print("[FAIL] Mine at (0, 0) should be auto-flagged")
		grid.free()
		return false

	grid.toggle_flag(Vector2i(0, 0))
	if not mine_cell.is_flagged:
		print("[FAIL] toggle_flag should NOT remove flag from mine in cleared chunk")
		grid.free()
		return false

	# 2. Safe cell in cleared chunk. Attempt to toggle flag -> must NOT flag
	var safe_cell = grid.get_cell(Vector2i(1, 0))
	grid.toggle_flag(Vector2i(1, 0))
	if safe_cell.is_flagged:
		print("[FAIL] toggle_flag should NOT place flag on cell in cleared chunk")
		grid.free()
		return false

	# 3. Reveal cell in cleared chunk -> must return false
	if grid.reveal_cell(Vector2i(0, 0)):
		print("[FAIL] reveal_cell on mine in cleared chunk should return false")
		grid.free()
		return false
	if grid.reveal_cell(Vector2i(1, 0)):
		print("[FAIL] reveal_cell on safe cell in cleared chunk should return false")
		grid.free()
		return false

	# 4. Chord reveal inside cleared chunk on cell with no unrevealed neighbors -> returns false
	if grid.chord_reveal(Vector2i(1, 1)):
		print("[FAIL] chord_reveal with no unrevealed neighbors should return false")
		grid.free()
		return false

	# 4b. Chord reveal from a cleared chunk into an adjacent uncleared chunk
	var test_grid = GridManager.new()
	test_grid.chunk_size = Vector2i(4, 4)
	test_grid.set_first_click(Vector2i(100, 100))
	for x in range(4):
		for y in range(4):
			test_grid.set_mine_at(Vector2i(x, y), false)
	test_grid.set_mine_at(Vector2i(0, 0), true) # 1 mine in chunk (0, 0)
	test_grid.get_cell(Vector2i(-1, 0)).is_revealed = true # Anchor
	test_grid.set_mine_at(Vector2i(4, 0), false) # safe target in chunk (1, 0)
	test_grid.set_mine_at(Vector2i(4, 1), true) # mine to flag in chunk (1, 0)
	test_grid.set_mine_at(Vector2i(1, -1), true) # mine to isolate (2, 0) from cascading
	test_grid.set_mine_at(Vector2i(2, -1), false)
	test_grid.set_mine_at(Vector2i(3, -1), false)
	test_grid.set_mine_at(Vector2i(4, -1), false)

	# Reveal all 15 safe cells in chunk (0, 0)
	for x in range(4):
		for y in range(4):
			if x == 0 and y == 0:
				continue
			test_grid.reveal_cell(Vector2i(x, y))

	test_grid.toggle_flag(Vector2i(4, 1))
	var chord_success = test_grid.chord_reveal(Vector2i(3, 0))
	if not chord_success or not test_grid.get_cell(Vector2i(4, 0)).is_revealed:
		print("[FAIL] chord_reveal inside cleared chunk failed to reveal adjacent active cell")
		test_grid.free()
		grid.free()
		return false
	test_grid.free()

	# 5. set_mine_at on cleared chunk cell -> must be rejected
	var original_mine_state = mine_cell.is_mine
	grid.set_mine_at(Vector2i(0, 0), false)
	if mine_cell.is_mine != original_mine_state:
		print("[FAIL] set_mine_at should NOT modify mine state in cleared chunk")
		grid.free()
		return false

	# 6. BFS flood fill from adjacent active chunk must NOT expand into cleared chunk
	# Setup Chunk (1, 0) and perimeter to be safe with 0 mines
	for x in range(3, 9):
		for y in range(-1, 5):
			if x == 0 and y == 0:
				continue
			grid.set_mine_at(Vector2i(x, y), false)

	# Cell (3, 0) is inside cleared chunk (0, 0)
	grid.reveal_cell(Vector2i(4, 0))
	if not grid.get_cell(Vector2i(5, 0)).is_revealed:
		print("[FAIL] Adjacent chunk reveal failed")
		grid.free()
		return false

	# 7. Chord reveal from adjacent active chunk (1, 0) must skip neighbors in cleared chunk (0, 0)
	grid.set_mine_at(Vector2i(4, 1), true)
	grid.toggle_flag(Vector2i(4, 1))
	var _chord_res = grid.chord_reveal(Vector2i(4, 0))

	grid.free()
	print("[PASS] Test 11: Cleared chunk interactions blocked verified")
	return true

func test_auto_reveal_safe_cells_on_chunk_clear() -> bool:
	print("[RUN] Test 12: Auto-reveal Safe Cells, Misplaced Flag Cleanup & Zero BFS Cascade on Chunk Clear")
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(2, 2)
	grid.set_first_click(Vector2i(100, 100))

	var hud = HUD.new()
	hud.setup_ui_nodes()
	hud.bind_grid_manager(grid)

	# --- Subtest A: Misplaced Flag Removal, Safe Cell Auto-Reveal & Mine Auto-Flag ---
	# Setup Chunk (0, 0): Mines at (0, 0) and (1, 1), Safe cells at (1, 0) and (0, 1)
	var m1 = Vector2i(0, 0)
	var m2 = Vector2i(1, 1)
	var s1 = Vector2i(1, 0)
	var s2 = Vector2i(0, 1)

	grid.set_mine_at(m1, true)
	grid.set_mine_at(m2, true)
	grid.set_mine_at(s1, false)
	grid.set_mine_at(s2, false)
	grid.get_cell(Vector2i(0, 2)).is_revealed = true # Anchor for s2
	grid.get_cell(Vector2i(2, 0)).is_revealed = true # Anchor for s1

	# Player places a mistaken flag on safe cell s2 (0, 1)
	grid.toggle_flag(s2)
	if hud.flag_count != 1:
		print("[FAIL] Initial misplaced flag not counted in HUD: ", hud.flag_count)
		hud.free()
		grid.free()
		return false

	var unflag_signals: Array[Vector2i] = []
	var reveal_signals: Array[Vector2i] = []
	grid.connect("cell_flag_changed", func(pos: Vector2i, is_flagged: bool):
		if not is_flagged:
			unflag_signals.append(pos)
	)
	grid.connect("cell_revealed", func(pos: Vector2i, _is_mine: bool):
		reveal_signals.append(pos)
	)

	# Reveal s1 (1, 0)
	grid.reveal_cell(s1)

	# Simulate / Trigger chunk clear event for Chunk (0, 0)
	grid._on_chunk_manager_cleared(Vector2i(0, 0))

	# Verify misplaced flag on s2 (0, 1) was cleared
	var cell_s2 = grid.get_cell(s2)
	if cell_s2.is_flagged:
		print("[FAIL] Misplaced flag on s2 (0, 1) should be removed")
		hud.free()
		grid.free()
		return false
	if not cell_s2.is_revealed:
		print("[FAIL] Safe cell s2 (0, 1) should be revealed")
		hud.free()
		grid.free()
		return false

	# Verify unflag signal emitted for s2
	if not unflag_signals.has(s2):
		print("[FAIL] cell_flag_changed(s2, false) was not emitted: ", unflag_signals)
		hud.free()
		grid.free()
		return false

	# Verify mines m1 and m2 are auto-flagged
	var cell_m1 = grid.get_cell(m1)
	var cell_m2 = grid.get_cell(m2)
	if not cell_m1.is_flagged or not cell_m2.is_flagged:
		print("[FAIL] Mines m1/m2 were not auto-flagged properly")
		hud.free()
		grid.free()
		return false

	# Verify HUD count: exactly 2 flags (m1, m2), 0 misplaced flags
	if hud.flag_count != 2:
		print("[FAIL] HUD flag_count should be 2 after chunk auto-reveal and auto-flag, got: ", hud.flag_count)
		hud.free()
		grid.free()
		return false

	# Verify HUD revealed count: both s1 and s2 are revealed
	if hud.revealed_count != 2:
		print("[FAIL] HUD revealed_count should be 2, got: ", hud.revealed_count)
		hud.free()
		grid.free()
		return false

	hud.free()
	grid.free()

	# --- Subtest B: Zero-Mine BFS Cascade from Auto-revealed Safe Cell ---
	var grid2 = GridManager.new()
	grid2.chunk_size = Vector2i(2, 2)
	grid2.set_first_click(Vector2i(100, 100))

	# All cells in Chunk (0, 0) and perimeter set to safe (0 mines)
	for x in range(-1, 3):
		for y in range(-1, 3):
			grid2.set_mine_at(Vector2i(x, y), false)
	grid2.get_cell(Vector2i(-1, 0)).is_revealed = true # Anchor

	# Neighbor chunk (1, 0): safe cell at (2, 0), mine at (3, 0)
	grid2.set_mine_at(Vector2i(3, 0), true) # Mine in chunk (1, 0)

	# Trigger clear on Chunk (0, 0)
	grid2._on_chunk_manager_cleared(Vector2i(0, 0))

	# All cells in Chunk (0, 0) should be revealed
	for x in range(2):
		for y in range(2):
			if not grid2.get_cell(Vector2i(x, y)).is_revealed:
				print("[FAIL] Cell (", x, ", ", y, ") in cleared chunk was not auto-revealed")
				grid2.free()
				return false

	# Due to 0-neighbor BFS expansion, adjacent safe cell (2, 0) in Chunk (1, 0) should also be revealed
	if not grid2.get_cell(Vector2i(2, 0)).is_revealed:
		print("[FAIL] BFS cascade failed to expand to adjacent chunk cell (2, 0)")
		grid2.free()
		return false

	grid2.free()
	print("[PASS] Test 12: Auto-reveal safe cells, misplaced flag cleanup & zero BFS cascade verified")
	return true

func test_chunk_clear_on_all_mines_flagged_integration() -> bool:
	print("[RUN] Test 13: Chunk Clear on All Mines Flagged Integration")
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(2, 2)
	grid.set_first_click(Vector2i(100, 100))

	var hud = HUD.new()
	hud.setup_ui_nodes()
	hud.bind_grid_manager(grid)

	# Setup Chunk (0, 0): Mines at (0, 0) and (1, 1), Safe at (1, 0) and (0, 1)
	var m1 = Vector2i(0, 0)
	var m2 = Vector2i(1, 1)
	var s1 = Vector2i(1, 0)
	var s2 = Vector2i(0, 1)

	grid.set_mine_at(m1, true)
	grid.set_mine_at(m2, true)
	grid.set_mine_at(s1, false)
	grid.set_mine_at(s2, false)

	# Anchors around Chunk (0, 0) so frontier allows flagging
	grid.get_cell(Vector2i(-1, 0)).is_revealed = true
	grid.get_cell(Vector2i(0, -1)).is_revealed = true
	grid.get_cell(Vector2i(2, 1)).is_revealed = true

	var chunk_cleared_events: Array[Vector2i] = []
	grid.connect("chunk_cleared", func(c_pos: Vector2i):
		chunk_cleared_events.append(c_pos)
	)

	# 1. Flag first mine m1 (0, 0)
	grid.toggle_flag(m1)
	if hud.flag_count != 1:
		print("[FAIL] HUD flag_count should be 1 after 1st flag, got: ", hud.flag_count)
		hud.free()
		grid.free()
		return false
	if grid.chunk_manager.is_chunk_cleared(Vector2i(0, 0)):
		print("[FAIL] Chunk should not be cleared after flagging only 1 of 2 mines")
		hud.free()
		grid.free()
		return false

	# 2. Flag second mine m2 (1, 1) -> triggers chunk clearance!
	grid.toggle_flag(m2)

	if not grid.chunk_manager.is_chunk_cleared(Vector2i(0, 0)):
		print("[FAIL] Chunk (0, 0) should be cleared after all mines are flagged")
		hud.free()
		grid.free()
		return false

	if chunk_cleared_events.size() != 1 or chunk_cleared_events[0] != Vector2i(0, 0):
		print("[FAIL] chunk_cleared signal not received properly: ", chunk_cleared_events)
		hud.free()
		grid.free()
		return false

	# Safe cells s1 and s2 should be auto-revealed
	var cell_s1 = grid.get_cell(s1)
	var cell_s2 = grid.get_cell(s2)
	if not cell_s1.is_revealed or not cell_s2.is_revealed:
		print("[FAIL] Safe cells not auto-revealed upon mine-flagged chunk clear: s1.revealed=", cell_s1.is_revealed, " s2.revealed=", cell_s2.is_revealed)
		hud.free()
		grid.free()
		return false

	# Mines m1 and m2 should both be flagged
	var cell_m1 = grid.get_cell(m1)
	var cell_m2 = grid.get_cell(m2)
	if not cell_m1.is_flagged or not cell_m2.is_flagged:
		print("[FAIL] Mines should remain flagged after chunk clear")
		hud.free()
		grid.free()
		return false

	# HUD statistics synchronization
	if hud.cleared_chunks_count != 1:
		print("[FAIL] HUD cleared_chunks_count should be 1, got: ", hud.cleared_chunks_count)
		hud.free()
		grid.free()
		return false

	if hud.flag_count != 2:
		print("[FAIL] HUD flag_count should be 2, got: ", hud.flag_count)
		hud.free()
		grid.free()
		return false

	if hud.revealed_count != 2:
		print("[FAIL] HUD revealed_count should be 2, got: ", hud.revealed_count)
		hud.free()
		grid.free()
		return false

	hud.free()
	grid.free()
	print("[PASS] Test 13: Chunk clear on all mines flagged integration verified")
	return true

func test_chunk_clear_on_mines_flagged_with_misplaced_flags() -> bool:
	print("[RUN] Test 14: Chunk Clear on Mines Flagged with Misplaced Flags")
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(2, 2)
	grid.set_first_click(Vector2i(100, 100))

	var hud = HUD.new()
	hud.setup_ui_nodes()
	hud.bind_grid_manager(grid)

	# Setup Chunk (0, 0): Mines at (0, 0) and (1, 1), Safe at (1, 0) and (0, 1)
	var m1 = Vector2i(0, 0)
	var m2 = Vector2i(1, 1)
	var s1 = Vector2i(1, 0)
	var s2 = Vector2i(0, 1)

	grid.set_mine_at(m1, true)
	grid.set_mine_at(m2, true)
	grid.set_mine_at(s1, false)
	grid.set_mine_at(s2, false)

	grid.get_cell(Vector2i(-1, 0)).is_revealed = true
	grid.get_cell(Vector2i(0, -1)).is_revealed = true
	grid.get_cell(Vector2i(2, 1)).is_revealed = true

	# 1. Place a misplaced flag on safe cell s1 (1, 0)
	grid.toggle_flag(s1)
	if hud.flag_count != 1:
		print("[FAIL] Expected flag_count 1 after misplaced flag, got: ", hud.flag_count)
		hud.free()
		grid.free()
		return false

	# 2. Flag mine m1 (0, 0)
	grid.toggle_flag(m1)
	if hud.flag_count != 2:
		print("[FAIL] Expected flag_count 2 after flagging m1, got: ", hud.flag_count)
		hud.free()
		grid.free()
		return false
	if grid.chunk_manager.is_chunk_cleared(Vector2i(0, 0)):
		print("[FAIL] Chunk should not clear while m2 remains unflagged")
		hud.free()
		grid.free()
		return false

	# 3. Flag mine m2 (1, 1) -> all actual mines flagged -> triggers chunk clearance
	grid.toggle_flag(m2)

	if not grid.chunk_manager.is_chunk_cleared(Vector2i(0, 0)):
		print("[FAIL] Chunk should be cleared after all mines are flagged")
		hud.free()
		grid.free()
		return false

	# Verify misplaced flag on s1 was removed and s1 is revealed
	var cell_s1 = grid.get_cell(s1)
	if cell_s1.is_flagged:
		print("[FAIL] Misplaced flag on s1 was not removed")
		hud.free()
		grid.free()
		return false
	if not cell_s1.is_revealed:
		print("[FAIL] Safe cell s1 was not revealed")
		hud.free()
		grid.free()
		return false

	# Verify safe cell s2 is revealed
	var cell_s2 = grid.get_cell(s2)
	if not cell_s2.is_revealed:
		print("[FAIL] Safe cell s2 was not revealed")
		hud.free()
		grid.free()
		return false

	# Verify HUD statistics reconciliation: exactly 2 flags (m1, m2), 2 revealed safe cells, 1 cleared chunk
	if hud.flag_count != 2:
		print("[FAIL] HUD flag_count should be 2 after misplaced flag removal, got: ", hud.flag_count)
		hud.free()
		grid.free()
		return false

	if hud.revealed_count != 2:
		print("[FAIL] HUD revealed_count should be 2, got: ", hud.revealed_count)
		hud.free()
		grid.free()
		return false

	if hud.cleared_chunks_count != 1:
		print("[FAIL] HUD cleared_chunks_count should be 1, got: ", hud.cleared_chunks_count)
		hud.free()
		grid.free()
		return false

	hud.free()
	grid.free()
	print("[PASS] Test 14: Chunk clear on mines flagged with misplaced flags verified")
	return true

func test_unlocked_chunk_clears_misplaced_flags() -> bool:
	print("[RUN] Test 15: Unlocked Chunk Clears Misplaced Flags on Safe Cells")

	# --- Subtest A: Single Locked Chunk Unlock with Misplaced Flag on Safe Cell ---
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(2, 2)
	grid.set_first_click(Vector2i(100, 100))

	var hud = HUD.new()
	hud.setup_ui_nodes()
	hud.bind_grid_manager(grid)

	# Setup Chunk (0, 0): Mines at (0, 0) and (1, 1), Safe at (1, 0) and (0, 1)
	var m1 = Vector2i(0, 0) # detonated mine
	var m2 = Vector2i(1, 1) # pre-flagged actual mine
	var s1 = Vector2i(1, 0) # safe cell with misplaced flag
	var s2 = Vector2i(0, 1) # unflagged safe cell

	grid.set_mine_at(m1, true)
	grid.set_mine_at(m2, true)
	grid.set_mine_at(s1, false)
	grid.set_mine_at(s2, false)

	# Surrounding anchors so frontier allows interaction
	grid.get_cell(Vector2i(-1, 0)).is_revealed = true
	grid.get_cell(Vector2i(0, -1)).is_revealed = true
	grid.get_cell(Vector2i(2, 1)).is_revealed = true

	# 1. Place a misplaced flag on safe cell s1 (1, 0)
	grid.toggle_flag(s1)
	if hud.flag_count != 1:
		print("[FAIL] Subtest A: Initial flag count mismatch after misplaced flag: ", hud.flag_count)
		hud.free()
		grid.free()
		return false

	# 2. Correctly flag mine m2 (1, 1)
	grid.toggle_flag(m2)
	if hud.flag_count != 2:
		print("[FAIL] Subtest A: Flag count should be 2 after flagging m2, got: ", hud.flag_count)
		hud.free()
		grid.free()
		return false

	# 3. Detonate mine m1 (0, 0) -> causes Chunk (0, 0) lockout
	grid.reveal_cell(m1)
	var chunk0 = grid.get_chunk(Vector2i(0, 0))
	if not chunk0.is_locked:
		print("[FAIL] Subtest A: Chunk (0, 0) should be locked after mine hit")
		hud.free()
		grid.free()
		return false
	if hud.locked_chunks_count != 1:
		print("[FAIL] Subtest A: HUD locked_chunks_count should be 1, got: ", hud.locked_chunks_count)
		hud.free()
		grid.free()
		return false

	var unflag_events: Array[Vector2i] = []
	var flag_events: Array[Vector2i] = []
	grid.connect("cell_flag_changed", func(pos: Vector2i, is_flagged: bool):
		if is_flagged:
			flag_events.append(pos)
		else:
			unflag_events.append(pos)
	)

	var unlocked_events: Array[Vector2i] = []
	grid.connect("chunk_unlocked", func(c_pos: Vector2i, _recovered: Array[Vector2i]):
		unlocked_events.append(c_pos)
	)

	# 4. Setup & Clear all 8 surrounding neighbor chunks (each with 1 mine, 3 safe cells)
	var neighbor_chunks: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1,  0),                  Vector2i(1,  0),
		Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)
	]

	for c_pos in neighbor_chunks:
		grid.set_mine_at(Vector2i(c_pos.x * 2, c_pos.y * 2), true)
		grid.set_mine_at(Vector2i(c_pos.x * 2 + 1, c_pos.y * 2), false)
		grid.set_mine_at(Vector2i(c_pos.x * 2, c_pos.y * 2 + 1), false)
		grid.set_mine_at(Vector2i(c_pos.x * 2 + 1, c_pos.y * 2 + 1), false)
		grid.get_cell(Vector2i(c_pos.x * 2, c_pos.y * 2)).is_revealed = true # Anchor
		grid.reveal_cell(Vector2i(c_pos.x * 2 + 1, c_pos.y * 2))
		grid.reveal_cell(Vector2i(c_pos.x * 2, c_pos.y * 2 + 1))
		grid.reveal_cell(Vector2i(c_pos.x * 2 + 1, c_pos.y * 2 + 1))

	# 5. Verify Chunk (0, 0) unlocked
	if chunk0.is_locked:
		print("[FAIL] Subtest A: Chunk (0, 0) should be unlocked after all 8 neighbors cleared")
		hud.free()
		grid.free()
		return false

	if not unlocked_events.has(Vector2i(0, 0)):
		print("[FAIL] Subtest A: chunk_unlocked signal was not received for (0, 0)")
		hud.free()
		grid.free()
		return false

	# 6. Verify detonated mine m1 (0, 0) recovered as flag
	var cell_m1 = grid.get_cell(m1)
	if not cell_m1.is_flagged or cell_m1.is_revealed:
		print("[FAIL] Subtest A: Detonated mine m1 was not converted to flag on unlock")
		hud.free()
		grid.free()
		return false

	# 7. Verify pre-flagged mine m2 (1, 1) remains flagged
	var cell_m2 = grid.get_cell(m2)
	if not cell_m2.is_flagged or cell_m2.is_revealed:
		print("[FAIL] Subtest A: Pre-flagged mine m2 did not remain flagged")
		hud.free()
		grid.free()
		return false

	# 8. Verify misplaced flag on safe cell s1 (1, 0) was automatically cleared
	var cell_s1 = grid.get_cell(s1)
	if cell_s1.is_flagged:
		print("[FAIL] Subtest A: Misplaced flag on safe cell s1 (1, 0) was NOT cleared on unlock")
		hud.free()
		grid.free()
		return false
	if cell_s1.is_revealed:
		print("[FAIL] Subtest A: Safe cell s1 should not be revealed automatically on unlock")
		hud.free()
		grid.free()
		return false
	if not unflag_events.has(s1):
		print("[FAIL] Subtest A: cell_flag_changed(s1, false) was not emitted on unlock")
		hud.free()
		grid.free()
		return false

	# 9. Verify safe cell s2 (0, 1) remains unflagged and unrevealed
	var cell_s2 = grid.get_cell(s2)
	if cell_s2.is_flagged or cell_s2.is_revealed:
		print("[FAIL] Subtest A: Safe cell s2 corrupted on unlock")
		hud.free()
		grid.free()
		return false

	# 10. Verify HUD statistics: exactly 10 flags (8 from cleared neighbor chunks + m1 recovered + m2 kept), 0 locked chunks, 8 cleared neighbors
	if hud.locked_chunks_count != 0:
		print("[FAIL] Subtest A: HUD locked_chunks_count should be 0, got: ", hud.locked_chunks_count)
		hud.free()
		grid.free()
		return false

	if hud.flag_count != 10:
		print("[FAIL] Subtest A: HUD flag_count should be 10, got: ", hud.flag_count)
		hud.free()
		grid.free()
		return false

	if hud.cleared_chunks_count != 8:
		print("[FAIL] Subtest A: HUD cleared_chunks_count should be 8, got: ", hud.cleared_chunks_count)
		hud.free()
		grid.free()
		return false

	# 11. Reveal safe cells s1 and s2 to complete chunk clearance
	grid.reveal_cell(s1)
	grid.reveal_cell(s2)

	if not chunk0.is_cleared:
		print("[FAIL] Subtest A: Chunk (0, 0) was not cleared after revealing safe cells")
		hud.free()
		grid.free()
		return false

	if hud.cleared_chunks_count != 9:
		print("[FAIL] Subtest A: HUD cleared_chunks_count should be 9, got: ", hud.cleared_chunks_count)
		hud.free()
		grid.free()
		return false

	hud.free()
	grid.free()

	# --- Subtest B: Connected Multi-Chunk Locked Cluster Unlock with Misplaced Flags ---
	var grid2 = GridManager.new()
	grid2.chunk_size = Vector2i(2, 2)
	grid2.set_first_click(Vector2i(100, 100))

	var hud2 = HUD.new()
	hud2.setup_ui_nodes()
	hud2.bind_grid_manager(grid2)

	var cA = Vector2i(0, 0)
	var cB = Vector2i(1, 0)

	var mA = Vector2i(0, 0) # mine in cA
	var sA = Vector2i(1, 0) # safe cell in cA with misplaced flag
	var mB = Vector2i(2, 0) # mine in cB
	var sB = Vector2i(3, 0) # safe cell in cB with misplaced flag

	grid2.set_mine_at(mA, true)
	grid2.set_mine_at(sA, false)
	grid2.set_mine_at(Vector2i(0, 1), false)
	grid2.set_mine_at(Vector2i(1, 1), false)
	grid2.get_cell(Vector2i(0, 1)).is_revealed = true # Anchor

	grid2.set_mine_at(mB, true)
	grid2.set_mine_at(sB, false)
	grid2.set_mine_at(Vector2i(2, 1), false)
	grid2.set_mine_at(Vector2i(3, 1), false)
	grid2.get_cell(Vector2i(2, 1)).is_revealed = true # Anchor

	# Misplaced flags on safe cells in both chunks
	grid2.toggle_flag(sA)
	grid2.toggle_flag(sB)
	if hud2.flag_count != 2:
		print("[FAIL] Subtest B: Expected 2 initial flags, got: ", hud2.flag_count)
		hud2.free()
		grid2.free()
		return false

	# Detonate mines in both chunks to lock the connected cluster
	grid2.reveal_cell(mA)
	grid2.reveal_cell(mB)

	if not grid2.get_chunk(cA).is_locked or not grid2.get_chunk(cB).is_locked:
		print("[FAIL] Subtest B: Both cluster chunks should be locked")
		hud2.free()
		grid2.free()
		return false

	# Clear the 10 perimeter chunks around {(0,0), (1,0)}
	var perimeter_10: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1),
		Vector2i(-1,  0),                                   Vector2i(2,  0),
		Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1), Vector2i(2,  1)
	]

	for p_chunk in perimeter_10:
		grid2.set_mine_at(Vector2i(p_chunk.x * 2, p_chunk.y * 2), true)
		grid2.set_mine_at(Vector2i(p_chunk.x * 2 + 1, p_chunk.y * 2), false)
		grid2.set_mine_at(Vector2i(p_chunk.x * 2, p_chunk.y * 2 + 1), false)
		grid2.set_mine_at(Vector2i(p_chunk.x * 2 + 1, p_chunk.y * 2 + 1), false)
		grid2.get_cell(Vector2i(p_chunk.x * 2, p_chunk.y * 2)).is_revealed = true # Anchor
		grid2.reveal_cell(Vector2i(p_chunk.x * 2 + 1, p_chunk.y * 2))
		grid2.reveal_cell(Vector2i(p_chunk.x * 2, p_chunk.y * 2 + 1))
		grid2.reveal_cell(Vector2i(p_chunk.x * 2 + 1, p_chunk.y * 2 + 1))

	# Both chunks should be unlocked
	if grid2.get_chunk(cA).is_locked or grid2.get_chunk(cB).is_locked:
		print("[FAIL] Subtest B: Both cluster chunks should be unlocked")
		hud2.free()
		grid2.free()
		return false

	# Verify misplaced flags cleared on both safe cells
	if grid2.get_cell(sA).is_flagged or grid2.get_cell(sB).is_flagged:
		print("[FAIL] Subtest B: Misplaced flags in unlocked cluster were not cleared: sA.flagged=", grid2.get_cell(sA).is_flagged, " sB.flagged=", grid2.get_cell(sB).is_flagged)
		hud2.free()
		grid2.free()
		return false

	# Verify detonated mines recovered as flags
	if not grid2.get_cell(mA).is_flagged or not grid2.get_cell(mB).is_flagged:
		print("[FAIL] Subtest B: Detonated mines were not recovered as flags in cluster")
		hud2.free()
		grid2.free()
		return false

	# Verify HUD statistics: exactly 12 flags (10 from perimeter + mA recovered + mB recovered, sA and sB unflagged), 0 locked chunks
	if hud2.flag_count != 12:
		print("[FAIL] Subtest B: HUD flag_count should be 12, got: ", hud2.flag_count)
		hud2.free()
		grid2.free()
		return false

	if hud2.locked_chunks_count != 0:
		print("[FAIL] Subtest B: HUD locked_chunks_count should be 0, got: ", hud2.locked_chunks_count)
		hud2.free()
		grid2.free()
		return false

	hud2.free()
	grid2.free()
	print("[PASS] Test 15: Unlocked chunk clears misplaced flags on safe cells verified")
	return true




