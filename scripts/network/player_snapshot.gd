class_name PlayerSnapshot
extends RefCounted

## Named shape for the host snapshot contract. Player keeps the actual encode
## close to its physics state, avoiding a duplicate movement model.

var peer_id := 1
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var alive := true
var has_dash := true


func to_dictionary() -> Dictionary:
	return {
		"peer_id": peer_id,
		"x": position.x, "y": position.y,
		"vx": velocity.x, "vy": velocity.y,
		"alive": alive, "dash": has_dash,
	}
