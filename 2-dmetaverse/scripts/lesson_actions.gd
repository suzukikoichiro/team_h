extends RefCounted


static func link_request(title_input: LineEdit, url_input: LineEdit, description_input: TextEdit) -> Dictionary:
	var title := title_input.text.strip_edges()
	var link_url := url_input.text.strip_edges()
	if title == "" or link_url == "":
		return {"ok": false, "status": "タイトルと共有URLを入力してください"}
	return {"ok": true, "status": "リンクを共有中...", "payload": {"title": title, "link_url": link_url, "description": description_input.text}}


static func reset_link_form(title_input: LineEdit, url_input: LineEdit, description_input: TextEdit) -> void:
	title_input.text = ""
	url_input.text = ""
	description_input.text = ""
