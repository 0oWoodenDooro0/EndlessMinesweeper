@tool
extends SceneTree

const GameSession = preload("res://scripts/game_session.gd")

func _init():
	print("--- Running Test Suite: GameSession Domain Module ---")
	var success = true

	# Test 1: Default Initial State
	if not test_initial_state():
		success = false

	# Test 2: Timer Lifecycle (start, pause, resume, update)
	if not test_timer_lifecycle():
		success = false

	# Test 3: Gameplay Events Recording (reveal, flag, lockout, clear, unlock)
	if not test_gameplay_events_recording():
		success = false

	# Test 4: Game Over Transition & Timer Stop
	if not test_game_over_transition():
		success = false

	# Test 5: Session Reset Lifecycle
	if not test_session_reset():
		success = false

	# Test 6: Stats Contract (No Difficulty Dependencies)
	if not test_stats_contract():
		success = false

	# Test 7: Signal Emission Contract (stats_changed, game_over, game_reset)
	if not test_signal_emission_contract():
		success = false

	# Test 8: Serialization and Deserialization
	if not test_serialization_deserialization():
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)

func test_initial_state() -> bool:
	print("[RUN] Test 1: Default Initial State")
	var session = GameSession.new()

	if session.revealed_count != 0:
		print("[FAIL] Expected revealed_count 0, got: ", session.revealed_count)
		return false

	if session.flag_count != 0:
		print("[FAIL] Expected flag_count 0, got: ", session.flag_count)
		return false

	if session.cleared_chunks_count != 0:
		print("[FAIL] Expected cleared_chunks_count 0, got: ", session.cleared_chunks_count)
		return false

	if session.locked_chunks_count != 0:
		print("[FAIL] Expected locked_chunks_count 0, got: ", session.locked_chunks_count)
		return false

	if not is_equal_approx(session.elapsed_time, 0.0):
		print("[FAIL] Expected elapsed_time 0.0, got: ", session.elapsed_time)
		return false

	if session.is_timer_running != false:
		print("[FAIL] Expected is_timer_running false initially")
		return false

	if session.is_game_over != false:
		print("[FAIL] Expected is_game_over false initially")
		return false

	var stats = session.get_stats()
	if stats.get("revealed_count") != 0 or stats.get("flag_count") != 0:
		print("[FAIL] get_stats() returned unexpected initial stats: ", stats)
		return false

	if stats.has("difficulty_index") or stats.has("mine_density"):
		print("[FAIL] get_stats() contains deprecated difficulty fields: ", stats)
		return false

	print("[PASS] Test 1: Default initial state verified")
	return true

func test_timer_lifecycle() -> bool:
	print("[RUN] Test 2: Timer Lifecycle (start, pause, resume, update)")
	var session = GameSession.new()

	session.update(5.0)
	if not is_equal_approx(session.elapsed_time, 0.0):
		print("[FAIL] Timer should not advance when stopped, got: ", session.elapsed_time)
		return false

	session.start()
	if not session.is_timer_running:
		print("[FAIL] Timer should be running after start()")
		return false

	session.update(2.5)
	if not is_equal_approx(session.elapsed_time, 2.5):
		print("[FAIL] Expected elapsed_time 2.5 after update(2.5), got: ", session.elapsed_time)
		return false

	session.pause()
	if session.is_timer_running:
		print("[FAIL] Timer should be paused")
		return false

	session.update(3.0)
	if not is_equal_approx(session.elapsed_time, 2.5):
		print("[FAIL] Elapsed time should remain 2.5 when paused, got: ", session.elapsed_time)
		return false

	session.resume()
	if not session.is_timer_running:
		print("[FAIL] Timer should resume running")
		return false

	session.update(1.5)
	if not is_equal_approx(session.elapsed_time, 4.0):
		print("[FAIL] Expected elapsed_time 4.0 after resume and update(1.5), got: ", session.elapsed_time)
		return false

	print("[PASS] Test 2: Timer lifecycle verified")
	return true

func test_gameplay_events_recording() -> bool:
	print("[RUN] Test 3: Gameplay Events Recording (reveal, flag, lockout, clear, unlock)")
	var session = GameSession.new()

	# Safe reveal starts timer and increments revealed_count
	session.record_reveal(Vector2i(1, 1), false)
	if session.revealed_count != 1:
		print("[FAIL] revealed_count should be 1, got: ", session.revealed_count)
		return false
	if not session.is_timer_running:
		print("[FAIL] Timer should auto-start on first safe reveal")
		return false

	session.record_reveal(Vector2i(1, 2), false)
	if session.revealed_count != 2:
		print("[FAIL] revealed_count should be 2, got: ", session.revealed_count)
		return false

	# Flag operations
	session.record_flag_toggle(Vector2i(3, 3), true)
	if session.flag_count != 1:
		print("[FAIL] flag_count should be 1 after flag placed, got: ", session.flag_count)
		return false

	session.record_flag_toggle(Vector2i(4, 4), true)
	if session.flag_count != 2:
		print("[FAIL] flag_count should be 2 after second flag, got: ", session.flag_count)
		return false

	session.record_flag_toggle(Vector2i(3, 3), false)
	if session.flag_count != 1:
		print("[FAIL] flag_count should be 1 after unflagging, got: ", session.flag_count)
		return false

	# Test flag underflow clamp
	session.record_flag_toggle(Vector2i(4, 4), false)
	session.record_flag_toggle(Vector2i(5, 5), false)
	if session.flag_count != 0:
		print("[FAIL] flag_count should clamp to 0, got: ", session.flag_count)
		return false

	# Chunk Lockout
	session.record_chunk_locked(Vector2i(0, 0), Vector2i(0, 1))
	if session.locked_chunks_count != 1:
		print("[FAIL] locked_chunks_count should be 1, got: ", session.locked_chunks_count)
		return false

	# Chunk Clear
	session.record_chunk_cleared(Vector2i(1, 0))
	if session.cleared_chunks_count != 1:
		print("[FAIL] cleared_chunks_count should be 1, got: ", session.cleared_chunks_count)
		return false

	# Chunk Unlock
	var recovered: Array[Vector2i] = [Vector2i(0, 1)]
	session.record_chunk_unlocked(Vector2i(0, 0), recovered)
	if session.locked_chunks_count != 0:
		print("[FAIL] locked_chunks_count should decrement to 0 on unlock, got: ", session.locked_chunks_count)
		return false

	print("[PASS] Test 3: Gameplay events recording verified")
	return true

func test_game_over_transition() -> bool:
	print("[RUN] Test 4: Game Over Transition & Timer Stop")
	var session = GameSession.new()

	session.start()
	session.update(10.0)
	session.record_reveal(Vector2i(0, 0), false)

	if not session.is_timer_running or session.is_game_over:
		print("[FAIL] Session should be active prior to game over")
		return false

	var game_over_data = {
		"received": false,
		"pos": Vector2i(-1, -1)
	}
	session.connect("game_over", func(pos: Vector2i):
		game_over_data["received"] = true
		game_over_data["pos"] = pos
	)

	session.trigger_game_over(Vector2i(5, 5))

	if not session.is_game_over:
		print("[FAIL] session.is_game_over should be true")
		return false

	if session.is_timer_running:
		print("[FAIL] Timer should stop when game over is triggered")
		return false

	if not game_over_data["received"] or game_over_data["pos"] != Vector2i(5, 5):
		print("[FAIL] game_over signal was not emitted with expected position")
		return false

	# Further timer updates should have no effect
	session.update(5.0)
	if not is_equal_approx(session.elapsed_time, 10.0):
		print("[FAIL] Elapsed time should remain 10.0 after game over, got: ", session.elapsed_time)
		return false

	# resume() should not restart timer if game over
	session.resume()
	if session.is_timer_running:
		print("[FAIL] resume() should not start timer when is_game_over is true")
		return false

	print("[PASS] Test 4: Game Over transition & timer stop verified")
	return true

func test_session_reset() -> bool:
	print("[RUN] Test 5: Session Reset Lifecycle")
	var session = GameSession.new()

	session.start()
	session.update(25.0)
	session.record_reveal(Vector2i(0, 0), false)
	session.record_flag_toggle(Vector2i(1, 1), true)
	session.record_chunk_locked(Vector2i(0, 0), Vector2i(0, 0))
	session.record_chunk_cleared(Vector2i(1, 0))
	session.trigger_game_over(Vector2i(0, 0))

	var reset_data = {
		"received": false
	}
	session.connect("game_reset", func():
		reset_data["received"] = true
	)

	session.reset()

	if not reset_data["received"]:
		print("[FAIL] game_reset signal was not emitted on reset()")
		return false

	if session.revealed_count != 0 or session.flag_count != 0 or session.cleared_chunks_count != 0 or session.locked_chunks_count != 0:
		print("[FAIL] Counters were not reset to 0")
		return false

	if not is_equal_approx(session.elapsed_time, 0.0) or session.is_timer_running:
		print("[FAIL] Timer was not reset to 0.0 and stopped")
		return false

	if session.is_game_over:
		print("[FAIL] is_game_over was not cleared on reset()")
		return false

	print("[PASS] Test 5: Session reset lifecycle verified")
	return true

func test_stats_contract() -> bool:
	print("[RUN] Test 6: Stats Contract (No Difficulty Dependencies)")
	var session = GameSession.new()
	session.revealed_count = 10
	session.flag_count = 2
	session.cleared_chunks_count = 1
	session.locked_chunks_count = 0
	session.elapsed_time = 15.5
	session.is_timer_running = true

	var stats = session.get_stats()
	var expected_keys = ["revealed_count", "flag_count", "cleared_chunks_count", "locked_chunks_count", "elapsed_time", "is_timer_running", "is_game_over"]
	for k in expected_keys:
		if not stats.has(k):
			print("[FAIL] Stats missing required key: ", k)
			return false

	if stats.has("difficulty_index") or stats.has("mine_density"):
		print("[FAIL] Stats contains deprecated difficulty keys: ", stats)
		return false

	print("[PASS] Test 6: Stats contract verified")
	return true

func test_signal_emission_contract() -> bool:
	print("[RUN] Test 7: Signal Emission Contract")
	var session = GameSession.new()

	var stats_data = {
		"received_stats": {},
		"emissions_count": 0
	}
	session.connect("stats_changed", func(stats: Dictionary):
		stats_data["received_stats"] = stats
		stats_data["emissions_count"] += 1
	)

	session.record_reveal(Vector2i(0, 0), false)
	if stats_data["emissions_count"] == 0 or stats_data["received_stats"].get("revealed_count") != 1:
		print("[FAIL] stats_changed signal not emitted properly on reveal")
		return false

	session.record_flag_toggle(Vector2i(1, 1), true)
	if stats_data["received_stats"].get("flag_count") != 1:
		print("[FAIL] stats_changed signal payload mismatch on flag: ", stats_data["received_stats"])
		return false

	session.record_chunk_locked(Vector2i(0, 0), Vector2i(0, 1))
	if stats_data["received_stats"].get("locked_chunks_count") != 1:
		print("[FAIL] stats_changed signal payload mismatch on chunk locked: ", stats_data["received_stats"])
		return false

	session.record_chunk_cleared(Vector2i(0, 0))
	if stats_data["received_stats"].get("cleared_chunks_count") != 1:
		print("[FAIL] stats_changed signal payload mismatch on chunk cleared: ", stats_data["received_stats"])
		return false

	print("[PASS] Test 7: Signal emission contract verified")
	return true

func test_serialization_deserialization() -> bool:
	print("[RUN] Test 8: Serialization and Deserialization")
	var session1 = GameSession.new()
	session1.revealed_count = 42
	session1.flag_count = 8
	session1.cleared_chunks_count = 3
	session1.locked_chunks_count = 1
	session1.elapsed_time = 123.45
	session1.is_timer_running = true
	session1.is_game_over = false

	var data = session1.serialize()
	if data == null or data.is_empty():
		print("[FAIL] session1.serialize() returned empty dictionary")
		return false

	if data.has("difficulty_index") or data.has("mine_density"):
		print("[FAIL] Serialized data should not contain difficulty fields: ", data)
		return false

	var session2 = GameSession.new()
	var success = session2.deserialize(data)
	if not success:
		print("[FAIL] session2.deserialize() returned false")
		return false

	if session2.revealed_count != 42 or session2.flag_count != 8:
		print("[FAIL] Deserialized counts mismatch: revealed=", session2.revealed_count, " flag=", session2.flag_count)
		return false

	if session2.cleared_chunks_count != 3 or session2.locked_chunks_count != 1:
		print("[FAIL] Deserialized chunk counts mismatch: cleared=", session2.cleared_chunks_count, " locked=", session2.locked_chunks_count)
		return false

	if not is_equal_approx(session2.elapsed_time, 123.45) or not session2.is_timer_running:
		print("[FAIL] Deserialized timer mismatch: elapsed=", session2.elapsed_time, " running=", session2.is_timer_running)
		return false

	# Backward compatibility: deserializing legacy save with difficulty fields should succeed
	var legacy_data = data.duplicate()
	legacy_data["difficulty_index"] = 2
	legacy_data["mine_density"] = 0.20
	var session3 = GameSession.new()
	var legacy_success = session3.deserialize(legacy_data)
	if not legacy_success or session3.revealed_count != 42:
		print("[FAIL] Legacy deserialization failed")
		return false

	# Invalid data handling
	var empty_success = session2.deserialize({})
	if empty_success:
		print("[FAIL] deserialize({}) should return false")
		return false

	print("[PASS] Test 8: Serialization and deserialization verified")
	return true
