## The names that ride the sphere, as a flat 2D layer over it: the eighty-eight
## constellations, the twenty-eight 宿 of the equator, and the bodies that are not
## pinned to it - the Moon and the seven planets.
##
## A Control rather than Label3D nodes: the names keep a constant size on screen
## whatever the field of view does (S3 zooms), they fade into the horizon like
## everything else, and a name that would collide with one already placed is
## dropped instead of stacking.
##
## The sky is static between time steps, so this projects once; whoever turns the
## sphere (S3's time control) calls refresh(). The planets are the exception - they
## are not pinned to the sphere, so the sky hands them over again on every step.
class_name SkyLabels
extends Control

const RADIUS := 476.0
const FONT_SIZE := 15
const GAP := 5.0        ## minimum clear space between two names
const SHADOW := Color(0.0, 0.0, 0.0, 0.6)
const FADE := 0.06      ## sine of the altitude names have faded out by

## The 宿 are a scale on the equator rather than a figure, so they are drawn in the
## warm ink the ground ring uses and sit just south of the line they divide; the
## planets carry their own name above the mark.
const MANSION_SIZE := 13
const MANSION_LIFT := -9.0
const MANSION_COLOUR := Color(0.90, 0.78, 0.54, 0.60)
## The 星官 names (2026-10-10): one per star group of the 宿 the sky draws
## (MansionFigures), in the same warm ink a shade dimmer and a size smaller than the
## 宿's own scale - a 宿 is a dozen 星官 and its name is the one that has to stay
## readable. They ride the 菜单's 星宿 switch with the ribbons they name.
const MANSION_FIGURE_SIZE := 12
const MANSION_FIGURE_LIFT := 9.0
const MANSION_FIGURE_COLOUR := Color(0.86, 0.72, 0.46, 0.62)
const PLANET_SIZE := 13
const PLANET_LIFT := 11.0
const PLANET_COLOUR := Color(0.96, 0.86, 0.60, 0.92)

## The Moon (2026-10-10): the one name on this layer that rides a disc rather than a
## point of light, and the disc is drawn MAGNIFY times its true size - so the name is
## lifted clear of the disc's own radius rather than of a constant (below). Placed
## with the single marks, before the planets: it is one body, and the only one of the
## eight that a name has to stay on.
const MOON_SIZE := 14
const MOON_LIFT := 14.0
const MOON_COLOUR := Color(0.90, 0.92, 0.99, 0.95)
const MOON_NAME := "月"

## The pole star (2026-10-10): the one named star the sky carries, because it is the
## point the whole sphere is read against - 北极星 is what "north" means on a star
## chart, and the compass HUD's own reading is checked against its altitude.
##
## It is a star and not a figure, so the 菜单's 星座 switch does not touch it (the
## same reason the 宿 and the planets stay): the switch takes the eighty-eight
## constellations' names, and this one is not one of them.
const POLARIS_SIZE := 15
const POLARIS_LIFT := 11.0
const POLARIS_COLOUR := Color(0.92, 0.96, 1.00, 0.95)
const POLARIS_NAME := "北极星"

## The vernal equinox - the point λ = 0 the ecliptic's own divisions are measured
## from - in the accent the HUD chrome uses: it is the sky's own mark, not a thing
## in it, and Ecliptic draws the ring this name sits under.
const EQUINOX_SIZE := 14
const EQUINOX_LIFT := 13.0
const EQUINOX_COLOUR := Color(0.42, 0.88, 1.00, 0.95)
const EQUINOX_NAME := "春分"

## The zenith (2026-10-10): the point straight up has no star on it, and it is
## where the HUD's 天顶 button aims the view - so the sky hangs a hollow cross on
## it. A 虚十字 rather than a mark on the sphere: the arms are dashed and the
## centre is left empty, so the point itself is never painted over, and the whole
## reticle is read against the frame - this is the one mark on the layer that is
## about the observer rather than about the sky.
##
## Screen-space on purpose: a crosshair keeps its size while the sky zooms (the
## sky's own geometry is scaled by fov / BASE_FOV; a reticle that scaled would be
## a nine-pixel cross at one zoom and a wall of dashes at another).
const ZENITH_COLOUR := Color(0.42, 0.88, 1.00, 0.60)
const ZENITH_GAP := 4.0       ## the hollow centre, either side of the point
const ZENITH_DASH := 3.0      ## one dash of an arm
const ZENITH_SPACE := 2.0
const ZENITH_DASHES := 3      ## dashes per arm
const ZENITH_WIDTH := 1.0

var camera: Camera3D
var sky_root: Node3D

var _font: Font
var _anchors := {}     ## abbreviation -> unit direction on the sphere
var _rank := {}        ## abbreviation -> how prominent it is, for the draw order
var _planets: Array = []    ## [{name, direction}], the seven, restated every step
## The Moon's own direction and the world radius its disc was drawn at, restated
## every step with the planets - it is not pinned to the sphere either.
var _moon: Variant = null
var _moon_radius := 0.0
var _mansions: Array = []   ## [{name, direction}], the twenty-eight, fixed
## The 星官 names of the 宿 the sky draws (MansionFigures), [{name, direction}] each,
## and whether they are drawn: the 菜单's 星宿 switch, which the sky hands over with
## the ribbons themselves.
var _mansion_figures: Array = []
var _mansion_figures_shown := true
## The pole star's own direction on the sphere (α UMi out of the catalogue), or
## null when it is not in the catalogue: a name is not drawn for a star that is
## not there.
var _polaris: Variant = null
## The vernal equinox's direction, handed over by the sky with the ecliptic it is
## measured from - Ecliptic draws the ring, this draws the name under it.
var _equinox: Variant = null
## Whether the 88 constellation names are drawn: the 菜单's 星座 switch, which is
## about the constellations alone. The 宿 and the planets stay - they are not
## figures, and a switch that took them off with the figures would be lying about
## its own name (2026-10-09: the layer grew past the one switch).
var _figures_shown := true


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
	# the pole star, out of the same catalogue every other star comes from
	var polaris := catalogue.find("α", "UMi")
	if polaris < 0:
		push_warning("XuanDesk: sky: 北极星 (α UMi) not in the catalogue, name dropped")
	else:
		_polaris = StarCat.direction(catalogue.ra[polaris], catalogue.dec[polaris])
	# a Control under a CanvasLayer gets no layout from a Control parent, so it
	# takes the viewport's size and follows it
	_follow_viewport()
	get_viewport().size_changed.connect(_follow_viewport)
	refresh()


## The planets, in the order the sky keeps them: {name, direction} each, the
## direction a unit vector in the catalogue frame. Called on every time step - these
## are the one thing on this layer that moves.
func set_planets(entries: Array) -> void:
	_planets = entries
	refresh()


## The Moon, handed over on every time step the way the planets are: where it
## stands, and the world radius the sky drew its disc at (SkyMoon.disc_radius), so
## the name can be lifted clear of the disc itself.
func set_moon(direction: Vector3, radius: float) -> void:
	_moon = direction
	_moon_radius = radius
	refresh()


## The twenty-eight 宿, handed over once with their layer: their names stand at the
## middle of their own span on the equator.
func set_mansions(entries: Array) -> void:
	_mansions = entries
	refresh()


## The 星官 of the 宿 the sky draws, handed over once with their layer: one entry per
## star group, its name at the middle of the stars it is drawn by.
func set_mansion_figures(entries: Array) -> void:
	_mansion_figures = entries
	refresh()


## The 菜单's 星宿 switch, handed over by the sky with the figure layer itself: the 宿's
## ribbons and their 星官 names go together (and the 宿's own scale, the 88's names and
## the planets stay - the same rule the 星座 switch follows).
func set_mansion_figures_shown(on: bool) -> void:
	_mansion_figures_shown = on
	refresh()


## The vernal equinox, handed over with the ecliptic: the point λ = 0, in the
## catalogue frame at the sky's own instant, exactly the point Ecliptic's ring is
## drawn round.
func set_equinox(direction: Vector3) -> void:
	_equinox = direction
	refresh()


## The 菜单's 星座 switch, handed over by the sky with the figure layer itself: the
## figure ribbons and their 88 names go together, and nothing else does.
func set_figures(on: bool) -> void:
	_figures_shown = on
	refresh()


func _follow_viewport() -> void:
	size = get_viewport_rect().size
	refresh()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if camera == null or not is_instance_valid(camera) or _font == null:
		return
	var basis := sky_root.global_transform.basis
	var placed: Array[Rect2] = []
	# The two single named marks first - the equinox and the pole star are one
	# point each, and a name that yields is gone for good, while a planet's or a
	# constellation's simply moves a few pixels (2026-10-10: 海王星 stands within a
	# degree of the vernal equinox this decade, and took the row off 春分点). The
	# Moon joins them: it is one body with a disc under its name, and the disc is
	# what makes it the thing to look at. Then the seven planets and the 宿, then
	# the plentiful layer (88 names), which is the one that makes way.
	if _equinox != null:
		_place({"name": EQUINOX_NAME, "direction": _equinox}, placed, basis,
				EQUINOX_SIZE, EQUINOX_COLOUR, EQUINOX_LIFT)
	if _polaris != null:
		_place({"name": POLARIS_NAME, "direction": _polaris}, placed, basis,
				POLARIS_SIZE, POLARIS_COLOUR, POLARIS_LIFT)
	if _moon != null:
		_place({"name": MOON_NAME, "direction": _moon}, placed, basis, MOON_SIZE,
				MOON_COLOUR, _moon_lift())
	for entry in _planets:
		_place(entry, placed, basis, PLANET_SIZE, PLANET_COLOUR, PLANET_LIFT)
	for entry in _mansions:
		_place(entry, placed, basis, MANSION_SIZE, MANSION_COLOUR, MANSION_LIFT)
	# the 星官 names come after the 宿's own scale (a 宿's name is what has to stay
	# readable) and before the 88, which are the most plentiful layer here and the one
	# that makes way for both
	for entry in _mansion_figures if _mansion_figures_shown else []:
		_place(entry, placed, basis, MANSION_FIGURE_SIZE, MANSION_FIGURE_COLOUR,
				MANSION_FIGURE_LIFT)

	var order := _anchors.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return _rank[a] > _rank[b])
	for abbrev in order if _figures_shown else []:
		_place({"name": Constellations.chinese(abbrev), "direction": _anchors[abbrev]},
				placed, basis, FONT_SIZE, Color(0.62, 0.74, 0.92, 0.85), 0.0)
	_draw_zenith()


## How far above the Moon's point its name stands: the sky's own lift plus the disc
## it has to clear, in pixels. The disc is drawn MAGNIFY times its true size
## (SkyMoon) and grows with the field of view, so a constant lift would put the name
## on the Moon's face as soon as the sky is zoomed in.
##
## The disc's world radius is at SkyMoon.RADIUS while this layer measures at the
## star sphere's - a 4 per cent difference in the scale, which is nothing against a
## gap that is about clearing the disc at all.
func _moon_lift() -> float:
	if camera == null or not is_instance_valid(camera):
		return MOON_LIFT
	var half := camera.fov * 0.5
	if half <= 0.0 or half >= 89.0:
		return MOON_LIFT
	var per_unit := size.y * 0.5 / (RADIUS * tan(deg_to_rad(half)))
	return MOON_LIFT + _moon_radius * per_unit


## The hollow cross on the observer's own zenith. The zenith is the pole of the
## *world* frame rather than a direction in the catalogue one, so it is projected
## without SkyRoot's own turn - straight up stays straight up however the sky is
## turned under it.
func _draw_zenith() -> void:
	var world := Vector3.UP * RADIUS
	if camera.is_position_behind(world):
		return
	var at := camera.unproject_position(world)
	var reach := ZENITH_GAP + float(ZENITH_DASHES) * (ZENITH_DASH + ZENITH_SPACE)
	var corner := Vector2(reach, reach)
	if not Rect2(Vector2.ZERO, size).intersects(Rect2(at - corner, corner * 2.0)):
		return
	for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
		for arm in 2:
			var way: Vector2 = axis if arm == 0 else -axis
			for dash in ZENITH_DASHES:
				var from := ZENITH_GAP + float(dash) * (ZENITH_DASH + ZENITH_SPACE)
				draw_line(at + way * from, at + way * (from + ZENITH_DASH),
						ZENITH_COLOUR, ZENITH_WIDTH, false)


## One name, dropped when its point is below the horizon, behind the camera, off the
## frame, or closer to a name already placed than GAP. `lift` raises the box above
## the point - a planet's name sits over the mark itself, a 宿's name under the
## equator it divides.
func _place(entry: Dictionary, placed: Array[Rect2], basis: Basis, font_size: int,
		colour: Color, lift: float) -> void:
	var direction: Vector3 = entry["direction"]
	# the horizon moves with the sphere, so test in world space
	var altitude := (basis * direction).y
	if altitude <= 0.0:
		return
	var world := sky_root.global_transform * (direction * RADIUS)
	if camera.is_position_behind(world):
		return
	var at := camera.unproject_position(world)
	var text := String(entry["name"])
	var extent := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var box := Rect2(at.x - extent.x * 0.5, at.y - extent.y * 0.5 - lift, extent.x,
			extent.y)
	if not Rect2(Vector2.ZERO, size).intersects(box):
		return
	for other in placed:
		if other.grow(GAP).intersects(box):
			return
	placed.append(box)

	var alpha := clampf(altitude / FADE, 0.0, 1.0)
	var baseline := box.position + Vector2(0.0, extent.y * 0.78)
	draw_string(_font, baseline + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, font_size, Color(SHADOW, SHADOW.a * alpha))
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
			Color(colour, colour.a * alpha))
