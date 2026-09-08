extends RefCounted


static func preview(text: String) -> String:
	var compact := text.replace("\r", "").replace("\n\n", "\n").strip_edges()
	if compact.length() <= 90:
		return compact
	return compact.substr(0, 90) + "..."


static func format_time(value: String) -> String:
	var text := value.replace("T", " ").substr(0, 16)
	return text if text != "" else "不明"
