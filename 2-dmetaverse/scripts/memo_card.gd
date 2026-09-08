extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")
const MemoStatusStyle := preload("res://scripts/memo_status_style.gd")
const MemoText := preload("res://scripts/memo_text.gd")


static func build(memo: Dictionary, selected_memo_id: int, font: Font, selected: Callable) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(250, 150)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var memo_id := int(memo.get("id", 0))
	var memo_status := str(memo.get("status", "none"))
	var border_color := Color(0.20, 0.42, 0.72) if memo_id == selected_memo_id else MemoStatusStyle.border_color(memo_status)
	var border_width := 2 if memo_id == selected_memo_id else 1
	card.add_theme_stylebox_override("panel", UiFactory.style(MemoStatusStyle.card_color(memo_status), border_color, 8, border_width))

	var memo_copy: Dictionary = memo.duplicate()
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.call(memo_copy)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(22, 7)
	marker.color = MemoStatusStyle.border_color(memo_status)
	header.add_child(marker)

	var selection_state := _label("選択中" if memo_id == selected_memo_id else "", 13, Color(0.20, 0.42, 0.72), font)
	selection_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	selection_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(selection_state)

	var text := _label(MemoText.preview(str(memo.get("text", ""))), 18, Color(0.06, 0.09, 0.13), font)
	text.custom_minimum_size = Vector2(0, 96)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(text)

	return card


static func _label(text: String, size: int, color: Color, font: Font) -> Label:
	return UiFactory.label(text, size, color, font)
