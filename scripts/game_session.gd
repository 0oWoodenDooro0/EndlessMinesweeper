class_name GameSession
extends RefCounted

signal stats_changed(stats: Dictionary)
signal game_over(hit_pos: Vector2i)
signal game_reset
signal difficulty_changed(density: float, index: int)

const DIFFICULTIES: Array[float] = [0.10, 0.15, 0.20]
const DIFFICULTY_NAMES: Array[String] = ["Easy (10%)", "Medium (15%)", "Hard (20%)"]

var revealed_count: int = 0
var flag_count: int = 0
var cleared_chunks_count: int = 0
var locked_chunks_count: int = 0
var elapsed_time: float = 0.0
var is_timer_running: bool = false
var is_game_over: bool = false
var difficulty_index: int = 1
var mine_density: float = 0.15

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

func reset(new_density: float = -1.0) -> void:
	revealed_count = 0
	flag_count = 0
	cleared_chunks_count = 0
	locked_chunks_count = 0
	elapsed_time = 0.0
	is_timer_running = false
	is_game_over = false

	if new_density > 0.0:
		sync_difficulty_with_density(new_density)

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

func set_difficulty_by_index(index: int) -> void:
	if index >= 0 and index < DIFFICULTIES.size():
		difficulty_index = index
		mine_density = DIFFICULTIES[index]
		difficulty_changed.emit(mine_density, difficulty_index)
		stats_changed.emit(get_stats())

func sync_difficulty_with_density(density: float) -> void:
	for i in range(DIFFICULTIES.size()):
		if is_equal_approx(DIFFICULTIES[i], density):
			difficulty_index = i
			mine_density = DIFFICULTIES[i]
			difficulty_changed.emit(mine_density, difficulty_index)
			stats_changed.emit(get_stats())
			return

	# Fallback if density is not standard
	mine_density = density
	difficulty_changed.emit(mine_density, difficulty_index)
	stats_changed.emit(get_stats())

func get_difficulty_density() -> float:
	return mine_density

func get_stats() -> Dictionary:
	return {
		"revealed_count": revealed_count,
		"flag_count": flag_count,
		"cleared_chunks_count": cleared_chunks_count,
		"locked_chunks_count": locked_chunks_count,
		"elapsed_time": elapsed_time,
		"is_timer_running": is_timer_running,
		"is_game_over": is_game_over,
		"difficulty_index": difficulty_index,
		"mine_density": mine_density
	}

func serialize() -> Dictionary:
	return {
		"revealed_count": revealed_count,
		"flag_count": flag_count,
		"cleared_chunks_count": cleared_chunks_count,
		"locked_chunks_count": locked_chunks_count,
		"elapsed_time": elapsed_time,
		"is_timer_running": is_timer_running,
		"is_game_over": is_game_over,
		"difficulty_index": difficulty_index,
		"mine_density": mine_density
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

	if data.has("difficulty_index"):
		difficulty_index = int(data["difficulty_index"])
		if difficulty_index >= 0 and difficulty_index < DIFFICULTIES.size():
			mine_density = DIFFICULTIES[difficulty_index]
	elif data.has("mine_density"):
		sync_difficulty_with_density(float(data["mine_density"]))

	stats_changed.emit(get_stats())
	return true
