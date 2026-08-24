@tool
extends SceneTree

func _init():
	print("--- Running Test Suite: Project Setup ---")
	var success = true
	
	# Test 1: Check Input Map Actions
	var required_actions = ["left_click", "right_click", "middle_click", "zoom_in", "zoom_out", "reveal_cell", "flag_cell"]
	for action in required_actions:
		if InputMap.has_action(action):
			print("[PASS] Input action found: ", action)
		else:
			print("[FAIL] Input action missing: ", action)
			success = false

	# Test 2: Check Main Scene Load & Instantiate
	var main_scene_path = "res://scenes/main.tscn"
	if ResourceLoader.exists(main_scene_path):
		var main_scene = load(main_scene_path)
		if main_scene is PackedScene:
			var instance = main_scene.instantiate()
			if instance != null:
				print("[PASS] Main scene loaded and instantiated successfully: ", instance.name)
				instance.free()
			else:
				print("[FAIL] Failed to instantiate main scene")
				success = false
		else:
			print("[FAIL] res://scenes/main.tscn is not a PackedScene")
			success = false
	else:
		print("[FAIL] Main scene does not exist at ", main_scene_path)
		success = false

	print("--- Test Suite Finished ---")
	if success:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)
