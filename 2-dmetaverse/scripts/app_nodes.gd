extends RefCounted


static func world(owner: Node) -> Node:
	if owner == null:
		return null
	return owner.get_node_or_null("/root/Main/World")


static func hud(owner: Node) -> Node:
	if owner == null:
		return null
	return owner.get_node_or_null("/root/Main/HUD")


static func nakama(owner: Node) -> Node:
	if owner == null:
		return null
	return owner.get_node_or_null("/root/Nakama")


static func local_log(owner: Node) -> Node:
	if owner == null:
		return null
	return owner.get_node_or_null("/root/LocalLog")


static func write_log(owner: Node, message: String) -> void:
	var logger := local_log(owner)
	if logger != null and logger.has_method("write"):
		logger.write(message)


static func value(source: Object, property_name: String, default_value: Variant) -> Variant:
	if source == null:
		return default_value
	var property_value: Variant = source.get(property_name)
	return default_value if property_value == null else property_value


static func lobby_room(school_id: int) -> String:
	return "school-%s-lobby" % school_id
