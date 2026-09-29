## The Chinese constellation names, as a flat 2D layer over the sphere.
##
## A Control rather than Label3D nodes: the names keep a constant size on screen
## whatever the field of view does (S3 zooms), they fade into the horizon like
## everything else, and a name that would collide with one already placed is
## dropped instead of stacking.
##
## The sky is static between time steps, so this projects once; whoever turns the
## sphere (S3's time control) calls refresh().
class_name SkyLabels
extends Control

const RADIUS := 476.0
const FONT_SIZE := 15
const GAP := 5.0        ## minimum clear space between two names
const SHADOW := Color(0.0, 0.0, 0.0, 0.6)
const FADE := 0.06      ## sine of the altitude names have faded out by

var camera: Camera3D
var sky_root: Node3D

var _font: Font
var _anchors := {}     ## abbreviation -> unit direction on the sphere
var _rank := {}        ## abbreviation -> how prominent it is, for the draw order


func setup(catalogue: StarCat, camera_3d: Camera3D, root: Node3D) -> void:
	camera = camera_3d
	sky_root = root
	_font = Fonts.ui_font()
	_anchors = SkyLines.figure_anchors(catalogue)
	for abbrev in _anchors:
		var weight := 0.0
		for seg in Constellations.figure(catalogue, abbrev):
			weight += (7.0 - catalogue.mag[seg.x]) + (7.0 - catalogue.mag[seg.y])
		_rank[abbrev] = weight
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# a Control under a CanvasLayer gets no layout from a Control parent, so it
	# takes the viewport's size and follows it
	_follow_viewport()
	get_viewport().size_changed.connect(_follow_viewport)
	refresh()


func _follow_viewport() -> void:
	size = get_viewport_rect().size
	refresh()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if camera == null or not is_instance_valid(camera) or _font == null:
		return
	var order := _anchors.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return _rank[a] > _rank[b])
	var placed: Array[Rect2] = []
	var basis := sky_root.global_transform.basis
	for abbrev in order:
		var dir: Vector3 = _anchors[abbrev]
		# the horizon moves with the sphere, so test in world space
		var altitude := (basis * dir).y
		if altitude <= 0.0:
			continue
		var world := sky_root.global_transform * (dir * RADIUS)
		if camera.is_position_behind(world):
			continue
		var at := camera.unproject_position(world)
		var text := Constellations.chinese(abbrev)
		var extent := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var box := Rect2(at.x - extent.x * 0.5, at.y - extent.y * 0.5, extent.x, extent.y)
		if not Rect2(Vector2.ZERO, size).intersects(box):
			continue
		var blocked := false
		for other in placed:
			if other.grow(GAP).intersects(box):
				blocked = true
				break
		if blocked:
			continue
		placed.append(box)

		var alpha := clampf(altitude / FADE, 0.0, 1.0)
		var colour := Color(0.62, 0.74, 0.92, alpha * 0.85)
		var baseline := box.position + Vector2(0.0, extent.y * 0.78)
		draw_string(_font, baseline + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT,
				-1.0, FONT_SIZE, Color(SHADOW, SHADOW.a * alpha))
		draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE,
				colour)
