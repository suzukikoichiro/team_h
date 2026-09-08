extends Node2D

const PLANT_POSITION := Vector2(640, 300)
const IMAGE_ROOT := "res://assets/growth"

var sprite: Sprite2D
var label: Label
var current_growth := {}


func _ready() -> void:
	position = PLANT_POSITION
	_build_nodes()
	if DjangoApi != null and DjangoApi.has_signal("growth_received"):
		DjangoApi.growth_received.connect(_on_growth_received)
	if Global.is_logged_in:
		refresh()
	else:
		Global.login_done.connect(refresh)


func refresh() -> void:
	if DjangoApi != null and DjangoApi.has_method("fetch_growth_summary"):
		DjangoApi.fetch_growth_summary()


func _build_nodes() -> void:
	sprite = Sprite2D.new()
	sprite.centered = true
	sprite.scale = Vector2(0.72, 0.72)
	add_child(sprite)

	label = Label.new()
	label.position = Vector2(-112, 84)
	label.custom_minimum_size = Vector2(224, 54)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.05, 0.08, 0.07))
	label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.95))
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)


func _on_growth_received(growth: Dictionary) -> void:
	current_growth = growth
	var season := str(growth.get("season_id", "summer"))
	var stage := clampi(int(growth.get("stage", 0)), 0, int(growth.get("max_stage", 4)))
	var plant_scale := clampf(float(growth.get("plant_scale", 0.72)), 0.60, 1.10)
	var path := "%s/%s/stage_%d.png" % [IMAGE_ROOT, season, stage]
	var texture := load(path)
	if texture == null:
		texture = load("%s/summer/stage_%d.png" % [IMAGE_ROOT, stage])
	if texture != null:
		sprite.texture = texture
		sprite.scale = Vector2.ONE * plant_scale
	var plant_name := str(growth.get("plant_name", "植物"))
	label.text = "%s" % plant_name
