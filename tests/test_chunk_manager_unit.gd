@tool
extends SceneTree

const ChunkManager = preload("res://scripts/chunk_manager.gd")
const ChunkData = preload("res://scripts/chunk_data.gd")

func _init():
	print("--- Running Test Suite: ChunkManager Deep Module Unit Tests ---")
	var success = true

	# Test 1: Cell Coordinate to Chunk Coordinate Mapping
	if not test_cell_to_chunk_coordinate_mapping():
		success = false

	# Test 2: ChunkData Initialization, Safe Cells & Progress Calculation
	if not test_chunk_safe_cells_and_progress_calculation():
		success = false

	# Test 3: Single Chunk Lockout Lifecycle on Mine Reveal
	if not test_single_chunk_lockout_lifecycle():
		success = false

	# Test 4: Chunk Clearance & Auto-Flag Coordinate Extraction
	if not test_chunk_clearance_and_auto_flag_extraction():
		success = false

	# Test 5: Surrounding 8-Neighbor Cluster Revival
	if not test_surrounding_8_neighbor_cluster_revival():
		success = false

	# Test 6: Multi-Chunk Connected Cluster Revival (2-chunk & L-shaped 3-chunk)
	if not test_multi_chunk_connected_cluster_revival():
		success = false

	# Test 7: Chunk State Serialization & Deserialization
	if not test_chunk_manager_serialization_and_deserialization():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL CHUNK MANAGER UNIT TESTS PASSED")
		quit(0)
	else:
		print("SOME CHUNK MANAGER UNIT TESTS FAILED")
		quit(1)

func test_cell_to_chunk_coordinate_mapping() -> bool:
	print("[RUN] Test 1: Cell Coordinate to Chunk Coordinate Mapping")
	var cm = ChunkManager.new()
	cm.setup(Vector2i(8, 8))

	# Positive coordinates
	if cm.cell_to_chunk(Vector2i(0, 0)) != Vector2i(0, 0):
		print("[FAIL] (0, 0) should map to chunk (0, 0), got: ", cm.cell_to_chunk(Vector2i(0, 0)))
		return false
	if cm.cell_to_chunk(Vector2i(7, 7)) != Vector2i(0, 0):
		print("[FAIL] (7, 7) should map to chunk (0, 0), got: ", cm.cell_to_chunk(Vector2i(7, 7)))
		return false
	if cm.cell_to_chunk(Vector2i(8, 0)) != Vector2i(1, 0):
		print("[FAIL] (8, 0) should map to chunk (1, 0), got: ", cm.cell_to_chunk(Vector2i(8, 0)))
		return false
	if cm.cell_to_chunk(Vector2i(15, 23)) != Vector2i(1, 2):
		print("[FAIL] (15, 23) should map to chunk (1, 2), got: ", cm.cell_to_chunk(Vector2i(15, 23)))
		return false

	# Negative coordinates
	if cm.cell_to_chunk(Vector2i(-1, -1)) != Vector2i(-1, -1):
		print("[FAIL] (-1, -1) should map to chunk (-1, -1), got: ", cm.cell_to_chunk(Vector2i(-1, -1)))
		return false
	if cm.cell_to_chunk(Vector2i(-8, -8)) != Vector2i(-1, -1):
		print("[FAIL] (-8, -8) should map to chunk (-1, -1), got: ", cm.cell_to_chunk(Vector2i(-8, -8)))
		return false
	if cm.cell_to_chunk(Vector2i(-9, -1)) != Vector2i(-2, -1):
		print("[FAIL] (-9, -1) should map to chunk (-2, -1), got: ", cm.cell_to_chunk(Vector2i(-9, -1)))
		return false
	if cm.cell_to_chunk(Vector2i(-16, -8)) != Vector2i(-2, -1):
		print("[FAIL] (-16, -8) should map to chunk (-2, -1), got: ", cm.cell_to_chunk(Vector2i(-16, -8)))
		return false

	# Non-square chunk size (4, 8)
	cm.setup(Vector2i(4, 8))
	if cm.cell_to_chunk(Vector2i(4, 7)) != Vector2i(1, 0):
		print("[FAIL] (4, 7) with chunk_size (4,8) should map to (1, 0), got: ", cm.cell_to_chunk(Vector2i(4, 7)))
		return false
	if cm.cell_to_chunk(Vector2i(3, 8)) != Vector2i(0, 1):
		print("[FAIL] (3, 8) with chunk_size (4,8) should map to (0, 1), got: ", cm.cell_to_chunk(Vector2i(3, 8)))
		return false

	print("[PASS] Test 1: Coordinate mapping verified")
	return true

func test_chunk_safe_cells_and_progress_calculation() -> bool:
	print("[RUN] Test 2: ChunkData Initialization, Safe Cells & Progress Calculation")
	var mines: Dictionary = {
		Vector2i(0, 0): true,
		Vector2i(1, 1): true
	}
	var is_mine_cb = func(pos: Vector2i) -> bool:
		return mines.get(pos, false)

	var revealed_cells: Dictionary = {}
	var is_revealed_cb = func(pos: Vector2i) -> bool:
		return revealed_cells.get(pos, false)

	var cm = ChunkManager.new()
	cm.setup(Vector2i(4, 4), is_mine_cb, is_revealed_cb)

	var chunk = cm.get_chunk(Vector2i(0, 0))
	if chunk == null:
		print("[FAIL] get_chunk returned null")
		return false

	# Chunk has 16 cells, 2 mines -> 14 safe cells
	if chunk.total_safe_cells != 14:
		print("[FAIL] Expected 14 safe cells, got: ", chunk.total_safe_cells)
		return false
	if chunk.revealed_safe_cells != 0:
		print("[FAIL] Expected 0 revealed safe cells initially, got: ", chunk.revealed_safe_cells)
		return false
	if not is_equal_approx(chunk.get_progress(), 0.0):
		print("[FAIL] Expected 0.0 progress, got: ", chunk.get_progress())
		return false

	# Reveal 7 safe cells
	chunk.revealed_safe_cells = 7
	if not is_equal_approx(chunk.get_progress(), 0.5):
		print("[FAIL] Expected 0.5 progress, got: ", chunk.get_progress())
		return false

	# Modify mines and recalculate
	mines[Vector2i(2, 2)] = true # now 3 mines -> 13 safe cells
	cm.recalculate_chunk_safe_cells(Vector2i(0, 0))
	if chunk.total_safe_cells != 13:
		print("[FAIL] Expected 13 safe cells after recalculation, got: ", chunk.total_safe_cells)
		return false

	print("[PASS] Test 2: Safe cells and progress calculation verified")
	return true

func test_single_chunk_lockout_lifecycle() -> bool:
	print("[RUN] Test 3: Single Chunk Lockout Lifecycle on Mine Reveal")
	var mines: Dictionary = {Vector2i(1, 1): true}
	var is_mine_cb = func(pos: Vector2i) -> bool:
		return mines.get(pos, false)

	var cm = ChunkManager.new()
	cm.setup(Vector2i(4, 4), is_mine_cb)

	var locked_signals: Array[Dictionary] = []
	cm.chunk_locked.connect(func(c_pos: Vector2i, m_pos: Vector2i):
		locked_signals.append({"chunk_pos": c_pos, "mine_pos": m_pos})
	)

	# 1. Reveal safe cell at (0, 0)
	var res_safe = cm.register_reveal(Vector2i(0, 0), false)
	if res_safe.get("action") != "revealed":
		print("[FAIL] Expected 'revealed' action for safe cell, got: ", res_safe)
		return false
	if cm.is_chunk_locked(Vector2i(0, 0)):
		print("[FAIL] Chunk should not be locked after safe reveal")
		return false

	# 2. Reveal mine at (1, 1) with lockout enabled
	var res_mine = cm.register_reveal(Vector2i(1, 1), true, true)
	if res_mine.get("action") != "locked":
		print("[FAIL] Expected 'locked' action for mine hit, got: ", res_mine)
		return false
	if not cm.is_chunk_locked(Vector2i(0, 0)):
		print("[FAIL] Chunk (0, 0) should be locked after mine hit")
		return false
	if not cm.is_cell_in_locked_chunk(Vector2i(2, 2)):
		print("[FAIL] is_cell_in_locked_chunk should return true for cells in chunk (0, 0)")
		return false
	if cm.is_cell_in_locked_chunk(Vector2i(5, 5)):
		print("[FAIL] is_cell_in_locked_chunk should return false for adjacent unlocked chunk (1, 1)")
		return false

	if locked_signals.size() != 1:
		print("[FAIL] Expected 1 chunk_locked signal, got: ", locked_signals.size())
		return false
	if locked_signals[0]["chunk_pos"] != Vector2i(0, 0) or locked_signals[0]["mine_pos"] != Vector2i(1, 1):
		print("[FAIL] chunk_locked signal payload mismatch: ", locked_signals[0])
		return false

	# 3. Verify chunk.locked_mine_positions contains the mine
	var chunk = cm.get_chunk(Vector2i(0, 0))
	if not chunk.locked_mine_positions.has(Vector2i(1, 1)):
		print("[FAIL] chunk.locked_mine_positions should contain (1, 1)")
		return false

	print("[PASS] Test 3: Single chunk lockout lifecycle verified")
	return true

func test_chunk_clearance_and_auto_flag_extraction() -> bool:
	print("[RUN] Test 4: Chunk Clearance & Auto-Flag Coordinate Extraction")
	var mines: Dictionary = {
		Vector2i(0, 0): true,
		Vector2i(1, 1): true
	}
	var is_mine_cb = func(pos: Vector2i) -> bool:
		return mines.get(pos, false)

	var cm = ChunkManager.new()
	cm.setup(Vector2i(2, 2), is_mine_cb) # 4 cells: (0,0)[mine], (1,1)[mine], (1,0)[safe], (0,1)[safe]

	var cleared_signals: Array[Vector2i] = []
	cm.chunk_cleared.connect(func(c_pos: Vector2i):
		cleared_signals.append(c_pos)
	)

	# Reveal 1st safe cell: (1, 0)
	var res1 = cm.register_reveal(Vector2i(1, 0), false)
	if res1.get("action") != "revealed":
		print("[FAIL] 1st reveal should have action 'revealed', got: ", res1)
		return false
	if cm.is_chunk_cleared(Vector2i(0, 0)):
		print("[FAIL] Chunk should not be cleared after 1 of 2 safe cells revealed")
		return false

	# Reveal 2nd safe cell: (0, 1) -> Chunk cleared!
	var res2 = cm.register_reveal(Vector2i(0, 1), false)
	if res2.get("action") != "cleared":
		print("[FAIL] 2nd reveal should have action 'cleared', got: ", res2)
		return false
	if not cm.is_chunk_cleared(Vector2i(0, 0)):
		print("[FAIL] Chunk should be cleared after all safe cells revealed")
		return false

	# Check auto_flags extraction
	var auto_flags: Array = res2.get("auto_flags", [])
	if auto_flags.size() != 2:
		print("[FAIL] Expected 2 auto-flag mine positions, got: ", auto_flags)
		return false
	if not auto_flags.has(Vector2i(0, 0)) or not auto_flags.has(Vector2i(1, 1)):
		print("[FAIL] Auto-flags list missing expected mine coordinates: ", auto_flags)
		return false

	# Check get_chunk_mine_positions
	var direct_mines = cm.get_chunk_mine_positions(Vector2i(0, 0))
	if direct_mines.size() != 2 or not direct_mines.has(Vector2i(0, 0)) or not direct_mines.has(Vector2i(1, 1)):
		print("[FAIL] get_chunk_mine_positions mismatch: ", direct_mines)
		return false

	if cleared_signals.size() != 1 or cleared_signals[0] != Vector2i(0, 0):
		print("[FAIL] chunk_cleared signal not emitted properly: ", cleared_signals)
		return false

	print("[PASS] Test 4: Chunk clearance and auto-flag extraction verified")
	return true

func test_surrounding_8_neighbor_cluster_revival() -> bool:
	print("[RUN] Test 5: Surrounding 8-Neighbor Cluster Revival")
	var mines: Dictionary = {
		Vector2i(0, 0): true # Mine in center chunk (0, 0)
	}
	var neighbor_chunks: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1,  0),                  Vector2i(1,  0),
		Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)
	]
	for c_pos in neighbor_chunks:
		mines[Vector2i(c_pos.x * 2, c_pos.y * 2)] = true # 1 mine, 3 safe cells per neighbor chunk

	var is_mine_cb = func(pos: Vector2i) -> bool:
		return mines.get(pos, false)

	var cm = ChunkManager.new()
	cm.setup(Vector2i(2, 2), is_mine_cb)

	var unlocked_signals: Array[Dictionary] = []
	cm.chunk_unlocked.connect(func(c_pos: Vector2i, recovered: Array[Vector2i]):
		unlocked_signals.append({"chunk_pos": c_pos, "recovered": recovered})
	)

	# Lock center chunk (0, 0)
	cm.register_reveal(Vector2i(0, 0), true, true)
	if not cm.is_chunk_locked(Vector2i(0, 0)):
		print("[FAIL] Center chunk (0, 0) should be locked")
		return false

	# Clear first 7 neighbor chunks
	for i in range(7):
		var c = neighbor_chunks[i]
		cm.register_reveal(Vector2i(c.x * 2 + 1, c.y * 2), false)
		cm.register_reveal(Vector2i(c.x * 2, c.y * 2 + 1), false)
		cm.register_reveal(Vector2i(c.x * 2 + 1, c.y * 2 + 1), false)

		if not cm.is_chunk_cleared(c):
			print("[FAIL] Neighbor chunk ", c, " should be cleared")
			return false
		if not cm.is_chunk_locked(Vector2i(0, 0)):
			print("[FAIL] Center chunk unlocked prematurely at step ", i)
			return false

	# Clear 8th neighbor chunk -> Triggers revival of center chunk (0, 0)
	var last_c = neighbor_chunks[7]
	cm.register_reveal(Vector2i(last_c.x * 2 + 1, last_c.y * 2), false)
	cm.register_reveal(Vector2i(last_c.x * 2, last_c.y * 2 + 1), false)
	var final_res = cm.register_reveal(Vector2i(last_c.x * 2 + 1, last_c.y * 2 + 1), false)

	if cm.is_chunk_locked(Vector2i(0, 0)):
		print("[FAIL] Center chunk (0, 0) should be unlocked after all 8 neighbors are cleared")
		return false

	if unlocked_signals.size() != 1:
		print("[FAIL] Expected 1 chunk_unlocked signal, got: ", unlocked_signals.size())
		return false

	if unlocked_signals[0]["chunk_pos"] != Vector2i(0, 0) or not unlocked_signals[0]["recovered"].has(Vector2i(0, 0)):
		print("[FAIL] chunk_unlocked payload mismatch: ", unlocked_signals[0])
		return false

	print("[PASS] Test 5: Surrounding 8-neighbor cluster revival verified")
	return true

func test_multi_chunk_connected_cluster_revival() -> bool:
	print("[RUN] Test 6: Multi-Chunk Connected Cluster Revival (2-chunk & L-shaped 3-chunk)")
	var mines: Dictionary = {
		Vector2i(0, 0): true, # in chunk (0,0)
		Vector2i(2, 0): true, # in chunk (1,0)
		Vector2i(0, 2): true  # in chunk (0,1)
	}

	# 12 perimeter chunks around {(0,0), (1,0), (0,1)}
	var perimeter_chunks: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1),
		Vector2i(-1,  0),                                   Vector2i(2,  0),
		Vector2i(-1,  1),                  Vector2i(1,  1), Vector2i(2,  1),
		Vector2i(-1,  2), Vector2i(0,  2), Vector2i(1,  2)
	]
	for p_c in perimeter_chunks:
		mines[Vector2i(p_c.x * 2, p_c.y * 2)] = true

	var is_mine_cb = func(pos: Vector2i) -> bool:
		return mines.get(pos, false)

	var cm = ChunkManager.new()
	cm.setup(Vector2i(2, 2), is_mine_cb)

	var unlocked_chunks: Array[Vector2i] = []
	cm.chunk_unlocked.connect(func(c_pos: Vector2i, _rec: Array[Vector2i]):
		unlocked_chunks.append(c_pos)
	)

	# Lock all 3 cluster members
	cm.register_reveal(Vector2i(0, 0), true, true)
	cm.register_reveal(Vector2i(2, 0), true, true)
	cm.register_reveal(Vector2i(0, 2), true, true)

	var cluster = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	for cp in cluster:
		if not cm.is_chunk_locked(cp):
			print("[FAIL] Cluster member ", cp, " should be locked")
			return false

	# Clear 11 of 12 perimeter chunks
	for i in range(11):
		var p_c = perimeter_chunks[i]
		cm.register_reveal(Vector2i(p_c.x * 2 + 1, p_c.y * 2), false)
		cm.register_reveal(Vector2i(p_c.x * 2, p_c.y * 2 + 1), false)
		cm.register_reveal(Vector2i(p_c.x * 2 + 1, p_c.y * 2 + 1), false)

		for cp in cluster:
			if not cm.is_chunk_locked(cp):
				print("[FAIL] Cluster member ", cp, " unlocked prematurely at step ", i)
				return false

	# Clear 12th perimeter chunk
	var last_p = perimeter_chunks[11]
	cm.register_reveal(Vector2i(last_p.x * 2 + 1, last_p.y * 2), false)
	cm.register_reveal(Vector2i(last_p.x * 2, last_p.y * 2 + 1), false)
	cm.register_reveal(Vector2i(last_p.x * 2 + 1, last_p.y * 2 + 1), false)

	# All 3 chunks should now be unlocked!
	for cp in cluster:
		if cm.is_chunk_locked(cp):
			print("[FAIL] Cluster member ", cp, " is still locked after full perimeter clear")
			return false
		if not unlocked_chunks.has(cp):
			print("[FAIL] chunk_unlocked signal missing for cluster member ", cp)
			return false

	print("[PASS] Test 6: Multi-chunk connected cluster revival verified")
	return true

func test_chunk_manager_serialization_and_deserialization() -> bool:
	print("[RUN] Test 7: Chunk State Serialization & Deserialization")
	var cm1 = ChunkManager.new()
	cm1.setup(Vector2i(4, 4))

	var chunk0 = cm1.get_chunk(Vector2i(0, 0))
	chunk0.is_locked = true
	chunk0.locked_mine_positions = [Vector2i(1, 1), Vector2i(2, 2)]
	chunk0.total_safe_cells = 14
	chunk0.revealed_safe_cells = 5
	chunk0.is_cleared = false

	var chunk1 = cm1.get_chunk(Vector2i(1, 0))
	chunk1.is_locked = false
	chunk1.locked_mine_positions = []
	chunk1.total_safe_cells = 12
	chunk1.revealed_safe_cells = 12
	chunk1.is_cleared = true

	var serialized = cm1.serialize()
	if serialized == null or serialized.size() != 2:
		print("[FAIL] Serialized array size mismatch: ", serialized)
		return false

	var cm2 = ChunkManager.new()
	cm2.setup(Vector2i(4, 4))
	var des_res = cm2.deserialize(serialized)
	if not des_res:
		print("[FAIL] deserialize returned false")
		return false

	if cm2.chunks.size() != 2:
		print("[FAIL] Deserialized chunks dictionary size mismatch: ", cm2.chunks.size())
		return false

	var des_chunk0 = cm2.get_chunk(Vector2i(0, 0))
	if not des_chunk0.is_locked or des_chunk0.total_safe_cells != 14 or des_chunk0.revealed_safe_cells != 5 or des_chunk0.is_cleared:
		print("[FAIL] Deserialized chunk0 properties mismatch")
		return false
	if des_chunk0.locked_mine_positions.size() != 2 or not des_chunk0.locked_mine_positions.has(Vector2i(1, 1)):
		print("[FAIL] Deserialized chunk0 locked_mine_positions mismatch: ", des_chunk0.locked_mine_positions)
		return false

	var des_chunk1 = cm2.get_chunk(Vector2i(1, 0))
	if des_chunk1.is_locked or des_chunk1.total_safe_cells != 12 or des_chunk1.revealed_safe_cells != 12 or not des_chunk1.is_cleared:
		print("[FAIL] Deserialized chunk1 properties mismatch")
		return false

	print("[PASS] Test 7: Serialization and deserialization verified")
	return true
