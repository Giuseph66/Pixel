class_name EnetTransport
extends NetworkTransport

## Direct UDP transport for loopback and LAN. It intentionally has no room
## registry: an internet room code needs the signalling service described in
## doc/multiplayer, not a hidden IP lookup in the client.


func host(port: int, max_clients: int) -> Error:
	close()
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_server(port, max_clients, 4)
	if err == OK:
		peer = enet
	return err


func join(address: String, port: int) -> Error:
	close()
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_client(address, port, 4)
	if err == OK:
		peer = enet
	return err
