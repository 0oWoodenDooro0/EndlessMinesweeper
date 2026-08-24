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

	# Chunk (1, 0) has safe cell at (4, 0)
	var safe_other_pos = Vector2i(4, 0)
	grid.set_mine_at(safe_other_pos, false)

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
	grid.mine_density = 1.0 # High density so outer unconfigured cells are mines (no unwanted BFS)
	grid.set_first_click(Vector2i(100, 100))

	# Setup center chunk (0, 0) with a mine at (0, 0) and 3 safe cells
	grid.set_mine_at(Vector2i(0, 0), true)
	grid.set_mine_at(Vector2i(1, 0), false)
	grid.set_mine_at(Vector2i(0, 1), false)
	grid.set_mine_at(Vector2i(1, 1), false)

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
	grid.mine_density = 1.0 # High density so outer unconfigured cells are mines (no unwanted BFS)
	grid.set_first_click(Vector2i(100, 100))

	# Setup center chunk (0, 0) with mine at (0, 0) and 3 safe cells
	var mine_pos = Vector2i(0, 0)
	grid.set_mine_at(mine_pos, true)
	grid.set_mine_at(Vector2i(1, 0), false)
	grid.set_mine_at(Vector2i(0, 1), false)
	grid.set_mine_at(Vector2i(1, 1), false)

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
