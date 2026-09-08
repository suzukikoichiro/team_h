extends Node

signal login_done
signal stamp_selected(texture: Texture2D, index: int)
signal avatar_changed(avatar_key: String)
signal ui_theme_changed(theme: String)
signal ui_text_scale_changed(scale: float)

const UI_TEXT_SCALES := [1.0, 1.2, 1.4]
const TEXT_SCALE_META := "ui_text_scale_base_font_size"
const TEXT_MIN_HEIGHT_META := "ui_text_scale_base_min_height"


var user_id: int = -1
var username: String = ""
var school_id: int = -1
var user_position: int = -1
var gender: int = 2
var avatar_key: String = "skin_01"
var is_logged_in: bool = false
var chat_is_open: bool = false
var chat_enter_to_send: bool = true
var chat_history_limit: int = 100
var allow_nearby_chat: bool = true
var mood_status: String = "fine"
var talk_permission: String = "all"
var temporary_reply_allowed_user_ids := {}
var ui_theme := "light"
var ui_text_scale_level := 0

func _ready():
	_load_ui_theme()
	get_tree().node_added.connect(_on_node_added)
	call_deferred("apply_text_scale_to_tree")
	LocalLog.write("Global ready instance=%s" % get_instance_id())


func set_ui_theme(value: String) -> void:
	var next := "light" if value == "light" else "dark"
	if ui_theme == next:
		return
	ui_theme = next
	var config := ConfigFile.new()
	config.set_value("display", "ui_theme", ui_theme)
	config.set_value("display", "ui_text_scale_level", ui_text_scale_level)
	config.save("user://ui_settings.cfg")
	emit_signal("ui_theme_changed", ui_theme)


func _load_ui_theme() -> void:
	var config := ConfigFile.new()
	if config.load("user://ui_settings.cfg") == OK:
		ui_theme = "light" if str(config.get_value("display", "ui_theme", "light")) == "light" else "dark"
		ui_text_scale_level = clampi(int(config.get_value("display", "ui_text_scale_level", 0)), 0, UI_TEXT_SCALES.size() - 1)


func get_ui_text_scale() -> float:
	return UI_TEXT_SCALES[ui_text_scale_level]


func set_ui_text_scale_level(value: int) -> void:
	var next := clampi(value, 0, UI_TEXT_SCALES.size() - 1)
	if ui_text_scale_level == next:
		return
	ui_text_scale_level = next
	var config := ConfigFile.new()
	config.set_value("display", "ui_theme", ui_theme)
	config.set_value("display", "ui_text_scale_level", ui_text_scale_level)
	config.save("user://ui_settings.cfg")
	apply_text_scale_to_tree()
	emit_signal("ui_text_scale_changed", get_ui_text_scale())


func apply_text_scale_to_tree() -> void:
	_apply_text_scale_recursive(get_tree().root)


func _on_node_added(node: Node) -> void:
	if node is Control:
		call_deferred("_apply_text_scale_recursive", node)


func _apply_text_scale_recursive(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is Label or node is RichTextLabel or node is Button or node is OptionButton or node is CheckBox or node is LineEdit or node is TextEdit:
		_apply_text_scale(node as Control)
	for child in node.get_children():
		_apply_text_scale_recursive(child)


func _apply_text_scale(control: Control) -> void:
	if not control.has_meta(TEXT_SCALE_META):
		control.set_meta(TEXT_SCALE_META, control.get_theme_font_size("font_size"))
	var base_size := int(control.get_meta(TEXT_SCALE_META))
	control.add_theme_font_size_override("font_size", roundi(base_size * get_ui_text_scale()))
	if control is Button or control is OptionButton or control is LineEdit or control is TextEdit:
		if not control.has_meta(TEXT_MIN_HEIGHT_META):
			control.set_meta(TEXT_MIN_HEIGHT_META, control.custom_minimum_size.y)
		var base_height := float(control.get_meta(TEXT_MIN_HEIGHT_META))
		if base_height > 0.0:
			control.custom_minimum_size.y = roundf(base_height * get_ui_text_scale())

func set_login_info(id: int, name: String, _school_id: int, _user_position: int = -1, _gender: int = 2, _avatar_key: String = "") -> void:
	user_id = id
	username = name
	school_id = _school_id
	user_position = _user_position
	gender = _gender
	avatar_key = _avatar_key if _avatar_key != "" else default_avatar_for_gender(gender)
	is_logged_in = true
	emit_signal("login_done")
	LocalLog.write("Global login_done user=%s school=%s position=%s" % [user_id, school_id, user_position])

func clear_login_info():
	user_id = -1
	username = ""
	school_id = -1
	user_position = -1
	gender = 2
	avatar_key = "skin_01"
	is_logged_in = false
	chat_is_open = false
	allow_nearby_chat = true
	mood_status = "fine"
	talk_permission = "all"
	temporary_reply_allowed_user_ids.clear()


func is_teacher() -> bool:
	return user_position == 1


func is_student() -> bool:
	return user_position == 2


func default_avatar_for_gender(value: int) -> String:
	return "skin_02" if value == 1 else "skin_01"


func set_avatar_key(value: String, force_emit := false) -> void:
	var next_avatar := value if value != "" and value != "default" else default_avatar_for_gender(gender)
	if avatar_key == next_avatar and not force_emit:
		return
	avatar_key = next_avatar
	emit_signal("avatar_changed", avatar_key)


func set_daily_mood(status: String, permission: String) -> void:
	mood_status = status
	talk_permission = permission
	allow_nearby_chat = permission != "none"


func can_be_approached_by(role: String) -> bool:
	match talk_permission:
		"none":
			return false
		"students":
			return role == "student"
		"teachers":
			return role == "teacher"
		_:
			return true


func allow_temporary_reply_to_user(id: int) -> void:
	if id <= 0 or id == user_id:
		return
	temporary_reply_allowed_user_ids[id] = true


func revoke_temporary_reply_to_user(id: int) -> void:
	temporary_reply_allowed_user_ids.erase(id)


func can_temporary_reply_to_user(id: int) -> bool:
	return temporary_reply_allowed_user_ids.has(id)
