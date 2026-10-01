## The "sky" background: a real star sphere with the celestial machinery on top,
## built in stages (计划 §6.5).
##
## This file is the stage door: it stands up the celestial sphere - the night-sky
## dome (real geometry: an environment-only scene never presents into the
## wallpaper window, 计划 §2.2 V3) and the `SkyRoot` node every other layer hangs
## its objects from - and it owns the three pieces that say *when* and *from
## where* the sky is seen: the Observer, the TimeCore clock and the CameraRig.
## Turning the sky to a date and a place is one assignment to SkyRoot's basis
## (Astro.sky_basis), which is why the sphere can idle between frames.
##
## S1 brought the BSC5 star field, S2 the constellations, S3 this clockwork; S4
## the Sun, the Moon and the daylight they bring - and the Moon's own orbit, the one
## line the sky draws that belongs to a body rather than to the sphere (2026-10-10);
## S5 the planets, S6 the ecliptic and the twenty-eight 宿, S7 the compass HUD - whose
## rings are a 奇门 chart and a 大六壬 chart cast for the sky's own instant
## (`_chart`), the 大六壬 one also standing over the horizon as the heaven ring of
## branches, and whose marks outside them are the bodies, the Sun, the Moon and the
## seven planets, on the bearings the sky has them on.
##
## Named SkyBackground because `Sky` is the engine's sky resource.
class_name SkyBackground
extends Background

## Radius of the celestial sphere the stars are pinned to.
const SPHERE_RADIUS := 500.0

## Height of the compass half of the HUD; the time bar takes the rest of
## hud_size() below it. The card owns everything up to here and all four of its
## corners: 左转/右转 at the top (12..36) and the time bar's 时辰−/时辰+ at the bottom
## (268..292, the corners 左转/右转 used before 2026-10-10 第十八轮), plus the four
## direction triangles on its axes - the bottom one reaches 300. Every chip lives
## inside this rectangle, so what is left below it is the bar's two readout lines
## and nothing else.
const HUD_COMPASS_HEIGHT := 300.0

## J2000 directions of the galactic frame, for the Milky Way band on the dome.
const GALACTIC_POLE := Vector2(192.85948, 27.12825)    ## RA°, Dec°
const GALACTIC_CENTRE := Vector2(266.40499, -28.93617)

## The celestial equator and the 二十八宿's divisions along it (S6). The circle is
## the dimmest thing the sphere carries - it is the scale the 宿 are measured on,
## not a thing in the sky like the ecliptic - and the ticks are half a degree either
## side of it, the reach the solar terms have across the ecliptic.
const EQUATOR_WIDTH := 0.26
const EQUATOR_COLOUR := Color(0.030, 0.044, 0.076)
const MANSION_TICK := 1.4
const MANSION_TICK_WIDTH := 0.34
const MANSION_COLOUR := Color(0.098, 0.068, 0.026)
## The 宿's own star groups (MansionFigures): drawn in the amber the 宿's scale is
## drawn in rather than the blue of the 88 IAU figures, so the Chinese sky reads as
## one layer - its divisions and the figures that stand in them. Brighter than the
## scale is, because a figure is the thing being read and the scale is what it is
## read against: at the figures' own brightness the amber came out a washed grey
## against the blue of the night (measured on the 2026-10-10 shot).
const MANSION_FIGURE_WIDTH := 0.40
const MANSION_FIGURE_COLOUR := Color(0.20, 0.10, 0.028)

var sky_root: Node3D
var camera: Camera3D
var star_count := 0

## Where and when the sky is seen from; the clock drives SkyRoot's basis.
var observer: Observer
var clock: TimeCore
var rig: CameraRig

## The things in the sky that are not fixed to the sphere: they are placed again on
## every time step. The Sun's direction is what lights the Moon.
var sun: SkySun
var moon: SkyMoon
## The seven planets and their trails (S5).
var planets: SkyPlanets

var _catalogue: StarCat
var _labels: SkyLabels
var _branches: SkyBranches
var _compass: SkyCompassHud
var _time_bar: SkyTimeBar
## The twenty-eight 宿 (S6) and the two layers they are drawn as: the equator and
## the tick at each 距星's right ascension. Null until the catalogue is read.
var _mansions: Mansions
var _equator: MeshInstance3D
var _mansion_ticks: MeshInstance3D
## The 宿's own star groups (MansionFigures) and whether they are drawn: the 菜单's
## 星宿 switch, the counterpart of the 星座 one.
var _mansion_figures: MeshInstance3D
var _mansion_figures_shown := true
var _pan: Dictionary = {}      ## the 奇门 chart of the drawn instant (S7)
var _liuren: Dictionary = {}   ## the 大六壬 chart of the drawn instant
var _chart_key := ""
## The 农历 line, and the local day it was worked out for: the calendar is derived
## from the Sun and Moon, so it is cached rather than recomputed per time step.
var _lunar_day := 0
var _lunar := ""
var _dome: MeshInstance3D
var _stars: MeshInstance3D
var _figures: MeshInstance3D
var _boundaries: MeshInstance3D
## The ecliptic and its solar-term ticks (S6), which share the lighting and zoom
## treatment of the figure/boundary layers.
var _ecliptic: Array = []
## Whether the constellation figures and their Chinese names are drawn: the 菜单's
## 星座 switch (`menu_switches`). On to begin with - the figures are what makes the
## constellations readable.
var _figures_shown := true


# -------------------------------------------------------- background interface

func id() -> String:
	return "sky"


func display_name() -> String:
	return "星空"


func build(_host: Node) -> void:
	_build_environment()
	sky_root = Node3D.new()
	sky_root.name = "SkyRoot"
	add_child(sky_root)
	_build_dome()
	_build_camera()
	_build_catalogue()
	_build_bodies()
	_build_labels()
	_build_clock()
	_build_ecliptic()
	_build_mansions()
	_build_mansion_figures()


func build_hud() -> Control:
	# The compass dial (S7's 卦/干/支 layers) and the time bar. The dial reads the
	# background's own rig and the bar its clock, so both show the
	# same sky the wallpaper does.
	var hud := Control.new()
	hud.name = "SkyHud"
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.size = Vector2(hud_size())

	var compass := SkyCompassHud.new()
	compass.name = "Compass"
	compass.position = Vector2.ZERO
	compass.size = Vector2(float(hud_size().x), HUD_COMPASS_HEIGHT)
	hud.add_child(compass)
	compass.setup(rig, clock, observer)
	_compass = compass

	var bar := SkyTimeBar.new()
	bar.name = "TimeBar"
	bar.position = Vector2(0.0, HUD_COMPASS_HEIGHT)
	bar.size = Vector2(float(hud_size().x), float(hud_size().y) - HUD_COMPASS_HEIGHT)
	hud.add_child(bar)
	bar.setup(clock)
	_time_bar = bar
	# the chart was cast and the bodies placed before the HUD existed: hand both
	# over now
	_bodies()
	_chart()
	return hud


func hud_size() -> Vector2i:
	# as wide as the card is: the disc is 276 px (2 x R_DISC) and 12 px is left
	# either side of it for the direction marks and the view arc, so the card's own
	# square is 300 x 300. Everything that can be pressed stands inside that square -
	# 左转/右转 up at its top corners, 时辰± down at its bottom ones, 现在 at the end of
	# the clock line - so the only strip left under it is the bar's two readout lines:
	# 40 px (2026-10-10 第十八轮, 由 364 收掉那一行按钮).
	return Vector2i(300, 340)


## The switches the sky offers the 菜单 (`Background.menu_switches`): the 88
## constellation figures with their Chinese names, and the 宿's own star groups
## (MansionFigures) - the two layers the sky can do without, and the pair the two
## names of the sky's line work are turned off by. The stars, the branch rings and the
## compass card are not touched by either.
func menu_switches() -> Array:
	return [{"id": "figures", "label": "星座", "on": _figures_shown},
			{"id": "mansions", "label": "星宿", "on": _mansion_figures_shown}]


func set_menu_switch(id: String, on: bool) -> void:
	match id:
		"figures":
			_figures_shown = on
			if _figures != null:
				_figures.visible = on
			# the 星座 switch takes the figures and their 88 names, and leaves the 宿's
			# scale and the planets' names on the sky (SkyLabels.set_figures)
			if _labels != null:
				_labels.set_figures(on)
		"mansions":
			_mansion_figures_shown = on
			if _mansion_figures != null:
				_mansion_figures.visible = on
			# the 星宿 switch takes the 宿's ribbons and their 星官 names, and leaves the
			# 宿's scale on the sky (the same split as 星座)
			if _labels != null:
				_labels.set_mansion_figures_shown(on)
		_:
			return
	# the wallpaper idles between time steps, so a change of its own has to ask
	# for the frame that shows it (Policy.ON_DEMAND)
	request_redraw()


func render_policy() -> int:
	# Nothing on the sphere moves between time updates: the wallpaper draws when
	# the clock ticks (_apply_time) or the camera rig moves, and idles in
	# between (计划 §7). With the clock at rate 1 that is one frame per second,
	# for a sky that turns 0.0002 deg in it.
	return Policy.ON_DEMAND


func vignette_shader() -> Shader:
	return null


# --------------------------------------------------------------------- scene

func _build_environment() -> void:
	# The night sky itself is the dome mesh below; this is the colour behind it,
	# tonemapped the way the stars are so the whole frame sits in one grade.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.06)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	# the bright stars need to bloom a little; additive star quads push them
	# over the threshold while the sky gradient stays under it
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = env
	add_child(world)


## The celestial sphere's inner surface: a gradient dome sized so it always
## fills the frame, with the horizon at its equator.
func _build_dome() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = SPHERE_RADIUS
	mesh.height = SPHERE_RADIUS * 2.0
	mesh.radial_segments = 64
	mesh.rings = 32

	var dome := MeshInstance3D.new()
	dome.name = "Dome"
	dome.mesh = mesh
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = load("res://backgrounds/sky/shaders/dome.gdshader")
	material.set_shader_parameter("galactic_pole",
			StarCat.direction(GALACTIC_POLE.x, GALACTIC_POLE.y))
	material.set_shader_parameter("galactic_centre",
			StarCat.direction(GALACTIC_CENTRE.x, GALACTIC_CENTRE.y))
	dome.material_override = material
	sky_root.add_child(dome)
	_dome = dome


## The things the sphere does not carry: the Sun, the Moon and the seven planets.
## They are placed again on each time step, drawn through the same horizon as
## everything else, and the Sun's direction is what the Moon's phase is lit by.
func _build_bodies() -> void:
	sun = SkySun.new()
	sun.name = "Sun"
	sky_root.add_child(sun)
	moon = SkyMoon.new()
	moon.name = "Moon"
	sky_root.add_child(moon)
	planets = SkyPlanets.new()
	planets.name = "Planets"
	sky_root.add_child(planets)


## Everything that comes out of the star catalogue: the stars themselves, the
## constellation figures, and - only when asked for - the IAU boundaries.
func _build_catalogue() -> void:
	_catalogue = StarCat.load_default()
	if _catalogue == null:
		return
	star_count = _catalogue.count()
	_stars = StarField.build(sky_root, _catalogue)
	var boundaries := opts != null and opts.flag("sky_boundaries", false)
	var lines := SkyLines.build(sky_root, _catalogue, boundaries)
	_figures = lines[0]
	_boundaries = lines[1]
	# the 88 figures can be left off from the command line as well as from the 菜单.
	# The 宿's own figures are drawn either way, so a shot that has to show them wants
	# the blue out of the way (the same reason --sky-boundaries exists).
	_figures_shown = opts == null or opts.flag("sky_figures", true)
	_figures.visible = _figures_shown
	print("XuanDesk: sky: %d stars, %d figure segments, %d boundary segments"
			% [star_count, _ribs(_figures), 0 if _boundaries == null \
					else _ribs(_boundaries)])


## How many ribbon quads a layer's mesh holds, one per segment.
static func _ribs(layer: MeshInstance3D) -> int:
	return layer.mesh.surface_get_array_len(0) / 4


## The ecliptic: the Sun's own circle on the sphere, with a tick at each of the
## twenty-four solar terms and a ring round the vernal equinox (计划 §6.5 S6,
## 2026-10-10). Static geometry in the catalogue frame like everything else the
## sphere carries, but its divisions are λ measured from the equinox of the sky's
## own instant, so it is built once the clock has been set - and it is the same
## Ecliptic data the HUD's own readings of λ are taken from, so the drawn 春分 tick,
## the ringed 春分点 and the HUD's 春分 are the same point.
func _build_ecliptic() -> void:
	var jd := clock.julian_day()
	_ecliptic = Ecliptic.build(sky_root, jd)
	if _labels != null:
		_labels.set_equinox(Ecliptic.vernal_equinox(jd))


## The twenty-eight 宿 (S6): the equatorial divisions, drawn on the equator they are
## measured along - a thin circle, a tick at each 距星's right ascension where one 宿
## hands over to the next, and the 宿's name at the middle of its own span. Static
## geometry in the catalogue frame like the ecliptic, and like the ecliptic the names
## ride the sphere (SkyLabels projects them).
##
## The 距星 themselves are catalogue stars, so a 宿 whose star is missing would put
## its tick at right ascension 0 and quietly draw a wrong sky: that case draws
## nothing instead.
func _build_mansions() -> void:
	if _catalogue == null:
		return
	_mansions = Mansions.build(_catalogue)
	if not _mansions.complete():
		push_warning("XuanDesk: sky: 二十八宿 dropped, a 距星 is not in the catalogue")
		_mansions = null
		return
	var walk := []
	for i in 361:
		walk.append(StarCat.direction(float(i), 0.0))
	_equator = SkyLines.polyline_layer(sky_root, [walk], EQUATOR_WIDTH, EQUATOR_COLOUR,
			"Equator")

	var ticks := []
	var names := []
	for index in Mansions.NAMES.size():
		var ra := _mansions.boundary_ra[index]
		ticks.append([StarCat.direction(ra, -MANSION_TICK),
				StarCat.direction(ra, MANSION_TICK)])
		names.append({"name": Mansions.NAMES[index],
				"direction": _mansions.centre_direction(index)})
	_mansion_ticks = SkyLines.polyline_layer(sky_root, ticks, MANSION_TICK_WIDTH,
			MANSION_COLOUR, "MansionTicks")
	if _labels != null:
		_labels.set_mansions(names)
	print("XuanDesk: sky: 二十八宿 %d divisions, 觜 %.2f deg, 井 %.2f deg"
			% [Mansions.NAMES.size(), _mansions.span(19), _mansions.span(21)])


## The 宿's own star groups (MansionFigures): the 星官 drawn as lines between their
## stars - 角宿's 角, 库楼, 柱 and the rest - which is the Chinese counterpart of the 88
## IAU figures and the layer that makes a 宿 the shape it is named for rather than
## just a span of right ascension. Static geometry in the catalogue frame, and on the
## same layer list as the rest, so it dims with the daylight and scales with the zoom.
##
## The figures need nothing but the catalogue, so unlike the divisions next door they
## are drawn even when a 距星 is missing. A 星官 the catalogue cannot place is reported
## by MansionFigures and left out whole.
func _build_mansion_figures() -> void:
	if _catalogue == null:
		return
	var chains := MansionFigures.chains(_catalogue)
	if chains.is_empty():
		return
	_mansion_figures = SkyLines.polyline_layer(sky_root, chains, MANSION_FIGURE_WIDTH,
			MANSION_FIGURE_COLOUR, "MansionFigures")
	# the ribbons come with their names: a 宿 is a dozen 星官, and 2 to 10 stars that
	# are not named read as loose strokes (the 88 have had their names since S2 for the
	# same reason)
	if _labels != null:
		_labels.set_mansion_figures(MansionFigures.anchors(_catalogue))
	var names := []
	var guan := 0
	var stars := 0
	for mansion: String in MansionFigures.mansions():
		names.append(mansion + "宿")
		guan += MansionFigures.guan_count(mansion)
		stars += MansionFigures.star_count(mansion)
	print("XuanDesk: sky: 星宿图 %s: %d 星官 %d 星, %d 段"
			% ["/".join(names), guan, stars, _ribs(_mansion_figures)])


## The layers that carry the night's light and the zoom's scale: the stars and
## everything drawn as ribbons on the sphere.
func _marked_layers() -> Array:
	var layers := [_stars, _figures, _boundaries, _equator, _mansion_ticks,
			_mansion_figures]
	layers.append_array(_ecliptic)
	return layers


## The names that ride the sphere, and the two branch rings that stay on the
## horizon, on their own canvas layer under the shell's colour grade and well
## under its fade. Neither ring needs a catalogue, so they are built even without
## one.
func _build_labels() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Labels"
	layer.layer = 5
	add_child(layer)

	_branches = SkyBranches.new()
	_branches.name = "BranchRings"
	layer.add_child(_branches)
	_branches.setup(camera)

	if _catalogue == null:
		return
	var labels := SkyLabels.new()
	labels.name = "SkyLabels"
	layer.add_child(labels)
	_labels = labels
	labels.setup(_catalogue, camera, sky_root)
	labels.set_figures(_figures_shown)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.1
	camera.far = SPHERE_RADIUS * 2.0
	camera.position = Vector3.ZERO
	camera.current = true
	add_child(camera)

	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	# opens facing south with the whole sky in the frame - horizon to zenith,
	# mostly sky with a sliver of ground (CameraRig.OPENING_*)
	rig.setup(camera)


# --------------------------------------------------------------- where and when

## The observer, the clock and the camera rig: S3's whole point. The catalogue is
## fixed to J2000, so a change of instant is one basis on SkyRoot.
func _build_clock() -> void:
	observer = Observer.new()
	clock = TimeCore.new()
	clock.name = "TimeCore"
	add_child(clock)
	if opts != null:
		if opts.has("sky_time"):
			clock.set_time_unix(time_from_text(opts.text("sky_time", "")))
		clock.rate = opts.num("sky_rate", clock.rate)
		if opts.has("sky_fov"):
			rig.set_fov(opts.num("sky_fov", rig.fov))
		if opts.has("sky_view"):
			var bearing := opts.text("sky_view", "").split(",", false)
			if bearing.size() == 2:
				rig.face(float(bearing[0]), float(bearing[1]))

	clock.changed.connect(_apply_time)
	rig.moved.connect(_on_view_changed)
	_apply_time()


## --sky-time takes a Unix instant or an ISO 8601 UTC string, so a shot can name
## the moment it wants.
static func time_from_text(text: String) -> float:
	if text.contains(":"):
		return float(Time.get_unix_time_from_datetime_string(text))
	return float(text)


## Turns the sphere to the clock's instant - local sidereal time on the meridian,
## the celestial pole at the observer's latitude, the equinox of date on the
## catalogue's J2000 coordinates - puts the Sun and the Moon where the ephemeris
## has them, and tells the shaders how light the sky is.
##
## The two time scales split here: the sphere's rotation and its sidereal time are
## UT, which is what the clock keeps, while the Sun and the Moon are computed for
## TT, which is what their periodic terms describe.
func _apply_time() -> void:
	var ut := clock.julian_day()
	sky_root.basis = Astro.sky_basis(ut, observer.latitude, observer.longitude)
	var jd := Astro.tt_from_ut(ut)
	sun.place(jd)
	moon.place(jd, sun.direction)
	planets.place(jd)
	_light()
	_bodies()
	_body_labels()
	_chart()
	_on_view_changed()


## Where the marks outside the chart rings stand, handed to the dial on every time
## step: the card is read as bearings, and the Sun, the Moon and the planets are the
## only things on the sky that are not pinned to it, so they are placed again rather
## than cast with the charts. Each is Vector2(altitude, azimuth) - `Astro.altaz()`'s
## own pair. The 二十八宿's openings come over the same way, for the same reason.
func _bodies() -> void:
	if _compass == null:
		return
	var basis := sky_root.basis
	_compass.set_bodies(_altaz(basis * sun.direction), _altaz(basis * moon.direction),
			_planet_marks(basis))
	_compass.set_mansions(_mansion_marks(basis))


## The planets as the dial's own marks: where each stands, its own colour, and the
## magnitude ramp the sky's own mark is read off.
func _planet_marks(basis: Basis) -> Array:
	var marks := []
	for state: SkyPlanets.PlanetState in planets.states:
		marks.append({"at": _altaz(basis * state.direction), "colour": state.colour,
				"norm": SkyPlanets.mark_norm(state.magnitude)})
	return marks


## The 宿's openings as bearings: an equatorial division is not a fixed point of the
## horizon, so which way one faces has to be worked out for the instant, the way the
## bodies are.
func _mansion_marks(basis: Basis) -> Array:
	if _mansions == null:
		return []
	var marks := []
	for index in Mansions.NAMES.size():
		marks.append({"at": _altaz(basis * _mansions.opening_direction(index))})
	return marks


## The names of the bodies that are not pinned to the sphere - the Moon and the seven
## planets - restated on every time step, for the same reason the marks are: they move.
## The Moon is handed its drawn radius too, because its name sits over a disc rather
## than over a point (SkyLabels.set_moon).
func _body_labels() -> void:
	if _labels == null:
		return
	_labels.set_moon(moon.direction, moon.disc_radius)
	var entries := []
	for state: SkyPlanets.PlanetState in planets.states:
		entries.append({"name": state.name, "direction": state.direction})
	_labels.set_planets(entries)


static func _altaz(world: Vector3) -> Vector2:
	return Vector2(Astro.altitude_of(world), Astro.azimuth_of(world))


## The 排盘 the dial and the heaven ring are drawn from: the four pillars for the
## sky's own instant, and the 奇门 and 大六壬 charts cast on them (计划 §6.5 S7).
##
## A clock and a chart live on different scales, so the charts are cast when the
## 时辰 turns rather than on every tick - and the key carries the term as well,
## because a 节 can fall inside a 时辰 and turn the 局数 with it. Called again
## after the HUD is built, which is the one moment the computed chart has nowhere
## to go yet.
func _chart() -> void:
	if observer == null or clock == null:
		return
	var pillars := GanZhi.of(clock.julian_day(), observer.local_datetime(clock.unix()))
	var key := "%s %s" % [pillars["hour"], pillars["term"]]
	if key != _chart_key:
		_chart_key = key
		_pan = QiMen.pan(pillars)
		_liuren = LiuRen.pan(pillars)
	_lunar_date()
	if _branches != null:
		_branches.set_heaven(_liuren.get("slots", []))
	var ju := int(_pan.get("ju", 0))
	if _compass != null:
		# the 驿马 is a branch, and the dial places marks by index (0 = 子); the
		# 旬空 two 支 ride along for the 神盘's 〇; the 局 is what the 八分盘's 内盘
		# half is read off
		_compass.set_chart(_pan.get("palaces", []), _liuren.get("slots", []),
				Branches.NAMES.find(String(_pan.get("horse", ""))),
				_pan.get("kong", []))
		_compass.set_ju(ju)
	# the bar reads the pillars whether or not they turned - its date line carries
	# the sky's own 农历 date, and the pillars and 局 it shows are the 时辰's own
	if _time_bar != null:
		_time_bar.set_pillars(pillars)
		_time_bar.set_lunar(_lunar)
		_time_bar.set_ju(int(_pan.get("yuan", 0)), ju)


## The 农历 date line, with the year counted 道历 (`Lunar`). It is derived from the
## Sun and the Moon rather than read off a table, which costs some 900
## `Astro.moon_state()` calls a date, so it is worked out once per *local day*
## rather than once per time step - `_chart` runs on every frame of a 时辰 glide.
func _lunar_date() -> void:
	var day := Lunar.local_day(clock.julian_day(), observer.utc_offset)
	if day == _lunar_day:
		return
	_lunar_day = day
	_lunar = String(Lunar.date(clock.julian_day(), observer.utc_offset)["text"])


## How much of the star field survives the daylight. The sky is a wallpaper, not
## an almanac: the stars stay on the sky all day (dimmed, not switched off), and
## the day palette above is kept deep enough that they still read against it.
const DAY_STAR_FLOOR := 0.65
## The Milky Way's own floor, far lower: it is a diffuse band rather than a point
## of light, so a little of it goes a long way once the sky is blue, and keeping
## it up there would paint a wall of glow instead of a band of stars.
const DAY_BAND_FLOOR := 0.10


## The day's light, handed to the shaders that paint it: how much of the day the
## sky has, how strong the glow low over the horizon is, and which way the Sun
## lies - all three read from the Sun's altitude at the observer, which is the
## one thing about this sky that is not geometry.
##
## The star layers take the night down to DAY_STAR_FLOOR rather than to nothing,
## so daylight dims them without taking the constellation off the sky.
func _light() -> void:
	var sun_world := sky_root.basis * sun.direction
	var altitude := Astro.altitude_of(sun_world)
	var day := Astro.daylight(altitude)
	var dome_material := _dome.material_override as ShaderMaterial
	dome_material.set_shader_parameter("day", day)
	dome_material.set_shader_parameter("twilight", Astro.twilight(altitude))
	dome_material.set_shader_parameter("sun_world", sun_world)
	var night := lerpf(DAY_STAR_FLOOR, 1.0, 1.0 - day)
	dome_material.set_shader_parameter("band_night",
			lerpf(DAY_BAND_FLOOR, 1.0, 1.0 - day))
	for layer in _marked_layers():
		if layer != null:
			layer.material_override.set_shader_parameter("night", night)
	if planets != null:
		planets.set_night(night)
	if moon != null:
		# the Moon's orbit is the one line on the sky that is a body's own; the disc
		# is not dimmed by daylight, the ribbon is
		moon.set_night(night)


## The sky is redrawn only when it actually changes - a new instant, or a camera
## that moved (计划 §7) - and the names are re-projected with it.
func _on_view_changed() -> void:
	if _labels != null:
		_labels.refresh()
	if _branches != null:
		_branches.refresh()
	_scale_marks()
	request_redraw()


## The stars and the figures are drawn in world units on the sphere, so a zoom
## would blow them up into blobs unless their materials are told the field in
## use: this is the other half of CameraRig.BASE_FOV.
func _scale_marks() -> void:
	var scale := rig.fov / CameraRig.BASE_FOV
	for layer in _marked_layers():
		if layer != null:
			layer.material_override.set_shader_parameter("size_scale", scale)
	if planets != null:
		planets.set_zoom(scale)
	if moon != null:
		moon.set_zoom(scale)


func _unhandled_input(event: InputEvent) -> void:
	if rig != null and rig.feed(event):
		get_viewport().set_input_as_handled()
