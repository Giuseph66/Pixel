class_name NetworkLog
extends RefCounted

## Keep diagnostics useful without leaking passwords, proofs or addresses.


static func event(role: String, peer_id: int, state: int, message: String) -> void:
	print("[NET][role=%s][peer=%d][state=%d] %s" % [role, peer_id, state, message])
