@tool
extends SceneTree

const GridManager = preload("res://scripts/grid_manager.gd")
const HUD = preload("res://scripts/hud.gd")

func _init():
	print("--- Running Test Suite: HUD & Game Statistics ---")
	var success = true

	# Test 1: Time Formatting Helper
	if not test_time_formatting():
		success = false

	# Test 2: HUD Initial State
	if not test_hud_initial_state():
		success = false

	# Test 3: Statistics Updating on Cell Reveal & Flag Change
	if not test_stats_updating():
		success = false

	# Test 4: Difficulty Selection & Density Application
	if not test_difficulty_selection():
		success = false

	# Test 5: Game Over Modal & Timer Stop
	if not test_game_over_modal():
		success = false

	# Test 6: Restart & State Reset
	if not test_restart_reset():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)

func test_time_formatting() -> bool:
	print("[RUN] Test 1: Time Formatting Helper")
	var hud = HUD.new()

	var t0 = hud.format_time(0.0)
	if t0 != "00:00":
		print("[FAIL] Expected 00:00, got: ", t0)
		hud.free()
		return false

	var t1 = hud.format_time(65.4)
	if t1 != "01:05":
		print("[FAIL] Expected 01:05, got: ", t1)
		hud.free()
		return false

	var t2 = hud.format_time(3599.0)
	if t2 != "59:59":
		print("[FAIL] Expected 59:59, got: ", t2)
		hud.free()
		return false

	hud.free()
	print("[PASS] Test 1: Time formatting helper verified")
	return true

func test_hud_initial_state() -> bool:
	print("[RUN] Test 2: HUD Initial State")
	var hud = HUD.new()
	hud.setup_ui_nodes()

	if hud.revealed_count != 0:
		print("[FAIL] Initial revealed_count should be 0, got ", hud.revealed_count)
		hud.free()
		return false

	if hud.flag_count != 0:
		print("[FAIL] Initial flag_count should be 0, got ", hud.flag_count)
		hud.free()
		return false

	if hud.elapsed_time != 0.0:
		print("[FAIL] Initial elapsed_time should be 0.0, got ", hud.elapsed_time)
		hud.free()
		return false

	if hud.is_timer_running:
		print("[FAIL] Initial is_timer_running should be false")
		hud.free()
		return false

	if hud.is_game_over_visible():
		print("[FAIL] GameOver modal should be hidden initially")
		hud.free()
		return false

	hud.free()
	print("[PASS] Test 2: HUD initial state verified")
	return true

func test_stats_updating() -> bool:
	print("[RUN] Test 3: Statistics Updating on Cell Reveal & Flag Change")
	var grid = GridManager.new()
	grid.safe_zone_radius = 0
	var hud = HUD.new()
	hud.setup_ui_nodes()
	hud.bind_grid_manager(grid)

	var safe_pos = Vector2i(2, 2)
	grid.set_mine_at(Vector2i(2, 3), true) # prevent BFS expansion
	grid.set_mine_at(safe_pos, false)

	# Reveal a cell -> stats and timer should update
	grid.reveal_cell(safe_pos)

	if hud.revealed_count != 1:
		print("[FAIL] revealed_count should be 1 after single reveal, got ", hud.revealed_count)
		hud.free()
		grid.free()
		return false

	if not hud.is_timer_running:
		print("[FAIL] Timer should start running after first cell reveal")
		hud.free()
		grid.free()
		return false

	# Toggle flag on adjacent cell -> flag count should update
	var flag_pos = Vector2i(2, 1)
	grid.toggle_flag(flag_pos)

	if hud.flag_count != 1:
		print("[FAIL] flag_count should be 1 after flagging, got ", hud.flag_count)
		hud.free()
		grid.free()
		return false

	# Unflag -> flag count should decrement
	grid.toggle_flag(flag_pos)
	if hud.flag_count != 0:
		print("[FAIL] flag_count should be 0 after unflagging, got ", hud.flag_count)
		hud.free()
		grid.free()
		return false

	hud.free()
	grid.free()
	print("[PASS] Test 3: Statistics updating on reveal & flag verified")
	return true

func test_difficulty_selection() -> bool:
	print("[RUN] Test 4: Difficulty Selection & Density Application")
	var grid = GridManager.new()
	var hud = HUD.new()
	hud.setup_ui_nodes()
	hud.bind_grid_manager(grid)

	# Select Easy (0 -> 10%)
	hud.set_difficulty_by_index(0)
	if not is_equal_approx(grid.mine_density, 0.10):
		print("[FAIL] Easy density expected 0.10, got ", grid.mine_density)
		hud.free()
		grid.free()
		return false

	# Select Medium (1 -> 15%)
	hud.set_difficulty_by_index(1)
	if not is_equal_approx(grid.mine_density, 0.15):
		print("[FAIL] Medium density expected 0.15, got ", grid.mine_density)
		hud.free()
		grid.free()
		return false

	# Select Hard (2 -> 20%)
	hud.set_difficulty_by_index(2)
	if not is_equal_approx(grid.mine_density, 0.20):
		print("[FAIL] Hard density expected 0.20, got ", grid.mine_density)
		hud.free()
		grid.free()
		return false

	hud.free()
	grid.free()
	print("[PASS] Test 4: Difficulty selection verified")
	return true

func test_game_over_modal() -> bool:
	print("[RUN] Test 5: Game Over Modal & Timer Stop")
	var grid = GridManager.new()
	grid.enable_chunk_lockout = false
	var hud = HUD.new()
	hud.setup_ui_nodes()
	hud.bind_grid_manager(grid)

	# Setup first click elsewhere to not trigger safe zone on mine
	grid.set_first_click(Vector2i(100, 100))
	hud.is_timer_running = true
	hud.elapsed_time = 45.0

	var mine_pos = Vector2i(0, 0)
	grid.set_mine_at(mine_pos, true)
	grid.get_cell(Vector2i(0, 1)).is_revealed = true # Anchor

	grid.reveal_cell(mine_pos)

	if not grid.is_game_over:
		print("[FAIL] Grid should be in game over state")
		hud.free()
		grid.free()
		return false

	if hud.is_timer_running:
		print("[FAIL] HUD timer should stop when game is over")
		hud.free()
		grid.free()
		return false

	if not hud.is_game_over_visible():
		print("[FAIL] GameOver modal should be visible on game over")
		hud.free()
		grid.free()
		return false

	var stats_text = hud.get_game_over_stats_text()
	if not ("Explored" in stats_text or "00:45" in stats_text):
		print("[FAIL] GameOver stats text does not contain required stats: ", stats_text)
		hud.free()
		grid.free()
		return false

	hud.free()
	grid.free()
	print("[PASS] Test 5: Game Over modal & timer stop verified")
	return true

func test_restart_reset() -> bool:
	print("[RUN] Test 6: Restart & State Reset")
	var grid = GridManager.new()
	grid.enable_chunk_lockout = false
	var hud = HUD.new()
	hud.setup_ui_nodes()
	hud.bind_grid_manager(grid)

	# Trigger some state changes
	grid.set_first_click(Vector2i(100, 100))
	var mine_pos = Vector2i(0, 0)
	grid.set_mine_at(mine_pos, true)
	grid.get_cell(Vector2i(0, 1)).is_revealed = true # Anchor
	grid.reveal_cell(mine_pos)

	if not grid.is_game_over or not hud.is_game_over_visible():
		print("[FAIL] Setup state for restart test failed")
		hud.free()
		grid.free()
		return false

	# Press restart
	hud.on_restart_pressed()

	if grid.is_game_over:
		print("[FAIL] Grid is_game_over should be false after restart")
		hud.free()
		grid.free()
		return false

	if grid.has_first_clicked:
		print("[FAIL] Grid has_first_clicked should be false after restart")
		hud.free()
		grid.free()
		return false

	if hud.revealed_count != 0:
		print("[FAIL] HUD revealed_count should be reset to 0, got ", hud.revealed_count)
		hud.free()
		grid.free()
		return false

	if hud.flag_count != 0:
		print("[FAIL] HUD flag_count should be reset to 0, got ", hud.flag_count)
		hud.free()
		grid.free()
		return false

	if hud.elapsed_time != 0.0 or hud.is_timer_running:
		print("[FAIL] HUD timer should be reset to 0.0 and stopped")
		hud.free()
		grid.free()
		return false

	if hud.is_game_over_visible():
		print("[FAIL] GameOver modal should be hidden after restart")
		hud.free()
		grid.free()
		return false

	hud.free()
	grid.free()
	print("[PASS] Test 6: Restart & state reset verified")
	return true
