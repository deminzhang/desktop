## The floating monitor window: a borderless, always-on-top, per-pixel
## transparent OS window.
##
## The shell's chrome - the 菜单 button and the panel it opens - is a window of its
## own (`HudMenu`, built and owned by the shell), glued to this window's top-right
## corner. It has to be a window of its own: 穿透 passes every mouse event through
## this window (`Window.mouse_passthrough`), and a window that has passed the mouse
## through has passed it through everywhere, so a corner of this one could not stay
## live. The menu window is never passed through, which is what makes the way out of
## 穿透 clickable (计划 §6.4).
##
## It has to be the *shell's* window rather than this window's child, too: a Window
## node nested inside another Window draws its first frame and then never draws again
## (计划 §2.3 G30), and this one's whole point is that it changes under the pointer.
##
## Everything above that is whatever the current background built. Switching a
## background replaces the content and resizes this window to match.
##
## The "desktop" control and the rest of the chrome belong to the menu window the
## shell owns (`HudMenu`): this window is only what a background draws in, plus the
## corner the menu is glued to.
##
## Dragging is done by hand (mouse offset -> window position) rather than with a
## native caption drag, so it keeps working while the window is non-activating - and
## the menu window is re-glued to the corner on every frame, because a native window
## does not follow another one by itself.
class_name HudWindow
extends Window

## The host's own quit hotkey lands on this window (Ctrl+Alt+Q, `_on_host_event`).
## It is the shell that exits, so this is a request, like the menu's 退出.
signal quit_requested

const MARGIN := 26
const SEED_SIZE := Vector2i(320, 200)
## Where the menu's 菜单 button sits inside this window's content: `MENU_MARGIN` from
## the right edge, `MENU_TOP` from the top. The menu window grows left and down from
## that corner when its panel opens, so the corner itself never moves.
##
## It hangs *above* the content (a negative top) since 2026-10-10 第十八轮: the sky's
## compass card now keeps its 左转/右转 chips in its own two upper corners - the old
## 268..292 corner pair moved up to 8..32 - and a 菜单 button inside the top-right one
## covered the ↘ chip's glyph and took its clicks (the menu is a window above this
## one, so nothing of the chip was left). Floating it 28 px higher keeps it in the
## corner the user knows, clear of the card. The window is its own, so this only
## moves where it is; a background that puts a control in the bottom-left of its HUD
## would want the same treatment.
const MENU_MARGIN := 11.0
const MENU_TOP := -28.0

var metrics: MetricsClient

var _content: Control
var _menu: HudMenu
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


func _process(_delta: float) -> void:
	_glue_menu()


## The shell's menu window, glued to this window's corner from here on. Null is a
## HUD without chrome, which is what the probe builds.
func set_menu(menu: HudMenu) -> void:
	_menu = menu
	_menu.set_locked(_locked)
	_glue_menu()


## The menu window, for the shell's shot target and the probes.
func menu_window() -> HudMenu:
	return _menu


## The 穿透 switch, driven from the menu's own row - the shell is not in the way of
## it, so the menu does not need a signal of its own for it.
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
	_glue_menu()


## Points the menu at the live background without emitting background_selected.
func set_current(id: String) -> void:
	if _menu != null:
		_menu.set_current(id)


func attach(client: MetricsClient) -> void:
	metrics = client
	client.host_event.connect(_on_host_event)


# --------------------------------------------------------------------- window

func _fit(content_size: Vector2i) -> void:
	# this window is the content, edge to edge: the shell's chrome lives in the menu
	# window above it, so there is no strip to add here any more
	_content_size = content_size
	size = content_size


## How many screen pixels one of this window's own pixels is: the HUD is a fixed
## pixel size on a fixed-scale display, but the OS is the one that decides.
func _pixel_scale() -> float:
	var physical := Vector2(DisplayServer.window_get_size(get_window_id()))
	if size.x <= 0 or size.y <= 0:
		return 1.0
	var scale := physical.x / float(size.x)
	return scale if scale > 0.0 else 1.0


## Puts the menu window's 菜单 button on this window's top-right corner: the menu
## grows left and downwards from there, so what is glued is the button, not the
## window - `HudMenu.button_origin()` is where the button sits inside it.
func _glue_menu() -> void:
	if _menu == null or not is_instance_valid(_menu):
		return
	var scale := _pixel_scale()
	var corner := Vector2(float(_content_size.x) - MENU_MARGIN - HudMenu.BUTTON.x, MENU_TOP)
	_menu.place_at(position + Vector2i((corner * scale).round()))


func _default_position() -> Vector2i:
	var screen := DisplayServer.get_primary_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	return Vector2i(usable.position.x + usable.size.x - size.x - MARGIN,
			usable.position.y + MARGIN)


## The one switch that is about the mouse rather than about the sky: with it on,
## every event this window sees is passed to the desktop under it - and the menu
## window, which is not passed through, is the only part of the HUD left clickable.
func _toggle_lock() -> void:
	_locked = not _locked
	mouse_passthrough = _locked
	if _menu != null:
		_menu.set_locked(_locked)
	print("XuanDesk: HUD mouse passthrough %s" % ("on" if _locked else "off"))


func _on_host_event(name: String) -> void:
	print("XuanDesk: host event '", name, "'")
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
			# a press on the HUD itself shuts the menu's panel: the panel is a window
			# of its own and never sees this one's events
			if _menu != null:
				_menu.close_panel()
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
## background can have both (计划 §6.5 S7).
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
