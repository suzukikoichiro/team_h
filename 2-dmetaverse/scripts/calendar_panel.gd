extends Control

signal close_pressed

const BOLD_FONT := preload("res://assets/fonts/Noto_Sans_JP/static/NotoSansJP-Bold.ttf")
const UiFactory := preload("res://scripts/ui_factory.gd")
const MemoSchedule := preload("res://scripts/memo_schedule.gd")
const CalendarWidgets := preload("res://scripts/calendar_widgets.gd")
const PANEL_MAX_WIDTH := 940.0
const PANEL_MAX_HEIGHT := 660.0
const PANEL_MARGIN := 28.0

var panel: PanelContainer
var month_label: Label
var calendar_grid: GridContainer
var event_list: VBoxContainer
var status_label: Label
var title_input: LineEdit
var hour_input: LimitedOptionButton
var minute_input: LimitedOptionButton
var loaded_events: Array = []
var display_year := 0
var display_month := 0
var selected_date := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_connect_api()
	_set_today()
	_fetch_events()


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
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var title := UiFactory.label("カレンダー", 30, Color(0.08, 0.11, 0.15), BOLD_FONT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var refresh := UiFactory.filled_button("更新", Vector2(78, 38), Color(0.18, 0.48, 0.40), BOLD_FONT, 15)
	refresh.pressed.connect(_fetch_events)
	top.add_child(refresh)
	var close := UiFactory.filled_button("閉じる", Vector2(92, 38), Color(0.36, 0.43, 0.50), BOLD_FONT, 15)
	close.pressed.connect(_close_panel)
	top.add_child(close)

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	left.add_child(nav)
	var prev := UiFactory.filled_button("<", Vector2(44, 34), Color(0.34, 0.48, 0.62), BOLD_FONT, 15)
	prev.pressed.connect(func(): _move_month(-1))
	nav.add_child(prev)
	month_label = UiFactory.label("", 20, Color(0.08, 0.12, 0.17), BOLD_FONT)
	month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	month_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	month_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(month_label)
	var next := UiFactory.filled_button(">", Vector2(44, 34), Color(0.34, 0.48, 0.62), BOLD_FONT, 15)
	next.pressed.connect(func(): _move_month(1))
	nav.add_child(next)

	calendar_grid = GridContainer.new()
	calendar_grid.columns = 7
	calendar_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	calendar_grid.add_theme_constant_override("h_separation", 6)
	calendar_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(calendar_grid)

	var form := PanelContainer.new()
	form.add_theme_stylebox_override("panel", UiFactory.style(Color(0.94, 0.975, 1.0), Color(0.58, 0.70, 0.84), 8))
	left.add_child(form)
	var form_box := VBoxContainer.new()
	form_box.add_theme_constant_override("separation", 8)
	form.add_child(form_box)
	form_box.add_child(UiFactory.label("自分の予定を追加", 16, Color(0.08, 0.12, 0.17), BOLD_FONT))
	title_input = UiFactory.line_edit("予定の内容", Vector2(0, 34), BOLD_FONT, 15)
	form_box.add_child(title_input)
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 8)
	form_box.add_child(time_row)
	hour_input = CalendarWidgets.time_option(0, 23, 1, 72, BOLD_FONT)
	time_row.add_child(hour_input)
	time_row.add_child(UiFactory.label("時", 13, Color(0.15, 0.22, 0.30), BOLD_FONT))
	minute_input = CalendarWidgets.time_option(0, 55, 5, 72, BOLD_FONT)
	time_row.add_child(minute_input)
	time_row.add_child(UiFactory.label("分", 13, Color(0.15, 0.22, 0.30), BOLD_FONT))
	var add_button := UiFactory.filled_button("追加", Vector2(76, 34), Color(0.05, 0.38, 0.64), BOLD_FONT, 14)
	add_button.pressed.connect(_create_personal_event)
	time_row.add_child(add_button)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	right.add_child(UiFactory.label("選択日の予定", 20, Color(0.08, 0.12, 0.17), BOLD_FONT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	event_list = VBoxContainer.new()
	event_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_list.add_theme_constant_override("separation", 8)
	scroll.add_child(event_list)

	status_label = UiFactory.label("", 15, Color(0.18, 0.27, 0.35), BOLD_FONT)
	root.add_child(status_label)


func _connect_api() -> void:
	if not DjangoApi.memos_received.is_connected(_on_memos_received):
		DjangoApi.memos_received.connect(_on_memos_received)
	if not DjangoApi.memo_saved.is_connected(_on_memo_saved):
		DjangoApi.memo_saved.connect(_on_memo_saved)
	if not DjangoApi.memo_deleted.is_connected(_on_memo_deleted):
		DjangoApi.memo_deleted.connect(_on_memo_deleted)
	if not DjangoApi.request_failed.is_connected(_on_request_failed):
		DjangoApi.request_failed.connect(_on_request_failed)


func _fetch_events() -> void:
	status_label.text = "読み込み中..."
	DjangoApi.fetch_calendar_memos()


func _on_memos_received(memos: Array) -> void:
	loaded_events = memos
	_render_calendar()
	_render_event_list()
	status_label.text = ""


func _on_memo_saved(_memo: Dictionary) -> void:
	title_input.text = ""
	_fetch_events()


func _on_memo_deleted(_id: int) -> void:
	_fetch_events()


func _on_request_failed(code: int, _errors = {}) -> void:
	status_label.text = "通信に失敗しました: %s" % code


func _create_personal_event() -> void:
	var text := title_input.text.strip_edges()
	if text == "":
		status_label.text = "予定の内容を入力してください"
		return
	status_label.text = "保存中..."
	DjangoApi.create_memo(text, "planned", _selected_iso())


func _set_today() -> void:
	var now := MemoSchedule.now_parts()
	display_year = int(now["year"])
	display_month = int(now["month"])
	selected_date = MemoSchedule.date_string(display_year, display_month, int(now["day"]))
	UiFactory.select_item_by_id(hour_input, int(now["hour"]))
	UiFactory.select_item_by_id(minute_input, MemoSchedule.round_minute_to_step(int(now["minute"])))
	_render_calendar()


func _move_month(delta: int) -> void:
	var moved := MemoSchedule.move_month(display_year, display_month, delta)
	display_year = int(moved["year"])
	display_month = int(moved["month"])
	_render_calendar()


func _render_calendar() -> void:
	if calendar_grid == null:
		return
	UiFactory.clear_children(calendar_grid)
	month_label.text = "%d年 %d月" % [display_year, display_month]
	for day_name in ["日", "月", "火", "水", "木", "金", "土"]:
		var label := UiFactory.label(day_name, 13, Color(0.26, 0.34, 0.43), BOLD_FONT)
		label.custom_minimum_size = Vector2(54, 26)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		calendar_grid.add_child(label)
	var first_weekday := MemoSchedule.first_weekday(display_year, display_month)
	for _i in range(first_weekday):
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(54, 50)
		calendar_grid.add_child(spacer)
	for day in range(1, MemoSchedule.days_in_month(display_year, display_month) + 1):
		var date_text := MemoSchedule.date_string(display_year, display_month, day)
		var count := _events_on(date_text).size()
		var button_text := str(day) if count == 0 else "%d\n%d件" % [day, count]
		var button := CalendarWidgets.day_button(button_text, date_text == selected_date, count > 0, BOLD_FONT)
		button.pressed.connect(func(value = date_text): _select_date(value))
		calendar_grid.add_child(button)


func _select_date(value: String) -> void:
	selected_date = value
	_render_calendar()
	_render_event_list()


func _render_event_list() -> void:
	if event_list == null:
		return
	UiFactory.clear_children(event_list)
	var events := _events_on(selected_date)
	if events.is_empty():
		event_list.add_child(UiFactory.label("%s の予定はありません" % selected_date, 17, Color(0.30, 0.36, 0.43), BOLD_FONT))
		return
	for event in events:
		if typeof(event) == TYPE_DICTIONARY:
			event_list.add_child(CalendarWidgets.event_card(event, BOLD_FONT, _delete_event))


func _delete_event(id: int) -> void:
	if id <= 0:
		status_label.text = "削除する予定を選択できませんでした"
		return
	status_label.text = "削除中..."
	DjangoApi.delete_memo(id)


func _events_on(date_text: String) -> Array:
	var results: Array = []
	for event in loaded_events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if MemoSchedule.jst_iso_string(str(event.get("scheduled_at", ""))).substr(0, 10) == date_text:
			results.append(event)
	results.sort_custom(func(a, b): return MemoSchedule.jst_iso_string(str(a.get("scheduled_at", ""))) < MemoSchedule.jst_iso_string(str(b.get("scheduled_at", ""))))
	return results


func _selected_iso() -> String:
	return MemoSchedule.iso_string(selected_date, UiFactory.selected_item_id(hour_input), UiFactory.selected_item_id(minute_input))


func _close_panel() -> void:
	emit_signal("close_pressed")
	queue_free()


func _fit_panel() -> void:
	UiFactory.fit_centered_panel(panel, get_viewport_rect().size, Vector2(PANEL_MAX_WIDTH, PANEL_MAX_HEIGHT), PANEL_MARGIN)
