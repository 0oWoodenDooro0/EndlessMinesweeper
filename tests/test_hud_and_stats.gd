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

	# Test 4: HUD Layout & Cleanliness (No Difficulty UI)
	if not test_hud_layout_and_cleanliness():
		success = false

	# Test 5: Game Over Modal & Timer Stop
	if not test_game_over_modal():
		success = false

	# Test 6: Restart & State Reset
	if not test_restart_reset():
		success = false

	# Test 7: Button Focus Mode & Focus Release Behavior
	if not test_button_focus_mode_and_release():
		success = false

	# Test 8: Global GUI Theme Font & License Verification
	if not test_gui_theme_font_and_license():
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

func test_hud_layout_and_cleanliness() -> bool:
	print("[RUN] Test 4: HUD Layout & Cleanliness (No Difficulty UI)")
	var hud_scene = preload("res://scenes/hud.tscn")
	var hud_inst = hud_scene.instantiate()
	if hud_inst == null:
		print("[FAIL] Failed to instantiate hud scene")
		return false

	if hud_inst.has_node("TopBar/MarginContainer/HBoxContainer/DifficultyOption"):
		print("[FAIL] HUD TopBar should NOT have DifficultyOption")
		hud_inst.free()
		return false

	if not hud_inst.has_node("TopBar/MarginContainer/HBoxContainer/ExploredLabel"):
		print("[FAIL] HUD TopBar missing ExploredLabel")
		hud_inst.free()
		return false

	if not hud_inst.has_node("TopBar/MarginContainer/HBoxContainer/FlagLabel"):
		print("[FAIL] HUD TopBar missing FlagLabel")
		hud_inst.free()
		return false

	if not hud_inst.has_node("TopBar/MarginContainer/HBoxContainer/ChunkStatsLabel"):
		print("[FAIL] HUD TopBar missing ChunkStatsLabel")
		hud_inst.free()
		return false

	if not hud_inst.has_node("TopBar/MarginContainer/HBoxContainer/TimeLabel"):
		print("[FAIL] HUD TopBar missing TimeLabel")
		hud_inst.free()
		return false

	if not hud_inst.has_node("TopBar/MarginContainer/HBoxContainer/RestartButton"):
		print("[FAIL] HUD TopBar missing RestartButton")
		hud_inst.free()
		return false

	hud_inst.free()
	print("[PASS] Test 4: HUD layout & cleanliness verified")
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

func test_button_focus_mode_and_release() -> bool:
	print("[RUN] Test 7: Button Focus Mode & Focus Release Behavior")
	var hud_scene = preload("res://scenes/hud.tscn")
	var hud_inst = hud_scene.instantiate()
	if hud_inst == null:
		print("[FAIL] Failed to instantiate hud scene")
		return false

	var restart_btn = hud_inst.get_node_or_null("TopBar/MarginContainer/HBoxContainer/RestartButton") as Button
	if restart_btn == null:
		print("[FAIL] RestartButton node not found")
		hud_inst.free()
		return false

	if restart_btn.focus_mode != Control.FOCUS_NONE:
		print("[FAIL] RestartButton focus_mode in scene is not FOCUS_NONE (0), got: ", restart_btn.focus_mode)
		hud_inst.free()
		return false

	var play_again_btn = hud_inst.get_node_or_null("GameOverModal/Panel/VBoxContainer/PlayAgainButton") as Button
	if play_again_btn == null:
		print("[FAIL] PlayAgainButton node not found")
		hud_inst.free()
		return false

	if play_again_btn.focus_mode != Control.FOCUS_NONE:
		print("[FAIL] PlayAgainButton focus_mode in scene is not FOCUS_NONE (0), got: ", play_again_btn.focus_mode)
		hud_inst.free()
		return false

	hud_inst.free()

	# Also test programmatic HUD instance setup_ui_nodes()
	var hud = HUD.new()
	hud.setup_ui_nodes()

	if hud.restart_button.focus_mode != Control.FOCUS_NONE:
		print("[FAIL] Programmatic restart_button focus_mode is not FOCUS_NONE, got: ", hud.restart_button.focus_mode)
		hud.free()
		return false

	if hud.play_again_button.focus_mode != Control.FOCUS_NONE:
		print("[FAIL] Programmatic play_again_button focus_mode is not FOCUS_NONE, got: ", hud.play_again_button.focus_mode)
		hud.free()
		return false

	# Test focus release on restart pressed
	hud.on_restart_pressed()
	if hud.restart_button.has_focus():
		print("[FAIL] restart_button retained focus after on_restart_pressed()")
		hud.free()
		return false
	if hud.play_again_button.has_focus():
		print("[FAIL] play_again_button retained focus after on_restart_pressed()")
		hud.free()
		return false

	hud.free()
	print("[PASS] Test 7: Button focus mode & focus release behavior verified")
	return true

func test_gui_theme_font_and_license() -> bool:
	print("[RUN] Test 8: Global GUI Theme Font & License Verification")

	# Verify project setting for gui theme font
	var theme_font_path = ProjectSettings.get_setting("gui/theme/custom_font", "")
	if theme_font_path != "res://assets/fonts/NotoSans-Bold.ttf":
		print("[FAIL] ProjectSettings gui/theme/custom_font is not 'res://assets/fonts/NotoSans-Bold.ttf', got: ", theme_font_path)
		return false

	# Verify font resource exists and is loadable
	if not ResourceLoader.exists(theme_font_path):
		print("[FAIL] Font file does not exist at: ", theme_font_path)
		return false

	var font_res = load(theme_font_path)
	if font_res == null:
		print("[FAIL] Failed to load font resource from: ", theme_font_path)
		return false

	# Verify OFL license file exists
	if not FileAccess.file_exists("res://assets/fonts/OFL.txt"):
		print("[FAIL] OFL license file missing at res://assets/fonts/OFL.txt")
		return false

	# Verify HUD scene controls resolve properly with font available
	var hud_scene = preload("res://scenes/hud.tscn")
	var hud_inst = hud_scene.instantiate()
	if hud_inst == null:
		print("[FAIL] Failed to instantiate hud scene")
		return false

	hud_inst.free()
	print("[PASS] Test 8: Global GUI theme font & license verified")
	return true

