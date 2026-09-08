extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")


static func render(
	class_list: VBoxContainer,
	student_list: VBoxContainer,
	classes: Array,
	students: Array,
	selected_class_ids: Dictionary,
	selected_student_ids: Dictionary,
	font: Font
) -> void:
	if class_list == null or student_list == null:
		return
	_clear_node(class_list)
	_clear_node(student_list)
	_render_classes(class_list, classes, selected_class_ids, font)
	_render_students(student_list, students, selected_student_ids, font)


static func _render_classes(class_list: VBoxContainer, classes: Array, selected_class_ids: Dictionary, font: Font) -> void:
	if classes.is_empty():
		class_list.add_child(_label("担当クラスがありません", 13, Color(0.35, 0.40, 0.46), font))
	for class_data in classes:
		if typeof(class_data) != TYPE_DICTIONARY:
			continue
		var class_id := int(class_data.get("class_id", 0))
		var check := _check_box(str(class_data.get("label", "クラス")), font)
		check.button_pressed = selected_class_ids.has(class_id)
		check.toggled.connect(func(pressed: bool, id = class_id):
			if pressed:
				selected_class_ids[id] = true
			else:
				selected_class_ids.erase(id)
		)
		class_list.add_child(check)


static func _render_students(student_list: VBoxContainer, students: Array, selected_student_ids: Dictionary, font: Font) -> void:
	if students.is_empty():
		student_list.add_child(_label("対象学生がいません", 13, Color(0.35, 0.40, 0.46), font))
	for student in students:
		if typeof(student) != TYPE_DICTIONARY:
			continue
		var student_id := int(student.get("user_id", 0))
		var label := student_label(student)
		var check := _check_box(label, font)
		check.button_pressed = selected_student_ids.has(student_id)
		check.toggled.connect(func(pressed: bool, id = student_id):
			if pressed:
				selected_student_ids[id] = true
			else:
				selected_student_ids.erase(id)
		)
		student_list.add_child(check)


static func student_label(student: Dictionary) -> String:
	var student_id := int(student.get("user_id", 0))
	var class_labels: Array[String] = []
	for class_data in student.get("classes", []):
		if typeof(class_data) == TYPE_DICTIONARY:
			class_labels.append(str(class_data.get("label", "")))
	var label := "%s  ID:%s" % [str(student.get("user_name", "学生")), student_id]
	if not class_labels.is_empty():
		label += " / %s" % "・".join(class_labels)
	return label


static func _check_box(text: String, font: Font) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.add_theme_font_override("font", font)
	check.add_theme_font_size_override("font_size", 13)
	var text_color := UiFactory.TEXT if UiFactory.is_dark_theme() else Color(0.08, 0.11, 0.15)
	check.add_theme_color_override("font_color", text_color)
	check.add_theme_color_override("font_hover_color", text_color)
	check.add_theme_color_override("font_pressed_color", text_color)
	check.custom_minimum_size = Vector2(0, 24)
	return check


static func _label(text: String, size: int, color: Color, font: Font) -> Label:
	return UiFactory.label(text, size, color, font)


static func _clear_node(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
