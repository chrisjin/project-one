## Immutable ruleset instance reproducing the authoritative current core game.
class_name AnchorCoreRuleSet
extends "res://scripts/gameplay/rules_config.gd"

func _init() -> void:
	var anchor_config := EntityConfig.new({
		"attack_type": RuleTypes.AttackType.NONE,
		"attack_range": 0,
		"attack_damage": 0,
		"attack_blocking_type": RuleTypes.AttackBlockingType.ENEMY,
		"targetable": true,
		"movement_type": RuleTypes.MovementType.ORTHOGONAL,
		"movement_range": 1,
		"max_hp": 3,
		"defense": 0,
		"binding_limit": 3,
		"hp_reductions": [],
	})
	var base_board_piece_values := {
		"attack_range": 6,
		"attack_damage": 2,
		"attack_blocking_type": RuleTypes.AttackBlockingType.ENEMY,
		"targetable": true,
		"movement_type": RuleTypes.MovementType.ORTHOGONAL,
		"movement_range": 0,
		"max_hp": 2,
		"defense": 0,
		"binding_limit": 0,
		"hp_reductions": [{
			"type": RuleTypes.HpReductionType.MAIN_ANCHOR_DAMAGE_REDUCTION,
			"amount": 1,
		}],
	}
	var o_values := base_board_piece_values.duplicate(true)
	o_values.attack_type = RuleTypes.AttackType.ORTHOGONAL
	var d_values := base_board_piece_values.duplicate(true)
	d_values.attack_type = RuleTypes.AttackType.DIAGONAL
	var piece_spirit_config := EntityConfig.new({
		"attack_type": RuleTypes.AttackType.NONE,
		"attack_range": 0,
		"attack_damage": 0,
		"attack_blocking_type": RuleTypes.AttackBlockingType.BOTH,
		"targetable": false,
		"movement_type": RuleTypes.MovementType.NONE,
		"movement_range": 0,
		"max_hp": 0,
		"defense": 0,
		"binding_limit": 0,
		"hp_reductions": [],
	})
	super({
		"standard_board_size": Vector2i(7, 7),
		"max_categories_per_turn": 2,
		"anchor_deployment_limit": 12,
		"anchor_config": anchor_config,
		"board_piece_configs": {
			RuleTypes.BoardPieceType.ORTHOGONAL: EntityConfig.new(o_values),
			RuleTypes.BoardPieceType.DIAGONAL: EntityConfig.new(d_values),
			RuleTypes.BoardPieceType.PIECE_SPIRIT: piece_spirit_config,
		},
	})
