class_name InputRouter
extends Node

const GridManager = preload("res://scripts/grid_manager.gd")
const CameraController = preload("res://scripts/camera_controller.gd")

signal cell_reveal_requested(cell_pos: Vector2i)
signal cell_flag_toggled(cell_pos: Vector2i)
signal cell_chord_requested(cell_pos: Vector2i)
signal camera_pan_requested(relative: Vector2)
signal camera_zoom_step_requested(direction: int)
signal camera_pinch_zoom_requested(factor: float)

@export var cell_size: Vector2i = Vector2i(32, 32)
@export var drag_threshold: float = 16.0
@export var long_press_duration: float = 0.15
@export var is_enabled: bool = true
@export var is_game_over: bool = false

var is_cell_revealed_query: Callable = Callable()

var _is_right_mouse_down: bool = false
var _right_mouse_dragged: bool = false
var _right_mouse_press_pos: Vector2 = Vector2.ZERO
var _right_mouse_press_cell: Vector2i = Vector2i.ZERO

var _is_middle_mouse_down: bool = false
var _middle_mouse_dragged: bool = false
var _middle_mouse_press_pos: Vector2 = Vector2.ZERO
var _middle_mouse_press_cell: Vector2i = Vector2i.ZERO

var _last_mouse_world_pos: Vector2 = Vector2.ZERO

var _touch_points: Dictionary = {} # index -> Vector2
var _is_single_touch_active: bool = false
var _touch_press_pos: Vector2 = Vector2.ZERO
var _touch_press_cell: Vector2i = Vector2i.ZERO
var _touch_press_cell_was_revealed: bool = false
var _touch_hold_time: float = 0.0
var _touch_dragged: bool = false
var _touch_long_pressed: bool = false
var _is_multi_touch_active: bool = false
var _pinch_previous_dist: float = -1.0
var _pinch_previous_center: Vector2 = Vector2.ZERO
var _last_touch_time_msec: int = -999999

func bind_grid_manager(grid: GridManager) -> void:
	if grid == null:
		return
	if not cell_reveal_requested.is_connected(grid.reveal_cell):
		cell_reveal_requested.connect(grid.reveal_cell)
	if not cell_flag_toggled.is_connected(grid.toggle_flag):
		cell_flag_toggled.connect(grid.toggle_flag)
	if not cell_chord_requested.is_connected(grid.chord_reveal):
		cell_chord_requested.connect(grid.chord_reveal)
	if not is_cell_revealed_query.is_valid():
		is_cell_revealed_query = Callable(grid, "is_cell_revealed")

func bind_camera_controller(camera: CameraController) -> void:
	if camera == null:
		return
	if not camera_pan_requested.is_connected(camera.pan_by):
		camera_pan_requested.connect(camera.pan_by)
	if not camera_zoom_step_requested.is_connected(camera.apply_zoom_step):
		camera_zoom_step_requested.connect(camera.apply_zoom_step)
	if not camera_pinch_zoom_requested.is_connected(camera.apply_pinch_zoom):
		camera_pinch_zoom_requested.connect(camera.apply_pinch_zoom)

func reset_state() -> void:
	_is_right_mouse_down = false
	_right_mouse_dragged = false
	_right_mouse_press_pos = Vector2.ZERO
	_right_mouse_press_cell = Vector2i.ZERO
	_is_middle_mouse_down = false
	_middle_mouse_dragged = false
	_middle_mouse_press_pos = Vector2.ZERO
	_middle_mouse_press_cell = Vector2i.ZERO
	_last_mouse_world_pos = Vector2.ZERO

	_touch_points.clear()
	_is_single_touch_active = false
	_touch_press_pos = Vector2.ZERO
	_touch_press_cell = Vector2i.ZERO
	_touch_press_cell_was_revealed = false
	_touch_hold_time = 0.0
	_touch_dragged = false
	_touch_long_pressed = false
	_is_multi_touch_active = false
	_pinch_previous_dist = -1.0
	_pinch_previous_center = Vector2.ZERO
	_last_touch_time_msec = -999999

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / float(cell_size.x))), int(floor(world_pos.y / float(cell_size.y))))

func _is_cell_revealed(pos: Vector2i) -> bool:
	if is_cell_revealed_query.is_valid():
		return is_cell_revealed_query.call(pos)
	return false

func _get_mouse_world_pos(event: InputEventMouse) -> Vector2:
	if is_inside_tree() and get_viewport() != null:
		var canvas_transform = get_viewport().get_canvas_transform()
		return canvas_transform.affine_inverse() * event.position
	return event.position

func _get_current_mouse_world_pos(event: InputEvent = null) -> Vector2:
	if is_inside_tree() and get_viewport() != null:
		var canvas_transform = get_viewport().get_canvas_transform()
		var mouse_pos = get_viewport().get_mouse_position()
		return canvas_transform.affine_inverse() * mouse_pos
	if event is InputEventMouse:
		return _get_mouse_world_pos(event)
	return _last_mouse_world_pos

func _get_touch_world_pos(screen_pos: Vector2) -> Vector2:
	if is_inside_tree() and get_viewport() != null:
		var canvas_transform = get_viewport().get_canvas_transform()
		return canvas_transform.affine_inverse() * screen_pos
	return screen_pos

func process_frame(delta: float) -> void:
	if not is_enabled or is_game_over:
		return
	if _is_single_touch_active and not _touch_dragged and not _touch_long_pressed:
		_touch_hold_time += delta
		if _touch_hold_time >= long_press_duration:
			_touch_long_pressed = true
			if not _touch_press_cell_was_revealed:
				cell_flag_toggled.emit(_touch_press_cell)
				if Input.has_method("vibrate_handheld"):
					Input.vibrate_handheld(50)

func _process(delta: float) -> void:
	process_frame(delta)

func process_input(event: InputEvent) -> void:
	_unhandled_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if not is_enabled or is_game_over:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event.is_action_pressed("reveal_cell") and not event.is_echo():
		var world_pos = _get_current_mouse_world_pos(event)
		var cell_pos = world_to_cell(world_pos)
		if _is_cell_revealed(cell_pos):
			cell_chord_requested.emit(cell_pos)
		else:
			cell_reveal_requested.emit(cell_pos)
	elif event.is_action_pressed("flag_cell") and not event.is_echo():
		var world_pos = _get_current_mouse_world_pos(event)
		var cell_pos = world_to_cell(world_pos)
		cell_flag_toggled.emit(cell_pos)
	elif event.is_action_pressed("zoom_in"):
		camera_zoom_step_requested.emit(1)
	elif event.is_action_pressed("zoom_out"):
		camera_zoom_step_requested.emit(-1)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	_last_touch_time_msec = Time.get_ticks_msec()
	if event.pressed:
		_touch_points[event.index] = event.position
		if _touch_points.size() == 1 and event.index == 0:
			_is_single_touch_active = true
			_touch_press_pos = event.position
			var world_pos = _get_touch_world_pos(event.position)
			_touch_press_cell = world_to_cell(world_pos)
			_touch_press_cell_was_revealed = _is_cell_revealed(_touch_press_cell)
			_touch_hold_time = 0.0
			_touch_dragged = false
			_touch_long_pressed = false
			_is_multi_touch_active = false
		elif _touch_points.size() >= 2:
			_is_single_touch_active = false
			_is_multi_touch_active = true
			if _touch_points.has(0) and _touch_points.has(1):
				_pinch_previous_dist = _touch_points[0].distance_to(_touch_points[1])
				_pinch_previous_center = (_touch_points[0] + _touch_points[1]) / 2.0
	else:
		if _touch_points.has(event.index):
			_touch_points.erase(event.index)

		if event.index == 0 and _is_single_touch_active:
			if not _touch_dragged and not _touch_long_pressed:
				if _touch_press_cell_was_revealed:
					cell_chord_requested.emit(_touch_press_cell)
				else:
					cell_reveal_requested.emit(_touch_press_cell)
			_is_single_touch_active = false
			_touch_dragged = false
			_touch_long_pressed = false

		if _touch_points.size() < 2:
			_is_multi_touch_active = false
			_pinch_previous_dist = -1.0

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_last_touch_time_msec = Time.get_ticks_msec()
	if _touch_points.has(event.index):
		_touch_points[event.index] = event.position

	if _touch_points.size() == 1 and event.index == 0 and _is_single_touch_active:
		if not _touch_dragged:
			if event.position.distance_to(_touch_press_pos) > drag_threshold or _touch_long_pressed:
				_touch_dragged = true
		if _touch_dragged or _touch_long_pressed:
			camera_pan_requested.emit(event.relative)
	elif _touch_points.size() >= 2 and _is_multi_touch_active:
		if _touch_points.has(0) and _touch_points.has(1):
			var p0 = _touch_points[0]
			var p1 = _touch_points[1]
			var curr_dist = p0.distance_to(p1)
			var curr_center = (p0 + p1) / 2.0
			if _pinch_previous_dist > 0.0 and curr_dist > 0.0:
				var factor = curr_dist / _pinch_previous_dist
				camera_pinch_zoom_requested.emit(factor)
				var center_delta = curr_center - _pinch_previous_center
				camera_pan_requested.emit(center_delta)
			_pinch_previous_dist = curr_dist
			_pinch_previous_center = curr_center

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if _is_single_touch_active or _is_multi_touch_active or (_last_touch_time_msec > 0 and Time.get_ticks_msec() - _last_touch_time_msec < 250):
		return
	var world_pos = _get_mouse_world_pos(event)
	_last_mouse_world_pos = world_pos
	var cell_pos = world_to_cell(world_pos)
	if event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				cell_chord_requested.emit(cell_pos)
			else:
				cell_reveal_requested.emit(cell_pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_is_right_mouse_down = true
			_right_mouse_dragged = false
			_right_mouse_press_pos = event.position
			_right_mouse_press_cell = cell_pos
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_middle_mouse_down = true
			_middle_mouse_dragged = false
			_middle_mouse_press_pos = event.position
			_middle_mouse_press_cell = cell_pos
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_zoom_step_requested.emit(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_zoom_step_requested.emit(-1)
	else:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if _is_right_mouse_down and not _right_mouse_dragged:
				cell_flag_toggled.emit(_right_mouse_press_cell)
			_is_right_mouse_down = false
			_right_mouse_dragged = false
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if _is_middle_mouse_down and not _middle_mouse_dragged:
				cell_chord_requested.emit(_middle_mouse_press_cell)
			_is_middle_mouse_down = false
			_middle_mouse_dragged = false

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var world_pos = _get_mouse_world_pos(event)
	_last_mouse_world_pos = world_pos

	if _is_right_mouse_down and not _right_mouse_dragged:
		if event.position.distance_to(_right_mouse_press_pos) > drag_threshold:
			_right_mouse_dragged = true
	if _is_middle_mouse_down and not _middle_mouse_dragged:
		if event.position.distance_to(_middle_mouse_press_pos) > drag_threshold:
			_middle_mouse_dragged = true

	if _is_right_mouse_down or _is_middle_mouse_down:
		camera_pan_requested.emit(event.relative)
