extends CanvasLayer

@export var next_scene_path := "res://scenes/main.tscn"

const MIN_DISPLAY_TIME := 0.8
const CONNECT_CAP_PERCENT := 85
const FINISH_DELAY := 0.35
const MAX_WAIT_TIME := 14.0

var elapsed := 0.0
var finish_timer := -1.0
var connection_started := false
var completed := false
var entering_without_realtime := false
var progress := 8.0

@onready var percent_label: Label = $Root/Panel/Margin/Box/PercentLabel
@onready var status_label: Label = $Root/Panel/Margin/Box/StatusLabel
@onready var progress_bar: ProgressBar = $Root/Panel/Margin/Box/ProgressBar


func _ready() -> void:
	if not Global.is_logged_in:
		get_tree().change_scene_to_file("res://scenes/login.tscn")
		return

	if not Network.realtime_connected.is_connected(_on_realtime_connected):
		Network.realtime_connected.connect(_on_realtime_connected)
	if Network.has_signal("realtime_connection_failed") and not Network.realtime_connection_failed.is_connected(_on_realtime_connection_failed):
		Network.realtime_connection_failed.connect(_on_realtime_connection_failed)

	_start_connection()
	_update_view("登校準備中")


func _process(delta: float) -> void:
	elapsed += delta

	if completed:
		progress = move_toward(progress, 100.0, delta * 90.0)
		_update_view("教室に入ります" if entering_without_realtime else "教室に到着しました")
		finish_timer -= delta
		if finish_timer <= 0.0 and elapsed >= MIN_DISPLAY_TIME:
			get_tree().change_scene_to_file(next_scene_path)
		return

	if Network.connected:
		_on_realtime_connected()
		return
	if elapsed >= MAX_WAIT_TIME:
		_continue_without_realtime()
		return

	var target := _target_progress_before_connection()
	progress = move_toward(progress, target, delta * 24.0)
	_update_view(_status_for_progress(progress))


func _start_connection() -> void:
	if connection_started:
		return
	connection_started = true
	if Network.connected:
		_on_realtime_connected()
		return
	Network.connect_world(Global.school_id, Global.user_id)


func _on_realtime_connected() -> void:
	if completed:
		return
	completed = true
	entering_without_realtime = false
	finish_timer = FINISH_DELAY
	progress = max(progress, 92.0)
	Network.emit_signal("state_sync_requested")


func _on_realtime_connection_failed(_reason: String) -> void:
	if completed:
		return
	progress = max(progress, float(CONNECT_CAP_PERCENT))
	_update_view("接続を再試行しています")


func _continue_without_realtime() -> void:
	if completed:
		return
	completed = true
	entering_without_realtime = true
	finish_timer = FINISH_DELAY
	progress = max(progress, 92.0)


func _target_progress_before_connection() -> float:
	if elapsed < 0.25:
		return 18.0
	if elapsed < 0.75:
		return 38.0
	if elapsed < 1.5:
		return 58.0
	if elapsed < 3.0:
		return 74.0
	return float(CONNECT_CAP_PERCENT)


func _status_for_progress(value: float) -> String:
	if value < 25.0:
		return "ログイン情報を確認中"
	if value < 50.0:
		return "学校サーバーへ接続中"
	if value < 72.0:
		return "教室のチャットへ参加中"
	if value < CONNECT_CAP_PERCENT:
		return "友達の表示準備中"
	return "接続完了を待っています"


func _update_view(status: String) -> void:
	var shown := int(round(clamp(progress, 0.0, 100.0)))
	percent_label.text = "登校中... 現在%d%%" % shown
	status_label.text = status
	progress_bar.value = shown
