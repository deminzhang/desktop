## The floating monitor window: a borderless, always-on-top, per-pixel
## transparent OS window holding the HUD.
##
## Dragging is done by hand (mouse offset -> window position) rather than with a
## native caption drag, so it keeps working while the window is non-activating.
class_name HudWindow
extends Window

signal quit_requested

const MARGIN := 26

var metrics: MetricsClient
var hud: Hud

var _buttons: Array[Button] = []
var _dragging := false
var _drag_offset := Vector2i.ZERO
var _locked := false


func _ready() -> void:
	title = MetricsClient.HUD_TITLE
	borderless = true
	transparent = true
	always_on_top = true
	size = Vector2i(Hud.PANEL)
	position = _default_position()
	visible = true

	hud = Hud.new()
	hud.name = "Hud"
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud.position = Vector2.ZERO

	_build_buttons()
	set_process_input(true)


func _default_position() -> Vector2i:
	var screen := DisplayServer.get_primary_screen()
	var origin := DisplayServer.screen_get_position(screen)
	var usable := DisplayServer.screen_get_usable_rect(screen)
	return Vector2i(usable.position.x + usable.size.x - int(Hud.PANEL.x) - MARGIN,
			usable.position.y + MARGIN)


func attach(client: MetricsClient) -> void:
	metrics = client
	hud.attach(client)
	client.host_event.connect(_on_host_event)


func _build_buttons() -> void:
	var specs := [
		["pass", Vector2(14.0, 214.0)],
		["hide", Vector2(58.0, 214.0)],
		["quit", Vector2(102.0, 214.0)],
	]
	for spec: Array in specs:
		var b := Button.new()
		b.name = String(spec[0])
		b.position = spec[1]
		b.size = Vector2(40.0, 20.0)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 10)
		b.add_theme_color_override("font_color", Hud.C_DIM)
		b.add_theme_color_override("font_hover_color", Hud.C_TEXT)
		b.add_theme_color_override("font_pressed_color", Hud.C_CPU)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.21, 0.26, 0.80)
		sb.set_corner_radius_all(5)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.30, 0.72, 0.82, 0.32)
		var sb_hover := sb.duplicate() as StyleBoxFlat
		sb_hover.bg_color = Color(0.14, 0.31, 0.38, 0.90)
		sb_hover.border_color = Color(0.40, 0.85, 0.95, 0.55)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb_hover)
		b.add_theme_stylebox_override("pressed", sb_hover)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		hud.add_child(b)
		_buttons.append(b)

	_buttons[0].pressed.connect(_toggle_lock)
	_buttons[1].pressed.connect(_toggle_visible)
	_buttons[2].pressed.connect(func() -> void: quit_requested.emit())
	_relabel()


func _relabel() -> void:
	var cn: bool = hud.chinese
	for b in _buttons:
		b.add_theme_font_override("font", hud.font)
	_buttons[0].text = ("解锁" if _locked else "穿透") if cn else ("unlock" if _locked else "pass")
	_buttons[1].text = "隐藏" if cn else "hide"
	_buttons[2].text = "退出" if cn else "exit"


func _toggle_lock() -> void:
	_locked = not _locked
	mouse_passthrough = _locked
	_relabel()


func _toggle_visible() -> void:
	visible = not visible


func _on_host_event(name: String) -> void:
	print("XuanDesk: host event '", name, "'")
	match name:
		"toggle_hud":
			visible = not visible
		"toggle_clickthrough":
			_toggle_lock()
		"quit":
			quit_requested.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _over_button(event.position):
				return
			_dragging = true
			_drag_offset = DisplayServer.window_get_position(get_window_id()) \
					- DisplayServer.mouse_get_position()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		DisplayServer.window_set_position(
				DisplayServer.mouse_get_position() + _drag_offset, get_window_id())


func _over_button(local: Vector2) -> bool:
	for b in _buttons:
		if Rect2(b.position, b.size).has_point(local):
			return true
	return false
