@tool
extends SceneTree

const GridManager = preload("res://scripts/grid_manager.gd")
const GameSession = preload("res://scripts/game_session.gd")
const HUD = preload("res://scripts/hud.gd")
const SaveManager = preload("res://scripts/save_manager.gd")

func _init():
	print("--- Running Test Suite: 8x8 Chunk Peaked Mine Distribution ---")
	var success = true

	# Test 1: Chunk Size & Coordinate Mapping
	if not test_chunk_size_and_dimensions():
		success = false

	# Test 2: Mine Count Bounded Range [10, 25]
	if not test_mine_count_bounds_range():
		success = false

	# Test 3: Statistical Center-Peaked Distribution
	if not test_statistical_center_peaked_distribution():
		success = false

	# Test 4: Deterministic Reproducibility
	if not test_deterministic_reproducibility():
		success = false

	# Test 5: Safe Zone Integration
	if not test_safe_zone_integration():
		success = false

	# Test 6: HUD and GameSession No Difficulty
	if not test_hud_and_session_no_difficulty():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)

func test_chunk_size_and_dimensions() -> bool:
	print("[RUN] Test 1: Chunk Size & Coordinate Mapping")
	var grid = GridManager.new()

	if grid.chunk_size != Vector2i(8, 8):
		print("[FAIL] Expected chunk_size (8, 8), got: ", grid.chunk_size)
		grid.free()
		return false

	# Coordinate mapping verification
	var mapping_cases = [
		{"cell": Vector2i(0, 0), "chunk": Vector2i(0, 0)},
		{"cell": Vector2i(7, 7), "chunk": Vector2i(0, 0)},
		{"cell": Vector2i(8, 0), "chunk": Vector2i(1, 0)},
		{"cell": Vector2i(0, 8), "chunk": Vector2i(0, 1)},
		{"cell": Vector2i(15, 23), "chunk": Vector2i(1, 2)},
		{"cell": Vector2i(-1, -1), "chunk": Vector2i(-1, -1)},
		{"cell": Vector2i(-8, -8), "chunk": Vector2i(-1, -1)},
		{"cell": Vector2i(-9, -1), "chunk": Vector2i(-2, -1)},
		{"cell": Vector2i(-16, -16), "chunk": Vector2i(-2, -2)}
	]

	for c in mapping_cases:
		var result = grid.cell_to_chunk(c["cell"])
		if result != c["chunk"]:
			print("[FAIL] Mapping failed for cell ", c["cell"], ". Expected chunk: ", c["chunk"], " Got: ", result)
			grid.free()
			return false

	grid.free()
	print("[PASS] Test 1: Chunk size and coordinate mapping verified")
	return true

func test_mine_count_bounds_range() -> bool:
	print("[RUN] Test 2: Mine Count Bounded Range [10, 20]")
	var grid = GridManager.new()
	grid.world_seed = 424242

	# Sample 1,000 distinct chunks across various regions
	for cx in range(-15, 16):
		for cy in range(-15, 17):
			var mines_in_chunk = 0
			var min_x = cx * 8
			var min_y = cy * 8

			for x in range(min_x, min_x + 8):
				for y in range(min_y, min_y + 8):
					if grid.is_mine_at(Vector2i(x, y)):
						mines_in_chunk += 1

			if mines_in_chunk < 10 or mines_in_chunk > 20:
				print("[FAIL] Chunk (", cx, ", ", cy, ") mine count out of bounds [10, 20]: ", mines_in_chunk)
				grid.free()
				return false

	grid.free()
	print("[PASS] Test 2: Mine count bounded range [10, 20] verified")
	return true

func test_statistical_center_peaked_distribution() -> bool:
	print("[RUN] Test 3: Statistical Center-Peaked Distribution")
	var grid = GridManager.new()
	grid.world_seed = 1337

	var total_samples = 25000
	var counts_hist: Dictionary = {}
	for m in range(10, 21):
		counts_hist[m] = 0

	# Sample 25,000 chunks
	var sample_side = int(ceil(sqrt(total_samples)))
	var half_side = sample_side / 2
	var sampled = 0

	for cx in range(-half_side, half_side + 1):
		for cy in range(-half_side, half_side + 1):
			if sampled >= total_samples:
				break
			var mines_in_chunk = 0
			var min_x = cx * 8
			var min_y = cy * 8
			for x in range(min_x, min_x + 8):
				for y in range(min_y, min_y + 8):
					if grid.is_mine_at(Vector2i(x, y)):
						mines_in_chunk += 1

			if counts_hist.has(mines_in_chunk):
				counts_hist[mines_in_chunk] += 1
			else:
				print("[FAIL] Sampled mine count out of range [10, 20]: ", mines_in_chunk)
				grid.free()
				return false
			sampled += 1

	print("Histogram of 25,000 chunk mine counts:")
	for m in range(10, 21):
		var pct = float(counts_hist[m]) / float(total_samples) * 100.0
		print("  Mines %2d: %5d (%.2f%%)" % [m, counts_hist[m], pct])

	# Statistical validation:
	# 1. Endpoints (10 and 20) must have lowest frequencies
	var pct_10 = float(counts_hist[10]) / float(total_samples) * 100.0
	var pct_20 = float(counts_hist[20]) / float(total_samples) * 100.0
	if pct_10 < 0.3 or pct_10 > 2.5 or pct_20 < 0.3 or pct_20 > 2.5:
		print("[FAIL] Endpoint percentages unexpected: 10=", pct_10, "%, 20=", pct_20, "%")
		grid.free()
		return false

	# 2. Peak Center (15) must have highest frequency
	var pct_15 = float(counts_hist[15]) / float(total_samples) * 100.0
	if pct_15 < 12.0 or pct_15 > 20.0:
		print("[FAIL] Peak center percentages unexpected: 15=", pct_15, "%")
		grid.free()
		return false

	# 3. Overall peaked shape: low groups < mid groups < peak groups > mid-high groups > high groups
	var group_low = counts_hist[10] + counts_hist[11]
	var group_mid_low = counts_hist[12] + counts_hist[13]
	var group_peak = counts_hist[14] + counts_hist[15] + counts_hist[16]
	var group_mid_high = counts_hist[17] + counts_hist[18]
	var group_high = counts_hist[19] + counts_hist[20]

	if not (group_low < group_mid_low and group_mid_low < group_peak and group_peak > group_mid_high and group_mid_high > group_high):
		print("[FAIL] Distribution failed peaked monotonicity: ", [group_low, group_mid_low, group_peak, group_mid_high, group_high])
		grid.free()
		return false

	# 4. Symmetry check: lower half [10..14] vs upper half [16..20]
	var lower_sum = 0
	var upper_sum = 0
	for m in range(10, 15):
		lower_sum += counts_hist[m]
	for m in range(16, 21):
		upper_sum += counts_hist[m]

	var diff_ratio = abs(float(lower_sum - upper_sum)) / float(total_samples)
	if diff_ratio > 0.05:
		print("[FAIL] Distribution symmetry violated: lower=", lower_sum, " upper=", upper_sum, " diff_ratio=", diff_ratio)
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 3: Statistical center-peaked distribution verified")
	return true

func test_deterministic_reproducibility() -> bool:
	print("[RUN] Test 4: Deterministic Reproducibility")
	var grid1 = GridManager.new()
	grid1.world_seed = 88888

	var grid2 = GridManager.new()
	grid2.world_seed = 88888

	var grid3 = GridManager.new()
	grid3.world_seed = 99999

	var sample_cells = [
		Vector2i(0, 0), Vector2i(5, 5), Vector2i(7, 7),
		Vector2i(10, 15), Vector2i(-20, 35), Vector2i(-100, -200)
	]

	# Check same seed produces identical results
	for p in sample_cells:
		if grid1.is_mine_at(p) != grid2.is_mine_at(p):
			print("[FAIL] Determinism mismatch at ", p, " between grid1 and grid2 with same seed")
			grid1.free()
			grid2.free()
			grid3.free()
			return false

	# Check different seed produces differences
	var diff_count = 0
	for x in range(0, 24):
		for y in range(0, 24):
			var p = Vector2i(x, y)
			if grid1.is_mine_at(p) != grid3.is_mine_at(p):
				diff_count += 1

	if diff_count == 0:
		print("[FAIL] Different seeds produced identical grid")
		grid1.free()
		grid2.free()
		grid3.free()
		return false

	grid1.free()
	grid2.free()
	grid3.free()
	print("[PASS] Test 4: Deterministic reproducibility verified")
	return true

func test_safe_zone_integration() -> bool:
	print("[RUN] Test 5: Safe Zone Integration")
	var grid = GridManager.new()
	grid.world_seed = 777123
	grid.safe_zone_radius = 1

	var first_click = Vector2i(12, 14)
	grid.set_first_click(first_click)

	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var p = first_click + Vector2i(dx, dy)
			if grid.is_mine_at(p):
				print("[FAIL] Mine found in safe zone at ", p)
				grid.free()
				return false

	grid.free()
	print("[PASS] Test 5: Safe zone integration verified")
	return true

func test_hud_and_session_no_difficulty() -> bool:
	print("[RUN] Test 6: HUD and GameSession No Difficulty")
	var hud = HUD.new()
	hud.setup_ui_nodes()

	# HUD should not have difficulty_option
	if hud.get("difficulty_option") != null:
		print("[FAIL] HUD should not expose difficulty_option")
		hud.free()
		return false

	var session = GameSession.new()
	var stats = session.get_stats()
	if stats.has("difficulty_index") or stats.has("mine_density"):
		print("[FAIL] GameSession stats should not contain difficulty fields: ", stats)
		hud.free()
		return false

	var serialized = session.serialize()
	if serialized.has("difficulty_index") or serialized.has("mine_density"):
		print("[FAIL] GameSession serialization should not contain difficulty fields: ", serialized)
		hud.free()
		return false

	hud.free()
	print("[PASS] Test 6: HUD and GameSession without difficulty verified")
	return true
