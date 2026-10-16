## The floating monitor window: a borderless, always-on-top, per-pixel
## transparent OS window.
##
## Nothing is glued to it any more: the shell's chrome - the 菜单 - lives in the
## notification area since 2026-10-13 (the tray icon and Win32 popup the native side
## owns, see the tray block in native/gdext/xuandesk_native.c). That is also what keeps 穿透
## escapable: 穿透 passes every mouse event through this window, and a window that
## has passed the mouse through has passed it through everywhere, so nothing drawn
## *in* it stays clickable - while a tray icon is not a window of ours at all.
##
## 穿透 itself is not done with Godot's `Window.mouse_passthrough` (2026-10-13):
## on Windows that flag only makes the window answer WM_NCHITTEST with
## HTTRANSPARENT, which the system forwards to underlying windows *in the same
## thread* - so the HUD stopped taking clicks but nothing underneath got them
## either (measured; see native/gdext/xuandesk_native.c apply_one_overlay). The window
## style Windows honours across processes is the native side's business, like its
## topmost / tool-window / no-activate bits: this class owns the flag and says when
## it turned over.
##
## Everything in here is whatever the current background built. Switching a
## background replaces the content and resizes this window to match.
##
## Dragging is done by hand (mouse offset -> window position) rather than with a
## native caption drag, so it keeps working while the window is non-activating.
class_name HudWindow
extends Window

## The native side's quit hotkey lands on this window (Ctrl+Alt+Q, `_on_native_event`).
## It is the shell that exits, so this is a request, like the tray's 退出 row.
signal quit_requested
## 穿透 has turned over - through Ctrl+Alt+T or the tray's 穿透 row. This window
## owns the flag (the mouse passthrough is its own), the tray is the shell's, and
## the two are kept in step through this (2026-10-13).
signal passthrough_changed(locked: bool)

## The gap the window is seeded at: `MARGIN` from the usable area's right edge,
## `TOP_MARGIN` from its top (用户 2026-10-14: the HUD's default distance from the
## screen top is 100). Only the first placement uses them - thereafter the window
## stays where the user dragged it (`_placed`).
const MARGIN := 26
const TOP_MARGIN := 100
const SEED_SIZE := Vector2i(320, 200)

var metrics: MetricsClient

var _content: Control
var _placed := false
var _dragging := false
var _drag_offset := Vector2i.ZERO
var _locked := false
var _content_size := SEED_SIZE


func _ready() -> void:
	title = MetricsClient.HUD_TITLE
	borderless = true
	transparent = true
	always_on_top = true
	visible = true

	_fit(SEED_SIZE)   # the real size arrives with the first set_content()
	set_process_input(true)


## The 穿透 switch, driven from the tray's own row (the shell routes the event
## back here) and from Ctrl+Alt+T. This window is not in the way of it, so the
## signal it carries is for whoever else keeps the state - the tray's tick.
func toggle_passthrough() -> void:
	_toggle_lock()


## Hands the window to `content` and grows it to `content_size`. The previous
## content is dropped - HUDs are rebuilt per background so no state survives a
## switch - and the window keeps the position the user dragged it to.
func set_content(content: Control, content_size: Vector2i) -> void:
	if _content != null:
		_content.get_parent().remove_child(_content)
		_content.queue_free()
	_content = content
	add_child(content)
	content.set_anchors_preset(Control.PRESET_TOP_LEFT)
	content.position = Vector2.ZERO
	content.size = Vector2(content_size)
	_fit(content_size)
	if not _placed:
		_placed = true
		position = _default_position()


func attach(client: MetricsClient) -> void:
	metrics = client
	client.native_event.connect(_on_native_event)


# --------------------------------------------------------------------- window

func _fit(content_size: Vector2i) -> void:
	# this window is the content, edge to edge: the chrome is the tray's now, so
	# there is no strip to add here
	_content_size = content_size
	size = content_size


func _default_position() -> Vector2i:
	var screen := DisplayServer.get_primary_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	return Vector2i(usable.position.x + usable.size.x - size.x - MARGIN,
			usable.position.y + TOP_MARGIN)


## The one switch that is about the mouse rather than about the sky: with it on,
## every event this window sees is passed to the desktop under it. The tray icon is
## what stays clickable when it is on (2026-10-13) - before that it was the menu
## window sitting on this one's corner.
##
## The window style that does the passing is the native side's to set (it owns this
## window's styles and holds the same flag): this only turns the flag over and
## says so - what main.gd sends to the native side, and what the tray's row shows.
func _toggle_lock() -> void:
	_locked = not _locked
	passthrough_changed.emit(_locked)
	print("XuanDesk: HUD mouse passthrough %s" % ("on" if _locked else "off"))


## Whether the mouse is being passed through - what the tray's 穿透 row ticks.
func is_locked() -> bool:
	return _locked


func _on_native_event(name: String) -> void:
	print("XuanDesk: native event '", name, "'")
	# "toggle_desktop" is the shell's (shell/main.gd): the desktop layer is the
	# wallpaper window's business, not the HUD's, and the shell owns the state of
	# the two windows. Only the HUD's own two events are answered here.
	match name:
		"toggle_clickthrough":
			_toggle_lock()
		"quit":
			quit_requested.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _over_content_control(event.position):
				return
			_dragging = true
			_drag_offset = DisplayServer.window_get_position(get_window_id()) \
					- DisplayServer.mouse_get_position()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		DisplayServer.window_set_position(
				DisplayServer.mouse_get_position() + _drag_offset, get_window_id())


## Whether a point falls on a control a background put in its HUD that takes the
## mouse itself - a button, or the dial if it ever becomes draggable. Those keep
## their presses; the rest of the content stays the window's drag handle, so a
## background can have both (README「HUD 罗盘规格（自内向外）」).
func _over_content_control(point: Vector2) -> bool:
	return _content != null and _control_at(_content, point)


func _control_at(node: Node, point: Vector2) -> bool:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if control.visible and control.mouse_filter != Control.MOUSE_FILTER_IGNORE \
					and control.get_global_rect().has_point(point):
				return true
		if _control_at(child, point):
			return true
	return false
