extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")
const MemoSchedule := preload("res://scripts/memo_schedule.gd")


static func picker(font: Font) -> Dictionary:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(420, 0)
	card.add_theme_stylebox_override("panel", UiFactory.style(Color(0.945, 0.975, 1.0), Color(0.52, 0.66, 0.82), 6))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	box.add_child(top)

	var prev := UiFactory.filled_button("<", Vector2(40, 34), Color(0.34, 0.48, 0.62), font, 15, 6, true)
	top.add_child(prev)

	var month_label := UiFactory.label("", 17, Color(0.08, 0.12, 0.17), font)
	month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	month_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	month_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(month_label)

	var next := UiFactory.filled_button(">", Vector2(40, 34), Color(0.34, 0.48, 0.62), font, 15, 6, true)
	top.add_child(next)

	var calendar_grid := GridContainer.new()
	calendar_grid.columns = 7
	calendar_grid.add_theme_constant_override("h_separation", 5)
	calendar_grid.add_theme_constant_override("v_separation", 5)
	box.add_child(calendar_grid)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	box.add_child(bottom)

	var date_label := UiFactory.label("", 15, Color(0.15, 0.22, 0.30), font)
	date_label.custom_minimum_size = Vector2(180, 34)
	date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(date_label)

	var hour := time_option(0, 23, 1, 64, font)
	bottom.add_child(hour)
	bottom.add_child(time_unit_label("時", font))

	var minute := time_option(0, 55, 5, 64, font)
	bottom.add_child(minute)
	bottom.add_child(time_unit_label("分", font))

	return {
		"root": card,
		"prev": prev,
		"next": next,
		"month_label": month_label,
		"calendar_grid": calendar_grid,
		"date_label": date_label,
		"hour": hour,
		"minute": minute,
	}


static func build_personal_picker(owner: Object, parent: VBoxContainer, font: Font) -> void:
	var picker_parts := picker(font)
	parent.add_child(picker_parts["root"] as Node)
	owner.set("schedule_month_label", picker_parts["month_label"] as Label)
	owner.set("schedule_calendar_grid", picker_parts["calendar_grid"] as GridContainer)
	owner.set("schedule_date_label", picker_parts["date_label"] as Label)
	owner.set("schedule_hour", picker_parts["hour"] as LimitedOptionButton)
	owner.set("schedule_minute", picker_parts["minute"] as LimitedOptionButton)
	var prev := picker_parts["prev"] as Button
	var next := picker_parts["next"] as Button
	var selected := Callable(owner, "_select_schedule_date")
	prev.pressed.connect(func(): move_personal_month(owner, -1, font, selected))
	next.pressed.connect(func(): move_personal_month(owner, 1, font, selected))
	apply_personal_schedule(owner, personal_schedule_today(owner.get("schedule_hour"), owner.get("schedule_minute")), font, selected)


static func time_option(min_value: int, max_value: int, step_value: int, width: int, font: Font) -> LimitedOptionButton:
	var option := date_option(width, font)
	for value in range(min_value, max_value + 1, step_value):
		option.add_item("%02d" % value, value)
	return option


static func time_unit_label(text: String, font: Font) -> Label:
	# OptionButton の矢印に重ならないよう、単位用の表示幅を明示する。
	var label := UiFactory.label(text, 15, Color(0.15, 0.22, 0.30), font)
	label.custom_minimum_size = Vector2(24, 34)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


static func date_option(width: int, font: Font) -> LimitedOptionButton:
	var option := LimitedOptionButton.new()
	option.custom_minimum_size = Vector2(width, 34)
	option.configure_popup(width, 34)
	option.add_theme_font_override("font", font)
	option.add_theme_font_size_override("font_size", 15)
	option.add_theme_color_override("font_color", UiFactory.TEXT if UiFactory.is_dark_theme() else Color(0.06, 0.09, 0.13))
	option.add_theme_stylebox_override("normal", _compact_style(Color.WHITE, Color(0.55, 0.62, 0.70), 5))
	option.add_theme_stylebox_override("hover", _compact_style(Color(0.94, 0.97, 1.0), Color(0.35, 0.52, 0.72), 5))
	option.add_theme_stylebox_override("pressed", _compact_style(Color(0.90, 0.95, 1.0), Color(0.25, 0.45, 0.70), 5))
	return option


static func weekday_label(text: String, font: Font) -> Label:
	var label := UiFactory.label(text, 14, Color(0.26, 0.34, 0.43), font)
	label.custom_minimum_size = Vector2(54, 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


static func calendar_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(54, 36)
	return spacer


static func calendar_day_button(text: String, active: bool, font: Font) -> Button:
	var color := Color(0.16, 0.43, 0.72) if active else Color(1, 1, 1)
	var font_color := Color.WHITE if active else (UiFactory.TEXT if UiFactory.is_dark_theme() else Color(0.08, 0.12, 0.17))
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(54, 36)
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_stylebox_override("normal", _compact_style(color, Color(0.50, 0.62, 0.76), 5))
	button.add_theme_stylebox_override("hover", _compact_style(color.lightened(0.08), Color(0.22, 0.44, 0.72), 5))
	button.add_theme_stylebox_override("pressed", _compact_style(color.darkened(0.08), Color(0.22, 0.44, 0.72), 5))
	return button


static func render_calendar(grid: GridContainer, year: int, month: int, selected_date: String, font: Font, selected: Callable) -> void:
	if grid == null:
		return
	_clear_node(grid)
	var weekdays := ["日", "月", "火", "水", "木", "金", "土"]
	for day_name in weekdays:
		grid.add_child(weekday_label(day_name, font))
	for _i in range(MemoSchedule.first_weekday(year, month)):
		grid.add_child(calendar_spacer())
	for day in range(1, MemoSchedule.days_in_month(year, month) + 1):
		var date_text := MemoSchedule.date_string(year, month, day)
		var button := calendar_day_button(str(day), date_text == selected_date, font)
		button.pressed.connect(func(value = date_text): selected.call(value))
		grid.add_child(button)


static func personal_schedule_today(hour_option: Object, minute_option: Object) -> Dictionary:
	var now := MemoSchedule.now_parts()
	UiFactory.select_item_by_id(hour_option, int(now["hour"]))
	UiFactory.select_item_by_id(minute_option, MemoSchedule.round_minute_to_step(int(now["minute"])))
	return {
		"year": int(now["year"]),
		"month": int(now["month"]),
		"date": MemoSchedule.date_string(int(now["year"]), int(now["month"]), int(now["day"])),
	}


static func personal_schedule_from_iso(value: String, hour_option: Object, minute_option: Object) -> Dictionary:
	var parsed := MemoSchedule.parse_iso(value)
	if parsed.is_empty():
		return personal_schedule_today(hour_option, minute_option)
	if int(parsed["hour"]) >= 0:
		UiFactory.select_item_by_id(hour_option, int(parsed["hour"]))
	if int(parsed["minute"]) >= 0:
		UiFactory.select_item_by_id(minute_option, int(parsed["minute"]))
	return {
		"year": int(parsed["year"]),
		"month": int(parsed["month"]),
		"date": str(parsed["date"]),
	}


static func personal_schedule_iso(current_status: String, selected_date: String, hour_option: Object, minute_option: Object) -> String:
	if current_status != "planned" or selected_date == "":
		return ""
	return MemoSchedule.iso_string(selected_date, UiFactory.selected_item_id(hour_option), UiFactory.selected_item_id(minute_option))


static func apply_personal_schedule(owner: Object, schedule: Dictionary, font: Font, selected: Callable) -> void:
	owner.set("schedule_year", int(schedule["year"]))
	owner.set("schedule_month", int(schedule["month"]))
	owner.set("selected_schedule_date", str(schedule["date"]))
	render_personal_calendar_for_owner(owner, font, selected)


static func move_personal_month(owner: Object, delta: int, font: Font, selected: Callable) -> void:
	var moved := MemoSchedule.move_month(int(owner.get("schedule_year")), int(owner.get("schedule_month")), delta)
	apply_personal_schedule(owner, {
		"year": int(moved["year"]),
		"month": int(moved["month"]),
		"date": str(owner.get("selected_schedule_date")),
	}, font, selected)


static func select_personal_date(owner: Object, value: String, font: Font, selected: Callable) -> void:
	owner.set("selected_schedule_date", value)
	render_personal_calendar_for_owner(owner, font, selected)


static func render_personal_calendar_for_owner(owner: Object, font: Font, selected: Callable) -> void:
	render_personal_calendar(
		owner.get("schedule_month_label") as Label,
		owner.get("schedule_date_label") as Label,
		owner.get("schedule_calendar_grid") as GridContainer,
		int(owner.get("schedule_year")),
		int(owner.get("schedule_month")),
		str(owner.get("selected_schedule_date")),
		font,
		selected
	)


static func render_personal_calendar(
	month_label: Label,
	date_label: Label,
	grid: GridContainer,
	year: int,
	month: int,
	selected_date: String,
	font: Font,
	selected: Callable
) -> void:
	if month_label != null:
		month_label.text = "%d年 %d月" % [year, month]
	render_calendar(grid, year, month, selected_date, font, selected)
	if date_label != null:
		date_label.text = "予定日: %s" % selected_date


static func set_teacher_schedule_today(
	year_option: Object,
	month_option: Object,
	day_option: Object,
	hour_option: Object,
	minute_option: Object
) -> void:
	var now := MemoSchedule.now_parts()
	var current_year := int(now["year"])
	year_option.clear()
	for year in range(current_year, current_year + 4):
		year_option.add_item(str(year), year)
	month_option.clear()
	for month in range(1, 13):
		month_option.add_item("%02d" % month, month)
	UiFactory.select_item_by_id(year_option, current_year)
	UiFactory.select_item_by_id(month_option, int(now["month"]))
	refresh_teacher_day_options(year_option, month_option, day_option, int(now["day"]))
	UiFactory.select_item_by_id(hour_option, int(now["hour"]))
	UiFactory.select_item_by_id(minute_option, MemoSchedule.round_minute_to_step(int(now["minute"])))


static func refresh_teacher_day_options(
	year_option: Object,
	month_option: Object,
	day_option: Object,
	preferred_day: int = 0
) -> void:
	if day_option == null:
		return
	var current_day := UiFactory.selected_item_id(day_option)
	if preferred_day > 0:
		current_day = preferred_day
	var year := UiFactory.selected_item_id(year_option)
	var month := UiFactory.selected_item_id(month_option)
	var max_day := MemoSchedule.days_in_month(year, month)
	day_option.clear()
	for day in range(1, max_day + 1):
		day_option.add_item("%02d" % day, day)
	UiFactory.select_item_by_id(day_option, clamp(current_day, 1, max_day))


static func teacher_schedule_iso(
	year_option: Object,
	month_option: Object,
	day_option: Object,
	hour_option: Object,
	minute_option: Object
) -> String:
	if year_option == null or month_option == null or day_option == null:
		return ""
	var date_text := MemoSchedule.date_string(
		UiFactory.selected_item_id(year_option),
		UiFactory.selected_item_id(month_option),
		UiFactory.selected_item_id(day_option)
	)
	return MemoSchedule.iso_string(date_text, UiFactory.selected_item_id(hour_option), UiFactory.selected_item_id(minute_option))


static func _compact_style(bg: Color, border: Color, radius: int, border_width: int = 1) -> StyleBoxFlat:
	return UiFactory.style(bg, border, radius, border_width, Vector4(8, 2, 8, 2))


static func _clear_node(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
