## The HUD's switch: a name with a knob at the end of it, thrown to one side or the
## other. Shared for the same reason the font is - a background's HUD puts a pair of
## them on one card (2026-10-12 第二十一轮: 用户把 星座/星宿 从菜单搬到罗盘左下角), and two
## hand-drawn switches sitting in one column would show every difference between them.
##
## The track is a **pill** rather than the 5 px corner the card's buttons wear, because
## that is what tells a switch from a button at a glance, and the knob is a ring while
## the thing is off and a filled dot while it is on. The name is this Button's own text
## (left-aligned), so the pill, its states and the label are the theme's business; only
## the knob is drawn here.
##
## One row of a card's corner column is SWITCH_H tall, which is what the pill's own ends
## are half of; a caller sets its own size (width and position walk with the column's
## own pitch) and this widget's look does not depend on anything outside it.
class_name SwitchChip
extends Button

## The name's font size: two CJK characters at this size are the 24 px a 38 px chip
## leaves room for beside its knob.
const LABEL_SIZE := 11
const LABEL_INSET := 5.0   ## from the pill's left edge to the name
const KNOB_R := 4.5
const KNOB_INSET := 6.5    ## from the pill's right edge to the knob's centre
## The pill's round ends: half a row of the card's columns - the height both callers
## give this chip.
const TRACK_H := 24.0

const C_DIM := Color(0.44, 0.63, 0.70)
const C_TEXT := Color(0.88, 0.96, 0.99)
const C_ACCENT := Color(0.30, 0.85, 1.00)
const C_FILL := Color(0.09, 0.21, 0.26, 0.80)
const C_FILL_HOVER := Color(0.14, 0.31, 0.38, 0.90)
const C_BORDER := Color(0.30, 0.72, 0.82, 0.32)
const C_BORDER_HOVER := Color(0.40, 0.85, 0.95, 0.55)
## The look while it is on: the accent it also writes its name in, over a fill a shade
## brighter than the hover - a switch has to say which way it is thrown from across
## the desk, and the accent is what the card says "live" with.
const C_FILL_ON := Color(0.16, 0.40, 0.48, 0.92)
const C_ON_BORDER := Color(0.40, 0.85, 0.95, 0.85)


func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_theme_stylebox_override("normal", _pill(C_FILL, C_BORDER))
	add_theme_stylebox_override("hover", _pill(C_FILL_HOVER, C_BORDER_HOVER))
	add_theme_stylebox_override("pressed", _pill(C_FILL_ON, C_ON_BORDER))
	add_theme_stylebox_override("hover_pressed", _pill(C_FILL_ON, C_ON_BORDER))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_theme_color_override("font_color", C_DIM)
	add_theme_color_override("font_hover_color", C_TEXT)
	add_theme_color_override("font_pressed_color", C_ACCENT)
	add_theme_color_override("font_hover_pressed_color", C_ACCENT)
	# the knob follows the button's own state and a toggle's look is in the styleboxes,
	# so the mark has to be repainted when either turns over. The signal carries the new
	# state, which is the button's own already.
	toggled.connect(func(_state: bool) -> void: queue_redraw())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


## Hands the chip the font the card is drawn in and the name to write. Called before
## the chip is in the tree, like every other override here.
func setup(font: Font, label: String) -> void:
	add_theme_font_override("font", font)
	add_theme_font_size_override("font_size", LABEL_SIZE)
	text = label


## Which way the switch is thrown, from whoever owns it - silent, because this is the
## chip being told what already happened rather than the user throwing it.
func show_state(state: bool) -> void:
	set_pressed_no_signal(state)
	queue_redraw()


func _draw() -> void:
	var ink := C_ACCENT if button_pressed else C_DIM
	if is_hovered():
		ink = ink.lightened(0.3)
	var at := Vector2(size.x - KNOB_INSET, size.y * 0.5)
	if button_pressed:
		draw_circle(at, KNOB_R, ink)
	else:
		draw_arc(at, KNOB_R, 0.0, TAU, 16, ink, 1.4, true)


static func _pill(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(TRACK_H * 0.5))
	box.set_border_width_all(1)
	box.border_color = border
	box.set_content_margin_all(0.0)
	box.content_margin_left = LABEL_INSET
	return box
