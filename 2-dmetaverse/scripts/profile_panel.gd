extends Control

signal close_pressed
signal locate_user(contact: Dictionary)

const BOLD_FONT := preload("res://assets/fonts/Noto_Sans_JP/static/NotoSansJP-Bold.ttf")
const UiFactory := preload("res://scripts/ui_factory.gd")
const ProfileAvatar := preload("res://scripts/profile_avatar.gd")
const ProfileEditWidgets := preload("res://scripts/profile_edit_widgets.gd")
const ProfileFormWidgets := preload("res://scripts/profile_form_widgets.gd")
const ProfileResultCard := preload("res://scripts/profile_result_card.gd")
const ProfileSkinChoices := preload("res://scripts/profile_skin_choices.gd")
const PANEL_MAX_WIDTH := 960.0
const PANEL_MAX_HEIGHT := 600.0
const PANEL_MARGIN := 48.0

var name_input: LineEdit
var nickname_input: LineEdit
var age_input: LineEdit
var hobbies_input: TextEdit
var message_input: TextEdit
var search_input: LineEdit
var status_label: Label
var result_list: VBoxContainer
var panel: PanelContainer
var avatar_texture: TextureRect
var skin_choice_panel: PanelContainer
var title_label: Label
var search_launcher: Button
var edit_view: Control
var drawer_overlay: Control
var search_drawer: PanelContainer
var drawer_tween: Tween
var current_avatar_key := "skin_01"
var avatar_dirty := false
var showing_search := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_connect_api()
	_fit_panel()
	if DjangoApi.has_method("fetch_my_profile"):
		DjangoApi.fetch_my_profile()


func _process(_delta: float) -> void:
	_fit_panel()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.055, 0.07, 0.42)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.add_theme_stylebox_override("panel", UiFactory.style(Color(0.972, 0.977, 0.984), Color(0.70, 0.75, 0.80), 8))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)

	title_label = UiFactory.label("プロフィール編集", 26, Color(0.08, 0.11, 0.15), BOLD_FONT)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_label)

	search_launcher = ProfileFormWidgets.search_launcher_button(BOLD_FONT)
	search_launcher.custom_minimum_size = Vector2(260, 38)
	search_launcher.pressed.connect(func():
		if not showing_search:
			call_deferred("_show_search_drawer")
	)
	top.add_child(search_launcher)

	var close_button := ProfileFormWidgets.primary_button("閉じる", Vector2(86, 38), BOLD_FONT)
	close_button.pressed.connect(func():
		emit_signal("close_pressed")
		queue_free()
	)
	top.add_child(close_button)

	edit_view = _build_edit_panel()
	edit_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(edit_view)

	status_label = UiFactory.label("", 17, Color(0.16, 0.26, 0.35), BOLD_FONT)
	root.add_child(status_label)

	_build_search_overlay()


func _build_edit_panel() -> Control:
	var refs := ProfileEditWidgets.build(BOLD_FONT, current_avatar_key, Callable(self, "_toggle_skin_choices"), Callable(self, "_save_profile"))
	name_input = refs["name_input"] as LineEdit
	nickname_input = refs["nickname_input"] as LineEdit
	age_input = refs["age_input"] as LineEdit
	hobbies_input = refs["hobbies_input"] as TextEdit
	message_input = refs["message_input"] as TextEdit
	avatar_texture = refs["avatar_texture"] as TextureRect
	return refs["root"] as Control


func _build_search_panel() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)

	var search_header := HBoxContainer.new()
	search_header.add_theme_constant_override("separation", 12)
	box.add_child(search_header)

	var search_title := UiFactory.label("ユーザーを探す", 22, Color(0.08, 0.11, 0.15), BOLD_FONT)
	search_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_header.add_child(search_title)

	var back_button := ProfileFormWidgets.primary_button("戻る", Vector2(86, 38), BOLD_FONT)
	back_button.pressed.connect(_close_search_drawer)
	search_header.add_child(back_button)

	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 8)
	box.add_child(search_row)

	search_input = ProfileFormWidgets.line_edit("名前・あだ名・趣味・一言で検索", BOLD_FONT)
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.text_submitted.connect(func(_text: String): _search_profiles())
	search_row.add_child(search_input)

	var search_button := ProfileFormWidgets.primary_button("検索", Vector2(78, 40), BOLD_FONT)
	search_button.pressed.connect(_search_profiles)
	search_row.add_child(search_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	result_list = VBoxContainer.new()
	result_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_list.add_theme_constant_override("separation", 8)
	scroll.add_child(result_list)
	result_list.add_child(UiFactory.label("キーワードを入力して検索してください", 18, Color(0.30, 0.36, 0.43), BOLD_FONT))
	return box


func _connect_api() -> void:
	if not DjangoApi.profile_received.is_connected(_on_profile_received):
		DjangoApi.profile_received.connect(_on_profile_received)
	if not DjangoApi.profile_saved.is_connected(_on_profile_saved):
		DjangoApi.profile_saved.connect(_on_profile_saved)
	if not DjangoApi.profile_search_received.is_connected(_on_profile_search_received):
		DjangoApi.profile_search_received.connect(_on_profile_search_received)
	if not DjangoApi.request_failed.is_connected(_on_request_failed):
		DjangoApi.request_failed.connect(_on_request_failed)


func _build_search_overlay() -> void:
	drawer_overlay = Control.new()
	drawer_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	drawer_overlay.visible = false
	drawer_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	drawer_overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_search_drawer()
	)
	panel.add_child(drawer_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.055, 0.07, 0.10)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer_overlay.add_child(shade)

	search_drawer = PanelContainer.new()
	search_drawer.anchor_left = 0.48
	search_drawer.anchor_top = 0.0
	search_drawer.anchor_right = 1.0
	search_drawer.anchor_bottom = 1.0
	search_drawer.offset_left = 0
	search_drawer.offset_top = 0
	search_drawer.offset_right = 0
	search_drawer.offset_bottom = 0
	search_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	search_drawer.add_theme_stylebox_override("panel", UiFactory.style(Color(0.985, 0.99, 1.0), Color(0.64, 0.70, 0.78), 8))
	drawer_overlay.add_child(search_drawer)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	search_drawer.add_child(margin)
	margin.add_child(_build_search_panel())


func _save_profile() -> void:
	var age_text := age_input.text.strip_edges()
	if age_text != "" and not age_text.is_valid_int():
		status_label.text = "年齢は整数で入力してください"
		age_input.grab_focus()
		return
	age_input.text = age_text
	if DjangoApi.has_method("save_profile"):
		DjangoApi.save_profile({
			"nickname": nickname_input.text,
			"age": age_text,
			"hobbies": hobbies_input.text,
			"message": message_input.text,
			"avatar_key": current_avatar_key,
		})
		status_label.text = "保存中..."


func _search_profiles() -> void:
	if not showing_search:
		_show_search_drawer()
	var query := search_input.text.strip_edges()
	if query == "":
		UiFactory.clear_children(result_list)
		status_label.text = "検索キーワードを入力してください"
		return
	status_label.text = "検索中..."
	if DjangoApi.has_method("search_profiles"):
		DjangoApi.search_profiles(query)


func _on_profile_received(profile: Dictionary) -> void:
	_apply_profile(profile, not avatar_dirty, false)
	status_label.text = ""


func _on_profile_saved(profile: Dictionary) -> void:
	avatar_dirty = false
	_apply_profile(profile, true, true)
	status_label.text = "保存しました"


func _on_profile_search_received(profiles: Array) -> void:
	UiFactory.clear_children(result_list)
	if profiles.is_empty():
		result_list.add_child(UiFactory.label("見つかりませんでした", 18, Color(0.30, 0.36, 0.43), BOLD_FONT))
		status_label.text = ""
		return
	for profile in profiles:
		if typeof(profile) == TYPE_DICTIONARY:
			var avatar := ProfileAvatar.preview_texture(str(profile.get("avatar_key", "skin_01")))
			result_list.add_child(ProfileResultCard.build(profile, avatar, BOLD_FONT, _emit_locate_user))
	status_label.text = "%d件見つかりました" % profiles.size()


func _on_request_failed(code: int, errors = {}) -> void:
	var source := ""
	if typeof(errors) == TYPE_DICTIONARY:
		source = str(errors.get("source", ""))
	if source != "profile_me" and source != "profile_save" and source != "profile_search":
		return
	var age_errors = errors.get("errors", {}).get("age", []) if typeof(errors) == TYPE_DICTIONARY else []
	if not age_errors.is_empty():
		status_label.text = str(age_errors[0])
		age_input.grab_focus()
		return
	status_label.text = "通信に失敗しました: %s" % code


func _apply_profile(profile: Dictionary, overwrite_avatar := true, force_avatar_emit := false) -> void:
	name_input.text = str(profile.get("display_name", profile.get("user_name", "")))
	nickname_input.text = str(profile.get("nickname", ""))
	var age_value = profile.get("age", "")
	age_input.text = "" if age_value == null else str(int(age_value))
	hobbies_input.text = str(profile.get("hobbies", ""))
	message_input.text = str(profile.get("message", ""))
	if overwrite_avatar:
		current_avatar_key = str(profile.get("avatar_key", Global.default_avatar_for_gender(int(profile.get("gender", Global.gender)))))
		Global.set_avatar_key(current_avatar_key, force_avatar_emit)
		if avatar_texture != null:
			avatar_texture.texture = ProfileAvatar.preview_texture(current_avatar_key)


func _emit_locate_user(profile: Dictionary) -> void:
	emit_signal("locate_user", {
		"user_id": int(profile.get("user_id", 0)),
		"user_name": str(profile.get("user_name", profile.get("display_name", "ユーザー"))),
		"role": str(profile.get("role", "")),
		"role_label": str(profile.get("role_label", "ユーザー")),
		"avatar_key": str(profile.get("avatar_key", "skin_01")),
	})


func _close_search_drawer() -> void:
	if not showing_search:
		return
	showing_search = false
	if drawer_tween != null:
		drawer_tween.kill()
	if search_drawer != null and drawer_overlay != null and drawer_overlay.visible:
		drawer_tween = create_tween()
		drawer_tween.set_parallel(true)
		drawer_tween.tween_property(search_drawer, "anchor_left", 1.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		drawer_tween.tween_property(drawer_overlay, "modulate:a", 0.0, 0.16)
		drawer_tween.finished.connect(func():
			if drawer_overlay != null:
				drawer_overlay.visible = false
			if search_drawer != null:
				search_drawer.anchor_left = 0.48
			drawer_tween = null
		)
	status_label.text = ""


func _show_search_drawer() -> void:
	if showing_search:
		return
	showing_search = true
	if drawer_overlay != null:
		if drawer_tween != null:
			drawer_tween.kill()
		drawer_overlay.visible = true
		drawer_overlay.modulate.a = 0.0
		drawer_overlay.move_to_front()
	if search_drawer != null:
		search_drawer.anchor_left = 1.0
		drawer_tween = create_tween()
		drawer_tween.set_parallel(true)
		drawer_tween.tween_property(search_drawer, "anchor_left", 0.48, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		drawer_tween.tween_property(drawer_overlay, "modulate:a", 1.0, 0.16)
		drawer_tween.finished.connect(func():
			drawer_tween = null
		)
	status_label.text = ""
	if search_input != null:
		search_input.call_deferred("grab_focus")


func _toggle_skin_choices(anchor: Control) -> void:
	if skin_choice_panel != null and is_instance_valid(skin_choice_panel):
		skin_choice_panel.queue_free()
		skin_choice_panel = null
		return
	skin_choice_panel = ProfileSkinChoices.build(anchor, BOLD_FONT, _select_skin)
	add_child(skin_choice_panel)
	skin_choice_panel.move_to_front()


func _select_skin(avatar_key: String) -> void:
	current_avatar_key = avatar_key
	avatar_dirty = true
	Global.set_avatar_key(current_avatar_key, true)
	if avatar_texture != null:
		avatar_texture.texture = ProfileAvatar.preview_texture(current_avatar_key)
	if skin_choice_panel != null and is_instance_valid(skin_choice_panel):
		skin_choice_panel.queue_free()
		skin_choice_panel = null
	status_label.text = "スキンを変更しました。保存すると反映されます"


func _fit_panel() -> void:
	UiFactory.fit_centered_panel(panel, get_viewport_rect().size, Vector2(PANEL_MAX_WIDTH, PANEL_MAX_HEIGHT), PANEL_MARGIN)
