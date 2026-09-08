extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")
const MemoEditorWidgets := preload("res://scripts/memo_editor_widgets.gd")


static func shell(owner: Control, font: Font, close_callable: Callable) -> Dictionary:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.055, 0.07, 0.42)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	owner.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.add_theme_stylebox_override("panel", UiFactory.style(Color(0.972, 0.977, 0.984), Color(0.70, 0.75, 0.80), 8))
	owner.add_child(panel)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var root := vbox(12)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)

	var title := UiFactory.label("どこでもメモ帳", 30, Color(0.08, 0.11, 0.15), font)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	var close_button := UiFactory.filled_button("閉じる", Vector2(92, 38), Color(0.36, 0.43, 0.50), font, 15, 6, true)
	close_button.pressed.connect(close_callable)
	top.add_child(close_button)

	return {
		"panel": panel,
		"root": root,
	}


static func teacher_mode_row(parent: VBoxContainer, font: Font, self_callable: Callable, distribute_callable: Callable) -> Dictionary:
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	parent.add_child(mode_row)

	var self_mode_button := MemoEditorWidgets.mode_button("自分用", Color(0.05, 0.38, 0.64), font)
	self_mode_button.pressed.connect(self_callable)
	mode_row.add_child(self_mode_button)

	var distribute_mode_button := MemoEditorWidgets.mode_button("配布用", Color(0.34, 0.48, 0.62), font)
	distribute_mode_button.pressed.connect(distribute_callable)
	mode_row.add_child(distribute_mode_button)

	return {
		"self_button": self_mode_button,
		"distribute_button": distribute_mode_button,
	}


static func personal_screen_row(parent: VBoxContainer, font: Font, write_callable: Callable, list_callable: Callable) -> Dictionary:
	var screen_row := HBoxContainer.new()
	screen_row.add_theme_constant_override("separation", 8)
	parent.add_child(screen_row)

	var write_button := MemoEditorWidgets.mode_button("書く", Color(0.05, 0.38, 0.64), font)
	write_button.custom_minimum_size = Vector2(86, 32)
	write_button.pressed.connect(write_callable)
	screen_row.add_child(write_button)

	var list_button := MemoEditorWidgets.mode_button("一覧", Color(0.34, 0.48, 0.62), font)
	list_button.custom_minimum_size = Vector2(86, 32)
	list_button.pressed.connect(list_callable)
	screen_row.add_child(list_button)

	return {
		"write_button": write_button,
		"list_button": list_button,
	}


static func list_scroll_grid(parent: VBoxContainer) -> Dictionary:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	return {
		"scroll": scroll,
		"grid": grid,
	}


static func vbox(separation: int, visible: bool = true) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.visible = visible
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", separation)
	return box
