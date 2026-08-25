class_name CameraController
extends Camera2D

const GridRenderer = preload("res://scripts/grid_renderer.gd")

@export var min_zoom: float = 0.2
@export var max_zoom: float = 8.0
@export var zoom_step: float = 0.15
@export var zoom_smoothness: float = 15.0
@export var pan_smoothness: float = 20.0
@export var grid_manager: GridManager
@export var grid_renderer: GridRenderer

var target_zoom: Vector2 = Vector2(1.0, 1.0)
var target_position: Vector2 = Vector2.ZERO
var is_panning: bool = false
var custom_viewport_size: Vector2 = Vector2.ZERO

var _last_notified_position: Vector2 = Vector2.INF
var _last_notified_zoom: Vector2 = Vector2.INF

func _ready() -> void:
	target_position = position
	target_zoom = zoom
	_auto_find_grid_manager()
	if is_inside_tree() and get_viewport() != null:
		if not get_viewport().size_changed.is_connected(Callable(self, "_on_viewport_size_changed")):
			get_viewport().size_changed.connect(Callable(self, "_on_viewport_size_changed"))
	force_update_visible_area()

func _on_viewport_size_changed() -> void:
	force_update_visible_area()

func force_update_visible_area() -> void:
	_last_notified_position = Vector2.INF
	_last_notified_zoom = Vector2.INF
	_notify_grid_manager()

func _auto_find_grid_manager() -> void:
	if get_parent() != null:
		if grid_manager == null:
			if get_parent().has_node("GridManager"):
				grid_manager = get_parent().get_node("GridManager") as GridManager
			elif get_parent() is GridManager:
				grid_manager = get_parent() as GridManager
		if grid_renderer == null:
			if get_parent().has_node("GridRenderer"):
				grid_renderer = get_parent().get_node("GridRenderer") as GridRenderer
			elif get_parent() is GridRenderer:
				grid_renderer = get_parent() as GridRenderer

func apply_zoom_step(direction: int) -> void:
	var factor = 1.0 + (zoom_step * direction)
	var new_zoom_val = clamp(target_zoom.x * factor, min_zoom, max_zoom)
	target_zoom = Vector2(new_zoom_val, new_zoom_val)

func apply_pinch_zoom(factor: float) -> void:
	var new_zoom_val = clamp(target_zoom.x * factor, min_zoom, max_zoom)
	target_zoom = Vector2(new_zoom_val, new_zoom_val)

func pan_by(relative: Vector2) -> void:
	var current_zoom_val = zoom.x if zoom.x > 0 else 1.0
	target_position -= relative / current_zoom_val

func _process(delta: float) -> void:
	update_camera(delta)

func update_camera(delta: float) -> void:
	if delta > 0.0:
		zoom = zoom.lerp(target_zoom, min(1.0, zoom_smoothness * delta))
		position = position.lerp(target_position, min(1.0, pan_smoothness * delta))

		if position.distance_to(target_position) < 0.01:
			position = target_position
		if (zoom - target_zoom).length() < 0.001:
			zoom = target_zoom
	else:
		zoom = target_zoom
		position = target_position

	if not position.is_equal_approx(_last_notified_position) or not zoom.is_equal_approx(_last_notified_zoom):
		_notify_grid_manager()

func _notify_grid_manager() -> void:
	_last_notified_position = position
	_last_notified_zoom = zoom
	var current_zoom_val = zoom.x if zoom.x > 0 else 1.0
	var v_rect = get_visible_world_rect()
	if grid_renderer != null:
		grid_renderer.update_visible_area(v_rect, current_zoom_val)
	elif grid_manager != null:
		grid_manager.update_visible_area(v_rect, current_zoom_val)

func get_visible_world_rect() -> Rect2:
	var vp_size = custom_viewport_size
	if vp_size == Vector2.ZERO:
		if is_inside_tree() and get_viewport() != null:
			vp_size = get_viewport_rect().size
		else:
			vp_size = Vector2(1280, 720)

	var current_zoom = zoom if (zoom.x > 0 and zoom.y > 0) else Vector2(1.0, 1.0)
	var world_size = vp_size / current_zoom
	var top_left = global_position - (world_size / 2.0)
	return Rect2(top_left, world_size)

func serialize() -> Dictionary:
	return {
		"position": [position.x, position.y],
		"target_position": [target_position.x, target_position.y],
		"zoom": [zoom.x, zoom.y],
		"target_zoom": [target_zoom.x, target_zoom.y]
	}

func deserialize(data: Dictionary) -> bool:
	if data == null or not data.has("position") or not data.has("zoom"):
		return false

	var pos = data["position"]
	var tpos = data.get("target_position", pos)
	var zm = data["zoom"]
	var tzm = data.get("target_zoom", zm)

	if not (pos is Array) or pos.size() < 2 or not (zm is Array) or zm.size() < 2:
		return false

	position = Vector2(float(pos[0]), float(pos[1]))
	if tpos is Array and tpos.size() >= 2:
		target_position = Vector2(float(tpos[0]), float(tpos[1]))
	else:
		target_position = position

	zoom = Vector2(float(zm[0]), float(zm[1]))
	if tzm is Array and tzm.size() >= 2:
		target_zoom = Vector2(float(tzm[0]), float(tzm[1]))
	else:
		target_zoom = zoom

	_last_notified_position = Vector2.INF
	_last_notified_zoom = Vector2.INF
	_notify_grid_manager()
	return true

