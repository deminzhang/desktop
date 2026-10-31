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
## Dragging is done by hand (the grab point inside the window -> window position) rather
## than with a native caption drag, so it keeps working while the window is non-activating;
## the grab point comes from the press event, never from the cursor, so no offset can carry
## the panel away from the cursor (2026-11-03).
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

## The panel's own watch (2026-11-02), the counterpart of the wallpaper window's
## (shell/main.gd::_watch_desktop_window). A window outside every monitor is invisible
## while Windows still calls it `visible`, and nothing else in this app ever looks at
## where the panel ended up: the one seeding in set_content() and the drag below are its
## only two writers. Measured that day: 300x340 at (2692,1520), on a desktop of two
## 2560x1440 screens side by side - 80 px below the bottom of a 5120x1440 desktop, alive
## and `visible` for days, with the compass on no screen at all and not one line in the
## log. The wait is so a desktop being re-arranged (a screen going away and coming back)
## is not fought, the same reason the wallpaper watch waits before it acts.
const LOST_GRACE_MS := 5000
## How much of the window a screen has to be showing, in each direction, to count as
## findable - a corner big enough to grab. Measured per monitor and per axis, so a panel
## straddling the seam between two screens is findable on both and one hanging 200 px off
## the bottom edge is findable on the 200 px that are still there.
const KEEP_VISIBLE := 40
## How long one drag may live: a drag older than this lost its release and is over
## (2026-11-03, the day the panel spent following a cursor with no button held).
const DRAG_MAX_MS := 60000

var metrics: MetricsClient

var _content: Control
var _placed := false
var _dragging := false
## Where inside the window the user took hold, in this window's own coordinates: the window
## is put so that this point stays under the cursor. It is read off the press event and is
## therefore always a point *of the window* - the cursor's own position is not, since it can
## have moved since the press, and on 2026-11-03 an offset read that way had the panel
## fleeing the cursor and off the desktop.
var _grab_point := Vector2i.ZERO
var _drag_started_ms := 0
var _locked := false
var _content_size := SEED_SIZE

## The watch's bookkeeping: the rect last seen, so a move nobody asked for is one line in
## the log, and when the window was first seen off every screen (0 = it is not out there).
var _last_rect := Rect2i()
var _lost_since := 0


func _ready() -> void:
	title = MetricsClient.HUD_TITLE
	borderless = true
	transparent = true
	# `transparent` is the OS window; `transparent_bg` is the viewport inside it. With only
	# the first one the viewport still clears with the project's `default_clear_color`
	# (rgb(3,9,14), alpha 1), and the HUD then shows that colour as an opaque 300x340
	# rectangle - measured on the live desktop as rgb(24,30,37) inside the window's edges
	# against rgb(21,21,23) just outside them, a one-pixel step. The card is a circle on the
	# desktop, not a rectangle on top of it (2026-11-03).
	transparent_bg = true
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
	# the watch starts from where the panel was put, not from (0,0)
	_last_rect = Rect2i(position, size)


## One metric frame in, one look at where the panel actually is (shell/main.gd::_on_frame,
## beside the wallpaper watch). Windows reports a window's position whether or not the
## position is on a monitor, so the only way to know the panel is findable is to measure
## it against the screens themselves.
##
## A panel off every screen is the failure this exists for, and it is not fatal to
## anything else: the window keeps drawing, the tray keeps working, and the panel is
## simply nowhere. It is put back where a fresh start would seed it, and both the loss
## and the recovery are one line each in the log - a loss with no trace is what took four
## days to find on 2026-11-02.
func keep_on_screen() -> void:
	var rect := Rect2i(DisplayServer.window_get_position(get_window_id()), size)
	if on_screen(rect, screen_rects()):
		if _lost_since != 0:
			_lost_since = 0
			print("XuanDesk: panel window back on screen at (%d,%d)"
					% [rect.position.x, rect.position.y])
		_note_move(rect)
		return

	var now := Time.get_ticks_msec()
	if _lost_since == 0:
		_lost_since = now
		print("XuanDesk: panel window is off every screen at (%d,%d) %d×%d - waiting %d ms"
				% [rect.position.x, rect.position.y, rect.size.x, rect.size.y,
				LOST_GRACE_MS])
		return
	if now - _lost_since < LOST_GRACE_MS:
		return
	var waited := now - _lost_since
	_lost_since = 0
	_dragging = false
	position = _default_position()
	_last_rect = Rect2i(position, size)
	print("XuanDesk: panel window was nowhere for %d ms - back to the default corner (%d,%d)"
			% [waited, position.x, position.y])


## Says so when the panel is somewhere it was not - the one line that answers "who moved
## it" the next time. A drag reports itself when it lets go instead, so a drag is one line
## and not one per frame.
func _note_move(rect: Rect2i) -> void:
	if rect == _last_rect:
		return
	var was := _last_rect
	_last_rect = rect
	if _dragging or was == Rect2i():
		return
	print("XuanDesk: panel window moved to (%d,%d) %d×%d (was %d,%d)"
			% [rect.position.x, rect.position.y, rect.size.x, rect.size.y,
			was.position.x, was.position.y])


## The screens the placement is measured against, in the coordinates a window position
## uses - every monitor's own rectangle, the taskbar and all, because a panel overlapping
## the taskbar is still a panel the user can grab.
static func screen_rects() -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	for index in DisplayServer.get_screen_count():
		rects.append(Rect2i(DisplayServer.screen_get_position(index),
				DisplayServer.screen_get_size(index)))
	return rects


## Whether any one monitor is showing a corner of `rect` big enough to grab: KEEP_VISIBLE
## px of it in each direction. False means the window is off every screen - alive,
## `visible`, and nowhere to be seen, which is the failure of 2026-11-02. Intersections
## are per monitor rather than against their bounding box, because two screens side by
## side leave a cross of dead space that is on neither of them.
static func on_screen(rect: Rect2i, screens: Array[Rect2i]) -> bool:
	for screen in screens:
		var hit := rect.intersection(screen)
		if hit.size.x >= KEEP_VISIBLE and hit.size.y >= KEEP_VISIBLE:
			return true
	return false


## Where to put a window instead of `rect` when `rect` is off every screen: each monitor
## is asked where it would keep the window whole, and the nearest answer wins. The drag is
## the only caller, and it asks *after* on_screen() has already said no - so this is the
## backstop at the edge of a drag, not a rule the cursor feels: a panel being dragged from
## one monitor to the next stays exactly under the cursor and straddles the seam on the
## way, because straddling it is on both screens.
static func clamp_into_screens(rect: Rect2i, screens: Array[Rect2i]) -> Vector2i:
	if screens.is_empty():
		return rect.position
	var best := rect.position
	var best_distance := -1.0
	for screen in screens:
		var candidate := Vector2i(
				clampi(rect.position.x, screen.position.x,
						maxi(screen.position.x, screen.end.x - rect.size.x)),
				clampi(rect.position.y, screen.position.y,
						maxi(screen.position.y, screen.end.y - rect.size.y)))
		var distance := Vector2(candidate - rect.position).length_squared()
		if best_distance < 0.0 or distance < best_distance:
			best_distance = distance
			best = candidate
	return best


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
			# A grab is a press that landed *inside* this window, and the grab point is
			# where inside it the press landed - both read off the event, never off the
			# cursor. A press that did not land inside is not a grab: with the mouse
			# captured this window also hears presses that happened elsewhere on the
			# desktop, and such a press is what a stale offset used to be computed from.
			if not Rect2(Vector2.ZERO, Vector2(size)).has_point(event.position):
				return
			if _over_content_control(event.position):
				return
			_dragging = true
			_grab_point = Vector2i(event.position)
			_drag_started_ms = Time.get_ticks_msec()
		elif _dragging:
			_end_drag()
	elif event is InputEventMouseMotion and _dragging:
		# The release can go missing - a lock takes the mouse, the window is hidden and
		# rebuilt under the cursor (G9), a screen changes - and then `_dragging` stays true
		# for days and the panel follows every mouse move (measured 2026-11-03 on the
		# shipped build: one WM_MOUSEMOVE carrying no button at all moved the panel from
		# (2608,1456) to (588,1341)). No honest drag lasts a minute, so a drag that old is
		# over.
		#
		# The button mask in the motion event is *not* what judges that: a motion the system
		# sent with MK_LBUTTON set still arrived here with an empty mask when posted
		# (measured the same day), and a guard that cannot be shown to pass for a real drag
		# is a guard that can stop the user's drag from working at all. The grab point below
		# is what keeps a stuck drag from doing harm instead: the panel is always put under
		# the cursor, so a drag that never ends carries the panel *with* the cursor rather
		# than away from it, the next real click on it (press and release, both inside) ends
		# it, and the watch is the backstop if it is ever carried off every screen.
		if Time.get_ticks_msec() - _drag_started_ms > DRAG_MAX_MS:
			_end_drag("the drag outlived %d s" % [DRAG_MAX_MS / 1000])
			return
		# `mouse_get_position()` is the cursor's own position on the desktop, so the
		# window follows it exactly and whatever lands under the cursor is where it goes -
		# a monitor away, a seam between two, half of it over the taskbar. The clamp only
		# speaks when the arithmetic would leave nothing on any screen at all (a screen
		# going away mid-drag, or a cursor position the desktop never had), which is what
		# keeps the watch above a backstop instead of the only thing between the user and
		# a lost panel.
		var target := Rect2i(DisplayServer.mouse_get_position() - _grab_point, size)
		var screens := screen_rects()
		if not on_screen(target, screens):
			target.position = clamp_into_screens(target, screens)
		DisplayServer.window_set_position(target.position, get_window_id())


## Ends a drag - the button came up, or the drag was found to be dead - and says where the
## panel came to rest. The drag is the only writer of a position that cannot be
## reconstructed from anything else, so the log has to carry it (2026-11-02: nothing in the
## log said how the panel left the screens and the window was 80 px past the bottom of the
## desktop; 2026-11-03: the drag that did it had never been let go of).
func _end_drag(reason := "") -> void:
	_dragging = false
	var moved := DisplayServer.window_get_position(get_window_id())
	_last_rect = Rect2i(moved, size)
	if reason.is_empty():
		print("XuanDesk: panel dragged to (%d,%d)" % [moved.x, moved.y])
	else:
		print("XuanDesk: panel drag dropped (%s) at (%d,%d)" % [reason, moved.x, moved.y])


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
