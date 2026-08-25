class_name NetworkTransport
extends RefCounted

## Small transport boundary. SessionManager owns the protocol; transports only
## create and close a MultiplayerPeer. This keeps ENet useful for LAN while a
## future WebRTC implementation can use the exact same session rules.

var peer: MultiplayerPeer


func host(_port: int, _max_clients: int) -> Error:
	return ERR_UNAVAILABLE


func join(_address: String, _port: int) -> Error:
	return ERR_UNAVAILABLE


func close() -> void:
	if peer != null:
		peer.close()
	peer = null
