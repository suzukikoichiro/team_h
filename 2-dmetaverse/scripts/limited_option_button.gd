extends Button
class_name LimitedOptionButton

const UiFactory := preload("res://scripts/ui_factory.gd")

signal item_selected(index: int)

const VISIBLE_ROWS := 5

var selected := -1
var item_count := 0
var popup_width := 72
var row_height := 30

var _texts: Array[String] = []
var _ids: Array[int] = []
var _popup: PopupPanel
var _scroll: ScrollContainer
var _list: VBoxContainer


func _ready() -> void:
	_apply_theme_font_colors()
	pressed.connect(_show_limited_popup)


func _apply_theme_font_colors() -> void:
	var font_color := UiFactory.TEXT if UiFactory.is_dark_theme() else Color(0.06, 0.09, 0.13)
	add_theme_color_override("font_color", font_color)
	add_theme_color_override("font_hover_color", font_color)
	add_theme_color_override("font_pressed_color", font_color)
	add_theme_color_override("font_hover_pressed_color", font_color)
	add_theme_color_override("font_focus_color", font_color)


func configure_popup(width: int, row_size: int) -> void:
	popup_width = width
	row_height = row_size


func add_item(label: String, id: int = -1) -> void:
	_texts.append(label)
	_ids.append(id if id != -1 else _texts.size() - 1)
	item_count = _texts.size()
	if selected < 0:
		select(0)


func clear() -> void:
	_texts.clear()
	_ids.clear()
	item_count = 0
	selected = -1
	text = ""


func select(index: int) -> void:
	if index < 0 or index >= _texts.size():
		return
	selected = index
	text = _texts[index]


func get_item_id(index: int) -> int:
	if index < 0 or index >= _ids.size():
		return 0
	return _ids[index]


func _show_limited_popup() -> void:
	if _texts.is_empty():
		return
	_build_popup()
	var visible_count = min(_texts.size(), VISIBLE_ROWS)
	var popup_size := Vector2i(max(popup_width, int(size.x)), row_height * visible_count + 6)
	var popup_position := Vector2i(int(global_position.x), int(global_position.y + size.y))
	_popup.popup(Rect2i(popup_position, popup_size))


func _build_popup() -> void:
	if _popup == null or not is_instance_valid(_popup):
		_popup = PopupPanel.new()
		add_child(_popup)
		_popup.add_theme_stylebox_override("panel", _popup_style())

		_scroll = ScrollContainer.new()
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_popup.add_child(_scroll)

		_list = VBoxContainer.new()
		_list.add_theme_constant_override("separation", 0)
		_scroll.add_child(_list)

	for child in _list.get_children():
		child.queue_free()

	for index in range(_texts.size()):
		var item_button := Button.new()
		item_button.text = _texts[index]
		item_button.custom_minimum_size = Vector2(popup_width, row_height)
		item_button.add_theme_font_size_override("font_size", 14)
		item_button.add_theme_color_override("font_color", Color(0.06, 0.09, 0.13))
		item_button.add_theme_color_override("font_hover_color", Color(0.06, 0.09, 0.13))
		item_button.add_theme_color_override("font_pressed_color", Color(0.06, 0.09, 0.13))
		item_button.add_theme_stylebox_override("normal", _item_style(index == selected))
		item_button.add_theme_stylebox_override("hover", _item_style(true))
		item_button.add_theme_stylebox_override("pressed", _item_style(true))
		item_button.pressed.connect(_select_from_popup.bind(index))
		_list.add_child(item_button)

	var visible_count = min(_texts.size(), VISIBLE_ROWS)
	_scroll.custom_minimum_size = Vector2(popup_width, row_height * visible_count)
	_list.custom_minimum_size = Vector2(popup_width, row_height * _texts.size())


func _select_from_popup(index: int) -> void:
	select(index)
	item_selected.emit(index)
	if _popup != null:
		_popup.hide()


func _popup_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = Color(0.45, 0.54, 0.66)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


func _item_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.90, 0.95, 1.0) if active else Color.WHITE
	style.border_color = style.bg_color
	style.set_content_margin_all(6)
	return style
