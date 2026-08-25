class_name ChunkData
extends RefCounted

var chunk_pos: Vector2i = Vector2i.ZERO
var is_locked: bool = false
var locked_mine_positions: Array = []
var total_safe_cells: int = 0
var revealed_safe_cells: int = 0
var is_cleared: bool = false

func _init(p_chunk_pos: Vector2i = Vector2i.ZERO) -> void:
	chunk_pos = p_chunk_pos

func get_progress() -> float:
	if is_cleared:
		return 1.0
	if total_safe_cells <= 0:
		return 1.0
	return clamp(float(revealed_safe_cells) / float(total_safe_cells), 0.0, 1.0)

func lock(mine_pos: Vector2i) -> void:
	is_locked = true
	if not locked_mine_positions.has(mine_pos):
		locked_mine_positions.append(mine_pos)

func unlock() -> Array[Vector2i]:
	is_locked = false
	var recovered: Array[Vector2i] = []
	for m in locked_mine_positions:
		if m is Vector2i:
			recovered.append(m)
	locked_mine_positions.clear()
	return recovered

func record_safe_reveal() -> bool:
	revealed_safe_cells += 1
	if not is_cleared and total_safe_cells > 0 and revealed_safe_cells >= total_safe_cells:
		is_cleared = true
		return true
	return false

func serialize() -> Dictionary:
	var locked_mines: Array = []
	for m in locked_mine_positions:
		locked_mines.append([m.x, m.y])
	return {
		"x": chunk_pos.x,
		"y": chunk_pos.y,
		"is_locked": is_locked,
		"locked_mine_positions": locked_mines,
		"total_safe_cells": total_safe_cells,
		"revealed_safe_cells": revealed_safe_cells,
		"is_cleared": is_cleared
	}

func deserialize(data: Dictionary) -> void:
	if not (data is Dictionary):
		return
	if data.has("x") and data.has("y"):
		chunk_pos = Vector2i(int(data["x"]), int(data["y"]))
	is_locked = bool(data.get("is_locked", false))
	total_safe_cells = int(data.get("total_safe_cells", 0))
	revealed_safe_cells = int(data.get("revealed_safe_cells", 0))
	is_cleared = bool(data.get("is_cleared", false))
	var locked_m: Array[Vector2i] = []
	if data.has("locked_mine_positions") and data["locked_mine_positions"] is Array:
		for m in data["locked_mine_positions"]:
			if m is Array and m.size() >= 2:
				locked_m.append(Vector2i(int(m[0]), int(m[1])))
	locked_mine_positions = locked_m
