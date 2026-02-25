extends Camera2D

## Pan/zoom camera for the world map.
## Controls: WASD/arrows to pan, scroll wheel to zoom, middle-click drag to pan.
## Trackpad: two-finger scroll pans, pinch to zoom (via magnify gesture).

const PAN_SPEED := 600.0
const ZOOM_SPEED := 0.1
const ZOOM_MIN := 0.2
const ZOOM_MAX := 6.0
const DRAG_THRESHOLD := 4.0  # pixels before drag starts (prevents accidental pan on click)

var is_dragging: bool = false
var drag_button: int = -1
var drag_origin: Vector2 = Vector2.ZERO
var drag_started: bool = false  # true once we pass the threshold

# Smooth zoom
var target_zoom: float = 1.0
const ZOOM_LERP_SPEED := 12.0


func _ready() -> void:
	target_zoom = zoom.x  # Match whatever's set in the scene


func center_on_map(bounds: Rect2) -> void:
	## Center the camera on the map content and set appropriate zoom.
	var center := bounds.get_center()
	position = center
	# Fit map into viewport with some padding
	var viewport_size := get_viewport_rect().size
	var scale_x := viewport_size.x / bounds.size.x
	var scale_y := viewport_size.y / bounds.size.y
	var fit_zoom := minf(scale_x, scale_y) * 0.85  # 85% fill
	target_zoom = clampf(fit_zoom, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(target_zoom, target_zoom)
	EventBus.zoom_changed.emit(target_zoom)


func _process(delta: float) -> void:
	# Keyboard panning
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

	# Smooth zoom interpolation
	var current := zoom.x
	if not is_equal_approx(current, target_zoom):
		var new_val := lerpf(current, target_zoom, minf(ZOOM_LERP_SPEED * delta, 1.0))
		# Snap when close enough
		if absf(new_val - target_zoom) < 0.001:
			new_val = target_zoom
		zoom = Vector2(new_val, new_val)


func _unhandled_input(event: InputEvent) -> void:
	# Scroll wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, ZOOM_SPEED)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, -ZOOM_SPEED)

		# Middle mouse drag to pan
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_dragging = true
				drag_started = false
				drag_button = event.button_index
				drag_origin = event.position
			elif not event.pressed and event.button_index == drag_button:
				is_dragging = false
				drag_started = false
				drag_button = -1

	# Trackpad pinch-to-zoom (magnify gesture)
	if event is InputEventMagnifyGesture:
		var factor := float(event.factor - 1.0) * 0.5
		_zoom_at(event.position, factor)

	# Trackpad two-finger pan (pan gesture)
	if event is InputEventPanGesture:
		position += event.delta * 2.0 / zoom.x

	# Drag pan (middle or right mouse)
	if event is InputEventMouseMotion and is_dragging:
		if not drag_started:
			if event.position.distance_to(drag_origin) >= DRAG_THRESHOLD:
				drag_started = true
		if drag_started:
			position -= event.relative / zoom.x
			get_viewport().set_input_as_handled()


func _zoom_at(mouse_pos: Vector2, factor: float) -> void:
	var old_zoom_val := zoom.x
	target_zoom = clampf(target_zoom + factor, ZOOM_MIN, ZOOM_MAX)

	# Immediately set zoom for responsive feel, then lerp will smooth it
	var new_zoom_val := clampf(zoom.x + factor, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(new_zoom_val, new_zoom_val)
	EventBus.zoom_changed.emit(target_zoom)

	# Zoom toward mouse position
	var viewport_size := get_viewport_rect().size
	var mouse_offset := (mouse_pos - viewport_size / 2.0) / old_zoom_val
	position += mouse_offset * (1.0 - old_zoom_val / new_zoom_val)
