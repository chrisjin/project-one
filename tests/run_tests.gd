## Command-line entry point for the dependency-free gameplay rule tests.
extends SceneTree

const TestRulesEngine = preload("res://tests/test_rules_engine.gd")


func _init() -> void:
	var suite = TestRulesEngine.new()
	quit(0 if suite.run_all() else 1)
