## The two rings of branches the sky is read against (计划 §6.5 S7): the twelve
## 地支 on the ground below the horizon - the compass rose, 子 due north - and the
## 大六壬 heaven plate laid directly above them, whose 天盘支 turns with the 时辰
## while the ground stands still.
##
## A Control, like the constellation names and for the same reasons: one size on
## screen whatever the field of view does, and nothing drawn for a bearing that is
## off the frame. Each mark hangs on its own point of the horizon - the ground ones
## set just under that line, the heaven ones raised just over it - so the pair
## reads as one scale across the sky/ground boundary at every view. Each heaven
## reading is a block of two rows of two characters, not a row of three: the 天将's
## full name (贵人, where the dial's ring only has room for 贵) over the 干支 - the
## 天盘支 with the 遁干 the day's 旬 puts on it. Unlike the constellation names they
## do not ride the sphere at all: the horizon is the observer's own frame, so only
## the camera moving re-projects the rings. Under the ground branches lies a
## third, coarser row: the eight compass points themselves, 北 and every 45° east
## of it, one size down and further back so the hour marks stay the scale.
class_name SkyBranches
extends Control

## Clear sky between the horizon line and the near edge of a mark, in pixels - the
## marks are a scale on that line, not a caption beside it, so this is small.
const GAP := 1.0
const RADIUS := 476.0   ## the shell the constellation names use
const FONT_SIZE := 15
## The 天将 name over a 干支: one size down and dimmer, so the row carrying the
## 天盘支 stays the mark that sits on the horizon bearing.
const PREFIX_SIZE := 11
const SHADOW := Color(0.0, 0.0, 0.0, 0.7)
const GROUND_COLOUR := Color(0.88, 0.76, 0.50, 0.62)   ## 地盘: the warm one
const HEAVEN_COLOUR := Color(0.78, 0.90, 0.96, 0.72)   ## 天盘: the cool one
const PREFIX_COLOUR := Color(0.78, 0.90, 0.96, 0.52)   ## 天盘's 神/干, further back
## The eight compass points the ground branches are counted from, 北 due north and
## every 45° east of it: a coarser row under the 地支, so the two interleave. One
## size down and carried further back in the ground ring's own warm colour, since
## the 地支 are the hour scale and these only say which way that scale faces.
const DIRECTIONS := ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
const DIRECTION_SPAN := 45.0
const DIRECTION_SIZE := 12
const DIRECTION_GAP := 2.0   ## clear sky between a 地支 mark's foot and a direction
const DIRECTION_COLOUR := Color(0.88, 0.76, 0.50, 0.42)

var camera: Camera3D

var _font: Font
var _heaven: Array = []   ## index = 地盘子, the 天盘支 standing over it


func setup(camera_3d: Camera3D) -> void:
	camera = camera_3d
	_font = Fonts.ui_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# a Control under a CanvasLayer gets no layout from a Control parent, so it
	# takes the viewport's size and follows it
	_follow_viewport()
	get_viewport().size_changed.connect(_follow_viewport)


## The heaven plate, handed over by the sky whenever the 时辰 turns: the 大六壬
## chart's slots, index = 地盘子. Empty until the first chart arrives, which is
## also when the ring is not drawn at all.
func set_heaven(slots: Array) -> void:
	_heaven = slots
	refresh()


## The horizon point a bearing hangs on, at the ring's radius.
static func direction_at(bearing_deg: float) -> Vector3:
	return Astro.horizon_direction(bearing_deg, 0.0) * RADIUS


## The point of the horizon a branch hangs on: due north for 子, eastwards through
## the branches. The marks stand just off that line, on either side of it.
static func direction(index: int) -> Vector3:
	return direction_at(Branches.bearing(index))


func _follow_viewport() -> void:
	size = get_viewport_rect().size
	refresh()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if camera == null or not is_instance_valid(camera) or _font == null:
		return
	for index in Branches.NAMES.size():
		var world := direction(index)
		if camera.is_position_behind(world):
			continue
		var on_horizon := camera.unproject_position(world)
		var text: String = Branches.NAMES[index]
		var extent := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		_draw_mark(Vector2(on_horizon.x - extent.x * 0.5, on_horizon.y + GAP),
				extent, text, GROUND_COLOUR, FONT_SIZE)
		if index >= _heaven.size() or not _heaven[index] is Dictionary:
			continue
		var slot: Dictionary = _heaven[index]
		if str(slot.get("branch", "")) == "":
			continue
		# The 大六壬 reading stands over the line as two rows of two: the 天将's
		# full name over the 干支 (遁干 + 天盘支 in one word), read outwards from
		# the horizon. The block is centred on the bearing its 天盘支 keeps, and
		# the row holding that branch stays the bright, larger one; the name over
		# it is the dial's own 神, written out.
		var bottom := on_horizon.y - GAP
		for part in [["%s%s" % [slot.get("stem", ""), slot.get("branch", "")],
					FONT_SIZE, HEAVEN_COLOUR],
				[str(slot.get("god_name", "")), PREFIX_SIZE, PREFIX_COLOUR]]:
			var line := str(part[0])
			if line == "":
				continue
			var line_size := int(part[1])
			var line_extent := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1,
					line_size)
			_draw_mark(Vector2(on_horizon.x - line_extent.x * 0.5,
					bottom - line_extent.y), line_extent, line, part[2], line_size)
			bottom -= line_extent.y
	# The compass points, under the ground branches: 45° to the 地支's 30°, so a
	# point falls between two branches and the two rows interlock. The label is
	# stacked under the 地支 mark on its own bearing: that mark's box starts GAP
	# below the horizon, so the direction starts one whole mark further down, plus
	# its own clear space. Measured rather than assumed, so the rows cannot drift
	# into each other if the font or FONT_SIZE changes.
	var branch_height := _font.get_string_size("子", HORIZONTAL_ALIGNMENT_LEFT, -1,
			FONT_SIZE).y
	var direction_top := GAP + branch_height + DIRECTION_GAP
	for index in DIRECTIONS.size():
		var world := direction_at(float(index) * DIRECTION_SPAN)
		if camera.is_position_behind(world):
			continue
		var on_horizon := camera.unproject_position(world)
		var text: String = DIRECTIONS[index]
		var extent := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				DIRECTION_SIZE)
		_draw_mark(Vector2(on_horizon.x - extent.x * 0.5,
				on_horizon.y + direction_top), extent, text, DIRECTION_COLOUR,
				DIRECTION_SIZE)


## One mark, its box's top-left and the size its extent was measured at given:
## dropped when the box is off the frame.
func _draw_mark(at: Vector2, extent: Vector2, text: String, colour: Color,
		font_size: int) -> void:
	var box := Rect2(at, extent)
	if not Rect2(Vector2.ZERO, size).intersects(box):
		return
	var baseline := box.position + Vector2(0.0, extent.y * 0.78)
	draw_string(_font, baseline + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, font_size, SHADOW)
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
			colour)
