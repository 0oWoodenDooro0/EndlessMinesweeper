@tool
extends SceneTree

const GridManager = preload("res://scripts/grid_manager.gd")
const CellData = preload("res://scripts/cell_data.gd")
const ChunkManager = preload("res://scripts/chunk_manager.gd")
const GameSession = preload("res://scripts/game_session.gd")
const SaveManager = preload("res://scripts/save_manager.gd")
const MainScene = preload("res://scenes/main.tscn")

func _init():
	print("--- Running Test Suite: Surrounding Precalc & Batch Reveal ---")
	var success = true

	# Test 1: CellData Neighbor Mines Caching
	if not test_neighbor_mines_caching():
		success = false

	# Test 2: Cache Invalidation on Safe Zone / Mine Modification
	if not test_cache_invalidation_on_mine_change():
		success = false

	# Test 3: Surrounding Chunk Preloading
	if not test_surrounding_chunk_preloading():
		success = false

	# Test 4: GameSession Batch Reveal
	if not test_game_session_batch_reveal():
		success = false

	# Test 5: Cascade BFS Flood Fill Batch Reveal & Performance Benchmark (< 10ms)
	if not test_cascade_bfs_batch_reveal_and_performance():
		success = false

	# Test 6: Auto-Save State Persistence After Cascade Reveal
	if not test_save_persistence_after_cascade_reveal():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)

func test_neighbor_mines_caching() -> bool:
	print("[RUN] Test 1: CellData Neighbor Mines Caching")
	var grid = GridManager.new()
	grid.safe_zone_radius = 0

	var center = Vector2i(0, 0)
	# Force 2 mines around center: at (-1, 0) and (1, 0)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			grid.set_mine_at(center + Vector2i(dx, dy), false)
	grid.set_mine_at(center + Vector2i(-1, 0), true)
	grid.set_mine_at(center + Vector2i(1, 0), true)

	var cell = grid.get_cell(center)
	if cell.neighbor_mines_cached:
		print("[FAIL] neighbor_mines_cached should be false before count_neighbor_mines()")
		grid.free()
		return false

	var count = grid.count_neighbor_mines(center)
	if count != 2:
		print("[FAIL] Expected neighbor count 2, got: ", count)
		grid.free()
		return false

	if not cell.neighbor_mines_cached:
		print("[FAIL] cell.neighbor_mines_cached should be true after count_neighbor_mines()")
		grid.free()
		return false

	if cell.neighbor_mines != 2:
		print("[FAIL] cell.neighbor_mines should be 2, got: ", cell.neighbor_mines)
		grid.free()
		return false

	# Simulate cache hit: modify cell.neighbor_mines directly to verify cache hit
	cell.neighbor_mines = 42
	var cached_count = grid.count_neighbor_mines(center)
	if cached_count != 42:
		print("[FAIL] count_neighbor_mines should return cached value without recalculating, got: ", cached_count)
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 1: CellData neighbor mines caching verified")
	return true

func test_cache_invalidation_on_mine_change() -> bool:
	print("[RUN] Test 2: Cache Invalidation on Safe Zone / Mine Modification")
	var grid = GridManager.new()
	grid.world_seed = 8888
	grid.mine_density = 0.5
	grid.safe_zone_radius = 1

	var target = Vector2i(5, 5)
	# Populate cell and calculate cache before first click
	grid.count_neighbor_mines(target)
	var cell = grid.get_cell(target)
	if not cell.neighbor_mines_cached:
		print("[FAIL] Target cell should be cached initially")
		grid.free()
		return false

	# First click at (5, 5) creates 3x3 safe zone with 0 mines
	grid.set_first_click(target)

	# Cache should be invalidated or recomputed
	var new_count = grid.count_neighbor_mines(target)
	if new_count != 0:
		print("[FAIL] count_neighbor_mines after safe zone creation should be 0, got: ", new_count)
		grid.free()
		return false

	# Change mine at (5, 6)
	grid.set_mine_at(Vector2i(5, 6), true)
	var updated_count = grid.count_neighbor_mines(target)
	if updated_count != 1:
		print("[FAIL] count_neighbor_mines after set_mine_at should be 1, got: ", updated_count)
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 2: Cache invalidation on mine change verified")
	return true

func test_surrounding_chunk_preloading() -> bool:
	print("[RUN] Test 3: Surrounding Chunk Preloading")
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(8, 8)

	var cm = grid.chunk_manager
	# 1. Test ChunkManager.preload_chunks_in_rect
	cm.preload_chunks_in_rect(Vector2i(-1, -1), Vector2i(1, 1))
	for cx in range(-1, 2):
		for cy in range(-1, 2):
			var cp = Vector2i(cx, cy)
			if not cm.has_chunk(cp):
				print("[FAIL] Preloaded chunk not found at: ", cp)
				grid.free()
				return false
			var chunk = cm.get_chunk(cp)
			if chunk.total_safe_cells < 0:
				print("[FAIL] Preloaded chunk safe cells not computed for: ", cp)
				grid.free()
				return false

	# 2. Test GridManager.preload_surrounding_chunks
	grid.preload_surrounding_chunks(Vector2i(3, 3), 1)
	for cx in range(2, 5):
		for cy in range(2, 5):
			var cp = Vector2i(cx, cy)
			if not cm.has_chunk(cp):
				print("[FAIL] GridManager preloaded chunk not found at: ", cp)
				grid.free()
				return false

	# 3. Test GridManager.preload_chunks_around_viewport
	grid.visible_rect = Rect2(0, 0, 128, 128) # covers chunks (0,0) to (1,1)
	grid.preload_chunks_around_viewport(1)
	for cx in range(-1, 3):
		for cy in range(-1, 3):
			var cp = Vector2i(cx, cy)
			if not cm.has_chunk(cp):
				print("[FAIL] Viewport preloaded chunk not found at: ", cp)
				grid.free()
				return false

	grid.free()
	print("[PASS] Test 3: Surrounding chunk preloading verified")
	return true

func test_game_session_batch_reveal() -> bool:
	print("[RUN] Test 4: GameSession Batch Reveal")
	var session = GameSession.new()

	var stats_data = {
		"emissions_count": 0,
		"last_revealed_stat": 0
	}
	session.connect("stats_changed", func(stats: Dictionary):
		stats_data["emissions_count"] += 1
		stats_data["last_revealed_stat"] = stats.get("revealed_count", 0)
	)

	var batch_positions: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)
	]

	# Record batch of 6 safe reveals
	session.record_reveals_batch(batch_positions, 0)

	if session.revealed_count != 6:
		print("[FAIL] Expected revealed_count 6, got: ", session.revealed_count)
		return false

	if not session.is_timer_running:
		print("[FAIL] Timer should auto-start on batch reveal")
		return false

	if stats_data["emissions_count"] != 1:
		print("[FAIL] stats_changed should be emitted exactly once for batch, got: ", stats_data["emissions_count"])
		return false

	if stats_data["last_revealed_stat"] != 6:
		print("[FAIL] stats_changed payload mismatch: ", stats_data["last_revealed_stat"])
		return false

	# Empty batch test
	var prev_emissions = stats_data["emissions_count"]
	session.record_reveals_batch([], 0)
	if session.revealed_count != 6 or stats_data["emissions_count"] != prev_emissions:
		print("[FAIL] Empty batch should be a no-op")
		return false

	# Game over test
	session.trigger_game_over(Vector2i(99, 99))
	session.record_reveals_batch([Vector2i(10, 10)], 0)
	if session.revealed_count != 6:
		print("[FAIL] Batch reveal after game over should be ignored")
		return false

	print("[PASS] Test 4: GameSession batch reveal verified")
	return true

func test_cascade_bfs_batch_reveal_and_performance() -> bool:
	print("[RUN] Test 5: Cascade BFS Flood Fill Batch Reveal & Performance Benchmark (< 10ms)")
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(16, 16)
	grid.safe_zone_radius = 0
	var session = GameSession.new()
	grid.bind_session(session)

	# Create a 10x10 zero-mine zone from (0, 0) to (9, 9) -> 100 safe cells
	for x in range(0, 10):
		for y in range(0, 10):
			grid.set_mine_at(Vector2i(x, y), false)

	# Surround with mine wall at x = -1, x = 10, y = -1, y = 10
	for x in range(-1, 11):
		grid.set_mine_at(Vector2i(x, -1), true)
		grid.set_mine_at(Vector2i(x, 10), true)
	for y in range(-1, 11):
		grid.set_mine_at(Vector2i(-1, y), true)
		grid.set_mine_at(Vector2i(10, y), true)

	var signal_data = {
		"emissions_count": 0
	}
	session.connect("stats_changed", func(_s):
		signal_data["emissions_count"] += 1
	)

	# Benchmark cascade reveal of 100 cells
	var start_time_usec = Time.get_ticks_usec()
	var reveal_ok = grid.reveal_cell(Vector2i(5, 5))
	var elapsed_usec = Time.get_ticks_usec() - start_time_usec
	var elapsed_ms = float(elapsed_usec) / 1000.0

	print("Cascade reveal of 100 cells took: ", elapsed_ms, " ms (", elapsed_usec, " µs)")

	if not reveal_ok:
		print("[FAIL] reveal_cell returned false")
		grid.free()
		return false

	if session.revealed_count != 100:
		print("[FAIL] Expected 100 revealed cells, got: ", session.revealed_count)
		grid.free()
		return false

	# All 100 cells must be marked revealed
	for x in range(0, 10):
		for y in range(0, 10):
			if not grid.get_cell(Vector2i(x, y)).is_revealed:
				print("[FAIL] Cell at (", x, ", ", y, ") was not revealed in cascade")
				grid.free()
				return false

	# Signal emission count must be batched (<= 2 times, NOT 100 times)
	if signal_data["emissions_count"] > 2:
		print("[FAIL] stats_changed emitted too many times during cascade: ", signal_data["emissions_count"], " (expected <= 2)")
		grid.free()
		return false

	# Performance benchmark threshold: must complete within 10ms (10,000 µs)
	if elapsed_ms > 10.0:
		print("[FAIL] Cascade reveal exceeded 10ms performance budget: ", elapsed_ms, " ms")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 5: Cascade BFS batch reveal & performance benchmark verified")
	return true

func test_save_persistence_after_cascade_reveal() -> bool:
	print("[RUN] Test 6: Auto-Save State Persistence After Cascade Reveal")
	var sm = SaveManager.new()
	var test_path = "user://test_cascade_autosave.json"
	if sm.has_save(test_path):
		sm.delete_save(test_path)

	var main = MainScene.instantiate()
	main.save_file_path = test_path
	root.add_child(main)
	main.save_file_path = test_path

	var grid = main.get_node("GridManager") as GridManager
	grid.chunk_size = Vector2i(4, 4)
	grid.safe_zone_radius = 0

	# 5x5 zero mine area -> 25 safe cells
	for x in range(0, 5):
		for y in range(0, 5):
			grid.set_mine_at(Vector2i(x, y), false)

	# Surround with mines
	for x in range(-1, 6):
		grid.set_mine_at(Vector2i(x, -1), true)
		grid.set_mine_at(Vector2i(x, 5), true)
	for y in range(-1, 6):
		grid.set_mine_at(Vector2i(-1, y), true)
		grid.set_mine_at(Vector2i(5, y), true)

	# Reveal origin to trigger cascade of 25 cells
	grid.reveal_cell(Vector2i(2, 2))

	if not sm.has_save(test_path):
		print("[FAIL] Auto-save file was not created after cascade reveal")
		sm.delete_save(test_path)
		main.queue_free()
		return false

	var save_data = sm.load_data_from_file(test_path)
	if save_data == null or not save_data.has("hud") or not save_data.has("grid"):
		print("[FAIL] Invalid save data structure: ", save_data)
		sm.delete_save(test_path)
		main.queue_free()
		return false

	if save_data["hud"]["revealed_count"] != 25:
		print("[FAIL] Auto-saved revealed_count mismatch. Expected 25, got: ", save_data["hud"]["revealed_count"])
		sm.delete_save(test_path)
		main.queue_free()
		return false

	# Clean up
	sm.delete_save(test_path)
	main.queue_free()
	print("[PASS] Test 6: Auto-save state persistence after cascade reveal verified")
	return true
