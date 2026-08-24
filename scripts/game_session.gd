class_name GameSession
extends RefCounted

signal stats_changed(stats: Dictionary)
signal game_over(hit_pos: Vector2i)
signal game_reset

var revealed_count: int = 0
var flag_count: int = 0
var cleared_chunks_count: int = 0
var locked_chunks_count: int = 0
var elapsed_time: float = 0.0
var is_timer_running: bool = false
var is_game_over: bool = false

func start() -> void:
	if not is_game_over:
		is_timer_running = true

func pause() -> void:
	is_timer_running = false

func resume() -> void:
	if not is_game_over:
		is_timer_running = true

func update(delta: float) -> void:
	if is_timer_running and not is_game_over:
		elapsed_time += delta

func reset() -> void:
	revealed_count = 0
	flag_count = 0
	cleared_chunks_count = 0
	locked_chunks_count = 0
	elapsed_time = 0.0
	is_timer_running = false
	is_game_over = false

	game_reset.emit()
	stats_changed.emit(get_stats())

func trigger_game_over(hit_pos: Vector2i = Vector2i.ZERO) -> void:
	is_timer_running = false
	is_game_over = true
	game_over.emit(hit_pos)
	stats_changed.emit(get_stats())

func record_reveal(pos: Vector2i, is_mine: bool) -> void:
	if is_game_over:
		return

	if not is_mine:
		revealed_count += 1
		if not is_timer_running:
			is_timer_running = true
		stats_changed.emit(get_stats())

func record_reveals_batch(revealed_positions: Array[Vector2i], mine_count: int = 0) -> void:
	if is_game_over or revealed_positions.is_empty():
		return

	var safe_count = revealed_positions.size() - mine_count
	if safe_count > 0:
		revealed_count += safe_count
		if not is_timer_running:
			is_timer_running = true
		stats_changed.emit(get_stats())

func record_flag_toggle(_pos: Vector2i, is_flagged: bool) -> void:
	if is_flagged:
		flag_count += 1
	else:
		flag_count = max(0, flag_count - 1)
	stats_changed.emit(get_stats())

func record_chunk_locked(_chunk_pos: Vector2i, _mine_pos: Vector2i) -> void:
	locked_chunks_count += 1
	if not is_timer_running and not is_game_over:
		is_timer_running = true
	stats_changed.emit(get_stats())

func record_chunk_cleared(_chunk_pos: Vector2i) -> void:
	cleared_chunks_count += 1
	stats_changed.emit(get_stats())

func record_chunk_unlocked(_chunk_pos: Vector2i, _recovered_flags: Array[Vector2i] = []) -> void:
	locked_chunks_count = max(0, locked_chunks_count - 1)
	stats_changed.emit(get_stats())

func get_stats() -> Dictionary:
	return {
		"revealed_count": revealed_count,
		"flag_count": flag_count,
		"cleared_chunks_count": cleared_chunks_count,
		"locked_chunks_count": locked_chunks_count,
		"elapsed_time": elapsed_time,
		"is_timer_running": is_timer_running,
		"is_game_over": is_game_over
	}

func serialize() -> Dictionary:
	return {
		"revealed_count": revealed_count,
		"flag_count": flag_count,
		"cleared_chunks_count": cleared_chunks_count,
		"locked_chunks_count": locked_chunks_count,
		"elapsed_time": elapsed_time,
		"is_timer_running": is_timer_running,
		"is_game_over": is_game_over
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
	is_game_over = bool(data.get("is_game_over", false))

	stats_changed.emit(get_stats())
	return true
