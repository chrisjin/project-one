## Success/error envelope for non-throwing simulation transitions.
class_name AnchorActionResult
extends RefCounted

var success: bool
var state: AnchorGameState
var error: String
var events: Array[Dictionary]


func _init(
	was_successful: bool,
	resulting_state: AnchorGameState,
	error_message: String = "",
	resolved_events: Array[Dictionary] = []
) -> void:
	success = was_successful
	state = resulting_state
	error = error_message
	events = resolved_events
