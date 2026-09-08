extends Camera2D

## Speedup Pull Zone (SPZ): the camera remains still while the player is in
## this central area, then accelerates smoothly as the player moves beyond it.
@export_range(0.1, 0.49, 0.01) var spz_screen_ratio := 0.16
@export_range(1.0, 1000.0, 1.0) var soft_zone_pixels := 180.0
@export_range(1.0, 5000.0, 1.0) var max_follow_speed := 900.0
@export_range(1.0, 20000.0, 1.0) var acceleration := 3600.0

var _camera_center := Vector2.ZERO
var _follow_velocity := Vector2.ZERO


func _ready() -> void:
	# Keep the camera independent of its Player parent after the initial position.
	_camera_center = global_position
	position_smoothing_enabled = false


func _process(delta: float) -> void:
	var player := get_parent() as Node2D
	if player == null:
		return

	var viewport_size := get_viewport_rect().size
	var spz_half_size := viewport_size * spz_screen_ratio
	var player_offset := player.global_position - _camera_center
	var overflow := Vector2(
		max(abs(player_offset.x) - spz_half_size.x, 0.0),
		max(abs(player_offset.y) - spz_half_size.y, 0.0)
	)
	var direction := Vector2(sign(player_offset.x), sign(player_offset.y))
	var desired_velocity := Vector2(
		direction.x * _speed_for_overflow(overflow.x),
		direction.y * _speed_for_overflow(overflow.y)
	)

	_follow_velocity = _follow_velocity.move_toward(desired_velocity, acceleration * delta)
	_camera_center += _follow_velocity * delta
	global_position = _camera_center


func _speed_for_overflow(overflow: float) -> float:
	# smoothstep gives a continuous 0 -> maximum-speed transition in the soft zone.
	var t: float = clampf(overflow / soft_zone_pixels, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return max_follow_speed * t
