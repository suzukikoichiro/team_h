extends Control

signal close_pressed

const BOLD_FONT := preload("res://assets/fonts/Noto_Sans_JP/static/NotoSansJP-Bold.ttf")
const UiFactory := preload("res://scripts/ui_factory.gd")
const LessonActions := preload("res://scripts/lesson_actions.gd")
const LessonCard := preload("res://scripts/lesson_card.gd")
const LessonDetailWidgets := preload("res://scripts/lesson_detail_widgets.gd")
const LessonTeacherForms := preload("res://scripts/lesson_teacher_forms.gd")
const LessonWidgets := preload("res://scripts/lesson_widgets.gd")
const PANEL_MAX_WIDTH := 960.0
const PANEL_MAX_HEIGHT := 640.0
const PANEL_MARGIN := 28.0

var panel: PanelContainer
var title_input: LineEdit
var url_input: LineEdit
var description_input: TextEdit
var links_list: GridContainer
var detail_panel: Control
var selected_title_label: Label
var selected_meta_label: Label
var selected_description_label: Label
var status_label: Label
var selected_url: String = ""
var links: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	Global.chat_is_open = true
	if not DjangoApi.lesson_recordings_received.is_connected(_on_links_received):
		DjangoApi.lesson_recordings_received.connect(_on_links_received)
	if not DjangoApi.lesson_recording_saved.is_connected(_on_link_saved):
		DjangoApi.lesson_recording_saved.connect(_on_link_saved)
	if not DjangoApi.request_failed.is_connected(_on_request_failed):
		DjangoApi.request_failed.connect(_on_request_failed)
	_build_ui()
	_refresh()


func _exit_tree() -> void:
	Global.chat_is_open = false


func _process(_delta: float) -> void:
	UiFactory.fit_centered_panel(panel, get_viewport_rect().size, Vector2(PANEL_MAX_WIDTH, PANEL_MAX_HEIGHT), PANEL_MARGIN)
	UiFactory.fit_grid_columns(links_list, links_list, 220.0, 3)


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.055, 0.07, 0.42)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -590
	panel.offset_top = -340
	panel.offset_right = 590
	panel.offset_bottom = 340
	panel.add_theme_stylebox_override("panel", LessonWidgets.panel_style())
	add_child(panel)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := LessonWidgets.heading("授業リンク", BOLD_FONT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var refresh := LessonWidgets.icon_button("↺", "更新")
	refresh.pressed.connect(_refresh)
	header.add_child(refresh)
	var close := LessonWidgets.icon_button("×", "閉じる")
	close.pressed.connect(_close)
	header.add_child(close)
	if _is_teacher():
		var controls := LessonTeacherForms.build_link(root, BOLD_FONT, _post_link)
		title_input = controls["title"]
		url_input = controls["url"]
		description_input = controls["description"]
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	root.add_child(content)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	left.add_theme_constant_override("separation", 8)
	content.add_child(left)
	left.add_child(LessonWidgets.section_label("共有されたリンク", BOLD_FONT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	links_list = GridContainer.new()
	links_list.columns = 3
	links_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links_list.add_theme_constant_override("h_separation", 8)
	links_list.add_theme_constant_override("v_separation", 8)
	scroll.add_child(links_list)
	var detail := LessonDetailWidgets.build(content, BOLD_FONT, _open_selected_url)
	detail_panel = detail["root"] as Control
	selected_title_label = detail["title_label"] as Label
	selected_meta_label = detail["meta_label"] as Label
	selected_description_label = detail["description_label"] as Label
	status_label = LessonWidgets.muted_label("")
	root.add_child(status_label)


func _refresh() -> void:
	DjangoApi.fetch_lesson_recordings()


func _post_link() -> void:
	var request := LessonActions.link_request(title_input, url_input, description_input)
	status_label.text = str(request.get("status", ""))
	if bool(request.get("ok", false)):
		DjangoApi.post_lesson_recording(request["payload"])


func _on_links_received(next_links: Array) -> void:
	links = next_links
	UiFactory.clear_children(links_list)
	if links.is_empty():
		links_list.add_child(LessonWidgets.muted_label("共有されたリンクはまだありません"))
		return
	for link in links:
		if typeof(link) == TYPE_DICTIONARY:
			links_list.add_child(LessonCard.build(link, BOLD_FONT, _select_link))


func _on_link_saved(_link: Dictionary) -> void:
	status_label.text = ""
	LessonActions.reset_link_form(title_input, url_input, description_input)
	_refresh()


func _select_link(link: Dictionary) -> void:
	selected_url = str(link.get("link_url", ""))
	selected_title_label.text = str(link.get("title", "共有リンク"))
	selected_meta_label.text = "投稿者: %s" % str(link.get("teacher_user_name", "教職員"))
	selected_description_label.text = "説明\n%s" % str(link.get("description", "説明はありません"))
	detail_panel.visible = true


func _open_selected_url() -> void:
	if selected_url != "":
		OS.shell_open(selected_url)


func _on_request_failed(code: int, _errors = {}) -> void:
	status_label.text = "通信に失敗しました: %s" % code


func _is_teacher() -> bool:
	return int(Global.user_position) == 1


func _close() -> void:
	emit_signal("close_pressed")
	queue_free()
