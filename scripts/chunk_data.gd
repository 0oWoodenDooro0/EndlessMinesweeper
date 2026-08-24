class_name ChunkData
extends RefCounted

var chunk_pos: Vector2i = Vector2i.ZERO
var is_locked: bool = false
var locked_mine_positions: Array[Vector2i] = []
var total_safe_cells: int = 0
var revealed_safe_cells: int = 0
var is_cleared: bool = false

func _init(p_chunk_pos: Vector2i = Vector2i.ZERO) -> void:
	chunk_pos = p_chunk_pos

func get_progress() -> float:
	if total_safe_cells <= 0:
		return 1.0
	return clamp(float(revealed_safe_cells) / float(total_safe_cells), 0.0, 1.0)
