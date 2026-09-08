extends RefCounted

const FALLBACK_TEXTURE := preload("res://assets/generated/skins/default/idle/1.png")


static func preview_texture(avatar_key: String) -> Texture2D:
	var skin_dir := "skin_02" if avatar_key == "skin_02" else "skin_01"
	var texture_path := "res://assets/generated/skins/%s/idle/1.png" % skin_dir
	if not ResourceLoader.exists(texture_path):
		return FALLBACK_TEXTURE
	var texture: Texture2D = load(texture_path)
	return texture if texture != null else FALLBACK_TEXTURE
