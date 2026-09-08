extends Control

signal close_pressed

const BOLD_FONT := preload("res://assets/fonts/Noto_Sans_JP/static/NotoSansJP-Bold.ttf")
const UiFactory := preload("res://scripts/ui_factory.gd")
const MemoApiConnections := preload("res://scripts/memo_api_connections.gd")
const MemoTeacherTargets := preload("res://scripts/memo_teacher_targets.gd")
const MemoScheduleWidgets := preload("res://scripts/memo_schedule_widgets.gd")
const MemoTeacherForm := preload("res://scripts/memo_teacher_form.gd")
const MemoTeacherDistribution := preload("res://scripts/memo_teacher_distribution.gd")
const MemoEditorWidgets := preload("res://scripts/memo_editor_widgets.gd")
const MemoFilter := preload("res://scripts/memo_filter.gd")
const MemoList := preload("res://scripts/memo_list.gd")
const MemoPersonalActions := preload("res://scripts/memo_personal_actions.gd")
const MemoSelectedActions := preload("res://scripts/memo_selected_actions.gd")
const MemoPanelLayout := preload("res://scripts/memo_panel_layout.gd")
const MemoPanelState := preload("res://scripts/memo_panel_state.gd")
const MemoFetch := preload("res://scripts/memo_fetch.gd")
const PANEL_MAX_WIDTH := 1100.0
const PANEL_MAX_HEIGHT := 760.0
const PANEL_MARGIN := 28.0
const STATUSES := [
	{"id": "none", "label": "未分類"},
	{"id": "planned", "label": "予定"},
	{"id": "important", "label": "重要"},
	{"id": "done", "label": "完了"},
]

var panel: PanelContainer
var memo_input: TextEdit
var filter_option: OptionButton
var memo_list: GridContainer
var status_label: Label
var selected_detail_label: Label
var save_button: Button
var delete_button: Button
var personal_section: VBoxContainer
var write_section: VBoxContainer
var list_section: VBoxContainer
var write_view_button: Button
var list_view_button: Button
var status_button_row: HBoxContainer
var schedule_section: VBoxContainer
var schedule_month_label: Label
var schedule_calendar_grid: GridContainer
var schedule_date_label: Label
var schedule_hour: LimitedOptionButton
var schedule_minute: LimitedOptionButton
var relabel_button_row: HBoxContainer
var list_detail_label: Label
var edit_selected_button: Button
var teacher_section: VBoxContainer
var self_mode_button: Button
var distribute_mode_button: Button
var teacher_text_input: TextEdit
var teacher_status_option: OptionButton
var teacher_schedule_year: LimitedOptionButton
var teacher_schedule_month: LimitedOptionButton
var teacher_schedule_day: LimitedOptionButton
var teacher_schedule_hour: LimitedOptionButton
var teacher_schedule_minute: LimitedOptionButton
var target_class_list: VBoxContainer
var target_student_list: VBoxContainer
var teacher_target_classes: Array = []
var teacher_target_students: Array = []
var selected_class_ids := {}
var selected_student_ids := {}
var current_filter := "active"
var current_view := "self"
var current_screen := "write"
var current_status := "none"
var editing_memo_id := 0
var selected_memo_id := 0
var selected_memo: Dictionary = {}
var loaded_memos: Array = []
var closing_with_autosave := false
var autosave_performed := false
var schedule_year := 0
var schedule_month := 0
var selected_schedule_date := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	if not Global.ui_theme_changed.is_connected(_on_ui_theme_changed):
		Global.ui_theme_changed.connect(_on_ui_theme_changed)
	MemoApiConnections.connect_signals(DjangoApi, self)
	_fetch_memos()


func _process(_delta: float) -> void:
	UiFactory.fit_centered_panel(panel, get_viewport_rect().size, Vector2(PANEL_MAX_WIDTH, PANEL_MAX_HEIGHT), PANEL_MARGIN)
	UiFactory.fit_grid_columns(memo_list, list_section)


func _exit_tree() -> void:
	_autosave_input_memo()


func _on_ui_theme_changed(_theme: String) -> void:
	# 既に開いているメモ画面にも、新しいテーマの可読色を直ちに反映する。
	UiFactory.apply_mysterious_theme(self)
	MemoPanelState.apply_status_buttons(status_button_row, current_status)
	MemoFilter.apply_filter_style(filter_option, current_filter, BOLD_FONT)
	if current_screen == "list":
		_render_memo_list(loaded_memos)


func _build_ui() -> void:
	var shell := MemoPanelLayout.shell(self, BOLD_FONT, _close_panel)
	panel = shell["panel"] as PanelContainer
	var root := shell["root"] as VBoxContainer

	if Global.is_teacher():
		var mode_row := MemoPanelLayout.teacher_mode_row(root, BOLD_FONT, func(): _set_memo_view("self"), func(): _set_memo_view("distribute"))
		self_mode_button = mode_row["self_button"] as Button
		distribute_mode_button = mode_row["distribute_button"] as Button

	personal_section = MemoPanelLayout.vbox(8)
	root.add_child(personal_section)

	var screen_row := MemoPanelLayout.personal_screen_row(personal_section, BOLD_FONT, _start_new_memo, func(): _set_personal_screen("list"))
	write_view_button = screen_row["write_button"] as Button
	list_view_button = screen_row["list_button"] as Button

	write_section = MemoPanelLayout.vbox(8)
	personal_section.add_child(write_section)

	var label_row := MemoEditorWidgets.status_label_row(STATUSES, BOLD_FONT, _set_current_status)
	write_section.add_child(label_row["root"] as Node)
	status_button_row = label_row["status_row"] as HBoxContainer

	var editor_layout := MemoEditorWidgets.editor_layout()
	write_section.add_child(editor_layout["root"] as Node)
	var editor_column := editor_layout["editor_column"] as VBoxContainer
	schedule_section = editor_layout["schedule_section"] as VBoxContainer

	memo_input = MemoEditorWidgets.memo_input(BOLD_FONT)
	editor_column.add_child(memo_input)
	Callable(UiFactory, "localize_text_edit_menu").call_deferred(memo_input)

	MemoScheduleWidgets.build_personal_picker(self, schedule_section, BOLD_FONT)

	var primary_row := MemoEditorWidgets.primary_actions(BOLD_FONT, _save_input_memo, _delete_selected_memo)
	editor_column.add_child(primary_row["root"] as Node)
	save_button = primary_row["save_button"] as Button
	delete_button = primary_row["delete_button"] as Button

	selected_detail_label = UiFactory.label("", 15, Color(0.32, 0.38, 0.45), BOLD_FONT)
	selected_detail_label.visible = false
	editor_column.add_child(selected_detail_label)

	list_section = MemoPanelLayout.vbox(10, false)
	personal_section.add_child(list_section)

	var toolbar := MemoFilter.toolbar(STATUSES, BOLD_FONT, _on_filter_selected, _apply_selected_status, _edit_selected_memo)
	list_section.add_child(toolbar["root"] as Node)
	filter_option = toolbar["filter_option"] as OptionButton
	UiFactory.limit_option_popup(filter_option, 132, 36)
	MemoFilter.apply_filter_style(filter_option, current_filter, BOLD_FONT)
	relabel_button_row = toolbar["relabel_row"] as HBoxContainer
	edit_selected_button = toolbar["edit_button"] as Button
	list_detail_label = toolbar["detail_label"] as Label
	list_section.add_child(list_detail_label)

	if Global.is_teacher():
		teacher_section = MemoPanelLayout.vbox(8, false)
		root.add_child(teacher_section)
		_build_teacher_distribution(teacher_section)

	var list_grid := MemoPanelLayout.list_scroll_grid(list_section)
	memo_list = list_grid["grid"] as GridContainer

	status_label = UiFactory.label("", 16, Color(0.18, 0.27, 0.35), BOLD_FONT)
	root.add_child(status_label)
	if Global.is_teacher():
		_set_memo_view("self", false)
	_set_current_status("none")
	_set_personal_screen("write", false)
	UiFactory.fit_centered_panel(panel, get_viewport_rect().size, Vector2(PANEL_MAX_WIDTH, PANEL_MAX_HEIGHT), PANEL_MARGIN)


func _build_teacher_distribution(parent: VBoxContainer) -> void:
	var form := MemoTeacherForm.build(STATUSES, BOLD_FONT)
	parent.add_child(form["root"] as Node)
	teacher_text_input = form["text_input"] as TextEdit
	teacher_status_option = form["status_option"] as OptionButton
	teacher_schedule_year = form["schedule_year"] as LimitedOptionButton
	teacher_schedule_month = form["schedule_month"] as LimitedOptionButton
	teacher_schedule_day = form["schedule_day"] as LimitedOptionButton
	teacher_schedule_hour = form["schedule_hour"] as LimitedOptionButton
	teacher_schedule_minute = form["schedule_minute"] as LimitedOptionButton
	target_class_list = form["target_class_list"] as VBoxContainer
	target_student_list = form["target_student_list"] as VBoxContainer
	var refresh := form["refresh"] as Button
	var class_send := form["class_send"] as Button
	var student_send := form["student_send"] as Button

	refresh.pressed.connect(func(): DjangoApi.fetch_teacher_memo_targets())
	UiFactory.limit_option_popup(teacher_status_option, 116, 32)
	class_send.pressed.connect(func(): _distribute_teacher_memo("classes", selected_class_ids.keys(), []))
	student_send.pressed.connect(func(): _distribute_teacher_memo("students", [], selected_student_ids.keys()))
	teacher_schedule_year.item_selected.connect(func(_index): MemoScheduleWidgets.refresh_teacher_day_options(teacher_schedule_year, teacher_schedule_month, teacher_schedule_day))
	teacher_schedule_month.item_selected.connect(func(_index): MemoScheduleWidgets.refresh_teacher_day_options(teacher_schedule_year, teacher_schedule_month, teacher_schedule_day))
	MemoScheduleWidgets.set_teacher_schedule_today(
		teacher_schedule_year,
		teacher_schedule_month,
		teacher_schedule_day,
		teacher_schedule_hour,
		teacher_schedule_minute
	)


func _fetch_memos() -> void:
	status_label.text = MemoFetch.fetch_memos(DjangoApi, Global.is_teacher(), current_view, current_filter)


func _set_memo_view(view: String, fetch: bool = true) -> void:
	current_view = view
	MemoPanelState.apply_memo_view(view, personal_section, teacher_section, self_mode_button, distribute_mode_button)
	if not fetch:
		return
	if view == "self":
		status_label.text = ""
		_fetch_memos()
	elif DjangoApi.has_method("fetch_teacher_memo_targets"):
		status_label.text = MemoFetch.fetch_teacher_targets(DjangoApi, memo_list)


func _set_personal_screen(screen: String, focus_input: bool = true) -> void:
	current_screen = screen
	MemoPanelState.apply_personal_screen(screen, editing_memo_id, write_section, list_section, write_view_button, list_view_button, memo_input, focus_input)


func _start_new_memo() -> void:
	_clear_selection()
	MemoPanelState.apply_new_editor(memo_input, save_button, status_label)
	MemoScheduleWidgets.apply_personal_schedule(self, MemoScheduleWidgets.personal_schedule_today(schedule_hour, schedule_minute), BOLD_FONT, _select_schedule_date)
	_set_current_status("none")
	_set_personal_screen("write")


func _save_input_memo() -> void:
	var text := memo_input.text.strip_edges()
	var request := MemoPersonalActions.save_request(text, editing_memo_id, current_status, _selected_schedule_iso())
	if not bool(request["ok"]):
		status_label.text = str(request["message"])
		return
	status_label.text = "保存中..."
	MemoPersonalActions.submit(DjangoApi, request)


func _apply_selected_status(status: String) -> void:
	var result := MemoSelectedActions.apply_status(DjangoApi, selected_memo_id, selected_memo, status)
	status_label.text = str(result["message"])


func _delete_selected_memo() -> void:
	var result := MemoSelectedActions.delete(DjangoApi, selected_memo_id)
	status_label.text = str(result["message"])


func _autosave_input_memo() -> void:
	var text := memo_input.text.strip_edges()
	if not MemoPersonalActions.has_autosave_text(text, autosave_performed):
		return
	autosave_performed = true
	closing_with_autosave = true
	var request := MemoPersonalActions.save_request(text, editing_memo_id, current_status, _selected_schedule_iso())
	MemoPersonalActions.submit(DjangoApi, request)


func _close_panel() -> void:
	_autosave_input_memo()
	emit_signal("close_pressed")
	queue_free()


func _on_filter_selected(index: int) -> void:
	current_filter = MemoFilter.selected_filter(index, STATUSES)
	MemoFilter.apply_filter_style(filter_option, current_filter, BOLD_FONT)
	_clear_selection()
	_fetch_memos()


func _on_memos_received(memos: Array) -> void:
	if current_view != "self":
		return
	loaded_memos = memos
	_render_memo_list(memos)


func _render_memo_list(memos: Array) -> void:
	MemoList.render(memo_list, memos, current_filter, selected_memo_id, BOLD_FONT, _select_memo)
	status_label.text = ""


func _on_memo_saved(_memo: Dictionary) -> void:
	if closing_with_autosave:
		return
	MemoPanelState.apply_new_editor(memo_input, save_button, null)
	editing_memo_id = 0
	_clear_selection()
	_set_current_status("none")
	_set_personal_screen("list", false)
	_fetch_memos()


func _on_memo_deleted(_id: int) -> void:
	_clear_selection()
	_fetch_memos()


func _on_request_failed(code: int, errors = {}) -> void:
	status_label.text = "通信に失敗しました: %s" % code


func _on_teacher_memo_targets_received(classes: Array, students: Array) -> void:
	teacher_target_classes = classes
	teacher_target_students = students
	_render_teacher_targets()


func _on_teacher_memo_distributed(created_count: int, _targets: Array) -> void:
	status_label.text = MemoTeacherDistribution.apply_success(created_count, teacher_text_input)


func _render_teacher_targets() -> void:
	MemoTeacherTargets.render(
		target_class_list,
		target_student_list,
		teacher_target_classes,
		teacher_target_students,
		selected_class_ids,
		selected_student_ids,
		BOLD_FONT
	)


func _distribute_teacher_memo(scope: String, class_ids: Array, student_ids: Array) -> void:
	if teacher_text_input == null:
		return
	var text := teacher_text_input.text.strip_edges()
	var request := MemoTeacherDistribution.request_payload(scope, class_ids, student_ids, text, STATUSES, teacher_status_option.selected, _teacher_schedule_iso())
	if not bool(request["ok"]):
		status_label.text = str(request["message"])
		return
	status_label.text = "配布中..."
	MemoTeacherDistribution.submit(DjangoApi, request)


func _select_memo(memo: Dictionary) -> void:
	var selection := MemoSelectedActions.selection_state(memo, selected_memo_id)
	if bool(selection["same_selection"]):
		_clear_selection()
		_render_memo_list(loaded_memos)
		return
	selected_memo = selection.get("memo", {}) as Dictionary
	selected_memo_id = int(selection["memo_id"])
	_update_selection_controls()
	_render_memo_list(loaded_memos)
	_start_edit_memo(memo)


func _edit_selected_memo() -> void:
	var request := MemoSelectedActions.edit_request(selected_memo_id, selected_memo)
	if not bool(request["ok"]):
		status_label.text = str(request["message"])
		return
	var memo: Dictionary = request.get("memo", {})
	_start_edit_memo(memo)


func _start_edit_memo(memo: Dictionary) -> void:
	var edit_state := MemoPanelState.apply_edit_editor(memo, memo_input, save_button, status_label)
	editing_memo_id = int(edit_state["id"])
	_set_current_status(str(edit_state["status"]))
	MemoScheduleWidgets.apply_personal_schedule(self, MemoScheduleWidgets.personal_schedule_from_iso(str(edit_state["scheduled_at"]), schedule_hour, schedule_minute), BOLD_FONT, _select_schedule_date)
	_set_personal_screen("write")
	memo_input.grab_focus()
	Callable(UiFactory, "move_text_caret_to_end").call_deferred(memo_input)
	_update_selection_controls()


func _clear_selection() -> void:
	var had_selection := MemoPanelState.clear_selection_state(self, memo_input)
	if had_selection:
		_set_current_status("none")
	_update_selection_controls()


func _update_selection_controls() -> void:
	MemoPanelState.apply_selection_controls(selected_memo, relabel_button_row, delete_button, edit_selected_button, selected_detail_label, list_detail_label, save_button)


func _set_current_status(status_id: String) -> void:
	var state := MemoPanelState.apply_status_state(STATUSES, status_id, status_button_row, memo_input, schedule_section, selected_schedule_date)
	current_status = str(state["status"])
	if bool(state["needs_default_schedule"]):
		MemoScheduleWidgets.apply_personal_schedule(self, MemoScheduleWidgets.personal_schedule_today(schedule_hour, schedule_minute), BOLD_FONT, _select_schedule_date)


func _selected_schedule_iso() -> String:
	return MemoScheduleWidgets.personal_schedule_iso(current_status, selected_schedule_date, schedule_hour, schedule_minute)


func _teacher_schedule_iso() -> String:
	return MemoScheduleWidgets.teacher_schedule_iso(
		teacher_schedule_year,
		teacher_schedule_month,
		teacher_schedule_day,
		teacher_schedule_hour,
		teacher_schedule_minute
	)


func _select_schedule_date(value: String) -> void:
	MemoScheduleWidgets.select_personal_date(self, value, BOLD_FONT, _select_schedule_date)
