class_name Main
extends Node2D

const GameSession = preload("res://scripts/game_session.gd")
const SaveManager = preload("res://scripts/save_manager.gd")
const GridManager = preload("res://scripts/grid_manager.gd")
const HUD = preload("res://scripts/hud.gd")
const CameraController = preload("res://scripts/camera_controller.gd")
const InputRouter = preload("res://scripts/input_router.gd")

@export var save_file_path: String = "user://savegame.json":
	set(val):
		save_file_path = val
		_ensure_node_references()
		if not _is_loaded:
			_try_auto_load()
		_connect_signals()

var grid_manager: GridManager
var camera: CameraController
var hud: HUD
var input_router: InputRouter
var session: GameSession = GameSession.new()

var save_manager: SaveManager = SaveManager.new()
var auto_save_timer: float = 0.0
const AUTO_SAVE_INTERVAL: float = 2.0
var _is_loaded: bool = false
var _is_dirty: bool = false

func _enter_tree() -> void:
	_ensure_node_references()
	if not _is_loaded:
		_try_auto_load()
	_connect_signals()

func _ready() -> void:
	_ensure_node_references()
	if not _is_loaded:
		_try_auto_load()
	_connect_signals()
	if camera != null:
		camera.force_update_visible_area()
	if grid_manager != null:
		grid_manager._request_redraw()

func setup(path: String = "") -> void:
	if path != "":
		save_file_path = path
	else:
		_ensure_node_references()
		if not _is_loaded:
			_try_auto_load()
		_connect_signals()

func _ensure_node_references() -> void:
	if grid_manager == null:
		grid_manager = get_node_or_null("GridManager") as GridManager
	if camera == null:
		camera = get_node_or_null("Camera2D") as CameraController
	if hud == null:
		hud = get_node_or_null("HUD") as HUD
	if input_router == null:
		input_router = get_node_or_null("InputRouter") as InputRouter

	if hud != null:
		hud.setup_ui_nodes()
		hud.bind_session(session)
		if grid_manager != null:
			hud.bind_grid_manager(grid_manager)

	if grid_manager != null:
		grid_manager.bind_session(session)

	if input_router != null:
		if grid_manager != null:
			input_router.bind_grid_manager(grid_manager)
		if camera != null:
			input_router.bind_camera_controller(camera)

func _try_auto_load() -> void:
	if save_manager.has_save(save_file_path):
		var success = save_manager.load_game_state(grid_manager, hud, camera, save_file_path)
		if success:
			_is_loaded = true
			if camera != null:
				camera.force_update_visible_area()
			if grid_manager != null:
				grid_manager._request_redraw()

func _connect_signals() -> void:
	if session != null:
		if not session.is_connected("stats_changed", Callable(self, "_on_session_stats_changed")):
			session.connect("stats_changed", Callable(self, "_on_session_stats_changed"))
		if not session.is_connected("game_over", Callable(self, "_on_session_game_over")):
			session.connect("game_over", Callable(self, "_on_session_game_over"))
		if not session.is_connected("game_reset", Callable(self, "_on_session_game_reset")):
			session.connect("game_reset", Callable(self, "_on_session_game_reset"))

	if grid_manager != null:
		if not grid_manager.is_connected("game_reset", Callable(self, "_on_session_game_reset")):
			grid_manager.connect("game_reset", Callable(self, "_on_session_game_reset"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST \
		or what == NOTIFICATION_APPLICATION_PAUSED \
		or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
		or what == NOTIFICATION_WM_GO_BACK_REQUEST \
		or what == NOTIFICATION_PREDELETE:
		if _is_dirty:
			save_game()

func save_game() -> void:
	_ensure_node_references()
	if grid_manager != null:
		save_manager.save_game_state(grid_manager, hud, camera, save_file_path)
		_is_dirty = false

func _on_session_stats_changed(_stats: Dictionary = {}) -> void:
	_is_dirty = true

func _on_session_game_over(_hit_pos: Vector2i = Vector2i.ZERO) -> void:
	if input_router != null:
		input_router.is_game_over = true
	save_game()

func _on_session_game_reset() -> void:
	if input_router != null:
		input_router.is_game_over = false
		input_router.reset_state()
	save_game()
