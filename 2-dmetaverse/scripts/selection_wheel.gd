@tool
extends Control
class_name SelectionWheel

# 選択結果を外へ通知（texture + 選ばれた index）
signal stamp_selected(texture: Texture2D, index: int)

# 1スタンプの描画サイズ（スプライトシート側が72px想定）
const SPRITE_SIZE: Vector2 = Vector2(72, 72)

# 見た目（背景 / 線 / ハイライト）
@export var bkg_color: Color = Color(0.2, 0.2, 0.2, 0.85)
@export var line_color: Color = Color(1, 1, 1, 0.9)
@export var highlight_color: Color = Color(0.35, 0.35, 0.35, 0.95)

# 円の半径や線幅
@export var outer_radius: float = 256.0
@export var inner_radius: float = 64.0
@export var line_width: float = 4.0

# options[0] は中央、options[1..] は外周（外周の分割数 = options.size() - 1）
@export var options: Array[WheelOption] = [] as Array[WheelOption]
# 開閉トグル用
@export var open_action: StringName = &"radial_open"
# 確定用（Enter / Space など "ui_accept"）
@export var confirm_action: StringName = &"ui_accept"

# 現在選択中の番号（0=中央 / 1..=外周）
var selection: int = 0
# メニューが開いているかどうか
var is_open: bool = false


func _ready() -> void:
	# 最初は閉じた状態
	visible = false

	# 開いている時に _process / _input で処理できるようにする
	set_process(true)
	set_process_input(true)

	# 画面上のUIとして常に最前面に置きたい設定
	top_level = true
	z_index = 4096
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(outer_radius * 2.0, outer_radius * 2.0)
	size = custom_minimum_size


func open() -> void:
	var global_state := get_node_or_null("/root/Global")
	if global_state != null and not bool(global_state.get("is_logged_in")):
		return
	if _hud_blocks_stamp_wheel():
		return
	# 開く
	is_open = true
	visible = true

	size = Vector2(outer_radius * 2.0, outer_radius * 2.0)
	global_position = get_viewport_rect().size * 0.5 - size * 0.5

	# 開いた瞬間は中央選択にしておく
	selection = 0

	# 再描画
	queue_redraw()


func close() -> void:
	# 閉じる
	is_open = false
	visible = false


func toggle() -> void:
	# open_action が押されたら開閉を切り替える
	if is_open:
		close()
	else:
		open()


func _input(event: InputEvent) -> void:
	if _hud_blocks_stamp_wheel():
		if is_open:
			close()
		return
	if _text_input_has_focus():
		return
	# 開閉キーが押されたらトグル
	if event.is_action_pressed(open_action):
		toggle()
		get_viewport().set_input_as_handled()
		return

	# 開いてない時はここで終了（確定なども受けない）
	if not is_open:
		return

	# 左クリックで確定
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_confirm_selection()
		get_viewport().set_input_as_handled()
		return

	# Enter等で確定（ui_accept）
	if event.is_action_pressed(confirm_action):
		_confirm_selection()
		get_viewport().set_input_as_handled()
		return

	# ESC（ui_cancel）で閉じる
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _confirm_selection() -> void:
	# 0（中心）はキャンセル扱い：何も出さず閉じる
	if selection == 0:
		close()
		return

	# 念のため範囲チェック（配列外参照防止）
	if selection < 0 or selection >= options.size():
		close()
		return

	# 選択中の WheelOption を取り出す
	var opt := options[selection]
	if opt == null or opt.atlas == null:
		close()
		return

	# atlas（スプライトシート）+ region（切り抜き範囲）から
	# そのスタンプだけを参照する AtlasTexture を作る
	var at := AtlasTexture.new()
	at.atlas = opt.atlas
	at.region = opt.region

	# 外へ通知（受け取り側で spawn_stamp などに使う）
	stamp_selected.emit(at, selection)

	# 確定したら閉じる
	close()


func _draw() -> void:
	# 開いていないなら描かない
	if not is_open:
		return

	# draw_texture_rect_region は左上座標で描くので、
	# 中心基準で置きたい時は「半分戻す」オフセットを足す
	var center := size * 0.5
	var offset: Vector2 = center - SPRITE_SIZE * 0.5

	# 背景の外円
	draw_circle(center, outer_radius, bkg_color)
	# 中心の穴（円弧をぐるっと1周）
	draw_arc(center, inner_radius, 0.0, TAU, 128, line_color, line_width, true)

	var n: int = options.size()
	if n <= 0:
		return

	# 外周の分割数（中央を除いた個数）
	var slices: int = max(n - 1, 0)

	# 選択中の扇形はアイコンより先に描き、スタンプ自体は常に上に乗せる
	if slices >= 1 and selection > 0:
		var selected_start: float = TAU * float(selection - 1) / float(slices)
		var selected_end: float = TAU * float(selection) / float(slices)
		_draw_slice_highlight(selected_start, selected_end)

	# 外周がある時だけ、仕切り線を描く
	if slices >= 1:
		for i in range(slices):
			var rads: float = TAU * float(i) / float(slices)
			var dir: Vector2 = Vector2.from_angle(rads)
			draw_line(center + dir * inner_radius, center + dir * outer_radius, line_color, line_width, true)

	# 中央が選択されているなら、中心をハイライト
	if selection == 0:
		draw_circle(center, inner_radius, highlight_color)

	# 中央アイコン（options[0]）を描画
	if options[0] != null and options[0].atlas != null:
		draw_texture_rect_region(
			options[0].atlas,
			Rect2(offset, SPRITE_SIZE),
			options[0].region
		)

	# 外周がなければここまで
	if slices <= 0:
		return

	# 外周アイコン + 外周ハイライト
	for i in range(1, n):
		# i番のセグメントが担当する角度範囲（start..end）
		var start_rads: float = TAU * float(i - 1) / float(slices)
		var end_rads: float = TAU * float(i) / float(slices)

		# 真ん中の角度（配置用）
		# 角度は “上方向を基準っぽく見せたい” ので反転している（- を付ける）
		var mid_rads: float = -((start_rads + end_rads) * 0.5)

		# アイコンは内半径と外半径の中間に置く
		var radius_mid: float = (inner_radius + outer_radius) * 0.5
		var draw_pos: Vector2 = center + radius_mid * Vector2.from_angle(mid_rads) - SPRITE_SIZE * 0.5

		# スプライトシートから切り抜いて描画
		if options[i] != null and options[i].atlas != null:
			draw_texture_rect_region(
				options[i].atlas,
				Rect2(draw_pos, SPRITE_SIZE),
				options[i].region
			)


func _draw_slice_highlight(start_rads: float, end_rads: float) -> void:
	var center := size * 0.5
	# 扇形のポリゴンを作るための分割数（大きいほど滑らか）
	var points_per_arc: int = 72

	var points_inner: PackedVector2Array = PackedVector2Array()
	var points_outer: PackedVector2Array = PackedVector2Array()

	# 内側円弧（start -> end）を点列にする
	for j in range(points_per_arc + 1):
		var a: float = lerp(start_rads, end_rads, float(j) / float(points_per_arc))
		# draw側と合わせるため、角度は -a にしている
		points_inner.append(center + inner_radius * Vector2.from_angle(-a))

	# 外側円弧（start -> end）を点列にして、あとで逆順にする
	for j in range(points_per_arc + 1):
		var a: float = lerp(start_rads, end_rads, float(j) / float(points_per_arc))
		points_outer.append(center + outer_radius * Vector2.from_angle(-a))
	points_outer.reverse()

	# 内側(順方向) + 外側(逆方向) をつなげると、閉じた扇形ポリゴンになる
	var poly: PackedVector2Array = points_inner + points_outer
	draw_polygon(poly, PackedColorArray([highlight_color]))


func _process(_delta: float) -> void:
	# 開いてないなら更新しない
	if not is_open:
		return

	var n: int = options.size()
	if n <= 0:
		selection = 0
		queue_redraw()
		return

	# 外周の分割数
	var slices: int = n - 1

	# ローカル座標（ホイール中心 = Vector2.ZERO 基準）でマウスを見る
	var mouse_pos: Vector2 = get_local_mouse_position() - size * 0.5
	var mouse_radius: float = mouse_pos.length()

	# 中心の穴の内側 or 外周がないなら中央選択
	if mouse_radius < inner_radius or slices <= 0:
		selection = 0
	else:
		# マウス角度を 0..TAU に正規化
		# 描画側と合わせるため角度を反転（-mouse_pos.angle()）
		var a: float = fposmod(-mouse_pos.angle(), TAU)

		# 角度 a が何番目のスライスか（0..slices-1）に変換し、外周は 1.. にする
		var idx: int = int(floor(a / TAU * float(slices))) + 1

		# 安全にクランプ
		selection = clamp(idx, 1, slices)

	# 選択が変わる可能性があるので再描画
	queue_redraw()


func _text_input_has_focus() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit


func _hud_blocks_stamp_wheel() -> bool:
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("blocks_background_input") and bool(hud.call("blocks_background_input")):
			return true
	return false
