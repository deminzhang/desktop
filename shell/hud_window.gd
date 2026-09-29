## The floating monitor window: a borderless, always-on-top, per-pixel
## transparent OS window.
##
## The shell owns its chrome - the background picker and the pass/hide/quit
## buttons in a toolbar strip under the content - while everything above that
## strip is whatever the current background built. Switching a background
## replaces the content and resizes the window to match.
##
## Dragging is done by hand (mouse offset -> window position) rather than with a
## native caption drag, so it keeps working while the window is non-activating.
##
## The picker's menu is drawn inside this window rather than with an
## OptionButton: its native popup never survives in a non-activating window, and
## the host keeps this one non-activating on purpose.
class_name HudWindow
extends Window

signal quit_requested
signal background_selected(id: String)

const MARGIN := 26
const TOOLBAR := 24.0  ## strip below the content holding the shell's controls
const SEED_SIZE := Vector2i(320, 200)

const PICKER_POS := Vector2(14.0, 2.0)
const PICKER_SIZE := Vector2(112.0, 20.0)
const MENU_ITEM_H := 18.0

const C_TEXT := Color(0.88, 0.96, 0.99)
const C_DIM := Color(0.44, 0.63, 0.70)
const C_ACCENT := Color(0.30, 0.85, 1.00)
const C_FILL := Color(0.09, 0.21, 0.26, 0.80)
const C_FILL_HOVER := Color(0.14, 0.31, 0.38, 0.90)
const C_BORDER := Color(0.30, 0.72, 0.82, 0.32)
const C_BORDER_HOVER := Color(0.40, 0.85, 0.95, 0.55)
const C_MENU := Color(0.05, 0.13, 0.17, 0.94)

var metrics: MetricsClient

var _content: Control
var _toolbar: Control
var _picker: Button
var _menu: PanelContainer
var _items: VBoxContainer
var _buttons: Array[Button] = []
var _placed := false
var _dragging := false
var _drag_offset := Vector2i.ZERO
var _locked := false


func _ready() -> void:
	title = MetricsClient.HUD_TITLE
	borderless = true
	transparent = true
	always_on_top = true
	visible = true

	_toolbar = Control.new()
	_toolbar.name = "Toolbar"
	_toolbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Controls draw in tree order and the content is added above the toolbar, so
	# the picker's menu needs an explicit z to unfold over the HUD instead of
	# behind it.
	_toolbar.z_index = 1
	add_child(_toolbar)
	_toolbar.set_anchors_preset(Control.PRESET_TOP_LEFT)

	_build_toolbar()
	_fit(SEED_SIZE)  # the real size arrives with the first set_content()
	set_process_input(true)


## Hands the window to `content` and grows it to `content_size` plus the
## toolbar. The previous content is dropped - HUDs are rebuilt per background so
## no state survives a switch - and the window keeps the position the user
## dragged it to.
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


## Points the picker at the live background without emitting background_selected.
func set_current(id: String) -> void:
	_menu.visible = false
	_picker.text = Backgrounds.display_name(id) + " ▾"
	for item in _items.get_children():
		item.add_theme_color_override("font_color",
				C_ACCENT if String(item.name) == id else C_DIM)


func attach(client: MetricsClient) -> void:
	metrics = client
	client.host_event.connect(_on_host_event)


# -------------------------------------------------------------------- toolbar

func _build_toolbar() -> void:
	_picker = Button.new()
	_picker.name = "BackgroundPicker"
	_picker.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_picker.position = PICKER_POS
	_picker.size = PICKER_SIZE
	_chrome(_picker)
	_picker.pressed.connect(_toggle_menu)
	_toolbar.add_child(_picker)

	_items = VBoxContainer.new()
	_items.name = "Items"
	_items.add_theme_constant_override("separation", 2)
	for index in Backgrounds.ids().size():
		var id := String(Backgrounds.ids()[index])
		var item := Button.new()
		item.name = id
		item.text = Backgrounds.display_name(id)
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.custom_minimum_size = Vector2(PICKER_SIZE.x - 8.0, MENU_ITEM_H)
		_chrome(item)
		item.pressed.connect(_on_pick.bind(index))
		_items.add_child(item)

	_menu = PanelContainer.new()
	_menu.name = "BackgroundMenu"
	_menu.visible = false
	var box := StyleBoxFlat.new()
	box.bg_color = C_MENU
	box.set_corner_radius_all(6)
	box.set_border_width_all(1)
	box.border_color = C_BORDER
	box.set_content_margin_all(4)
	_menu.add_theme_stylebox_override("panel", box)
	_menu.add_child(_items)
	_toolbar.add_child(_menu)

	var specs := [["pass", 130.0], ["hide", 174.0], ["quit", 218.0]]
	for spec: Array in specs:
		var button := Button.new()
		button.name = String(spec[0])
		button.position = Vector2(float(spec[1]), 2.0)
		button.size = Vector2(40.0, 20.0)
		_chrome(button)
		_toolbar.add_child(button)
		_buttons.append(button)

	_buttons[0].pressed.connect(_toggle_lock)
	_buttons[1].pressed.connect(_toggle_visible)
	_buttons[2].pressed.connect(func() -> void: quit_requested.emit())
	_relabel()


func _chrome(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", Fonts.ui_font())
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", C_DIM)
	button.add_theme_color_override("font_hover_color", C_TEXT)
	button.add_theme_color_override("font_pressed_color", C_ACCENT)
	button.add_theme_stylebox_override("normal", _chip(C_FILL, C_BORDER))
	button.add_theme_stylebox_override("hover", _chip(C_FILL_HOVER, C_BORDER_HOVER))
	button.add_theme_stylebox_override("pressed", _chip(C_FILL_HOVER, C_BORDER_HOVER))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _chip(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(5)
	box.set_border_width_all(1)
	box.border_color = border
	return box


## Opens or closes the picker's menu, which unfolds upward from the picker so it
## stays inside the window.
func _toggle_menu() -> void:
	var wanted := _menu.get_combined_minimum_size()
	_menu.size = wanted
	_menu.position = Vector2(PICKER_POS.x, PICKER_POS.y - wanted.y - 3.0)
	_menu.visible = not _menu.visible


func _on_pick(index: int) -> void:
	_menu.visible = false
	var ids := Backgrounds.ids()
	if index < 0 or index >= ids.size():
		return
	background_selected.emit(String(ids[index]))


func _fit(content_size: Vector2i) -> void:
	# the picker's menu unfolds upward from the toolbar, so the window always
	# keeps room for it: a background with a short HUD would otherwise clip the
	# menu against the window edge
	var room := maxf(float(content_size.y), _menu_room())
	size = Vector2i(content_size.x, int(room) + int(TOOLBAR))
	_toolbar.position = Vector2(0.0, room)
	_toolbar.size = Vector2(float(content_size.x), TOOLBAR)


func _menu_room() -> float:
	return float(Backgrounds.ids().size()) * (MENU_ITEM_H + 2.0) + 12.0


func _default_position() -> Vector2i:
	var screen := DisplayServer.get_primary_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	return Vector2i(usable.position.x + usable.size.x - size.x - MARGIN,
			usable.position.y + MARGIN)


func _relabel() -> void:
	var cn := Fonts.has_chinese()
	_buttons[0].text = ("解锁" if _locked else "穿透") if cn else ("unlock" if _locked else "pass")
	_buttons[1].text = "隐藏" if cn else "hide"
	_buttons[2].text = "退出" if cn else "exit"


# --------------------------------------------------------------------- window

func _toggle_lock() -> void:
	_locked = not _locked
	mouse_passthrough = _locked
	_relabel()


func _toggle_visible() -> void:
	_menu.visible = false
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
			if _menu.visible and not _menu.get_global_rect().has_point(event.position) \
					and not _picker.get_global_rect().has_point(event.position):
				_menu.visible = false
			# the toolbar belongs to the shell, the content above it is the drag handle
			if _toolbar.get_rect().has_point(event.position):
				return
			_dragging = true
			_drag_offset = DisplayServer.window_get_position(get_window_id()) \
					- DisplayServer.mouse_get_position()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		DisplayServer.window_set_position(
				DisplayServer.mouse_get_position() + _drag_offset, get_window_id())
