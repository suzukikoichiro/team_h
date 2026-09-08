extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")
const ProfileAvatar := preload("res://scripts/profile_avatar.gd")


static func build(anchor: Control, bold_font: Font, selected: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 0)
	panel.position = anchor.global_position + Vector2(0, anchor.size.y + 6)
	panel.add_theme_stylebox_override("panel", UiFactory.style(Color(0.98, 0.99, 1.0), Color(0.58, 0.66, 0.76), 8))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UiFactory.label("スキンを選択", 18, Color(0.08, 0.11, 0.15), bold_font))
	box.add_child(_skin_button("男性用スキン", "skin_01", bold_font, selected))
	box.add_child(_skin_button("女性用スキン", "skin_02", bold_font, selected))
	return panel


static func _skin_button(text: String, avatar_key: String, bold_font: Font, selected: Callable) -> Button:
	var button := UiFactory.filled_button(text, Vector2(0, 36), Color(0.05, 0.38, 0.64), bold_font, 16)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.icon = ProfileAvatar.preview_texture(avatar_key)
	button.expand_icon = true
	button.pressed.connect(func():
		selected.call(avatar_key)
	)
	return button
