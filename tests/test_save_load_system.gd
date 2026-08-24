@tool
extends SceneTree

const GridManager = preload("res://scripts/grid_manager.gd")
const HUD = preload("res://scripts/hud.gd")
const CameraController = preload("res://scripts/camera_controller.gd")
const SaveManager = preload("res://scripts/save_manager.gd")
const MainScene = preload("res://scenes/main.tscn")

func _init():
	print("--- Running Test Suite: Save & Load System (Auto-Save & Startup Auto-Load) ---")
	var success = true

	# Test 1: SaveManager File I/O & Basic Persistence
	if not test_save_manager_file_io():
		success = false

	# Test 2: GridManager Serialization & Deserialization
	if not test_grid_manager_serialization_and_deserialization():
		success = false

	# Test 3: HUD Serialization & Deserialization
	if not test_hud_serialization_and_deserialization():
		success = false

	# Test 4: CameraController Serialization & Deserialization
	if not test_camera_serialization_and_deserialization():
		success = false

	# Test 5: HUD UI Cleanliness (No Manual Save/Load Buttons)
	if not test_hud_no_manual_save_load_buttons():
		success = false

	# Test 6: Auto-Save Triggered on Gameplay Actions
	if not test_auto_save_on_gameplay_actions():
		success = false

	# Test 7: Startup Auto-Load When Save Exists
	if not test_startup_auto_load():
		success = false

	# Test 8: Error Handling & Corrupted Data Robustness
	if not test_error_handling_and_corrupted_data():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)

func test_save_manager_file_io() -> bool:
	print("[RUN] Test 1: SaveManager File I/O & Basic Persistence")
	var test_path = "user://test_io_save.json"
	var sm = SaveManager.new()

	if sm.has_save(test_path):
		sm.delete_save(test_path)

	if sm.has_save(test_path):
		print("[FAIL] has_save should return false for nonexistent file")
		return false

	var sample_data = {
		"version": 1,
		"title": "Endless Minesweeper Test",
		"number_val": 42
	}

	var save_res = sm.save_data_to_file(sample_data, test_path)
	if not save_res:
		print("[FAIL] save_data_to_file returned false")
		return false

	if not sm.has_save(test_path):
		print("[FAIL] has_save returned false after saving file")
		return false

	var loaded_data = sm.load_data_from_file(test_path)
	if loaded_data == null or typeof(loaded_data) != TYPE_DICTIONARY:
		print("[FAIL] load_data_from_file failed: ", loaded_data)
		sm.delete_save(test_path)
		return false

	if loaded_data.get("version") != 1 or loaded_data.get("number_val") != 42:
		print("[FAIL] Loaded data fields mismatch: ", loaded_data)
		sm.delete_save(test_path)
		return false

	sm.delete_save(test_path)
	print("[PASS] Test 1: SaveManager File I/O verified")
	return true

func test_grid_manager_serialization_and_deserialization() -> bool:
	print("[RUN] Test 2: GridManager Serialization & Deserialization")
	var grid1 = GridManager.new()
	grid1.world_seed = 98765
	grid1.mine_density = 0.25
	grid1.chunk_size = Vector2i(4, 4)
	grid1.safe_zone_radius = 2
	grid1.enable_chunk_lockout = true

	grid1.reveal_cell(Vector2i(5, 5))
	grid1.get_cell(Vector2i(1, 0)).is_revealed = true # Anchor
	grid1.toggle_flag(Vector2i(1, 1))

	var mine_pos = Vector2i(0, 0)
	grid1.set_mine_at(mine_pos, true)
	grid1.get_cell(Vector2i(0, 1)).is_revealed = true # Anchor
	grid1.reveal_cell(mine_pos)

	var chunk0 = grid1.get_chunk(Vector2i(0, 0))
	if not chunk0.is_locked:
		print("[FAIL] Grid1 chunk (0, 0) should be locked")
		grid1.free()
		return false

	var serialized_data = grid1.serialize()
	if serialized_data == null or serialized_data.is_empty():
		print("[FAIL] grid1.serialize() returned empty dictionary")
		grid1.free()
		return false

	var grid2 = GridManager.new()
	grid2.world_seed = 11111
	grid2.mine_density = 0.10
	grid2.chunk_size = Vector2i(8, 8)

	var des_res = grid2.deserialize(serialized_data)
	if not des_res:
		print("[FAIL] grid2.deserialize() returned false")
		grid1.free()
		grid2.free()
		return false

	if grid2.world_seed != 98765 or not is_equal_approx(grid2.mine_density, 0.25):
		print("[FAIL] Deserialized world settings mismatch")
		grid1.free()
		grid2.free()
		return false

	if grid2.chunk_size != Vector2i(4, 4) or grid2.first_click_pos != Vector2i(5, 5):
		print("[FAIL] Deserialized grid metadata mismatch")
		grid1.free()
		grid2.free()
		return false

	var cell_flag = grid2.get_cell(Vector2i(1, 1))
	if not cell_flag.is_flagged:
		print("[FAIL] Deserialized cell (1, 1) should be flagged")
		grid1.free()
		grid2.free()
		return false

	var cell_revealed = grid2.get_cell(Vector2i(5, 5))
	if not cell_revealed.is_revealed:
		print("[FAIL] Deserialized cell (5, 5) should be revealed")
		grid1.free()
		grid2.free()
		return false

	var chunk2_0 = grid2.get_chunk(Vector2i(0, 0))
	if not chunk2_0.is_locked:
		print("[FAIL] Deserialized chunk (0, 0) should be locked")
		grid1.free()
		grid2.free()
		return false

	grid1.free()
	grid2.free()
	print("[PASS] Test 2: GridManager serialization & deserialization verified")
	return true

func test_hud_serialization_and_deserialization() -> bool:
	print("[RUN] Test 3: HUD Serialization & Deserialization")
	var hud1 = HUD.new()
	hud1.setup_ui_nodes()
	hud1.revealed_count = 55
	hud1.flag_count = 12
	hud1.cleared_chunks_count = 4
	hud1.locked_chunks_count = 2
	hud1.elapsed_time = 145.8
	hud1.is_timer_running = true
	hud1.difficulty_option.selected = 2

	var serialized_hud = hud1.serialize()
	if serialized_hud == null or serialized_hud.is_empty():
		print("[FAIL] hud1.serialize() returned empty dictionary")
		hud1.free()
		return false

	var hud2 = HUD.new()
	hud2.setup_ui_nodes()
	var des_res = hud2.deserialize(serialized_hud)
	if not des_res:
		print("[FAIL] hud2.deserialize() returned false")
		hud1.free()
		hud2.free()
		return false

	if hud2.revealed_count != 55 or hud2.flag_count != 12 or hud2.cleared_chunks_count != 4 or hud2.locked_chunks_count != 2:
		print("[FAIL] Deserialized HUD stats mismatch")
		hud1.free()
		hud2.free()
		return false

	if not is_equal_approx(hud2.elapsed_time, 145.8) or hud2.is_timer_running != true:
		print("[FAIL] Deserialized HUD timer mismatch")
		hud1.free()
		hud2.free()
		return false

	if hud2.difficulty_option.selected != 2:
		print("[FAIL] Deserialized difficulty option mismatch: ", hud2.difficulty_option.selected)
		hud1.free()
		hud2.free()
		return false

	hud1.free()
	hud2.free()
	print("[PASS] Test 3: HUD serialization & deserialization verified")
	return true

func test_camera_serialization_and_deserialization() -> bool:
	print("[RUN] Test 4: CameraController Serialization & Deserialization")
	var cam1 = CameraController.new()
	cam1.position = Vector2(250.0, -180.0)
	cam1.target_position = Vector2(300.0, -150.0)
	cam1.zoom = Vector2(1.5, 1.5)
	cam1.target_zoom = Vector2(1.8, 1.8)

	var serialized_cam = cam1.serialize()
	if serialized_cam == null or serialized_cam.is_empty():
		print("[FAIL] cam1.serialize() returned empty dictionary")
		cam1.free()
		return false

	var cam2 = CameraController.new()
	var des_res = cam2.deserialize(serialized_cam)
	if not des_res:
		print("[FAIL] cam2.deserialize() returned false")
		cam1.free()
		cam2.free()
		return false

	if cam2.position != Vector2(250.0, -180.0) or cam2.zoom != Vector2(1.5, 1.5):
		print("[FAIL] Deserialized camera pos/zoom mismatch")
		cam1.free()
		cam2.free()
		return false

	cam1.free()
	cam2.free()
	print("[PASS] Test 4: CameraController serialization & deserialization verified")
	return true

func test_hud_no_manual_save_load_buttons() -> bool:
	print("[RUN] Test 5: HUD UI Cleanliness (No Manual Save/Load Buttons)")
	var hud_scene = preload("res://scenes/hud.tscn")
	var hud_inst = hud_scene.instantiate()
	if hud_inst == null:
		print("[FAIL] Failed to instantiate hud scene")
		return false

	if hud_inst.has_node("TopBar/MarginContainer/HBoxContainer/SaveButton"):
		print("[FAIL] HUD TopBar should NOT have SaveButton")
		hud_inst.free()
		return false

	if hud_inst.has_node("TopBar/MarginContainer/HBoxContainer/LoadButton"):
		print("[FAIL] HUD TopBar should NOT have LoadButton")
		hud_inst.free()
		return false

	hud_inst.free()
	print("[PASS] Test 5: HUD UI cleanliness verified (No Save/Load buttons)")
	return true

func test_auto_save_on_gameplay_actions() -> bool:
	print("[RUN] Test 6: Auto-Save Triggered on Gameplay Actions")
	var sm = SaveManager.new()
	var test_path = "user://test_autosave_action.json"
	if sm.has_save(test_path):
		sm.delete_save(test_path)

	var main = MainScene.instantiate()
	main.save_file_path = test_path
	root.add_child(main)
	# Trigger _ready
	main.save_file_path = test_path

	var grid = main.get_node("GridManager") as GridManager
	grid.chunk_size = Vector2i(4, 4)
	grid.safe_zone_radius = 0
	grid.set_mine_at(Vector2i(10, 9), true)

	# 1. Action: Reveal cell -> should auto-save
	grid.reveal_cell(Vector2i(10, 10))

	if not sm.has_save(test_path):
		print("[FAIL] Auto-save file was not created after reveal_cell")
		main.queue_free()
		return false

	var save_data = sm.load_data_from_file(test_path)
	if save_data == null or not save_data.has("grid"):
		print("[FAIL] Invalid auto-save data: ", save_data)
		sm.delete_save(test_path)
		main.queue_free()
		return false

	# 2. Action: Toggle flag -> should auto-save updated flag
	grid.toggle_flag(Vector2i(10, 11))
	var save_data2 = sm.load_data_from_file(test_path)
	var flag_found = false
	for cell in save_data2["grid"]["cells"]:
		if cell["x"] == 10 and cell["y"] == 11 and cell["is_flagged"]:
			flag_found = true
			break

	if not flag_found:
		print("[FAIL] Flag toggle was not saved to auto-save file")
		sm.delete_save(test_path)
		main.queue_free()
		return false

	# Clean up
	sm.delete_save(test_path)
	main.queue_free()
	print("[PASS] Test 6: Auto-save on gameplay actions verified")
	return true

func test_startup_auto_load() -> bool:
	print("[RUN] Test 7: Startup Auto-Load When Save Exists")
	var sm = SaveManager.new()
	var test_path = "user://test_startup_autoload.json"
	if sm.has_save(test_path):
		sm.delete_save(test_path)

	# 1. Create mock pre-existing save data
	var pre_existing_state = {
		"version": 1,
		"timestamp": 1234567,
		"grid": {
			"world_seed": 77777,
			"mine_density": 0.2,
			"has_first_clicked": true,
			"first_click_pos": [2, 2],
			"is_game_over": false,
			"chunk_size": [4, 4],
			"safe_zone_radius": 1,
			"enable_chunk_lockout": true,
			"cells": [
				{"x": 2, "y": 2, "is_mine": false, "is_revealed": true, "is_flagged": false},
				{"x": 3, "y": 3, "is_mine": true, "is_revealed": false, "is_flagged": true}
			],
			"chunks": [
				{"x": 0, "y": 0, "is_locked": false, "locked_mine_positions": [], "total_safe_cells": 10, "revealed_safe_cells": 1, "is_cleared": false}
			]
		},
		"hud": {
			"revealed_count": 88,
			"flag_count": 5,
			"cleared_chunks_count": 2,
			"locked_chunks_count": 1,
			"elapsed_time": 99.0,
			"is_timer_running": true
		},
		"camera": {
			"position": [500.0, 300.0],
			"target_position": [500.0, 300.0],
			"zoom": [2.0, 2.0],
			"target_zoom": [2.0, 2.0]
		}
	}
	sm.save_data_to_file(pre_existing_state, test_path)

	# 2. Instantiate Main and configure test path before ready
	var main = MainScene.instantiate()
	main.save_file_path = test_path
	root.add_child(main)

	# Check restored state on Main
	var grid = main.get_node("GridManager") as GridManager
	var hud = main.get_node("HUD") as HUD
	var cam = main.get_node("Camera2D") as CameraController

	if grid.world_seed != 77777:
		print("[FAIL] Grid world_seed not auto-loaded on startup: ", grid.world_seed)
		sm.delete_save(test_path)
		main.queue_free()
		return false

	if not grid.get_cell(Vector2i(3, 3)).is_flagged:
		print("[FAIL] Flag at (3, 3) not auto-loaded on startup")
		sm.delete_save(test_path)
		main.queue_free()
		return false

	if hud.revealed_count != 88 or hud.flag_count != 5:
		print("[FAIL] HUD stats not auto-loaded on startup: revealed=", hud.revealed_count)
		sm.delete_save(test_path)
		main.queue_free()
		return false

	if cam.position != Vector2(500.0, 300.0) or cam.zoom != Vector2(2.0, 2.0):
		print("[FAIL] Camera position/zoom not auto-loaded on startup")
		sm.delete_save(test_path)
		main.queue_free()
		return false

	if hud.difficulty_option.selected != 2:
		print("[FAIL] HUD difficulty option not synchronized on startup auto-load: ", hud.difficulty_option.selected)
		sm.delete_save(test_path)
		main.queue_free()
		return false

	# Clean up
	sm.delete_save(test_path)
	main.queue_free()
	print("[PASS] Test 7: Startup auto-load verified")
	return true

func test_error_handling_and_corrupted_data() -> bool:
	print("[RUN] Test 8: Error Handling & Corrupted Data Robustness")
	var sm = SaveManager.new()
	var test_corrupt_path = "user://test_corrupt_save.json"

	var non_existent = sm.load_data_from_file("user://non_existent_file_12345.json")
	if non_existent != null:
		print("[FAIL] load_data_from_file on non-existent file should return null")
		return false

	var grid = GridManager.new()
	var load_fail = sm.load_game_state(grid, null, null, "user://non_existent_file_12345.json")
	if load_fail != false:
		print("[FAIL] load_game_state on non-existent file should return false")
		grid.free()
		return false

	var file = FileAccess.open(test_corrupt_path, FileAccess.WRITE)
	if file != null:
		file.store_string("{ invalid_json: this is not json ... [}")
		file.close()

	var corrupt_data = sm.load_data_from_file(test_corrupt_path)
	if corrupt_data != null:
		print("[FAIL] load_data_from_file on corrupted JSON should return null")
		sm.delete_save(test_corrupt_path)
		grid.free()
		return false

	var load_corrupt_res = sm.load_game_state(grid, null, null, test_corrupt_path)
	if load_corrupt_res != false:
		print("[FAIL] load_game_state on corrupted file should return false")
		sm.delete_save(test_corrupt_path)
		grid.free()
		return false

	sm.delete_save(test_corrupt_path)

	var invalid_grid_data = {"random_field": 123}
	var des_invalid_res = grid.deserialize(invalid_grid_data)
	if des_invalid_res != false:
		print("[FAIL] grid.deserialize on invalid dictionary should return false")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 8: Error handling and corrupted data robustness verified")
	return true
