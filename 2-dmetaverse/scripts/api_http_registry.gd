extends RefCounted


static func setup(owner: Node, entries: Array) -> void:
	for entry in entries:
		var http := entry[0] as HTTPRequest
		var handler_name := str(entry[1])
		if http == null or handler_name == "":
			continue
		owner.add_child(http)
		http.request_completed.connect(Callable(owner, handler_name))
