class_name SignalingClient
extends RefCounted

## Contract placeholder for the deployed room-code service. The game does not
## fake internet support: without a configured HTTPS/WebSocket endpoint and
## TURN credentials this returns ERR_UNAVAILABLE rather than leaking a LAN IP.

var endpoint := ""


func is_configured() -> bool:
	return not endpoint.strip_edges().is_empty()


func create_room(_config: Dictionary) -> Error:
	return OK if is_configured() else ERR_UNAVAILABLE


func resolve_room(_code: String) -> Error:
	return OK if is_configured() else ERR_UNAVAILABLE
