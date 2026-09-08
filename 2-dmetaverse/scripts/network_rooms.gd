extends RefCounted


static func private_room(school_id: int, user_id: int, other_user_id: int) -> String:
	var a: int = min(user_id, other_user_id)
	var b: int = max(user_id, other_user_id)
	return "school-%s-dm-%s-%s" % [school_id, a, b]


static func school_room(school_id: int) -> String:
	return "school-%s" % school_id
