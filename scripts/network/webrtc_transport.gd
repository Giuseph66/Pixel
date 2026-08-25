class_name WebRtcTransport
extends NetworkTransport

## WebRTC is selected only after a native WebRTC GDExtension plus signalling,
## STUN and TURN are configured. Godot's stock desktop export cannot create
## this transport by itself.

func host(_port: int, _max_clients: int) -> Error:
	return ERR_UNAVAILABLE


func join(_address: String, _port: int) -> Error:
	return ERR_UNAVAILABLE
