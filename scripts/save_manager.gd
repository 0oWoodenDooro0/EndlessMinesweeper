class_name SaveManager
extends RefCounted

const DEFAULT_SAVE_PATH = "user://savegame.json"

func save_data_to_file(data: Dictionary, filepath: String = DEFAULT_SAVE_PATH) -> bool:
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		return false
	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	return true

func load_data_from_file(filepath: String = DEFAULT_SAVE_PATH) -> Variant:
	if not FileAccess.file_exists(filepath):
		return null
	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return null
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	var parse_result = json.parse(content)
	if parse_result != OK:
		return null
	return json.data

func has_save(filepath: String = DEFAULT_SAVE_PATH) -> bool:
	return FileAccess.file_exists(filepath)

func delete_save(filepath: String = DEFAULT_SAVE_PATH) -> bool:
	if not FileAccess.file_exists(filepath):
		return true
	return DirAccess.remove_absolute(filepath) == OK

func save_game_state(grid: GridManager, hud: HUD = null, camera: CameraController = null, filepath: String = DEFAULT_SAVE_PATH) -> bool:
	if grid == null:
		return false

	var state = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"grid": grid.serialize()
	}

	if hud != null:
		state["hud"] = hud.serialize()

	if camera != null:
		state["camera"] = camera.serialize()

	return save_data_to_file(state, filepath)

func load_game_state(grid: GridManager, hud: HUD = null, camera: CameraController = null, filepath: String = DEFAULT_SAVE_PATH) -> bool:
	var data = load_data_from_file(filepath)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		return false

	if not data.has("grid") or typeof(data["grid"]) != TYPE_DICTIONARY:
		return false

	if grid == null:
		return false

	var grid_success = grid.deserialize(data["grid"])
	if not grid_success:
		return false

	if hud != null and data.has("hud") and typeof(data["hud"]) == TYPE_DICTIONARY:
		hud.deserialize(data["hud"])
		if grid != null:
			hud.sync_difficulty_with_density(grid.mine_density)

	if camera != null and data.has("camera") and typeof(data["camera"]) == TYPE_DICTIONARY:
		camera.deserialize(data["camera"])

	return true
