## Command-line entry point for the dependency-free gameplay rule tests.
extends SceneTree

const TestRulesEngine = preload("res://tests/test_rules_engine.gd")
const TestMinimaxAi = preload("res://tests/test_minimax_ai.gd")


func _init() -> void:
	var rules_suite = TestRulesEngine.new()
	var ai_suite = TestMinimaxAi.new()
	var passed := rules_suite.run_all()
	passed = ai_suite.run_all() and passed
	quit(0 if passed else 1)
