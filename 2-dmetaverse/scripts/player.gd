extends CharacterBody2D

const SPEED := 400.0
const STAMP_ATLAS := preload("res://assets/textures/smileys-emotion-00.png")
const PlayerAvatar := preload("res://scripts/player_avatar.gd")
const STAMP_REGIONS := [
	Rect2(720, 1080, 72, 72),
	Rect2(432, 0, 72, 72),
	Rect2(1080, 0, 72, 72),
	Rect2(1080, 144, 72, 72),
]

# ===== ネットワーク送信制御 =====
const SEND_INTERVAL := 0.1        # 10Hz（0.05なら20Hz）
const MIN_SEND_DIST := 10.0       # px
const STATE_RESEND_INTERVAL := 1.0 # 入室時の同期漏れを回復するための状態再送間隔
var send_timer := 0.0
var state_resend_timer := 0.0
var last_sent_pos := Vector2.ZERO
var last_sent_flip := false
var last_sent_nearby_chat := true
var last_sent_talk_permission := ""
var last_sent_mood_status := ""
var last_sent_avatar_key := ""
var current_avatar_key := ""
var chat_bubble: Control = null

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var head_anchor: Marker2D = $HeadAnchor
@onready var stamp_spawner: StampSpawner = $StampSpawner
@onready var camera := $Camera2D

@export var player_id: int = -1
@export var school_id: String = ""
@export var head_offset_px: float = 100
@export var is_local := false


func _ready() -> void:
	LocalLog.write("Player ready id=%s local=%s" % [player_id, is_local])
	# ローカルプレイヤーは他プレイヤーより常に手前に描画する。
	z_index = 1 if is_local else 0
	last_sent_pos = Vector2(-999999, -999999)
	apply_avatar_key(Global.avatar_key if is_local else "skin_01")
	if is_local:
		camera.make_current()
		Global.stamp_selected.connect(_on_stamp_selected)
		if not Global.avatar_changed.is_connected(_on_avatar_changed):
			Global.avatar_changed.connect(_on_avatar_changed)
		var connected_callable := Callable(self, "_send_state_now")
		if not Network.realtime_connected.is_connected(connected_callable):
			Network.realtime_connected.connect(connected_callable)
		if not Network.state_sync_requested.is_connected(connected_callable):
			Network.state_sync_requested.connect(connected_callable)
		if Network.connected:
			call_deferred("_send_state_now")
	else:
		camera.queue_free()


func _physics_process(delta: float) -> void:
	if not is_local:
		return

	if Global.avatar_key != current_avatar_key:
		apply_avatar_key(Global.avatar_key)

	send_timer += delta
	state_resend_timer += delta

	var dir := Vector2.ZERO

	if not _ui_blocks_movement():
		if Input.is_action_pressed("move_right"):
			dir.x += 1
		if Input.is_action_pressed("move_left"):
			dir.x -= 1
		if Input.is_action_pressed("move_down"):
			dir.y += 1
		if Input.is_action_pressed("move_up"):
			dir.y -= 1

	# 移動
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		velocity = dir * SPEED
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_clamp_to_screen()
	_update_animation(dir)

	# 一定間隔でのみ送信判定
	if send_timer >= SEND_INTERVAL:
		send_timer = 0.0
		_send_state_if_needed(false)

	# 同時入室などで最初の state_request / move が届かなかった相手にも、
	# 最新の位置とプロフィールを再通知して表示を回復させる。
	if state_resend_timer >= STATE_RESEND_INTERVAL:
		state_resend_timer = 0.0
		_send_state_if_needed(true)


func _update_animation(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		anim.play("Idle")
		return

	anim.play("Run")

	if dir.x != 0:
		anim.flip_h = dir.x > 0


func _clamp_to_screen() -> void:
	var screen_size := get_viewport_rect().size
	position.x = clamp(position.x, 0.0, screen_size.x)
	position.y = clamp(position.y, 0.0, screen_size.y)


# ===============================
# ネットワーク送信
# ===============================
func _send_state_now() -> void:
	_send_state_if_needed(true)


func _send_state_if_needed(force_send: bool) -> void:
	if not Network.connected:
		return

	var moved := position.distance_to(last_sent_pos) >= MIN_SEND_DIST
	var flip_changed := anim.flip_h != last_sent_flip
	var nearby_changed := Global.allow_nearby_chat != last_sent_nearby_chat
	var talk_permission_changed := Global.talk_permission != last_sent_talk_permission
	var mood_changed := Global.mood_status != last_sent_mood_status
	var avatar_changed := Global.avatar_key != last_sent_avatar_key

	if not force_send and not moved and not flip_changed and not nearby_changed and not talk_permission_changed and not mood_changed and not avatar_changed:
		return

	last_sent_pos = position
	last_sent_flip = anim.flip_h
	last_sent_nearby_chat = Global.allow_nearby_chat
	last_sent_talk_permission = Global.talk_permission
	last_sent_mood_status = Global.mood_status
	last_sent_avatar_key = Global.avatar_key
	apply_avatar_key(Global.avatar_key)

	Network.send_move({
		"type": "move",
		"user_id": player_id,
		"school_id": school_id,
		"x": snapped(position.x, 1),
		"y": snapped(position.y, 1),
		"flip": anim.flip_h,
		"user_name": Global.username,
		"user_position": Global.user_position,
		"role": "teacher" if Global.is_teacher() else "student",
		"allow_nearby_chat": Global.allow_nearby_chat,
		"talk_permission": Global.talk_permission,
		"mood_status": Global.mood_status,
		"avatar_key": Global.avatar_key,
	})


# ===============================
# リモート反映
# ===============================
func apply_state(data: Dictionary) -> void:
	if data.has("avatar_key"):
		apply_avatar_key(str(data.get("avatar_key", current_avatar_key)))
	if data.has("x"):
		position.x = data["x"]
	if data.has("y"):
		position.y = data["y"]
	if data.has("flip"):
		anim.flip_h = data["flip"]


func apply_avatar_key(key: String) -> void:
	var clean := key if key != "" else "skin_01"
	if clean == "default":
		clean = Global.default_avatar_for_gender(Global.gender)
	if clean == current_avatar_key:
		return
	var frames := PlayerAvatar.frames_for_avatar(clean)
	if frames == null:
		return
	anim.sprite_frames = frames
	current_avatar_key = clean
	var animation_name := anim.animation
	if animation_name == "":
		animation_name = &"Idle"
	anim.play(animation_name)


func _on_avatar_changed(avatar_key: String) -> void:
	apply_avatar_key(avatar_key)
	_send_state_now()


func show_chat_bubble(message: String) -> void:
	var text := message.strip_edges()
	if text == "":
		return
	if chat_bubble != null and is_instance_valid(chat_bubble):
		chat_bubble.queue_free()

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(180, 0)
	panel.position = Vector2(-90, -head_offset_px - 78)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.95)
	style.border_color = Color(0.12, 0.18, 0.24)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text.left(42)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.04, 0.06, 0.08))
	panel.add_child(label)

	head_anchor.add_child(panel)
	chat_bubble = panel
	get_tree().create_timer(4.0).timeout.connect(func():
		if chat_bubble == panel and is_instance_valid(panel):
			panel.queue_free()
			chat_bubble = null
	)


# ===============================
# スタンプ
# ===============================
func show_stamp(texture: Texture2D) -> void:
	if texture == null:
		return

	for c in head_anchor.get_children():
		if c is Node2D:
			c.queue_free()

	var stamp := preload("res://scenes/stamp.tscn").instantiate()
	head_anchor.add_child(stamp)
	stamp.position = Vector2(0, -head_offset_px)
	stamp.set_texture(texture)


func show_stamp_index(index: int) -> void:
	var texture := texture_for_stamp_index(index)
	if texture != null:
		show_stamp(texture)


func texture_for_stamp_index(index: int) -> Texture2D:
	if index < 0 or index >= STAMP_REGIONS.size():
		return null
	var texture := AtlasTexture.new()
	texture.atlas = STAMP_ATLAS
	texture.region = STAMP_REGIONS[index]
	return texture


func _on_stamp_selected(texture: Texture2D, index: int) -> void:
	show_stamp(texture)
	Network.send_stamp({
		"type": "stamp",
		"user_id": player_id,
		"school_id": school_id,
		"stamp_index": index,
	})


func _ui_blocks_movement() -> bool:
	if Global.chat_is_open:
		return true
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("blocks_background_input") and bool(hud.call("blocks_background_input")):
			return true
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit
