class_name CameraController
extends Camera2D

@export var min_zoom: float = 0.2
@export var max_zoom: float = 3.0
@export var zoom_step: float = 0.15
@export var zoom_smoothness: float = 15.0
@export var pan_smoothness: float = 20.0
@export var grid_manager: GridManager

var target_zoom: Vector2 = Vector2(1.0, 1.0)
var target_position: Vector2 = Vector2.ZERO
var is_panning: bool = false
var custom_viewport_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	target_position = position
	target_zoom = zoom
	_auto_find_grid_manager()

func _auto_find_grid_manager() -> void:
	if grid_manager != null:
		return
	if get_parent() != null:
		if get_parent().has_node("GridManager"):
			grid_manager = get_parent().get_node("GridManager") as GridManager
		elif get_parent() is GridManager:
			grid_manager = get_parent() as GridManager

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		apply_zoom_step(1)
	elif event.is_action_pressed("zoom_out"):
		apply_zoom_step(-1)

	if event.is_action_pressed("middle_click") or event.is_action_pressed("right_click"):
		is_panning = true
	elif event.is_action_released("middle_click") and not Input.is_action_pressed("right_click"):
		is_panning = false
	elif event.is_action_released("right_click") and not Input.is_action_pressed("middle_click"):
		is_panning = false

	if is_panning and event is InputEventMouseMotion:
		pan_by(event.relative)

func apply_zoom_step(direction: int) -> void:
	var factor = 1.0 + (zoom_step * direction)
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
	else:
		zoom = target_zoom
		position = target_position

	_notify_grid_manager()

func _notify_grid_manager() -> void:
	if grid_manager != null:
		grid_manager.update_visible_area(get_visible_world_rect())

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

	_notify_grid_manager()
	return true

