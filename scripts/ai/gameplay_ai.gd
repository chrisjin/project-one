## Common rule-set-bound interface for interchangeable headless AI implementations.
class_name AnchorGameplayAi
extends RefCounted

const RuleSet = preload("res://scripts/gameplay/rules_config.gd")

var _rule_set: RuleSet
var rule_set: RuleSet:
	get:
		return _rule_set


func _init(configured_rule_set: RuleSet) -> void:
	assert(configured_rule_set != null)
	_rule_set = configured_rule_set


func choose_action(_state):
	push_error("AI implementations must provide choose_action(state).")
	return null
