class_name CellData
extends RefCounted

var pos: Vector2i
var is_mine: bool = false
var is_revealed: bool = false
var is_flagged: bool = false
var neighbor_mines: int = 0
var neighbor_mines_cached: bool = false

func _init(p_pos: Vector2i = Vector2i.ZERO) -> void:
	pos = p_pos
