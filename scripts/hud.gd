class_name HUD
extends CanvasLayer

const GameSession = preload("res://scripts/game_session.gd")
const SaveManager = preload("res://scripts/save_manager.gd")
const CameraController = preload("res://scripts/camera_controller.gd")

@export var grid_manager: GridManager
@export var camera_controller: CameraController

var session: GameSession = GameSession.new()

var revealed_count: int:
	get:
		return session.revealed_count if session != null else 0
	set(val):
		if session != null:
			session.revealed_count = val
			_update_labels()

var flag_count: int:
	get:
		return session.flag_count if session != null else 0
	set(val):
		if session != null:
			session.flag_count = val
			_update_labels()

var cleared_chunks_count: int:
	get:
		return session.cleared_chunks_count if session != null else 0
	set(val):
		if session != null:
			session.cleared_chunks_count = val
			_update_labels()

var locked_chunks_count: int:
	get:
		return session.locked_chunks_count if session != null else 0
	set(val):
		if session != null:
			session.locked_chunks_count = val
			_update_labels()

var elapsed_time: float:
	get:
		return session.elapsed_time if session != null else 0.0
	set(val):
		if session != null:
			session.elapsed_time = val
			_update_time_label()

var is_timer_running: bool:
	get:
		return session.is_timer_running if session != null else false
	set(val):
		if session != null:
			session.is_timer_running = val

var explored_label: Label
var flag_label: Label
var chunk_stats_label: Label
var time_label: Label
var restart_button: Button

var game_over_modal: Control
var game_over_stats_label: Label
var play_again_button: Button

func _init() -> void:
	_connect_session_signals()

func _ready() -> void:
	setup_ui_nodes()
	_connect_session_signals()
	if grid_manager == null:
		_auto_find_grid_manager()
	else:
		bind_grid_manager(grid_manager)

func setup_ui_nodes() -> void:
	_connect_session_signals()

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

	# Wire UI events
	if not restart_button.is_connected("pressed", Callable(self, "on_restart_pressed")):
		restart_button.connect("pressed", Callable(self, "on_restart_pressed"))
	if not play_again_button.is_connected("pressed", Callable(self, "on_restart_pressed")):
		play_again_button.connect("pressed", Callable(self, "on_restart_pressed"))

	_update_labels()

func bind_session(new_session: GameSession) -> void:
	if session != null and session != new_session:
		_disconnect_session_signals()
	session = new_session
	_connect_session_signals()
	if grid_manager != null and grid_manager.session != session:
		grid_manager.bind_session(session)
	_update_labels()

func _connect_session_signals() -> void:
	if session == null:
		return
	if not session.is_connected("stats_changed", Callable(self, "_on_session_stats_changed")):
		session.connect("stats_changed", Callable(self, "_on_session_stats_changed"))
	if not session.is_connected("game_over", Callable(self, "_on_session_game_over")):
		session.connect("game_over", Callable(self, "_on_session_game_over"))
	if not session.is_connected("game_reset", Callable(self, "_on_session_game_reset")):
		session.connect("game_reset", Callable(self, "_on_session_game_reset"))

func _disconnect_session_signals() -> void:
	if session == null:
		return
	if session.is_connected("stats_changed", Callable(self, "_on_session_stats_changed")):
		session.disconnect("stats_changed", Callable(self, "_on_session_stats_changed"))
	if session.is_connected("game_over", Callable(self, "_on_session_game_over")):
		session.disconnect("game_over", Callable(self, "_on_session_game_over"))
	if session.is_connected("game_reset", Callable(self, "_on_session_game_reset")):
		session.disconnect("game_reset", Callable(self, "_on_session_game_reset"))

func _auto_find_grid_manager() -> void:
	if grid_manager != null:
		return
	if get_parent() != null and get_parent().has_node("GridManager"):
		bind_grid_manager(get_parent().get_node("GridManager") as GridManager)

func bind_grid_manager(grid: GridManager) -> void:
	grid_manager = grid
	if grid_manager != null:
		grid_manager.bind_session(session)

func _process(delta: float) -> void:
	if session != null and session.is_timer_running:
		session.update(delta)
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

func _on_session_stats_changed(_stats: Dictionary) -> void:
	_update_labels()

func _on_session_game_over(_hit_mine_pos: Vector2i) -> void:
	show_game_over()

func _on_session_game_reset() -> void:
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
	if session != null:
		session.reset()
	if grid_manager != null:
		grid_manager.reset_game()

func serialize() -> Dictionary:
	return session.serialize() if session != null else {}

func deserialize(data: Dictionary) -> bool:
	if data == null or not data.has("revealed_count"):
		return false

	var success = session.deserialize(data) if session != null else false
	if not success:
		return false

	_update_labels()
	return true
