extends Node2D
class_name Stamp

@export var lifetime_sec: float = 2.0
@onready var icon: Sprite2D = $Icon

func set_texture(tex: Texture2D) -> void:
	icon.texture = tex

func _ready() -> void:
	if lifetime_sec > 0.0:
		get_tree().create_timer(lifetime_sec).timeout.connect(queue_free)
