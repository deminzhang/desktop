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

## The 宿 are a scale on the equator rather than a figure: each one's name stands at the
## middle of its own 分野 - the span its 距星 opens - just south of the line that divides
## it (2026-10-14, 用户: "天赤道线上淡色标下星宿分野…仅星宿开关开时显宿名"). The ink is
## the **pale gold** that band is drawn in (sky.gd's equator is 淡赤 and its 分野 ticks
## 淡金), lighter and fainter than the 星官 names at the star groups: a name on the
## equator reads as the division's, a name at the stars as the group's.
const MANSION_SIZE := 13
const MANSION_LIFT := -9.0
const MANSION_COLOUR := Color(0.95, 0.87, 0.60, 0.52)
## The 星官 names: one per star group of the 宿 the sky draws (MansionFigures), written
## at the stars themselves in **gold** (2026-10-14, 用户: "星宿本体星组处用金色显名") - the
## same gold the dial writes 值符 by (SkyCompassHud.C_DUTY), so 金 means one thing on the
## card and on the sky. A size smaller than the 宿's own name: a 宿 is a dozen 星官 and
## the division's name is the one that has to stay readable. They ride the card's 星宿
## switch with the ribbons they name.
const MANSION_FIGURE_SIZE := 12
const MANSION_FIGURE_LIFT := 9.0
const MANSION_FIGURE_COLOUR := Color(1.00, 0.84, 0.45, 0.85)
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
## It is a star and not a figure, so the card's 星座 switch does not touch it (the
## same reason the 宿 and the planets stay): the switch takes the eighty-eight
## constellations' names, and this one is not one of them.
const POLARIS_SIZE := 15
const POLARIS_LIFT := 11.0
const POLARIS_COLOUR := Color(0.92, 0.96, 1.00, 0.95)
const POLARIS_NAME := "北极星"

## 北斗 (2026-10-12 第二十一轮: "北斗星名加一下"): the Dipper is the one shape on the sky
## whose stars carry names of their own, and they are read by the card's 星宿 switch,
## which picks between two sets of them (2026-10-14 用户: "北斗星在星宿开关开时显贪狼武曲这套
## 神名.关时显天枢天玑这套名").
##
## While that switch is off each of the eight wears the name the sky's own tradition
## gives it - 天枢 α, 天璇 β, 天玑 γ, 天权 δ, 玉衡 ε, 开阳 ζ, 摇光 η and 左辅 (Alcor, 80 UMa,
## the small star on 开阳's shoulder) - the names a naked-eye reader navigates by, the
## 斗's two bowl stars being what points at the pole star. While it is on, the same
## eight wear the 神名 of the 九星, star by star: 贪狼, 巨门, 禄存, 文曲, 廉贞, 武曲, 破军
## and 洞明 - 八白左辅's own 神名, whose 星名 is the 左辅 the other set calls it, so that
## is the one star whose two names are not both in daily use.
##
## One name per star, so the Dipper is read star by star and no longer carries a 北斗
## of its own: the single name that used to stand at the seven's centre of figure was
## what the 星宿 switch gave way to, and now the eight stars speak for themselves in
## both of its states.
##
## Each entry carries the catalogue's own designation - a Bayer letter, or the
## Flamsteed number for 左辅, which has no letter - and both names. 天枢 α, 天璇 β,
## 天玑 γ and 天权 δ draw the 斗's bowl, 玉衡 ε, 开阳 ζ and 摇光 η its handle, and 左辅 is
## the eighth of the 九星.
##
## The ninth is 右弼, which the tradition itself calls the *unseen* one - there is no
## star where it belongs, and this layer names stars, so eight are drawn. (The rule is
## the sky's own: a name is not drawn for a star that is not there, which is why the
## pole star's name is dropped rather than guessed when α UMi is missing.)
## 左辅's own lift (the `lift` field in its DIPPER_STARS entry): Alcor stands 12 arcmin
## from 开阳 - 1.4 px at the opening field - so a name hung over both stars is a name
## drawn twice on the same spot, and the layer drops the second. Hanging the eighth
## *below* its star puts its box clear of 开阳's instead, which is what the tradition
## itself does with it (左辅 is read as 开阳's attendant, not as a star of its own).
const DIPPER_ATTENDANT_LIFT := -14.0
const DIPPER_STARS := [
	{"letter": "α", "number": 0, "name": "天枢", "god": "贪狼"},
	{"letter": "β", "number": 0, "name": "天璇", "god": "巨门"},
	{"letter": "γ", "number": 0, "name": "天玑", "god": "禄存"},
	{"letter": "δ", "number": 0, "name": "天权", "god": "文曲"},
	{"letter": "ε", "number": 0, "name": "玉衡", "god": "廉贞"},
	{"letter": "ζ", "number": 0, "name": "开阳", "god": "武曲"},
	{"letter": "η", "number": 0, "name": "摇光", "god": "破军"},
	{"letter": "", "number": 80, "name": "左辅", "god": "洞明", "lift": DIPPER_ATTENDANT_LIFT},
]
const DIPPER_ABBREV := "UMa"
## One named star of the 斗: a step smaller than the pole star's own name, in the ink
## 北极星 is written in - so the eight read as stars where the 宿, 星官 and 节气 names
## beside them read as the divisions they are.
const DIPPER_STAR_SIZE := 12
const DIPPER_STAR_LIFT := 9.0
const DIPPER_STAR_COLOUR := Color(0.86, 0.92, 1.00, 0.82)

## The twenty-four solar terms of the ecliptic, in the accent the HUD chrome uses: they
## are the sky's own marks, not things in it, and Ecliptic hands over the points the λ
## it measures is read from. All twenty-four are named here, and the layer keeps the
## HUD's cyan rather than the amber the 宿 and 星官 names are written in, so the two
## scales - the ecliptic's 15° steps and the equator's unequal 宿 - stay apart at a
## glance (2026-10-14 用户: "二十四节气都显出").
##
## They ride the card's 星宿 switch beside the 宿's own names (see set_mansions_shown):
## both are divisions λ and the 宿度 are read against, and the ticks they name are
## drawn on the sphere either way.
const TERM_SIZE := 14
const TERM_LIFT := 13.0
const TERM_COLOUR := Color(0.42, 0.88, 1.00, 0.95)

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
##
## Faint white (用户 2026-10-14: "标个淡白色虚十字"): every other mark on this layer
## belongs to something in the sky and is written in that thing's own ink - gold at the
## 星官, pale gold on the equator, the cyan of the card's chrome for the 节气 - and this
## one is the observer's own vertical, so it is neither warm nor cyan. 0.45 of white over
## the night dome is a mark the eye finds when it looks for it and never reads as a star.
##
## The opening view puts the zenith's own point on the frame's top edge, so what shows at
## the default framing is the lower half of this cross (CameraRig::OPENING_ALTITUDE/FOV).
const ZENITH_COLOUR := Color(1.00, 1.00, 1.00, 0.45)
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
## The twenty-eight 宿's own names, [{name, direction}], fixed to the sphere like the
## 宿 themselves - and whether they are drawn, which is the card's 星宿 switch (用户
## 2026-10-12 第二十一轮: 28宿名只在星宿开着时显).
var _mansions: Array = []
## The 星官 names of the 宿 the sky draws (MansionFigures), [{name, direction}] each,
## drawn on that same 星宿 switch, which the sky hands over with the ribbons
## themselves.
var _mansion_figures: Array = []
var _mansions_shown := true
## The pole star's own direction on the sphere (α UMi out of the catalogue), or
## null when it is not in the catalogue: a name is not drawn for a star that is
## not there.
var _polaris: Variant = null
## The 斗's stars as names, one entry per star the catalogue holds:
## {name, god, direction} - the 星名 and the 神名 of the same star, which of the two is
## drawn being the card's 星宿 switch (see DIPPER_STARS).
var _dipper_names: Array = []
## The ecliptic's twenty-four solar terms, handed over by the sky with the ecliptic
## they are measured on - Ecliptic draws the ticks, this draws the names.
var _terms: Array = []
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
	_dipper_names = _dipper_star_names(catalogue)
	# a Control under a CanvasLayer gets no layout from a Control parent, so it
	# takes the viewport's size and follows it
	_follow_viewport()
	get_viewport().size_changed.connect(_follow_viewport)
	refresh()


## The 斗's own stars, each with both of its Chinese names: one entry per star the
## catalogue holds, {name, god, direction} - the layer this is drawn on is the card's
## 星宿 switch, which picks the name out of the two (see DIPPER_STARS). A star the
## catalogue is missing is dropped from its own list and reported: the nine are the
## *names* of eight stars that are there, and inventing a place for the one that has
## none is not this sky's business.
static func _dipper_star_names(catalogue: StarCat) -> Array:
	var out := []
	var missing := []
	for entry: Dictionary in DIPPER_STARS:
		var index := _dipper_index(catalogue, entry)
		if index < 0:
			missing.append(String(entry["name"]))
			continue
		var named := {"name": String(entry["name"]), "god": String(entry["god"]),
				"direction": StarCat.direction(catalogue.ra[index], catalogue.dec[index])}
		# a star whose name cannot hang over it (左辅, on 开阳's shoulder) carries the
		# lift its own entry asks for; the rest take the layer's own
		if entry.has("lift"):
			named["lift"] = float(entry["lift"])
		out.append(named)
	if not missing.is_empty():
		push_warning("XuanDesk: sky: 北斗 %s not in the catalogue, their names dropped"
				% "/".join(missing))
	return out


## The catalogue's row for one DIPPER_STARS entry: by Bayer letter, or by Flamsteed
## number where the star has no letter (左辅/Alcor is 80 UMa).
static func _dipper_index(catalogue: StarCat, entry: Dictionary) -> int:
	var letter := String(entry["letter"])
	if letter != "":
		return catalogue.find(letter, DIPPER_ABBREV)
	return catalogue.find_flamsteed(int(entry["number"]), DIPPER_ABBREV)


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


## The twenty-eight 宿, handed over once with their layer: their names stand on the
## 宿's own 星官 where the sky can place one, and at the middle of its span otherwise.
func set_mansions(entries: Array) -> void:
	_mansions = entries
	refresh()


## The 星官 of the 宿 the sky draws, handed over once with their layer: one entry per
## star group, its name at the middle of the stars it is drawn by.
func set_mansion_figures(entries: Array) -> void:
	_mansion_figures = entries
	refresh()


## The card's 星宿 switch, handed over by the sky with the figure layer itself: the
## 宿's own names, their ribbons and their 星官 names go together (用户 2026-10-12
## 第二十一轮: 28宿名只在星宿开着时显), the 廿四节气 names with them (2026-10-14 用户:
## "二十四节气…仅星宿开关开时显"), and the 斗's stars change which of their two names
## they wear (see DIPPER_STARS). The 宿's *scale* - the equator, the 距星 ticks and the
## ecliptic's own ticks - stays on the sky alone, the same way the 星座 switch leaves
## the 宿 and the planets (SkyLabels.set_figures).
func set_mansions_shown(on: bool) -> void:
	_mansions_shown = on
	refresh()


## The ecliptic's twenty-four solar terms (Ecliptic.term_points), handed over with the
## ecliptic itself, in the catalogue frame at the sky's own instant: the names of the
## divisions whose ticks Ecliptic draws.
func set_terms(entries: Array) -> void:
	_terms = entries
	refresh()


## The card's 星座 switch, handed over by the sky with the figure layer itself: the
## figure ribbons and their 88 names go together, and nothing else does - not the 宿
## or their names, not the planets, not the two named stars.
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
	# The single named marks first - the pole star, the Moon and each of the 斗's stars
	# are one point each, and a name that yields is gone for good, while a planet's or a
	# constellation's simply moves a few pixels. The Moon joins them: it is one body
	# with a disc under its name, and the disc is what makes it the thing to look at.
	# Then the seven planets and the 星宿 switch's own divisions (the 宿, the 廿四节气 and
	# the 星官 inside the 宿 - they sit under the planets because a planet stands on the
	# ecliptic itself, where a 节气 name would otherwise take the row off 火星 every
	# time), then the plentiful layer (88 names), which is the one that makes way.
	if _polaris != null:
		_place({"name": POLARIS_NAME, "direction": _polaris}, placed, basis,
				POLARIS_SIZE, POLARIS_COLOUR, POLARIS_LIFT)
	# 北斗九星 (see DIPPER_STARS): one name per star, and the card's 星宿 switch picks
	# which of the two sets it is - the 星名 while it is off, the 神名 while it is on.
	for entry: Dictionary in _dipper_names:
		_place({"name": entry["god"] if _mansions_shown else entry["name"],
				"direction": entry["direction"]}, placed, basis, DIPPER_STAR_SIZE,
				DIPPER_STAR_COLOUR, float(entry.get("lift", DIPPER_STAR_LIFT)))
	if _moon != null:
		_place({"name": MOON_NAME, "direction": _moon}, placed, basis, MOON_SIZE,
				MOON_COLOUR, _moon_lift())
	for entry in _planets:
		_place(entry, placed, basis, PLANET_SIZE, PLANET_COLOUR, PLANET_LIFT)
	# the 宿, their 星官 and the 廿四节气 are the card's 星宿 switch between them: the
	# names of the divisions and the names of the star groups inside them are the same
	# layer of reading, and the switch that takes the ribbons takes them. The 宿's name
	# comes first (it is what has to stay readable), the ecliptic's terms next, the 星官
	# names of the 宿 after both
	for entry in _mansions if _mansions_shown else []:
		_place(entry, placed, basis, MANSION_SIZE, MANSION_COLOUR, MANSION_LIFT)
	for entry in _terms if _mansions_shown else []:
		_place(entry, placed, basis, TERM_SIZE, TERM_COLOUR, TERM_LIFT)
	# the 星官 names come after the 宿's own scale (a 宿's name is what has to stay
	# readable) and before the 88, which are the most plentiful layer here and the one
	# that makes way for both
	for entry in _mansion_figures if _mansions_shown else []:
		_place(entry, placed, basis, MANSION_FIGURE_SIZE, MANSION_FIGURE_COLOUR,
				MANSION_FIGURE_LIFT)

	var order := _anchors.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return _rank[a] > _rank[b])
	for abbrev in order if _figures_shown else []:
		_place({"name": Constellations.chinese(abbrev), "direction": _anchors[abbrev]},
				placed, basis, FONT_SIZE, Color(0.62, 0.74, 0.92, 0.85), 0.0)
	_draw_zenith()


## How far above the Moon's point its name stands: the sky's own lift plus the disc
## it has to clear, in pixels. The disc is drawn MAGNIFY times its true size (SkyMoon)
## and so it grows on screen as the sky is zoomed in - a constant lift would put the
## name on the Moon's face at the first notch of the wheel.
##
## The disc's world radius is at SkyMoon.RADIUS while this layer measures at the star
## sphere's - a 4 per cent difference in the scale, which is nothing against a gap
## that is about clearing the disc at all.
func _moon_lift() -> float:
	if camera == null or not is_instance_valid(camera):
		return MOON_LIFT
	return MOON_LIFT + _moon_radius * SkyProjection.pixels_per_unit(camera, size, RADIUS)


## The hollow cross on the observer's own zenith. The zenith is the pole of the
## *world* frame rather than a direction in the catalogue one, so it is projected
## without SkyRoot's own turn - straight up stays straight up however the sky is
## turned under it.
func _draw_zenith() -> void:
	var at := SkyProjection.screen_point(camera, Vector3.UP * RADIUS, size)
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
	var at := SkyProjection.screen_point(camera, world, size)
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
