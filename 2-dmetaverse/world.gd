extends Node2D

@onready var players_node := $Players
@export var player_scene: PackedScene
const GrowthPlantScript := preload("res://scripts/growth_plant.gd")
const WorldPlayerState := preload("res://scripts/world_player_state.gd")
const AppNodes := preload("res://scripts/app_nodes.gd")
var local_player_spawned := false


var players := {} # user_id -> node
var my_id := -1
var guide_target_id := -1
var guide_contact := {}
var guide_layer: CanvasLayer
var guide_label: Label
var pin_label: Label
var growth_plant: Node2D
var temporary_reply_allowed_user_ids := {}

const TALK_DISTANCE := 280.0
const STUDENT_ROLE := "student"
const TEACHER_ROLE := "teacher"

func _ready():
	LocalLog.write("World ready")
	Network.ws_message.connect(_on_ws_message)

	if Global.is_logged_in:
		_on_login_done()
	else:
		Global.login_done.connect(_on_login_done)
	_build_guide_ui()
	_build_growth_plant()


func _on_login_done():
	my_id = Global.user_id
	LocalLog.write("World login done user=%s school=%s" % [my_id, Global.school_id])

	Network.connect_world(Global.school_id, my_id)
	spawn_local_player()
	_spawn_cached_remote_players()
	if growth_plant != null and growth_plant.has_method("refresh"):
		growth_plant.call("refresh")

	
func spawn_local_player():
	if local_player_spawned:
		return
	local_player_spawned = true

	var p = player_scene.instantiate()
	p.player_id = my_id
	p.school_id = str(Global.school_id)
	p.is_local = true
	players_node.add_child(p)
	players[my_id] = p
	WorldPlayerState.apply_meta(p, {
		"user_name": Global.username,
		"user_position": Global.user_position,
		"role": TEACHER_ROLE if Global.is_teacher() else STUDENT_ROLE,
		"allow_nearby_chat": Global.allow_nearby_chat,
		"talk_permission": Global.talk_permission,
		"mood_status": Global.mood_status,
		"avatar_key": Global.avatar_key,
	})


func _build_growth_plant() -> void:
	if growth_plant != null:
		return
	growth_plant = Node2D.new()
	growth_plant.name = "GrowthPlant"
	growth_plant.set_script(GrowthPlantScript)
	add_child(growth_plant)
	move_child(growth_plant, 0)


func spawn_remote_player(id, data):
	if players.has(id):
		return

	var p = player_scene.instantiate()
	p.player_id = id
	p.is_local = false
	p.position = Vector2(float(data.get("x", 640.0)), float(data.get("y", 360.0)))
	WorldPlayerState.apply_meta(p, data)
	players_node.add_child(p)
	players[id] = p


func _spawn_cached_remote_players() -> void:
	if not Network.has_method("cached_remote_players"):
		return
	var cached: Dictionary = Network.call("cached_remote_players")
	for id in cached.keys():
		var app_user_id := int(id)
		if app_user_id != my_id:
			spawn_remote_player(app_user_id, cached[id])



func _on_ws_message(packet):
	LocalLog.write("World packet type=%s user=%s" % [str(packet.get("type", "")), str(packet.get("user_id", ""))])
	match packet.type:
		"init":
			for id in packet.players:
				id = int(id)
				if id != my_id:
					spawn_remote_player(id, packet.players[id])
		"join":
			var id = packet.user_id
			if id != my_id:
				spawn_remote_player(id, packet.data)
		"move":
			on_player_move(packet)
		"stamp":
			on_player_stamp(packet)
		"leave":
			remove_player(packet.user_id)

func on_player_move(data):
	var id = int(data.user_id)

	if id == my_id:
		return

	if not players.has(id):
		LocalLog.write("World spawn missing remote player id=%s" % id)
		spawn_remote_player(id, data)

	WorldPlayerState.apply_meta(players[id], data)
	players[id].apply_state(data)


func on_player_stamp(data: Dictionary) -> void:
	var id := int(data.get("user_id", -1))
	if id == my_id:
		return
	if not players.has(id):
		spawn_remote_player(id, data)
	if players.has(id) and players[id].has_method("show_stamp_index"):
		players[id].call("show_stamp_index", int(data.get("stamp_index", 0)))


func remove_player(id):
	if players.has(id):
		players[id].queue_free()
		players.erase(id)
	temporary_reply_allowed_user_ids.erase(int(id))
	Global.revoke_temporary_reply_to_user(int(id))


func _process(_delta: float) -> void:
	_update_nearby_talk_target()
	_update_guide()


func _update_nearby_talk_target() -> void:
	var hud := AppNodes.hud(self)
	if hud == null:
		return
	var contacts := _nearby_talkable_contacts()
	var contact: Dictionary = contacts[0] if not contacts.is_empty() else {}
	if hud.has_method("set_nearby_talk_targets"):
		hud.call("set_nearby_talk_targets", contacts)
	elif hud.has_method("set_nearby_talk_target"):
		hud.call("set_nearby_talk_target", contact)


func _nearby_talkable_contacts() -> Array:
	if not players.has(my_id):
		return []
	var local_player: Node2D = players[my_id]
	var found := []
	for id in players.keys():
		var other_id := int(id)
		if other_id == my_id:
			continue
		var player: Node2D = players[other_id]
		if not _is_player_on_screen(player):
			continue
		var dist := local_player.global_position.distance_to(player.global_position)
		if dist > TALK_DISTANCE or not WorldPlayerState.can_use_nearby_talk(player, _my_role()):
			continue
		var contact := WorldPlayerState.contact_for_player(other_id, player)
		contact["distance"] = dist
		found.append(contact)
	found.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("distance", 0)) < float(b.get("distance", 0)))
	return found


func can_chat_with_user(other_id: int) -> bool:
	if other_id == my_id:
		return false
	if temporary_reply_allowed_user_ids.has(other_id):
		return true
	if not players.has(other_id):
		return false
	var player: Node2D = players[other_id]
	if not WorldPlayerState.can_approach_player(player, _my_role()):
		return false
	if Global.is_teacher():
		return true
	if not WorldPlayerState.is_student(player):
		return true
	if not players.has(my_id):
		return false
	var local_player: Node2D = players[my_id]
	return local_player.global_position.distance_to(player.global_position) <= TALK_DISTANCE and _is_player_on_screen(player)


func has_player(user_id: int) -> bool:
	return players.has(user_id)


func allow_temporary_reply_to_user(user_id: int) -> void:
	if user_id <= 0 or user_id == my_id:
		return
	temporary_reply_allowed_user_ids[user_id] = true
	Global.allow_temporary_reply_to_user(user_id)


func guide_to_user(contact: Dictionary) -> void:
	guide_target_id = int(contact.get("user_id", -1))
	guide_contact = contact
	if guide_target_id <= 0:
		_clear_guide()
		return
	guide_label.visible = true
	guide_label.text = "相手の位置を探しています"


func show_chat_bubble_for_message(data: Dictionary) -> void:
	var sender_id := int(data.get("user_id", -1))
	if not players.has(sender_id):
		return
	var player: Node = players[sender_id]
	if player.has_method("show_chat_bubble"):
		player.call("show_chat_bubble", str(data.get("message", "")))


func _update_guide() -> void:
	if guide_target_id <= 0:
		return
	if not players.has(guide_target_id):
		guide_label.visible = true
		guide_label.text = "相手は現在この空間に見つかりません"
		pin_label.visible = false
		return
	var player: Node2D = players[guide_target_id]
	var screen_pos := _screen_position(player)
	var viewport_size := get_viewport_rect().size
	var on_screen := _is_player_on_screen(player)
	pin_label.position = screen_pos + Vector2(-22, -92)
	pin_label.visible = on_screen
	if on_screen:
		guide_label.visible = false
		return
	var center := viewport_size * 0.5
	var dir := (screen_pos - center).normalized()
	var arrow := "→"
	if abs(dir.x) > abs(dir.y):
		arrow = "→" if dir.x > 0 else "←"
	else:
		arrow = "↓" if dir.y > 0 else "↑"
	guide_label.visible = true
	guide_label.text = "%s  %s ID:%s" % [
		arrow,
		str(guide_contact.get("user_name", player.get_meta("user_name", "ユーザー"))),
		guide_target_id,
	]
	guide_label.position = Vector2(clamp(screen_pos.x, 24.0, viewport_size.x - 260.0), clamp(screen_pos.y, 24.0, viewport_size.y - 68.0))


func _clear_guide() -> void:
	guide_target_id = -1
	guide_contact = {}
	if guide_label != null:
		guide_label.visible = false
	if pin_label != null:
		pin_label.visible = false


func _build_guide_ui() -> void:
	guide_layer = CanvasLayer.new()
	guide_layer.layer = 15
	add_child(guide_layer)

	guide_label = Label.new()
	guide_label.visible = false
	guide_label.custom_minimum_size = Vector2(240, 44)
	guide_label.add_theme_font_size_override("font_size", 24)
	guide_label.add_theme_color_override("font_color", Color(1, 1, 1))
	guide_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.04))
	guide_label.add_theme_constant_override("shadow_offset_x", 2)
	guide_label.add_theme_constant_override("shadow_offset_y", 2)
	guide_layer.add_child(guide_label)

	pin_label = Label.new()
	pin_label.visible = false
	pin_label.text = "▼"
	pin_label.add_theme_font_size_override("font_size", 34)
	pin_label.add_theme_color_override("font_color", Color(1.0, 0.12, 0.16))
	pin_label.add_theme_color_override("font_shadow_color", Color(1, 1, 1))
	pin_label.add_theme_constant_override("shadow_offset_x", 1)
	pin_label.add_theme_constant_override("shadow_offset_y", 1)
	guide_layer.add_child(pin_label)


func _my_role() -> String:
	return TEACHER_ROLE if Global.is_teacher() else STUDENT_ROLE


func _is_player_on_screen(player: Node2D) -> bool:
	var viewport_size := get_viewport_rect().size
	var pos := _screen_position(player)
	return Rect2(Vector2.ZERO, viewport_size).grow(24).has_point(pos)


func _screen_position(player: Node2D) -> Vector2:
	return player.get_global_transform_with_canvas().origin
