@tool
extends SceneTree

const GridManager = preload("res://scripts/grid_manager.gd")
const CellData = preload("res://scripts/cell_data.gd")

func _init():
	print("--- Running Test Suite: Grid Procedural Generation ---")
	var success = true

	# Test 1: CellData Initialization
	if not test_cell_data_initialization():
		success = false

	# Test 2: Deterministic Hash Generation
	if not test_deterministic_generation():
		success = false

	# Test 3: Mine Density Distribution
	if not test_mine_density():
		success = false

	# Test 4: First-Click Guarantee Safe Zone
	if not test_first_click_guarantee():
		success = false

	# Test 5: Neighbor Mines Calculation
	if not test_neighbor_mines_count():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)

func test_cell_data_initialization() -> bool:
	print("[RUN] Test 1: CellData Initialization")
	var pos = Vector2i(10, -5)
	var cell = CellData.new(pos)
	if cell.pos != pos:
		print("[FAIL] Cell position mismatch. Expected: ", pos, " Got: ", cell.pos)
		return false
	if cell.is_mine != false or cell.is_revealed != false or cell.is_flagged != false or cell.neighbor_mines != 0:
		print("[FAIL] Cell default properties incorrect")
		return false
	print("[PASS] Test 1: CellData initialized correctly")
	return true

func test_deterministic_generation() -> bool:
	print("[RUN] Test 2: Deterministic Hash Generation")
	var grid1 = GridManager.new()
	grid1.world_seed = 12345
	grid1.mine_density = 0.2

	var grid2 = GridManager.new()
	grid2.world_seed = 12345
	grid2.mine_density = 0.2

	var grid3 = GridManager.new()
	grid3.world_seed = 54321
	grid3.mine_density = 0.2

	var sample_positions = [
		Vector2i(0, 0), Vector2i(10, 20), Vector2i(-15, 30), Vector2i(100, -200)
	]

	for pos in sample_positions:
		var mine1 = grid1.is_mine_at(pos)
		var mine2 = grid2.is_mine_at(pos)
		if mine1 != mine2:
			print("[FAIL] Deterministic check failed for same seed at ", pos)
			return false

	var differences = 0
	for pos in sample_positions:
		if grid1.is_mine_at(pos) != grid3.is_mine_at(pos):
			differences += 1

	if differences == 0:
		print("[FAIL] Different seeds produced identical mine distribution across samples")
		return false

	print("[PASS] Test 2: Deterministic Hash Generation verified")
	return true

func test_mine_density() -> bool:
	print("[RUN] Test 3: Mine Density Distribution")
	var grid = GridManager.new()
	grid.world_seed = 98765
	grid.mine_density = 0.20

	var total_cells = 0
	var mine_count = 0
	for x in range(-25, 25):
		for y in range(-25, 25):
			total_cells += 1
			if grid.is_mine_at(Vector2i(x, y)):
				mine_count += 1

	var calculated_density = float(mine_count) / float(total_cells)
	print("Sampled ", total_cells, " cells. Mines: ", mine_count, " Density: ", calculated_density)
	if calculated_density < 0.12 or calculated_density > 0.28:
		print("[FAIL] Mine density out of expected range [0.12, 0.28]. Calculated: ", calculated_density)
		return false

	print("[PASS] Test 3: Mine density within acceptable statistical variance")
	return true

func test_first_click_guarantee() -> bool:
	print("[RUN] Test 4: First-Click Guarantee Safe Zone")
	var grid = GridManager.new()
	grid.world_seed = 777
	grid.mine_density = 0.3 # High density to increase chance of mines
	grid.safe_zone_radius = 1 # 3x3 safe area

	var first_click = Vector2i(12, -8)
	grid.set_first_click(first_click)

	# Verify 3x3 area around first_click has zero mines
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var check_pos = first_click + Vector2i(dx, dy)
			var cell = grid.get_cell(check_pos)
			if cell.is_mine:
				print("[FAIL] Mine found in safe zone at ", check_pos, " after set_first_click(", first_click, ")")
				return false

	print("[PASS] Test 4: First-click guarantee safe zone verified")
	return true

func test_neighbor_mines_count() -> bool:
	print("[RUN] Test 5: Neighbor Mines Calculation")
	var grid = GridManager.new()
	grid.world_seed = 42

	var target_pos = Vector2i(0, 0)
	# Force specific mines around target_pos for testing calculation
	grid.set_mine_at(Vector2i(-1, -1), true)
	grid.set_mine_at(Vector2i(0, -1), true)
	grid.set_mine_at(Vector2i(1, 1), true)
	grid.set_mine_at(Vector2i(5, 5), true) # Far away, should not count

	var neighbor_count = grid.count_neighbor_mines(target_pos)
	if neighbor_count != 3:
		print("[FAIL] Neighbor mine count mismatch. Expected: 3, Got: ", neighbor_count)
		return false

	print("[PASS] Test 5: Neighbor mine calculation verified")
	return true
