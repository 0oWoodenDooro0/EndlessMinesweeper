class_name Main
extends Node2D

const SaveManager = preload("res://scripts/save_manager.gd")
const GridManager = preload("res://scripts/grid_manager.gd")
const HUD = preload("res://scripts/hud.gd")
const CameraController = preload("res://scripts/camera_controller.gd")

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

var save_manager: SaveManager = SaveManager.new()
var auto_save_timer: float = 0.0
const AUTO_SAVE_INTERVAL: float = 2.0
var _is_loaded: bool = false

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

	if hud != null and grid_manager != null:
		hud.setup_ui_nodes()
		hud.bind_grid_manager(grid_manager)

func _try_auto_load() -> void:
	if save_manager.has_save(save_file_path):
		var success = save_manager.load_game_state(grid_manager, hud, camera, save_file_path)
		if success:
			_is_loaded = true

func _connect_signals() -> void:
	if grid_manager != null:
		if not grid_manager.is_connected("cell_revealed", Callable(self, "_on_state_changed")):
			grid_manager.connect("cell_revealed", Callable(self, "_on_state_changed"))
		if not grid_manager.is_connected("cell_flag_changed", Callable(self, "_on_state_changed")):
			grid_manager.connect("cell_flag_changed", Callable(self, "_on_state_changed"))
		if not grid_manager.is_connected("chunk_locked", Callable(self, "_on_state_changed")):
			grid_manager.connect("chunk_locked", Callable(self, "_on_state_changed"))
		if not grid_manager.is_connected("chunk_cleared", Callable(self, "_on_state_changed")):
			grid_manager.connect("chunk_cleared", Callable(self, "_on_state_changed"))
		if not grid_manager.is_connected("chunk_unlocked", Callable(self, "_on_state_changed")):
			grid_manager.connect("chunk_unlocked", Callable(self, "_on_state_changed"))
		if not grid_manager.is_connected("game_reset", Callable(self, "_on_game_reset")):
			grid_manager.connect("game_reset", Callable(self, "_on_game_reset"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func _process(delta: float) -> void:
	if hud != null and hud.is_timer_running:
		auto_save_timer += delta
		if auto_save_timer >= AUTO_SAVE_INTERVAL:
			auto_save_timer = 0.0
			save_game()

func save_game() -> void:
	_ensure_node_references()
	if grid_manager != null:
		save_manager.save_game_state(grid_manager, hud, camera, save_file_path)

func _on_state_changed(_a = null, _b = null) -> void:
	save_game()

func _on_game_reset() -> void:
	save_game()
