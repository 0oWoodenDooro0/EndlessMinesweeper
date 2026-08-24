class_name HUD
extends CanvasLayer

const SaveManager = preload("res://scripts/save_manager.gd")
const CameraController = preload("res://scripts/camera_controller.gd")

const DIFFICULTIES = [0.10, 0.15, 0.20]
const DIFFICULTY_NAMES = ["Easy (10%)", "Medium (15%)", "Hard (20%)"]

@export var grid_manager: GridManager
@export var camera_controller: CameraController

var revealed_count: int = 0
var flag_count: int = 0
var cleared_chunks_count: int = 0
var locked_chunks_count: int = 0
var elapsed_time: float = 0.0
var is_timer_running: bool = false

var explored_label: Label
var flag_label: Label
var chunk_stats_label: Label
var time_label: Label
var difficulty_option: OptionButton
var save_button: Button
var load_button: Button
var restart_button: Button

var game_over_modal: Control
var game_over_stats_label: Label
var play_again_button: Button

func _ready() -> void:
	setup_ui_nodes()
	if grid_manager == null:
		_auto_find_grid_manager()
	else:
		bind_grid_manager(grid_manager)

func setup_ui_nodes() -> void:
	if has_node("TopBar/MarginContainer/HBoxContainer/ExploredLabel"):
		explored_label = get_node("TopBar/MarginContainer/HBoxContainer/ExploredLabel") as Label
	elif explored_label == null:
		explored_label = Label.new()

	if has_node("TopBar/MarginContainer/HBoxContainer/FlagLabel"):
		flag_label = get_node("TopBar/MarginContainer/HBoxContainer/FlagLabel") as Label
	elif flag_label == null:
		flag_label = Label.new()

	if has_node("TopBar/MarginContainer/HBoxContainer/ChunkStatsLabel"):
		chunk_stats_label = get_node("TopBar/MarginContainer/HBoxContainer/ChunkStatsLabel") as Label
	elif chunk_stats_label == null:
		chunk_stats_label = Label.new()

	if has_node("TopBar/MarginContainer/HBoxContainer/TimeLabel"):
		time_label = get_node("TopBar/MarginContainer/HBoxContainer/TimeLabel") as Label
	elif time_label == null:
		time_label = Label.new()

	if has_node("TopBar/MarginContainer/HBoxContainer/DifficultyOption"):
		difficulty_option = get_node("TopBar/MarginContainer/HBoxContainer/DifficultyOption") as OptionButton
	elif difficulty_option == null:
		difficulty_option = OptionButton.new()

	if has_node("TopBar/MarginContainer/HBoxContainer/SaveButton"):
		save_button = get_node("TopBar/MarginContainer/HBoxContainer/SaveButton") as Button
	elif save_button == null:
		save_button = Button.new()

	if has_node("TopBar/MarginContainer/HBoxContainer/LoadButton"):
		load_button = get_node("TopBar/MarginContainer/HBoxContainer/LoadButton") as Button
	elif load_button == null:
		load_button = Button.new()

	if has_node("TopBar/MarginContainer/HBoxContainer/RestartButton"):
		restart_button = get_node("TopBar/MarginContainer/HBoxContainer/RestartButton") as Button
	elif restart_button == null:
		restart_button = Button.new()

	if has_node("GameOverModal"):
		game_over_modal = get_node("GameOverModal") as Control
	elif game_over_modal == null:
		game_over_modal = Control.new()
		game_over_modal.visible = false

	if has_node("GameOverModal/Panel/VBoxContainer/StatsLabel"):
		game_over_stats_label = get_node("GameOverModal/Panel/VBoxContainer/StatsLabel") as Label
	elif game_over_stats_label == null:
		game_over_stats_label = Label.new()

	if has_node("GameOverModal/Panel/VBoxContainer/PlayAgainButton"):
		play_again_button = get_node("GameOverModal/Panel/VBoxContainer/PlayAgainButton") as Button
	elif play_again_button == null:
		play_again_button = Button.new()

	# Populate difficulty options if empty
	if difficulty_option.item_count == 0:
		for i in range(DIFFICULTY_NAMES.size()):
			difficulty_option.add_item(DIFFICULTY_NAMES[i], i)
		difficulty_option.selected = 1 # Default Medium

	# Wire UI events
	if not difficulty_option.is_connected("item_selected", Callable(self, "set_difficulty_by_index")):
		difficulty_option.connect("item_selected", Callable(self, "set_difficulty_by_index"))
	if not save_button.is_connected("pressed", Callable(self, "on_save_pressed")):
		save_button.connect("pressed", Callable(self, "on_save_pressed"))
	if not load_button.is_connected("pressed", Callable(self, "on_load_pressed")):
		load_button.connect("pressed", Callable(self, "on_load_pressed"))
	if not restart_button.is_connected("pressed", Callable(self, "on_restart_pressed")):
		restart_button.connect("pressed", Callable(self, "on_restart_pressed"))
	if not play_again_button.is_connected("pressed", Callable(self, "on_restart_pressed")):
		play_again_button.connect("pressed", Callable(self, "on_restart_pressed"))

	_update_labels()

func _auto_find_grid_manager() -> void:
	if grid_manager != null:
		return
	if get_parent() != null and get_parent().has_node("GridManager"):
		bind_grid_manager(get_parent().get_node("GridManager") as GridManager)

func bind_grid_manager(grid: GridManager) -> void:
	grid_manager = grid
	if not grid.is_connected("cell_revealed", Callable(self, "_on_cell_revealed")):
		grid.connect("cell_revealed", Callable(self, "_on_cell_revealed"))
	if not grid.is_connected("cell_flag_changed", Callable(self, "_on_cell_flag_changed")):
		grid.connect("cell_flag_changed", Callable(self, "_on_cell_flag_changed"))
	if not grid.is_connected("game_over", Callable(self, "_on_game_over")):
		grid.connect("game_over", Callable(self, "_on_game_over"))
	if not grid.is_connected("game_reset", Callable(self, "_on_game_reset")):
		grid.connect("game_reset", Callable(self, "_on_game_reset"))
	if not grid.is_connected("chunk_locked", Callable(self, "_on_chunk_locked")):
		grid.connect("chunk_locked", Callable(self, "_on_chunk_locked"))
	if not grid.is_connected("chunk_cleared", Callable(self, "_on_chunk_cleared")):
		grid.connect("chunk_cleared", Callable(self, "_on_chunk_cleared"))
	if not grid.is_connected("chunk_unlocked", Callable(self, "_on_chunk_unlocked")):
		grid.connect("chunk_unlocked", Callable(self, "_on_chunk_unlocked"))

func _process(delta: float) -> void:
	if is_timer_running:
		elapsed_time += delta
		_update_time_label()

func format_time(seconds: float) -> String:
	var total_sec = int(floor(seconds))
	var minutes = total_sec / 60
	var secs = total_sec % 60
	return "%02d:%02d" % [minutes, secs]

func _update_labels() -> void:
	if explored_label != null:
		explored_label.text = "Explored: %d" % revealed_count
	if flag_label != null:
		flag_label.text = "Flags: %d" % flag_count
	if chunk_stats_label != null:
		chunk_stats_label.text = "Cleared: %d | Locked: %d" % [cleared_chunks_count, locked_chunks_count]
	_update_time_label()

func _update_time_label() -> void:
	if time_label != null:
		time_label.text = "Time: " + format_time(elapsed_time)

func _on_cell_revealed(_pos: Vector2i, is_mine: bool) -> void:
	if not is_mine:
		revealed_count += 1
		if not is_timer_running:
			is_timer_running = true
		_update_labels()

func _on_cell_flag_changed(_pos: Vector2i, is_flagged: bool) -> void:
	if is_flagged:
		flag_count += 1
	else:
		flag_count = max(0, flag_count - 1)
	_update_labels()

func _on_chunk_locked(_chunk_pos: Vector2i, _mine_pos: Vector2i) -> void:
	locked_chunks_count += 1
	if not is_timer_running:
		is_timer_running = true
	_update_labels()

func _on_chunk_cleared(_chunk_pos: Vector2i) -> void:
	cleared_chunks_count += 1
	_update_labels()

func _on_chunk_unlocked(_chunk_pos: Vector2i, _recovered_flags: Array[Vector2i]) -> void:
	locked_chunks_count = max(0, locked_chunks_count - 1)
	_update_labels()

func _on_game_over(_hit_mine_pos: Vector2i) -> void:
	is_timer_running = false
	show_game_over()

func _on_game_reset() -> void:
	revealed_count = 0
	flag_count = 0
	cleared_chunks_count = 0
	locked_chunks_count = 0
	elapsed_time = 0.0
	is_timer_running = false
	if game_over_modal != null:
		game_over_modal.visible = false
	_update_labels()

func show_game_over() -> void:
	if game_over_stats_label != null:
		game_over_stats_label.text = "Explored: %d cells\nCleared Chunks: %d\nTime: %s" % [revealed_count, cleared_chunks_count, format_time(elapsed_time)]
	if game_over_modal != null:
		game_over_modal.visible = true

func is_game_over_visible() -> bool:
	return game_over_modal != null and game_over_modal.visible

func get_game_over_stats_text() -> String:
	if game_over_stats_label != null:
		return game_over_stats_label.text
	return "Explored: %d cells\nTime: %s" % [revealed_count, format_time(elapsed_time)]

func on_restart_pressed() -> void:
	_on_game_reset()
	if grid_manager != null:
		grid_manager.reset_game()

func set_difficulty_by_index(index: int) -> void:
	if index >= 0 and index < DIFFICULTIES.size():
		var density = DIFFICULTIES[index]
		if grid_manager != null:
			grid_manager.reset_game(density)
		_on_game_reset()
		if difficulty_option != null and difficulty_option.selected != index:
			difficulty_option.selected = index

func serialize() -> Dictionary:
	return {
		"revealed_count": revealed_count,
		"flag_count": flag_count,
		"cleared_chunks_count": cleared_chunks_count,
		"locked_chunks_count": locked_chunks_count,
		"elapsed_time": elapsed_time,
		"is_timer_running": is_timer_running
	}

func deserialize(data: Dictionary) -> bool:
	if data == null or not data.has("revealed_count"):
		return false

	revealed_count = int(data.get("revealed_count", 0))
	flag_count = int(data.get("flag_count", 0))
	cleared_chunks_count = int(data.get("cleared_chunks_count", 0))
	locked_chunks_count = int(data.get("locked_chunks_count", 0))
	elapsed_time = float(data.get("elapsed_time", 0.0))
	is_timer_running = bool(data.get("is_timer_running", false))

	_update_labels()
	return true

func _auto_find_camera_controller() -> CameraController:
	if camera_controller != null:
		return camera_controller
	if get_parent() != null:
		if get_parent().has_node("Camera2D"):
			var cam = get_parent().get_node("Camera2D")
			if cam is CameraController:
				return cam as CameraController
		for child in get_parent().get_children():
			if child is CameraController:
				return child as CameraController
	return null

func on_save_pressed() -> void:
	if grid_manager == null:
		_auto_find_grid_manager()
	var cam = _auto_find_camera_controller()
	var sm = SaveManager.new()
	var success = sm.save_game_state(grid_manager, self, cam)
	if success:
		print("Game saved successfully!")

func on_load_pressed() -> void:
	if grid_manager == null:
		_auto_find_grid_manager()
	var cam = _auto_find_camera_controller()
	var sm = SaveManager.new()
	var success = sm.load_game_state(grid_manager, self, cam)
	if success:
		print("Game loaded successfully!")

