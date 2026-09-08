extends Node

const MODE_LOCAL := "local"
const MODE_PUBLIC := "public"

# Change this one value before export/deploy.
const MODE := MODE_LOCAL

const ENABLE_LOCAL_GUEST := false
const ENABLE_CONSOLE_LOGS := false

const LOCAL_DJANGO_API_BASE := "http://127.0.0.1:8000"
const PUBLIC_DJANGO_API_BASE := "https://tad-unpoisonable-raina.ngrok-free.dev"

const LOCAL_NAKAMA_SCHEME := "http"
const LOCAL_NAKAMA_HOST := "127.0.0.1"
const LOCAL_NAKAMA_PORT := 7350
const LOCAL_NAKAMA_SERVER_KEY := "defaultkey"

const PUBLIC_NAKAMA_SCHEME := "https"
const PUBLIC_NAKAMA_HOST := "example.com"
const PUBLIC_NAKAMA_PORT := 7350
const PUBLIC_NAKAMA_SERVER_KEY := "replace-me"

func is_local() -> bool:
	var override := OS.get_environment("METAVERSE_MODE").strip_edges().to_lower()
	if override == MODE_PUBLIC:
		return false
	if override == MODE_LOCAL:
		return true
	return MODE == MODE_LOCAL


func console_logging_enabled() -> bool:
	var override := OS.get_environment("METAVERSE_CONSOLE_LOGS").strip_edges().to_lower()
	if override in ["1", "true", "yes", "on"]:
		return true
	if override in ["0", "false", "no", "off"]:
		return false
	return ENABLE_CONSOLE_LOGS


func django_api_base() -> String:
	var override := OS.get_environment("METAVERSE_DJANGO_API_BASE").strip_edges()
	if override != "":
		return override
	return LOCAL_DJANGO_API_BASE if is_local() else PUBLIC_DJANGO_API_BASE


func _env_or_default(name: String, default_value: String) -> String:
	var value := OS.get_environment(name).strip_edges()
	return value if value != "" else default_value


func _env_int_or_default(name: String, default_value: int) -> int:
	var value := OS.get_environment(name).strip_edges()
	return int(value) if value.is_valid_int() else default_value


func nakama_info_for_user(user_id: int, username: String, school_id: int) -> Dictionary:
	var local_mode := is_local()
	return {
		"scheme": _env_or_default("METAVERSE_NAKAMA_SCHEME", LOCAL_NAKAMA_SCHEME if local_mode else PUBLIC_NAKAMA_SCHEME),
		"host": _env_or_default("METAVERSE_NAKAMA_HOST", LOCAL_NAKAMA_HOST if local_mode else PUBLIC_NAKAMA_HOST),
		"port": _env_int_or_default("METAVERSE_NAKAMA_PORT", LOCAL_NAKAMA_PORT if local_mode else PUBLIC_NAKAMA_PORT),
		"server_key": _env_or_default("METAVERSE_NAKAMA_SERVER_KEY", LOCAL_NAKAMA_SERVER_KEY if local_mode else PUBLIC_NAKAMA_SERVER_KEY),
		"custom_id": "school:%s:user:%s" % [school_id, user_id],
		"username": username,
		"create": true,
		"vars": {
			"school_id": str(school_id),
			"user_id": str(user_id),
			"role": "user",
		},
		"room_name": "school-%s-lobby" % school_id,
	}


func fallback_world_ws_url(school_id: int) -> String:
	var base := django_api_base().replace("https://", "wss://").replace("http://", "ws://")
	return "%s/ws/world/%s/" % [base, str(school_id)]
