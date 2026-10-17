extends SceneTree

## Headless test runner. Run from the project root with:
##
##   godot --headless --path . --script res://tests/run_tests.gd
##
## Runs every test_* method in each tests/test_*.gd script, each in a fresh
## scene, and exits non-zero if any test failed.

const TEST_DIR := "res://tests"


func _initialize() -> void:
	var ran := 0
	var failed := 0
	var skipped := 0

	for script_path in _test_script_paths():
		var script := load(script_path) as GDScript
		for method in _test_method_names(script):
			var test = script.new()
			test.tree = self
			var label := "%s::%s" % [script_path.get_file(), method]
			await test.call(method)
			ran += 1

			if test.skip_reason != "":
				skipped += 1
				print("SKIP  %s (%s)" % [label, test.skip_reason])
			elif test.failures.is_empty():
				print("PASS  %s" % label)
			else:
				failed += 1
				print("FAIL  %s" % label)
				for message in test.failures:
					print("        - %s" % message)

			test.cleanup()
			await process_frame
			_release_all_actions()
			paused = false

	print("\n%d test(s): %d failed, %d skipped" % [ran, failed, skipped])
	quit(1 if failed > 0 else 0)


func _test_script_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for file in DirAccess.get_files_at(TEST_DIR):
		if file.begins_with("test_") and file.ends_with(".gd"):
			paths.append("%s/%s" % [TEST_DIR, file])
	paths.sort()
	return paths


func _test_method_names(script: GDScript) -> PackedStringArray:
	var names := PackedStringArray()
	for info in script.get_script_method_list():
		var method_name := String(info["name"])
		if method_name.begins_with("test_"):
			names.append(method_name)
	names.sort()
	return names


func _release_all_actions() -> void:
	for action in InputMap.get_actions():
		Input.action_release(action)
