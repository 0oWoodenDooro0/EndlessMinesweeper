@tool
extends SceneTree

const GridManager = preload("res://scripts/grid_manager.gd")
const HUD = preload("res://scripts/hud.gd")
const CameraController = preload("res://scripts/camera_controller.gd")
const SaveManager = preload("res://scripts/save_manager.gd")

func _init():
	print("--- Running Test Suite: Save & Load System ---")
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

	# Test 5: End-to-End Game State Save, Load & Gameplay Resumption
	if not test_end_to_end_game_state_save_and_load():
		success = false

	# Test 6: Error Handling & Corrupted Data Robustness
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

	# Clean up any leftover test file
	if sm.has_save(test_path):
		sm.delete_save(test_path)

	if sm.has_save(test_path):
		print("[FAIL] has_save should return false for nonexistent file")
		return false

	var sample_data = {
		"version": 1,
		"title": "Endless Minesweeper Test",
		"number_val": 42,
		"nested": {
			"key": "value",
			"arr": [1, 2, 3]
		}
	}

	# 1. Save data to file
	var save_res = sm.save_data_to_file(sample_data, test_path)
	if not save_res:
		print("[FAIL] save_data_to_file returned false")
		return false

	if not sm.has_save(test_path):
		print("[FAIL] has_save returned false after saving file")
		return false

	# 2. Load data from file
	var loaded_data = sm.load_data_from_file(test_path)
	if loaded_data == null or typeof(loaded_data) != TYPE_DICTIONARY:
		print("[FAIL] load_data_from_file failed or returned non-dictionary: ", loaded_data)
		sm.delete_save(test_path)
		return false

	if loaded_data.get("version") != 1 or loaded_data.get("number_val") != 42:
		print("[FAIL] Loaded data fields mismatch: ", loaded_data)
		sm.delete_save(test_path)
		return false

	if loaded_data.get("nested", {}).get("key") != "value":
		print("[FAIL] Nested loaded data mismatch: ", loaded_data)
		sm.delete_save(test_path)
		return false

	# 3. Delete file
	var del_res = sm.delete_save(test_path)
	if not del_res or sm.has_save(test_path):
		print("[FAIL] delete_save failed to delete test file")
		return false

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

	# Set first click to establish safe zone
	grid1.set_first_click(Vector2i(5, 5))

	# Modify specific cells and chunks
	# Flag cell (1, 1)
	grid1.toggle_flag(Vector2i(1, 1))
	# Reveal safe cell (5, 5)
	grid1.reveal_cell(Vector2i(5, 5))

	# Configure chunk (0, 0) with a mine hit to trigger lockout
	var mine_pos = Vector2i(0, 0)
	grid1.set_mine_at(mine_pos, true)
	grid1.reveal_cell(mine_pos)

	var chunk0 = grid1.get_chunk(Vector2i(0, 0))
	if not chunk0.is_locked:
		print("[FAIL] Grid1 chunk (0, 0) should be locked")
		grid1.free()
		return false

	# Serialize Grid1
	var serialized_data = grid1.serialize()
	if serialized_data == null or serialized_data.is_empty():
		print("[FAIL] grid1.serialize() returned empty dictionary")
		grid1.free()
		return false

	# Create fresh Grid2 with default/different values
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

	# Verify properties
	if grid2.world_seed != 98765:
		print("[FAIL] Deserialized world_seed mismatch: ", grid2.world_seed)
		grid1.free()
		grid2.free()
		return false

	if not is_equal_approx(grid2.mine_density, 0.25):
		print("[FAIL] Deserialized mine_density mismatch: ", grid2.mine_density)
		grid1.free()
		grid2.free()
		return false

	if grid2.chunk_size != Vector2i(4, 4):
		print("[FAIL] Deserialized chunk_size mismatch: ", grid2.chunk_size)
		grid1.free()
		grid2.free()
		return false

	if grid2.has_first_clicked != true or grid2.first_click_pos != Vector2i(5, 5):
		print("[FAIL] Deserialized first click info mismatch")
		grid1.free()
		grid2.free()
		return false

	# Verify cell states
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

	# Verify chunk lockout state
	var chunk2_0 = grid2.get_chunk(Vector2i(0, 0))
	if not chunk2_0.is_locked:
		print("[FAIL] Deserialized chunk (0, 0) should be locked")
		grid1.free()
		grid2.free()
		return false

	if not chunk2_0.locked_mine_positions.has(mine_pos):
		print("[FAIL] Deserialized chunk (0, 0) locked_mine_positions missing hit mine: ", chunk2_0.locked_mine_positions)
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

	if hud2.revealed_count != 55:
		print("[FAIL] Deserialized revealed_count mismatch: ", hud2.revealed_count)
		hud1.free()
		hud2.free()
		return false

	if hud2.flag_count != 12:
		print("[FAIL] Deserialized flag_count mismatch: ", hud2.flag_count)
		hud1.free()
		hud2.free()
		return false

	if hud2.cleared_chunks_count != 4 or hud2.locked_chunks_count != 2:
		print("[FAIL] Deserialized chunk counts mismatch: cleared=", hud2.cleared_chunks_count, " locked=", hud2.locked_chunks_count)
		hud1.free()
		hud2.free()
		return false

	if not is_equal_approx(hud2.elapsed_time, 145.8):
		print("[FAIL] Deserialized elapsed_time mismatch: ", hud2.elapsed_time)
		hud1.free()
		hud2.free()
		return false

	if hud2.is_timer_running != true:
		print("[FAIL] Deserialized is_timer_running should be true")
		hud1.free()
		hud2.free()
		return false

	if hud2.time_label.text != "Time: 02:25":
		print("[FAIL] Deserialized time_label text mismatch: ", hud2.time_label.text)
		hud1.free()
		hud2.free()
		return false

	if hud2.chunk_stats_label.text != "Cleared: 4 | Locked: 2":
		print("[FAIL] Deserialized chunk_stats_label mismatch: ", hud2.chunk_stats_label.text)
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

	if cam2.position != Vector2(250.0, -180.0) or cam2.target_position != Vector2(300.0, -150.0):
		print("[FAIL] Deserialized camera position mismatch: pos=", cam2.position, " target=", cam2.target_position)
		cam1.free()
		cam2.free()
		return false

	if cam2.zoom != Vector2(1.5, 1.5) or cam2.target_zoom != Vector2(1.8, 1.8):
		print("[FAIL] Deserialized camera zoom mismatch: zoom=", cam2.zoom, " target=", cam2.target_zoom)
		cam1.free()
		cam2.free()
		return false

	cam1.free()
	cam2.free()
	print("[PASS] Test 4: CameraController serialization & deserialization verified")
	return true

func test_end_to_end_game_state_save_and_load() -> bool:
	print("[RUN] Test 5: End-to-End Game State Save, Load & Gameplay Resumption")
	var test_path = "user://test_e2e_game_save.json"
	var sm = SaveManager.new()

	if sm.has_save(test_path):
		sm.delete_save(test_path)

	# 1. Setup active game environment
	var grid = GridManager.new()
	grid.chunk_size = Vector2i(2, 2)
	grid.mine_density = 1.0 # High density so outer unconfigured cells are mines
	grid.set_first_click(Vector2i(100, 100))

	var hud = HUD.new()
	hud.setup_ui_nodes()
	hud.bind_grid_manager(grid)

	var cam = CameraController.new()
	cam.position = Vector2(100.0, 50.0)
	cam.target_position = Vector2(100.0, 50.0)
	cam.zoom = Vector2(1.2, 1.2)
	cam.target_zoom = Vector2(1.2, 1.2)

	# 2. Perform gameplay actions:
	# Center chunk (0, 0) has mine at (0, 0) and 3 safe cells
	var mine_pos = Vector2i(0, 0)
	grid.set_mine_at(mine_pos, true)
	grid.set_mine_at(Vector2i(1, 0), false)
	grid.set_mine_at(Vector2i(0, 1), false)
	grid.set_mine_at(Vector2i(1, 1), false)

	# Trigger lock on (0, 0)
	grid.reveal_cell(mine_pos)

	# Setup 8 neighbor chunks around (0, 0)
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

	# Clear first 4 neighbor chunks
	for i in range(4):
		var c_pos = neighbor_chunks[i]
		grid.reveal_cell(Vector2i(c_pos.x * 2 + 1, c_pos.y * 2))
		grid.reveal_cell(Vector2i(c_pos.x * 2, c_pos.y * 2 + 1))
		grid.reveal_cell(Vector2i(c_pos.x * 2 + 1, c_pos.y * 2 + 1))

	# Advance timer
	hud._process(30.0)

	if hud.cleared_chunks_count != 4 or hud.locked_chunks_count != 1:
		print("[FAIL] Initial gameplay stats mismatch: cleared=", hud.cleared_chunks_count, " locked=", hud.locked_chunks_count)
		grid.free()
		hud.free()
		cam.free()
		return false

	# 3. Save Game State to test file
	var save_res = sm.save_game_state(grid, hud, cam, test_path)
	if not save_res:
		print("[FAIL] sm.save_game_state returned false")
		grid.free()
		hud.free()
		cam.free()
		return false

	# 4. Reset / Destroy active game
	grid.reset_game()
	hud._on_game_reset()
	cam.position = Vector2.ZERO
	cam.zoom = Vector2(1.0, 1.0)

	if hud.cleared_chunks_count != 0 or hud.locked_chunks_count != 0:
		print("[FAIL] Stats not reset after game reset")
		grid.free()
		hud.free()
		cam.free()
		sm.delete_save(test_path)
		return false

	# 5. Load Game State from file
	var load_res = sm.load_game_state(grid, hud, cam, test_path)
	if not load_res:
		print("[FAIL] sm.load_game_state returned false")
		grid.free()
		hud.free()
		cam.free()
		sm.delete_save(test_path)
		return false

	# Verify state was accurately restored
	if hud.cleared_chunks_count != 4 or hud.locked_chunks_count != 1:
		print("[FAIL] Restored HUD stats mismatch: cleared=", hud.cleared_chunks_count, " locked=", hud.locked_chunks_count)
		grid.free()
		hud.free()
		cam.free()
		sm.delete_save(test_path)
		return false

	var restored_center_chunk = grid.get_chunk(Vector2i(0, 0))
	if not restored_center_chunk.is_locked:
		print("[FAIL] Restored center chunk should be locked")
		grid.free()
		hud.free()
		cam.free()
		sm.delete_save(test_path)
		return false

	# 6. Resume gameplay on loaded state: clear the remaining 4 neighbor chunks
	for i in range(4, 8):
		var c_pos = neighbor_chunks[i]
		grid.reveal_cell(Vector2i(c_pos.x * 2 + 1, c_pos.y * 2))
		grid.reveal_cell(Vector2i(c_pos.x * 2, c_pos.y * 2 + 1))
		grid.reveal_cell(Vector2i(c_pos.x * 2 + 1, c_pos.y * 2 + 1))

	# All 8 neighbors cleared -> center chunk should be unlocked and recovered
	if restored_center_chunk.is_locked:
		print("[FAIL] Center chunk should have unlocked after clearing remaining neighbors on resumed game")
		grid.free()
		hud.free()
		cam.free()
		sm.delete_save(test_path)
		return false

	var mine_cell = grid.get_cell(mine_pos)
	if not mine_cell.is_flagged:
		print("[FAIL] Locked mine was not recovered to flag upon unlocking")
		grid.free()
		hud.free()
		cam.free()
		sm.delete_save(test_path)
		return false

	sm.delete_save(test_path)
	grid.free()
	hud.free()
	cam.free()
	print("[PASS] Test 5: End-to-end save, load & gameplay resumption verified")
	return true

func test_error_handling_and_corrupted_data() -> bool:
	print("[RUN] Test 6: Error Handling & Corrupted Data Robustness")
	var sm = SaveManager.new()
	var test_corrupt_path = "user://test_corrupt_save.json"

	# 1. Loading nonexistent file
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

	# 2. Corrupted JSON file
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

	# 3. Deserializing invalid dictionary (missing required fields)
	var invalid_grid_data = {"random_field": 123}
	var des_invalid_res = grid.deserialize(invalid_grid_data)
	if des_invalid_res != false:
		print("[FAIL] grid.deserialize on invalid dictionary should return false")
		grid.free()
		return false

	grid.free()
	print("[PASS] Test 6: Error handling and corrupted data robustness verified")
	return true
