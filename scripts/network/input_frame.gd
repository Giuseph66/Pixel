class_name InputFrame
extends RefCounted

## Serializable, intentionally tiny input representation used over channel 1.

var sequence := 0
var left := false
var right := false
var up := false
var down := false
var jump := false
var dash := false


func to_dictionary() -> Dictionary:
	return {
		"sequence": sequence,
		"left": left, "right": right, "up": up, "down": down,
		"jump": jump, "dash": dash,
	}
