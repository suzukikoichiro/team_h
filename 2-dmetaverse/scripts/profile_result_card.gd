extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")


static func build(profile: Dictionary, avatar_texture: Texture2D, bold_font: Font, locate_pressed: Callable) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiFactory.style(Color(1, 1, 1), Color(0.74, 0.79, 0.85), 8))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(58, 58)
	avatar.texture = avatar_texture
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(avatar)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 3)
	row.add_child(text_box)

	var title := "%s  ID:%s" % [str(profile.get("display_name", profile.get("user_name", "ユーザー"))), int(profile.get("user_id", 0))]
	text_box.add_child(UiFactory.label(title, 21, Color(0.06, 0.09, 0.13), bold_font))
	var meta := "%s / %s" % [str(profile.get("role_label", "ユーザー")), str(profile.get("nickname", ""))]
	text_box.add_child(UiFactory.label(meta, 16, Color(0.30, 0.36, 0.43), bold_font))
	text_box.add_child(UiFactory.label("趣味: %s" % str(profile.get("hobbies", "")), 16, Color(0.12, 0.16, 0.22), bold_font))
	text_box.add_child(UiFactory.label("一言: %s" % str(profile.get("message", "")), 16, Color(0.12, 0.16, 0.22), bold_font))

	var locate_button := UiFactory.filled_button("話しかけに行く", Vector2(132, 38), Color(0.05, 0.38, 0.64), bold_font, 16)
	locate_button.pressed.connect(func():
		locate_pressed.call(profile)
	)
	row.add_child(locate_button)
	return card
