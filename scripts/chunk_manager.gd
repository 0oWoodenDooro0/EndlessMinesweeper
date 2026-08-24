class_name ChunkManager
extends RefCounted

const ChunkData = preload("res://scripts/chunk_data.gd")

signal chunk_locked(chunk_pos: Vector2i, mine_pos: Vector2i)
signal chunk_cleared(chunk_pos: Vector2i)
signal chunk_unlocked(chunk_pos: Vector2i, recovered_flags: Array[Vector2i])

var chunk_size: Vector2i = Vector2i(8, 8)
var chunks: Dictionary = {} # Vector2i -> ChunkData
var is_mine_provider: Callable = Callable()
var is_cell_revealed_provider: Callable = Callable()

func setup(p_chunk_size: Vector2i = Vector2i(8, 8), p_is_mine_provider: Callable = Callable(), p_is_revealed_provider: Callable = Callable()) -> void:
	chunk_size = p_chunk_size
	is_mine_provider = p_is_mine_provider
	is_cell_revealed_provider = p_is_revealed_provider

func cell_to_chunk(cell_pos: Vector2i) -> Vector2i:
	return Vector2i(
		int(floor(float(cell_pos.x) / float(chunk_size.x))),
		int(floor(float(cell_pos.y) / float(chunk_size.y)))
	)

func get_chunk(c_pos: Vector2i) -> ChunkData:
	if chunks.has(c_pos):
		return chunks[c_pos]

	var chunk = ChunkData.new(c_pos)
	_calculate_chunk_safe_cells(chunk)
	chunks[c_pos] = chunk
	return chunk

func get_chunk_for_cell(cell_pos: Vector2i) -> ChunkData:
	return get_chunk(cell_to_chunk(cell_pos))

func has_chunk(c_pos: Vector2i) -> bool:
	return chunks.has(c_pos)

func preload_chunks_in_rect(min_c_pos: Vector2i, max_c_pos: Vector2i) -> void:
	for cx in range(min_c_pos.x, max_c_pos.x + 1):
		for cy in range(min_c_pos.y, max_c_pos.y + 1):
			get_chunk(Vector2i(cx, cy))

func is_chunk_locked(c_pos: Vector2i) -> bool:
	if chunks.has(c_pos):
		return chunks[c_pos].is_locked
	return false

func is_chunk_cleared(c_pos: Vector2i) -> bool:
	if chunks.has(c_pos):
		return chunks[c_pos].is_cleared
	return false

func is_cell_in_locked_chunk(cell_pos: Vector2i) -> bool:
	return is_chunk_locked(cell_to_chunk(cell_pos))

func is_cell_in_cleared_chunk(cell_pos: Vector2i) -> bool:
	return is_chunk_cleared(cell_to_chunk(cell_pos))

func _calculate_chunk_safe_cells(chunk: ChunkData) -> void:
	var safe_count = 0
	var revealed_count = 0
	var min_x = chunk.chunk_pos.x * chunk_size.x
	var min_y = chunk.chunk_pos.y * chunk_size.y

	for x in range(min_x, min_x + chunk_size.x):
		for y in range(min_y, min_y + chunk_size.y):
			var p = Vector2i(x, y)
			var is_mine = false
			if is_mine_provider.is_valid():
				is_mine = is_mine_provider.call(p)
			if not is_mine:
				safe_count += 1
				if is_cell_revealed_provider.is_valid() and is_cell_revealed_provider.call(p):
					revealed_count += 1

	chunk.total_safe_cells = safe_count
	chunk.revealed_safe_cells = revealed_count
	if chunk.total_safe_cells > 0 and chunk.revealed_safe_cells >= chunk.total_safe_cells:
		chunk.is_cleared = true

func recalculate_chunk_safe_cells(c_pos: Vector2i) -> void:
	if chunks.has(c_pos):
		_calculate_chunk_safe_cells(chunks[c_pos])

func recalculate_chunks_for_cells(cell_positions: Array[Vector2i]) -> void:
	var affected: Dictionary = {}
	for p in cell_positions:
		affected[cell_to_chunk(p)] = true
	for cp in affected:
		recalculate_chunk_safe_cells(cp)

func get_chunk_mine_positions(c_pos: Vector2i) -> Array[Vector2i]:
	var mines: Array[Vector2i] = []
	var min_x = c_pos.x * chunk_size.x
	var min_y = c_pos.y * chunk_size.y
	for x in range(min_x, min_x + chunk_size.x):
		for y in range(min_y, min_y + chunk_size.y):
			var p = Vector2i(x, y)
			if is_mine_provider.is_valid() and is_mine_provider.call(p):
				mines.append(p)
	return mines

func register_reveal(cell_pos: Vector2i, is_mine: bool, enable_chunk_lockout: bool = true) -> Dictionary:
	var chunk = get_chunk_for_cell(cell_pos)

	if is_mine:
		if enable_chunk_lockout:
			chunk.lock(cell_pos)
			chunk_locked.emit(chunk.chunk_pos, cell_pos)
			return {
				"action": "locked",
				"chunk_pos": chunk.chunk_pos,
				"mine_pos": cell_pos
			}
		else:
			return {
				"action": "game_over",
				"chunk_pos": chunk.chunk_pos,
				"mine_pos": cell_pos
			}

	var newly_cleared = chunk.record_safe_reveal()
	if newly_cleared:
		var auto_flags = get_chunk_mine_positions(chunk.chunk_pos)
		chunk_cleared.emit(chunk.chunk_pos)
		var unlocked = _check_neighbors_unlock(chunk.chunk_pos)
		return {
			"action": "cleared",
			"chunk_pos": chunk.chunk_pos,
			"auto_flags": auto_flags,
			"unlocked": unlocked
		}

	return {
		"action": "revealed",
		"chunk_pos": chunk.chunk_pos
	}

func _check_neighbors_unlock(cleared_chunk_pos: Vector2i) -> Dictionary:
	var processed_clusters: Dictionary = {}
	var all_unlocked: Dictionary = {}

	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var target_c_pos = cleared_chunk_pos + Vector2i(dx, dy)
			if processed_clusters.has(target_c_pos):
				continue
			if chunks.has(target_c_pos):
				var target_chunk = chunks[target_c_pos]
				if target_chunk.is_locked:
					var cluster_unlocked = _try_unlock_locked_cluster(target_c_pos, processed_clusters)
					for k in cluster_unlocked:
						all_unlocked[k] = cluster_unlocked[k]

	return all_unlocked

func _try_unlock_locked_cluster(start_c_pos: Vector2i, processed_clusters: Dictionary) -> Dictionary:
	# 1. Find all 8-direction connected locked chunks (BFS)
	var queue: Array[Vector2i] = [start_c_pos]
	var cluster: Array[Vector2i] = [start_c_pos]
	var cluster_set: Dictionary = {start_c_pos: true}

	while queue.size() > 0:
		var curr = queue.pop_front()
		processed_clusters[curr] = true
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var n_pos = curr + Vector2i(dx, dy)
				if cluster_set.has(n_pos):
					continue
				if chunks.has(n_pos) and chunks[n_pos].is_locked:
					cluster_set[n_pos] = true
					cluster.append(n_pos)
					queue.append(n_pos)

	# 2. Collect external perimeter of the cluster (all 8-neighbors of cluster members not in cluster)
	var perimeter: Dictionary = {}
	for c_member in cluster:
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var p_pos = c_member + Vector2i(dx, dy)
				if not cluster_set.has(p_pos):
					perimeter[p_pos] = true

	# 3. Check if all perimeter chunks are cleared
	var all_cleared = true
	for p_pos in perimeter:
		var p_chunk = get_chunk(p_pos)
		if not p_chunk.is_cleared:
			all_cleared = false
			break

	# 4. If all perimeter chunks are cleared, unlock all chunks in the cluster
	var unlocked_dict: Dictionary = {}
	if all_cleared:
		for c_member in cluster:
			var ch = get_chunk(c_member)
			var recovered = ch.unlock()
			unlocked_dict[c_member] = recovered
			chunk_unlocked.emit(c_member, recovered)

	return unlocked_dict

func reset(p_chunk_size: Vector2i = Vector2i.ZERO) -> void:
	if p_chunk_size != Vector2i.ZERO:
		chunk_size = p_chunk_size
	chunks.clear()

func serialize() -> Array:
	var serialized_chunks = []
	for cp in chunks:
		serialized_chunks.append(chunks[cp].serialize())
	return serialized_chunks

func deserialize(data: Array) -> bool:
	if data == null:
		return false

	chunks.clear()
	for ch_info in data:
		if not (ch_info is Dictionary) or not ch_info.has("x") or not ch_info.has("y"):
			continue
		var chunk = ChunkData.new()
		chunk.deserialize(ch_info)
		chunks[chunk.chunk_pos] = chunk

	return true
