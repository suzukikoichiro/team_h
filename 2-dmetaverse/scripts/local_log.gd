extends Node

const LOG_DIR := "user://"
const LATEST_PATH := "user://latest_log_path.txt"

var _file: FileAccess = null
var _path := ""

func _ready() -> void:
	_path = "%slocal_metaverse_%s_%s.log" % [LOG_DIR, OS.get_process_id(), Time.get_ticks_msec()]
	_file = FileAccess.open(_path, FileAccess.WRITE)
	var latest := FileAccess.open(LATEST_PATH, FileAccess.WRITE)
	if latest != null:
		latest.store_string(ProjectSettings.globalize_path(_path))
		latest.flush()
	write("LocalLog started: %s pid=%s" % [Time.get_datetime_string_from_system(), OS.get_process_id()])


func write(message: String) -> void:
	var line := "[%s] %s" % [Time.get_datetime_string_from_system(), message]
	if AppConfig.console_logging_enabled():
		print(line)
	if _file == null:
		return
	_file.store_line(line)
	_file.flush()


func path() -> String:
	return ProjectSettings.globalize_path(_path)
