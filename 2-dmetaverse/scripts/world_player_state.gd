extends RefCounted

const STUDENT_ROLE := "student"
const TEACHER_ROLE := "teacher"


static func apply_meta(player: Node, data: Dictionary) -> void:
	var role := str(data.get("role", ""))
	var user_position := int(data.get("user_position", -1))
	if role == "":
		role = TEACHER_ROLE if user_position == 1 else STUDENT_ROLE
	player.set_meta("role", role)
	player.set_meta("user_position", user_position)
	player.set_meta("user_name", str(data.get("user_name", "ユーザー")))
	player.set_meta("allow_nearby_chat", bool(data.get("allow_nearby_chat", true)))
	player.set_meta("talk_permission", str(data.get("talk_permission", "all")))
	player.set_meta("mood_status", str(data.get("mood_status", "fine")))
	player.set_meta("avatar_key", str(data.get("avatar_key", "skin_01")))


static func contact_for_player(id: int, player: Node) -> Dictionary:
	var role := str(player.get_meta("role", STUDENT_ROLE))
	return {
		"user_id": id,
		"user_name": str(player.get_meta("user_name", "ユーザー")),
		"role": role,
		"role_label": "教職員" if role == TEACHER_ROLE else "学生",
		"avatar_key": str(player.get_meta("avatar_key", "skin_01")),
		"mood_status": str(player.get_meta("mood_status", "fine")),
		"talk_permission": str(player.get_meta("talk_permission", "all")),
	}


static func is_student(player: Node) -> bool:
	return str(player.get_meta("role", STUDENT_ROLE)) == STUDENT_ROLE


static func can_use_nearby_talk(player: Node, my_role: String) -> bool:
	if not is_student(player):
		return true
	return can_approach_player(player, my_role)


static func can_approach_player(player: Node, my_role: String) -> bool:
	if not bool(player.get_meta("allow_nearby_chat", true)):
		return false
	var permission := str(player.get_meta("talk_permission", "all"))
	match permission:
		"none":
			return false
		"students":
			return my_role == STUDENT_ROLE
		"teachers":
			return my_role == TEACHER_ROLE
		_:
			return true
