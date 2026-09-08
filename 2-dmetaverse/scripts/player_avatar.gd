extends RefCounted


static func frames_for_avatar(key: String) -> SpriteFrames:
	var skin_root := skin_asset_root(key)
	if skin_root == "":
		return null
	var frames := SpriteFrames.new()
	frames.add_animation(&"Idle")
	frames.set_animation_loop(&"Idle", true)
	frames.set_animation_speed(&"Idle", 7.0)
	add_texture_frames(frames, &"Idle", skin_root, "idle", 12)
	frames.add_animation(&"Run")
	frames.set_animation_loop(&"Run", true)
	frames.set_animation_speed(&"Run", 8.0)
	add_texture_frames(frames, &"Run", skin_root, "run", 12)
	if frames.get_frame_count(&"Idle") == 0 or frames.get_frame_count(&"Run") == 0:
		return null
	return frames


static func skin_asset_root(key: String) -> String:
	match key:
		"skin_02", "female":
			return "res://assets/generated/skins/skin_02"
		"skin_01", "male":
			return "res://assets/generated/skins/skin_01"
		_:
			return "res://assets/generated/skins/skin_01"


static func add_texture_frames(frames: SpriteFrames, animation: StringName, root: String, dir: String, max_frames: int) -> void:
	for i in range(1, max_frames + 1):
		var frame_path := "%s/%s/%d.png" % [root, dir, i]
		if not ResourceLoader.exists(frame_path):
			continue
		var texture: Texture2D = load(frame_path)
		if texture != null:
			frames.add_frame(animation, texture)
