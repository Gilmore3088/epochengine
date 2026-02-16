extends Camera2D

## Pan/zoom camera for the world map.

const PAN_SPEED := 500.0
const ZOOM_SPEED := 0.1
const ZOOM_MIN := 0.3
const ZOOM_MAX := 3.0

var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO


func _ready() -> void:
	zoom = Vector2(1.0, 1.0)
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0


func _process(delta: float) -> void:
	var direction := Vector2.ZERO

	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		direction.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		direction.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		direction.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		direction.y += 1

	if direction != Vector2.ZERO:
		position += direction.normalized() * PAN_SPEED * delta / zoom.x


func _unhandled_input(event: InputEvent) -> void:
	# Scroll wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, ZOOM_SPEED)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, -ZOOM_SPEED)

		# Middle mouse drag
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_dragging = event.pressed
			if is_dragging:
				drag_start = event.position

	# Drag pan
	if event is InputEventMouseMotion and is_dragging:
		position -= (event.relative / zoom.x)


func _zoom_at(mouse_pos: Vector2, factor: float) -> void:
	var old_zoom := zoom
	var new_zoom_val := clampf(zoom.x + factor, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(new_zoom_val, new_zoom_val)
	EventBus.zoom_changed.emit(new_zoom_val)

	# Zoom toward mouse position
	var viewport_size := get_viewport_rect().size
	var mouse_offset := (mouse_pos - viewport_size / 2.0) / old_zoom.x
	position += mouse_offset * (1.0 - old_zoom.x / zoom.x)
