extends Node2D

@onready var bg := $BackGround
@onready var wheel = $HUD/SelectionWheel

func _ready():
	var screen_size = get_viewport_rect().size
	var tex_size = bg.texture.get_size()

	var scale = Vector2(
		screen_size.x / tex_size.x,
		screen_size.y / tex_size.y
	)
	var max_scale = max(scale.x, scale.y)
	bg.scale = Vector2(max_scale, max_scale)
	bg.position = Vector2.ZERO

	wheel.stamp_selected.connect(_on_stamp_selected)


func _on_stamp_selected(texture: Texture2D, _index: int) -> void:
	Global.emit_signal("stamp_selected", texture, _index)
