extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")
const ProfileAvatar := preload("res://scripts/profile_avatar.gd")
const ProfileFormWidgets := preload("res://scripts/profile_form_widgets.gd")


static func build(bold_font: Font, avatar_key: String, skin_pressed: Callable, save_pressed: Callable) -> Dictionary:
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)

	var preview := VBoxContainer.new()
	preview.custom_minimum_size = Vector2(300, 0)
	preview.add_theme_constant_override("separation", 10)
	body.add_child(preview)

	preview.add_child(UiFactory.label("公開される自己紹介", 20, Color(0.08, 0.11, 0.15), bold_font))

	var avatar_bg := PanelContainer.new()
	avatar_bg.custom_minimum_size = Vector2(280, 366)
	avatar_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	avatar_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	avatar_bg.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	avatar_bg.tooltip_text = "スキンを変更"
	avatar_bg.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			skin_pressed.call(avatar_bg)
	)
	avatar_bg.add_theme_stylebox_override("panel", UiFactory.style(Color(0.91, 0.94, 0.96), Color(0.65, 0.72, 0.80), 8))
	preview.add_child(avatar_bg)

	var avatar_texture := TextureRect.new()
	avatar_texture.texture = ProfileAvatar.preview_texture(avatar_key)
	avatar_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_bg.add_child(avatar_texture)

	var hint := UiFactory.label("スキンを押すと変更できます", 14, Color(0.30, 0.36, 0.43), bold_font)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.add_child(hint)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 7)
	body.add_child(box)

	var name_input := ProfileFormWidgets.line_edit("名前", bold_font)
	name_input.editable = false
	name_input.mouse_default_cursor_shape = Control.CURSOR_ARROW
	name_input.add_theme_color_override("font_color", UiFactory.TEXT if UiFactory.is_dark_theme() else Color(0.18, 0.22, 0.28))
	name_input.add_theme_stylebox_override("normal", UiFactory.style(Color(0.91, 0.94, 0.96), Color(0.66, 0.72, 0.80), 6))
	name_input.add_theme_stylebox_override("focus", UiFactory.style(Color(0.91, 0.94, 0.96), Color(0.66, 0.72, 0.80), 6))

	var nickname_input := ProfileFormWidgets.line_edit("あだ名", bold_font)
	var age_input := ProfileFormWidgets.line_edit("年齢", bold_font)
	var hobbies_input := ProfileFormWidgets.text_edit("趣味", bold_font)
	var message_input := ProfileFormWidgets.text_edit("皆へ一言", bold_font)

	box.add_child(ProfileFormWidgets.field("名前", name_input, bold_font))
	box.add_child(ProfileFormWidgets.field("あだ名", nickname_input, bold_font))
	box.add_child(ProfileFormWidgets.field("年齢", age_input, bold_font))
	box.add_child(ProfileFormWidgets.field("趣味", hobbies_input, bold_font))
	box.add_child(ProfileFormWidgets.field("皆へ一言", message_input, bold_font))

	var save_button := ProfileFormWidgets.primary_button("保存", Vector2(0, 42), bold_font)
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(save_pressed)
	box.add_child(save_button)

	return {
		"root": body,
		"name_input": name_input,
		"nickname_input": nickname_input,
		"age_input": age_input,
		"hobbies_input": hobbies_input,
		"message_input": message_input,
		"avatar_texture": avatar_texture,
	}
