extends Control
## A continuous, draggable time ruler. The centre marker stays fixed as years move.
signal value_changed(year: float)
const UI = preload("res://scripts/ui_theme.gd")
var value: float = 2000.0:
	set(year):
		var next := clampf(year, 1700.0, 2100.0)
		if is_equal_approx(next, value):
			return
		value = next
		queue_redraw()
		value_changed.emit(value)
var dragging := false
var press_x := 0.0
var press_year := 2000.0
var moved := false
var motion: Tween

func _ready() -> void:
	custom_minimum_size.y = 102
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = "Drag the ruler left or right. Scroll or use arrow keys. Home: 1700. End: 2100."
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func pixels_per_year() -> float:
	return maxf(size.x / 320.0, 1.0)

func scroll_years(delta: float) -> void:
	var destination := clampf(value + delta, 1700.0, 2100.0)
	if motion and motion.is_valid():
		motion.kill()
	motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	motion.tween_property(self, "value", destination, 0.16)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if motion and motion.is_valid():
					motion.kill()
				grab_focus()
				dragging = true
				press_x = event.position.x
				press_year = value
				moved = false
			else:
				if dragging and not moved:
					scroll_years((event.position.x - size.x * 0.5) / pixels_per_year())
				dragging = false
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			var direction := -1.0 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1.0
			scroll_years(direction * 12.0 * event.factor)
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		var distance: float = event.position.x - press_x
		moved = moved or absf(distance) > 3.0
		value = press_year - distance / pixels_per_year()
		accept_event()
	elif event is InputEventPanGesture:
		scroll_years((event.delta.x if absf(event.delta.x) > absf(event.delta.y) else event.delta.y) * 8.0)
		accept_event()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT: value -= 1.0
			KEY_RIGHT: value += 1.0
			KEY_HOME: value = 1700.0
			KEY_END: value = 2100.0
			_: return
		accept_event()

func _draw() -> void:
	var center := size.x * 0.5
	var scale := pixels_per_year()
	var mono := UI.mono_font()
	draw_line(Vector2(0, 44), Vector2(size.x, 44), Color(UI.CYAN, 0.3), 1.0)
	for year in range(1700, 2101, 10):
		var x := center + (float(year) - value) * scale
		if x < -65.0 or x > size.x + 65.0:
			continue
		var major := year % 100 == 0
		var alpha := clampf(minf(x, size.x - x) / 70.0, 0.0, 1.0)
		draw_line(Vector2(x, 44), Vector2(x, 64 if major else 51), Color(UI.CYAN, alpha * (0.8 if major else 0.28)), 1.0)
		if major:
			var text := str(year)
			var width := mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(mono, Vector2(x - width / 2, 84), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UI.TEXT, alpha))
	var readout := str(roundi(value)) + ("  SCENARIO" if value >= 2100.0 else "")
	var text_width := mono.get_string_size(readout, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	draw_string(mono, Vector2(center - text_width / 2, 23), readout, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UI.AMBER)
	draw_line(Vector2(center, 31), Vector2(center, 65), UI.AMBER, 2.0)
	draw_circle(Vector2(center, 44), 4.0, UI.AMBER)
	var hint := "DRAG LEFT / RIGHT"
	draw_string(mono, Vector2(size.x - 133, 20), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.MUTED)
	if has_focus():
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), Color(UI.AMBER, 0.55), false, 1.0)
