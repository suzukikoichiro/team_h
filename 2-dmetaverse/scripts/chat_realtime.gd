extends RefCounted


static func network_connected(network: Node) -> bool:
	if network == null:
		return false
	var value: Variant = network.get("connected")
	return bool(value)


static func connect_world(network: Node, school_id: int, user_id: int) -> void:
	if network != null and network.has_method("connect_world"):
		network.call("connect_world", school_id, user_id)
