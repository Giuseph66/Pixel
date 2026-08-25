class_name SessionConfig
extends RefCounted

## Serializable lobby settings. Password material never belongs in this object:
## configs travel over the network and are drawn by the lobby UI.

const MIN_PLAYERS := 2
const MAX_PLAYERS := 32

static func make(values: Dictionary) -> Dictionary:
	var raw_room_data: Variant = values.get("room_data", {})
	var room_data: Dictionary = raw_room_data.duplicate(true) if raw_room_data is Dictionary else {}
	return {
		"protocol": int(values.get("protocol", SessionManager.PROTOCOL_VERSION)),
		"room_code": str(values.get("room_code", "")),
		"room_name": str(values.get("room_name", "SALA")),
		"mode": str(values.get("mode", "story")),
		"level_index": int(values.get("level_index", 0)),
		"seed": int(values.get("seed", 0)),
		"max_players": clampi(int(values.get("max_players", 4)), MIN_PLAYERS, MAX_PLAYERS),
		"password_required": bool(values.get("password_required", false)),
		"allow_late_join": bool(values.get("allow_late_join", false)),
		"room_data": room_data,
		"room_data_hash": str(values.get("room_data_hash", "")),
		"content_hash": str(values.get("content_hash", "")),
	}
