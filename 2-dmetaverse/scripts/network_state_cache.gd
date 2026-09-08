extends RefCounted


static func apply_packet(cache: Dictionary, packet: Dictionary) -> void:
	match str(packet.get("type", "")):
		"init":
			var players: Variant = packet.get("players", {})
			if typeof(players) != TYPE_DICTIONARY:
				return
			for id in players.keys():
				var state: Variant = players[id]
				if typeof(state) != TYPE_DICTIONARY:
					continue
				var app_user_id := int(id)
				if app_user_id > 0:
					cache[app_user_id] = state
		"join":
			var join_id := int(packet.get("user_id", -1))
			var data: Variant = packet.get("data", {})
			if join_id > 0 and typeof(data) == TYPE_DICTIONARY:
				cache[join_id] = data
		"move":
			var move_id := int(packet.get("user_id", -1))
			if move_id > 0:
				cache[move_id] = packet
		"leave":
			cache.erase(int(packet.get("user_id", -1)))


static func remote_players(cache: Dictionary, local_user_id: int) -> Dictionary:
	var result := {}
	for id in cache.keys():
		var app_user_id := int(id)
		if app_user_id != local_user_id:
			result[app_user_id] = cache[id]
	return result


static func apply_nakama_leave(nakama_to_app_user: Dictionary, cache: Dictionary, nakama_user_id: String) -> Dictionary:
	if nakama_user_id == "" or not nakama_to_app_user.has(nakama_user_id):
		return {}
	var app_user_id := int(nakama_to_app_user[nakama_user_id])
	nakama_to_app_user.erase(nakama_user_id)
	cache.erase(app_user_id)
	return {
		"app_user_id": app_user_id,
		"nakama_user_id": nakama_user_id,
		"packet": {
			"type": "leave",
			"user_id": app_user_id,
		},
	}


static func remember_nakama_sender(nakama_to_app_user: Dictionary, nakama_user_id: String, packet: Dictionary) -> bool:
	if nakama_user_id == "" or not packet.has("user_id"):
		return false
	nakama_to_app_user[nakama_user_id] = int(packet.get("user_id", -1))
	return true
