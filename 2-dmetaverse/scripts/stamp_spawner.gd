extends Node
class_name StampSpawner

@export var stamp_scene: PackedScene

func spawn_stamp(world_pos: Vector2, texture: Texture2D) -> void:
	if stamp_scene == null or texture == null:
		return

	var inst := stamp_scene.instantiate()
	add_child(inst)

	if inst is Node2D:
		(inst as Node2D).global_position = world_pos

	if inst.has_method("set_texture"):
		inst.call("set_texture", texture)
