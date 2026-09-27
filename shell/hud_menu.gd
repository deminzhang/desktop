## The HUD's chrome: the 菜单 button that rides on the HUD window's top-right corner
## and the panel it opens - 换桌面 (the backgrounds, in a submenu that unfolds to its
## own left), 穿透, 桌面, 退出 (计划 §6.4 版面修订).
##
## Every row shuts the menu when it fires: the menu is chrome, and what a row asked
## for belongs to whoever answers the signal - leaving it open leaves a panel over
## the HUD that the user then has to click away themselves.
##
## A window of its own rather than a Control inside the HUD, and for one reason:
## 穿透. The HUD window passes every mouse event through when it is locked
## (`Window.mouse_passthrough`), and a window that has passed the mouse through has
## passed it through everywhere - no corner of it can stay live. This window is never
## passed through, so the way out of 穿透 is always there to click, while everything
## else on the HUD goes on through to the desktop.
##
## It is a child of the HUD window, which owns it: it is topmost with it, it leaves
## the taskbar with it, and it is destroyed with it. `HudWindow` keeps it glued to
## the corner (it does not follow its parent by itself - it is a native window), and
## owns the state the labels show (which background is live, locked or not).
class_name HudMenu
extends Window

signal background_selected(id: String)
signal desktop_toggle_requested
## Which monitor the 3D desktop should be on (2026-10-10): the index of
## MetricsClient.screens(), which is the host's own order.
signal screen_selected(index: int)
signal quit_requested
signal passthrough_toggled
## One of the live background's own switches (Background.menu_switches) has been
## clicked, `on` being the state it was switched to.
signal switch_toggled(id: String, on: bool)

const BUTTON := Vector2(34.0, 20.0)   ## 菜单 itself: the whole window when closed
const TOP_OF_BUTTON := 2.0            ## margin inside this window's own frame
const GAP := 4.0                      ## between the button and the panel under it
const GAP_X := 4.0                    ## between the submenu and the panel it hangs off
const PANEL_W := 104.0
const SUB_W := 92.0                   ## 换桌面's submenu; its rows ask for SUB_W - 8
const SCREEN_W := 118.0               ## 显示器's: 主屏/副屏 N and the resolution need the room
const ITEM_H := 20.0

const C_TEXT := Color(0.88, 0.96, 0.99)
const C_DIM := Color(0.44, 0.63, 0.70)
const C_ACCENT := Color(0.30, 0.85, 1.00)
const C_FILL := Color(0.09, 0.21, 0.26, 0.80)
const C_FILL_HOVER := Color(0.14, 0.31, 0.38, 0.90)
const C_BORDER := Color(0.30, 0.72, 0.82, 0.32)
const C_BORDER_HOVER := Color(0.40, 0.85, 0.95, 0.55)
const C_MENU := Color(0.05, 0.13, 0.17, 0.94)

var _button: Button
var _panel: PanelContainer          ## the drop, as big as its rows ask for
var _rows: VBoxContainer
var _sub: PanelContainer            ## the submenu that unfolds left of the panel
var _backgrounds: VBoxContainer     ## 换桌面's list, one row per registered background
var _bg_row: Button                 ## the 换桌面 row: the submenu sits level with it
## 显示器's list (2026-10-10): one row per monitor the host reported, index 0 the
## primary. Empty until a frame arrives, and the row itself is hidden while there is
## only one monitor - a menu that offers a choice of one is a menu that lies.
var _screens: VBoxContainer
var _screen_row: Button
var _screen_buttons: Array = []
var _screen_index := 0
var _screens_key := ""
## The row the unfolded submenu hangs level with - 换桌面's or 显示器's.
var _sub_row: Button = null
## The live background's own switches, drawn between 换桌面 and 穿透: one entry per
## row, {"id": String, "label": String, "on": bool, "button": Button}. Empty for a
## background that offers none.
var _switch_rows: Array = []
var _pass: Button
var _desk: Button
var _quit: Button
var _locked := false
var _open := false
## The 菜单 button's top-left on screen, as last handed over by the HUD: the point
## this window keeps still while its own frame grows and shrinks around it.
var _anchor := Vector2i.ZERO


func _ready() -> void:
	title = MetricsClient.MENU_TITLE
	borderless = true
	transparent = true
	always_on_top = true
	# NOTE: no `unfocusable` here. Godot maps it to NO_FOCUS, whose own docs promise
	# "ignore all input, except mouse clicks" while the member's docs say the window
	# "can't be focused nor interacted with" - and on this build the buttons stop
	# receiving clicks at all. The host sets WS_EX_NOACTIVATE on this window from
	# outside, which is the same guarantee without the input side effect.

	_panel = _box("Panel")
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.add_theme_constant_override("separation", 2)
	_panel.add_child(_rows)

	# The arrow points at the submenu's own direction, not down: ‹ and not ▾ - the
	# engine's font has no glyph for ▾ (U+25BE, measured), so that one drew as a box.
	_bg_row = _row("换桌面 ‹", _toggle_backgrounds)

	# Both submenus hang off the panel's left, inside one box: at most one of them is
	# unfolded, and the box is always level with the row that opened it.
	_sub = _box("Sub")
	_backgrounds = VBoxContainer.new()
	_backgrounds.name = "Backgrounds"
	_backgrounds.add_theme_constant_override("separation", 2)
	for index in Backgrounds.ids().size():
		var id := String(Backgrounds.ids()[index])
		var item := _chrome(Button.new(), false)
		item.name = id
		item.text = Backgrounds.display_name(id)
		item.custom_minimum_size = Vector2(SUB_W - 8.0, ITEM_H)
		item.pressed.connect(_pick_background.bind(index))
		_backgrounds.add_child(item)
	_sub.add_child(_backgrounds)
	_backgrounds.visible = false

	_screens = VBoxContainer.new()
	_screens.name = "Screens"
	_screens.add_theme_constant_override("separation", 2)
	_sub.add_child(_screens)
	_screens.visible = false

	_screen_row = _row("显示器 ‹", _toggle_screens)
	_screen_row.visible = false

	_pass = _row("穿透", _choose_passthrough)
	_desk = _row("桌面", _choose_desktop)
	_quit = _row("退出", _choose_quit)

	# 菜单 is the window's own handle, drawn over the panel: when the panel is open
	# the button stays where it was and the panel unfolds under it, so the corner of
	# the HUD the menu hangs on never moves.
	_button = _chrome(Button.new(), true)
	_button.name = "MenuButton"
	_button.custom_minimum_size = BUTTON
	_button.pressed.connect(_toggle)
	add_child(_button)

	_relabel()
	_layout(false)

	# This window has a viewport of its own, and one that is not being looked at
	# should not be drawn 60 times a second (计划 §7: the sky idles at 0.5% GPU).
	# It draws one frame per change instead, and draws continuously only while the
	# pointer is inside it, so the button hover follows the mouse.
	mouse_entered.connect(_live.bind(true))
	mouse_exited.connect(_live.bind(false))


func _live(on: bool) -> void:
	RenderingServer.viewport_set_update_mode(get_viewport_rid(),
			RenderingServer.VIEWPORT_UPDATE_ALWAYS if on
					else RenderingServer.VIEWPORT_UPDATE_ONCE)


## One frame, now: what every change to this window goes through. Without it the
## viewport draws once - at creation - and a panel opened later is never presented,
## which looks exactly like the menu being behind the HUD.
func _redraw() -> void:
	RenderingServer.viewport_set_update_mode(get_viewport_rid(),
			RenderingServer.VIEWPORT_UPDATE_ONCE)


## The window's own frame: the button when the panel is shut, the button plus
## whatever hangs off it when it is open. The button keeps its place in the top-right
## either way - and the window is re-anchored to it here, in the same frame, so
## unfolding the panel does not make the button jump left before the shell glues it
## back.
func _layout(open: bool) -> void:
	_open = open
	_panel.visible = open
	if not open:
		# - and the submenu folds with it: the next open starts at the four rows, not
		# at wherever the background list was left
		_sub.visible = false
		size = Vector2i(int(BUTTON.x + TOP_OF_BUTTON * 2.0),
				int(BUTTON.y + TOP_OF_BUTTON * 2.0))
		_button.position = Vector2(TOP_OF_BUTTON, TOP_OF_BUTTON)
		_button.size = BUTTON
		_apply_anchor()
		return

	var main_h := _panel.get_combined_minimum_size().y
	_panel.size = Vector2(PANEL_W, main_h)
	var sub_w := 0.0
	var sub_h := 0.0
	if _sub.visible:
		var asked := _sub.get_combined_minimum_size()
		sub_w = asked.x
		sub_h = asked.y
	var main_x := TOP_OF_BUTTON + (sub_w + GAP_X if _sub.visible else 0.0)
	_panel.position = Vector2(main_x, TOP_OF_BUTTON + BUTTON.y + GAP)
	var right := main_x + PANEL_W
	size = Vector2i(int(right + TOP_OF_BUTTON),
			int(TOP_OF_BUTTON * 2.0 + BUTTON.y + GAP + maxf(main_h, sub_h)))
	_button.position = Vector2(right - BUTTON.x, TOP_OF_BUTTON)
	_button.size = BUTTON
	if _sub.visible:
		# right edge on the panel's left edge, top level with the row that opened it
		# (换桌面 and 显示器 are both chrome rows, so the row it hangs off is the one
		# that was clicked)
		_sub.position = Vector2(TOP_OF_BUTTON, _panel.position.y + _rows.position.y
				+ (_sub_row.position.y if _sub_row != null else 0.0))
		_sub.size = Vector2(sub_w, sub_h)
	_apply_anchor()


## Where the button's top-left sits inside this window, in window pixels: what the
## shell needs to glue the corner of the menu to the corner of the HUD.
func button_origin() -> Vector2i:
	return Vector2i(_button.position)


## Puts the 菜单 button's top-left at `at` on screen - the HUD glues it there every
## frame, so a move (the HUD being dragged) only moves this window: its own content
## has not changed and does not need drawing again.
func place_at(at: Vector2i) -> void:
	if at == _anchor:
		return
	_anchor = at
	position = at - button_origin()


## Re-anchors after this window's own frame changed size, and draws it: a resize
## changes both where the button sits inside and what the frame looks like.
func _apply_anchor() -> void:
	position = _anchor - button_origin()
	_redraw()


## Whether the panel is down - a partly transparent window with a wide-open panel is
## worth knowing about when a shot is taken or a press is routed.
func is_open() -> bool:
	return _open


## Points the menu at the live background without emitting background_selected.
func set_current(id: String) -> void:
	for item in _backgrounds.get_children():
		item.add_theme_color_override("font_color",
				C_ACCENT if String(item.name) == id else C_DIM)
	_redraw()


## The 穿透 label follows the HUD's own state, whichever end of the wire toggled it.
func set_locked(locked: bool) -> void:
	_locked = locked
	_relabel()


# ------------------------------------------------------- the background's switches

## Rebuilds the rows the live background asked for (`Background.menu_switches`),
## above the shell's own 穿透/桌面/退出. Called on every background switch: a row
## belongs to the background that offered it, so the previous one's rows go.
func set_switches(items: Array) -> void:
	for row in _switch_rows:
		var old: Button = row["button"]
		_rows.remove_child(old)
		old.queue_free()
	_switch_rows.clear()
	for index in items.size():
		var item: Dictionary = items[index]
		var row := {
			"id": String(item.get("id", "")),
			"label": String(item.get("label", "")),
			"on": bool(item.get("on", false)),
			# 换桌面 is the panel's first row: the switches go under it, the shell's
			# three stay last
			"button": _row("", _toggle_switch.bind(index)),
		}
		_switch_rows.append(row)
		_rows.move_child(row["button"], 1 + index)
		_paint_switch(index)
	# 显示器 is the shell's own chrome and stays under the rows the background owns:
	# which monitor the 3D desktop sits on has nothing to do with what is drawn in it
	_rows.move_child(_screen_row, 1 + _switch_rows.size())
	# the panel is as tall as its rows ask: an open one grows a row taller here
	_layout(_open)


## A switch is a switch, not a command: the panel stays open on it, because the
## row the user is looking at is where the new state is written (the four
## command rows all shut the menu - 计划 §6.5).
func _toggle_switch(index: int) -> void:
	if index < 0 or index >= _switch_rows.size():
		return
	var row: Dictionary = _switch_rows[index]
	row["on"] = not row["on"]
	_paint_switch(index)
	switch_toggled.emit(String(row["id"]), bool(row["on"]))
	_redraw()


## On and off are two words rather than a mark: the engine's font has no glyph
## for most of the tick boxes that could stand in (G30's 换桌面 arrow), and the
## accent the live background's own row already uses is what "on" looks like.
func _paint_switch(index: int) -> void:
	var row: Dictionary = _switch_rows[index]
	var button: Button = row["button"]
	var label := String(row["label"])
	button.text = label if row["on"] else "%s·关" % label
	button.add_theme_color_override("font_color",
			C_ACCENT if row["on"] else C_DIM)


# --------------------------------------------------------------------- rows

func _row(text: String, pressed: Callable) -> Button:
	var item := _chrome(Button.new(), false)
	item.text = text
	item.custom_minimum_size = Vector2(PANEL_W - 8.0, ITEM_H)
	item.pressed.connect(pressed)
	_rows.add_child(item)
	return item


func _box(name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = name
	var box := StyleBoxFlat.new()
	box.bg_color = C_MENU
	box.set_corner_radius_all(6)
	box.set_border_width_all(1)
	box.border_color = C_BORDER
	box.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", box)
	add_child(panel)
	return panel


func _chrome(button: Button, accent: bool) -> Button:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", Fonts.ui_font())
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", C_ACCENT if accent else C_DIM)
	button.add_theme_color_override("font_hover_color", C_TEXT)
	button.add_theme_color_override("font_pressed_color", C_ACCENT)
	button.add_theme_stylebox_override("normal", _chip(C_FILL, C_BORDER))
	button.add_theme_stylebox_override("hover", _chip(C_FILL_HOVER, C_BORDER_HOVER))
	button.add_theme_stylebox_override("pressed", _chip(C_FILL_HOVER, C_BORDER_HOVER))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


static func _chip(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(5)
	box.set_border_width_all(1)
	box.border_color = border
	return box


func _relabel() -> void:
	_button.text = ".."
	_pass.text = "解锁" if _locked else "穿透"
	_desk.text = "桌面"
	_quit.text = "退出"
	_redraw()


# ------------------------------------------------------------------ actions

func _toggle() -> void:
	_layout(not _open)


## Shuts the panel, leaving the button where it is. The HUD calls this when its own
## body takes a press: the panel is a window of its own and never sees that press.
func close_panel() -> void:
	if _open:
		_layout(false)


## Unfolds the panel - the dev switch `--menu=1` uses this so a shot can be taken of
## a menu that nobody is there to click open.
func open_panel() -> void:
	if not _open:
		_layout(true)


## Unfolds one of the two submenus beside the row that owns it, or folds the one
## that is already down: they share the box, so opening either closes the other.
func _unfold(list: VBoxContainer, row: Button) -> void:
	var showing := _sub.visible and list.visible
	_backgrounds.visible = false
	_screens.visible = false
	_sub.visible = not showing
	if not showing:
		list.visible = true
		_sub_row = row
	_layout(true)


func _toggle_backgrounds() -> void:
	_unfold(_backgrounds, _bg_row)


func _toggle_screens() -> void:
	if _screen_buttons.is_empty():
		return
	_unfold(_screens, _screen_row)


## The monitors the host reported, in its own order (index 0 the primary), and which
## of them the 3D desktop is on. Rebuilt only when the list actually changed: this is
## fed from the metric stream, which arrives once a second.
func set_screens(entries: Array, current: int) -> void:
	_screen_index = current
	var key := "%d|%d" % [entries.size(), current]
	var listed := ""
	for entry: Dictionary in entries:
		listed += "%dx%d@%d,%d;" % [int(entry.get("w", 0)), int(entry.get("h", 0)),
				int(entry.get("x", 0)), int(entry.get("y", 0))]
	if key + listed == _screens_key:
		return
	_screens_key = key + listed
	for button in _screen_buttons:
		_screens.remove_child(button)
		button.queue_free()
	_screen_buttons.clear()
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var item := _chrome(Button.new(), false)
		item.name = "Screen%d" % index
		item.text = _screen_label(index, entry)
		item.custom_minimum_size = Vector2(SCREEN_W - 8.0, ITEM_H)
		item.pressed.connect(_pick_screen.bind(index))
		_screens.add_child(item)
		_screen_buttons.append(item)
	# one monitor is not a choice: the row goes, and the submenu folds with it
	_screen_row.visible = entries.size() > 1
	if not _screen_row.visible and _sub.visible and _screens.visible:
		_unfold(_screens, _screen_row)
	_paint_screens()
	# the panel is a row taller or shorter now, and an open submenu has changed size
	_rows.move_child(_screen_row, 1 + _switch_rows.size())
	_layout(_open)


## 主屏 / 副屏 N and the resolution: enough to tell two identical monitors apart is
## the geometry the host reported, which is what "at 2560,0" says.
static func _screen_label(index: int, entry: Dictionary) -> String:
	var place := "主屏" if bool(entry.get("primary", false)) else "副屏 %d" % index
	return "%s %d×%d" % [place, int(entry.get("w", 0)), int(entry.get("h", 0))]


func _paint_screens() -> void:
	for index in _screen_buttons.size():
		var button: Button = _screen_buttons[index]
		button.add_theme_color_override("font_color",
				C_ACCENT if index == _screen_index else C_DIM)


func _pick_screen(index: int) -> void:
	_screen_index = index
	_paint_screens()
	screen_selected.emit(index)
	_layout(false)


func _pick_background(index: int) -> void:
	var ids := Backgrounds.ids()
	if index < 0 or index >= ids.size():
		return
	background_selected.emit(String(ids[index]))
	_layout(false)


func _choose_passthrough() -> void:
	passthrough_toggled.emit()
	_layout(false)


func _choose_desktop() -> void:
	desktop_toggle_requested.emit()
	_layout(false)


func _choose_quit() -> void:
	quit_requested.emit()
	_layout(false)
