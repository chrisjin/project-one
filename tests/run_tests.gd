## Command-line entry point for the dependency-free gameplay rule tests.
extends SceneTree

const TestRulesEngine = preload("res://tests/test_rules_engine.gd")
const TestRuleSets = preload("res://tests/test_rule_sets.gd")
const TestMinimaxAi = preload("res://tests/test_minimax_ai.gd")


func _init() -> void:
	var rules_suite = TestRulesEngine.new()
	var rule_set_suite = TestRuleSets.new()
	var ai_suite = TestMinimaxAi.new()
	var passed := rules_suite.run_all()
	passed = rule_set_suite.run_all() and passed
	passed = ai_suite.run_all() and passed
	quit(0 if passed else 1)
