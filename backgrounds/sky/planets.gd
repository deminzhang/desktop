## The planets (计划 §6.5 S5).
##
## Heliocentric where the orbits are, geocentric where the sky is read: eight rows
## of JPL's approximate Keplerian elements - Mercury round to Neptune, the third of
## them the Earth-Moon barycentre, which is the one we are standing on and so the
## one the sky never draws - give a position good to a few arcseconds, and
## subtracting that row from any other turns it into the right ascension and
## declination the sphere is turned by (Standish & Williams, "Approximate Positions
## of the Planets"; the element set, and what it costs at each planet, is at
## ELEMENTS below). One pass of light-time on top: what we see left the planet a
## while ago.
##
## Jupiter's and Saturn's rows are not elements any more (2026-10-10): the straight
## rate cannot follow the great inequality, so those two come from VSOP87B instead
## (`Vsop87.heliocentric`, decoded in vsop87.gd). Everything else about them - the
## light-time pass, the brightness, the trail, the marks - is the same code either
## way, because both give the same quantity in the same frame.
##
## The seven marks hang on SkyRoot like the Sun and the Moon - placed again on every
## time step, never rebuilt - and carry a trail: the path the planet has walked over
## the last month or so, drawn faint, which is where a retrograde loop shows itself.
##
## Everything down to `state()` is static and takes its instant as an argument, so
## the whole ephemeris is reachable headless (the probes under .tmp/tests/).
class_name SkyPlanets
extends Node3D

## The planets the sky draws, in order out from the Sun: the Chinese name the mark
## carries and the row of ELEMENTS holding its orbit. The Earth's own row is not
## here - it is the frame these are read against.
const DRAWABLE := [
	["水星", 0], ["金星", 1], ["火星", 3], ["木星", 4], ["土星", 5],
	["天王星", 6], ["海王星", 7],
]

## JPL's approximate elements, per row (Standish & Williams, "Approximate Positions
## of the Planets", Table 1): semi-major axis (AU), eccentricity, inclination, mean
## longitude, longitude of perihelion and longitude of the ascending node - all
## degrees - then the per-Julian-century rate of each of the six. Row 2 is the
## Earth-Moon barycentre: the one we are standing on, and the only row that is never
## drawn.
##
## Table 1 and Table 2 (the 3000 BC - 3000 AD fit, whose Jupiter through Neptune rows
## carry four extra cosine terms for the great inequality) were both measured against
## JPL Horizons over 1801-2050, 20 dates each. Table 1 wins where this is used:
##
##   planet    Table 1 max   Table 2 max   Horizons' own nominal error (Table 1)
##   水星          21"          30"            15"
##   金星          42"          48"            20"
##   火星          60"         143"            40"
##   木星         426"         705"           400"
##   土星         631"        1276"           600"
##   天王星        81"        1018"            50"
##   海王星        59"         323"            10"
##
## So 计划 §8's A6 - every planet inside 5 arcminutes over 1800-2050 - held for the
## five inner ones and was missed by the great inequality itself: Jupiter and Saturn
## swing by degrees over the centuries and no straight-rate fit follows them (the
## four cosine terms follow the average of that swing, not this window's part of it).
##
## Those two rows are therefore not read from this table any more (2026-10-10):
## VSOP_ROWS below hands them to Vsop87, whose series the same A6 measurement puts
## inside 3" over the same twenty dates. The 木星/土星 rows are kept here anyway:
## they are the fit the other five are compared against, and the cutover should not
## look like the planets were never on one table.
const ELEMENTS := [
	[0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593,
		0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081],
	[0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255,
		0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418],
	[1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0,
		0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0],
	[1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891,
		0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343],
	[5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909,
		-0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106],
	[9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448,
		-0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794],
	[19.18916464, 0.04725744, 0.77263783, 313.23810451, 170.95427630, 74.01692503,
		-0.00196176, -0.00004397, -0.00242939, 428.48202785, 0.40805281, 0.04240589],
	[30.06992276, 0.00859048, 1.77004347, -55.12002969, 44.96476227, 131.78422574,
		0.00026291, 0.00005105, 0.00035372, 218.45945325, -0.32241464, -0.00508664],
]

## The Earth-Moon barycentre's row: the one that turns a heliocentric position into
## the geocentric one.
const EARTH_ROW := 2

## The rows VSOP87's series answer for instead of ELEMENTS (2026-10-10): Jupiter and
## Saturn, keyed the way the table writes them. The other five rows keep Kepler.
const VSOP_ROWS := {4: "J", 5: "S"}

## The planets' colours, in DRAWABLE order: the five elements the names are read
## from - 水, 金, 火, 木, 土 - and the two modern ones on the palette's own cool inks.
const COLOURS := [
	Color(0.66, 0.71, 0.78),   # 水星
	Color(0.98, 0.95, 0.85),   # 金星
	Color(0.95, 0.53, 0.36),   # 火星
	Color(0.93, 0.86, 0.70),   # 木星
	Color(0.91, 0.84, 0.56),   # 土星
	Color(0.70, 0.92, 0.95),   # 天王星
	Color(0.52, 0.70, 0.98),   # 海王星
]

## Equatorial semi-diameter at one astronomical unit, in arcseconds (the value the
## apparent size is 1/distance of - it is why a disc drawn from it is a tenth of a
## pixel wide at the sky's opening field, and why the mark is sized by magnitude
## instead, like a star).
const SEMI_DIAMETERS := [3.36, 8.34, 4.68, 98.44, 82.73, 35.02, 33.50]

## Days the light from one astronomical unit takes (1 AU / c), the unit the
## light-time pass below is in.
const LIGHT_TIME_DAYS := 0.0057755183

const LOG10 := 0.4342944819032518


# ------------------------------------------------------------------ ephemeris

## One planet at one instant: where it is, how far away, how bright and how big.
class PlanetState extends RefCounted:
	var name := ""
	var ra := 0.0              ## apparent geocentric right ascension, degrees, J2000
	var dec := 0.0             ## apparent geocentric declination, degrees, J2000
	var distance_au := 0.0     ## between the centres
	var sun_distance_au := 0.0 ## from the Sun
	var magnitude := 0.0       ## V, the Astronomical Almanac's approximations
	var radius_arcsec := 0.0   ## apparent angular radius of the disc
	var phase_angle_deg := 0.0 ## planet-centred Sun-Earth angle
	var elongation_deg := 0.0  ## from the Sun as seen from here
	var direction := Vector3.ZERO   ## unit vector in the catalogue frame
	var colour := Color.WHITE  ## the mark's own, from COLOURS


## The full state of the planet `index` of DRAWABLE for `jd` (dynamical time).
static func state(index: int, jd: float) -> PlanetState:
	var row: int = int(DRAWABLE[index][1])
	var t := (jd - Astro.J2000) / 36525.0
	var earth := _row_position(EARTH_ROW, t)
	var position := _row_position(row, t)
	# the light we see left the planet `distance / c` ago, so the position is taken
	# again for that earlier instant - twice round is past the arcminute this is
	# held to, and every extra pass is another Kepler solve
	var tau := 0.0
	for _pass in 2:
		tau = (position - earth).length() * LIGHT_TIME_DAYS
		position = _row_position(row, t - tau / 36525.0)
	var relative := position - earth
	var distance := relative.length()
	var sun_distance := position.length()
	var earth_distance := earth.length()

	var state := PlanetState.new()
	state.name = String(DRAWABLE[index][0])
	state.colour = COLOURS[index]
	state.distance_au = distance
	state.sun_distance_au = sun_distance
	state.phase_angle_deg = rad_to_deg(acos(clampf(
			(sun_distance * sun_distance + distance * distance
					- earth_distance * earth_distance) / (2.0 * sun_distance * distance),
			-1.0, 1.0)))
	state.magnitude = _magnitude(index, sun_distance, distance, state.phase_angle_deg)
	state.radius_arcsec = float(SEMI_DIAMETERS[index]) / distance
	state.elongation_deg = rad_to_deg(relative.angle_to(-earth))
	var equatorial := _equatorial(relative, distance)
	state.ra = equatorial.x
	state.dec = equatorial.y
	state.direction = StarCat.direction(state.ra, state.dec)
	return state


## Unit direction of the planet `index` in the catalogue frame for `jd`: the same
## computation as state() without the brightness and size terms, for the trail,
## which asks for a month of them at a time.
static func direction_of(index: int, jd: float) -> Vector3:
	var t := (jd - Astro.J2000) / 36525.0
	var earth := _row_position(EARTH_ROW, t)
	var position := _row_position(int(DRAWABLE[index][1]), t)
	var tau := 0.0
	for _pass in 2:
		tau = (position - earth).length() * LIGHT_TIME_DAYS
		position = _row_position(int(DRAWABLE[index][1]), t - tau / 36525.0)
	var relative := position - earth
	var equatorial := _equatorial(relative, relative.length())
	return StarCat.direction(equatorial.x, equatorial.y)


## Heliocentric position of one ephemeris row at `t` Julian centuries past J2000, in
## the J2000 ecliptic frame, in astronomical units - the one place the two theories
## meet. Rows in VSOP_ROWS are summed from the VSOP87 series (vsop87.gd); the rest
## are propagated from ELEMENTS by Kepler, in heliocentric() below. Both return the
## same quantity in the same frame, which is why every caller can be blind to which
## one answered.
static func _row_position(row: int, t: float) -> Vector3:
	if VSOP_ROWS.has(row):
		return Vsop87.heliocentric(String(VSOP_ROWS[row]), t)
	return heliocentric(row, t)


## Heliocentric position of one ELEMENTS row at `t` Julian centuries past J2000, in
## the J2000 ecliptic frame, in astronomical units. Standish 3.4-3.5: the elements,
## Kepler's equation solved by Newton three or four times, then the orbit turned into
## the ecliptic by the argument of perihelion, the inclination and the node.
static func heliocentric(row: int, t: float) -> Vector3:
	var element: Array = ELEMENTS[row]
	var axis: float = float(element[0]) + float(element[6]) * t
	var eccentricity: float = float(element[1]) + float(element[7]) * t
	var inclination := deg_to_rad(float(element[2]) + float(element[8]) * t)
	var mean_longitude: float = float(element[3]) + float(element[9]) * t
	var perihelion: float = float(element[4]) + float(element[10]) * t
	var node := deg_to_rad(float(element[5]) + float(element[11]) * t)
	var argument := deg_to_rad(perihelion) - node
	var mean_anomaly := deg_to_rad(fposmod(mean_longitude - perihelion, 360.0))

	var eccentric := _eccentric_anomaly(mean_anomaly, eccentricity)
	# in the orbital plane, x towards perihelion
	var x := axis * (cos(eccentric) - eccentricity)
	var y := axis * sqrt(1.0 - eccentricity * eccentricity) * sin(eccentric)
	var cos_argument := cos(argument)
	var sin_argument := sin(argument)
	var cos_node := cos(node)
	var sin_node := sin(node)
	var cos_inclination := cos(inclination)
	var sin_inclination := sin(inclination)
	return Vector3(
			(cos_argument * cos_node - sin_argument * sin_node * cos_inclination) * x
					+ (-sin_argument * cos_node - cos_argument * sin_node * cos_inclination) * y,
			(cos_argument * sin_node + sin_argument * cos_node * cos_inclination) * x
					+ (-sin_argument * sin_node + cos_argument * cos_node * cos_inclination) * y,
			(sin_argument * sin_inclination) * x + (cos_argument * sin_inclination) * y)


## Kepler's equation M = E - e sin E, by Newton's method from E = M: the orbits here
## are the near-circular ones of the planets, so this converges in three steps and
## the loop is for Mercury's 0.206 at worst.
static func _eccentric_anomaly(mean_anomaly_rad: float, eccentricity: float) -> float:
	var eccentric := mean_anomaly_rad + eccentricity * sin(mean_anomaly_rad)
	for _step in 6:
		var delta := (eccentric - eccentricity * sin(eccentric) - mean_anomaly_rad) \
				/ (1.0 - eccentricity * cos(eccentric))
		eccentric -= delta
		if absf(delta) < 1.0e-12:
			break
	return eccentric


## Ecliptic vector to J2000 right ascension and declination. The elements are
## referred to the J2000 ecliptic, so the obliquity is J2000's own - not the
## obliquity of the drawn date, which is what the Sun and the Moon are given.
static func _equatorial(ecliptic: Vector3, distance: float) -> Vector2:
	var lambda := fposmod(rad_to_deg(atan2(ecliptic.y, ecliptic.x)), 360.0)
	var beta := rad_to_deg(asin(clampf(ecliptic.z / distance, -1.0, 1.0)))
	return Astro.ecliptic_to_equatorial(lambda, beta, Astro.J2000)


## Apparent V magnitude: the Almanac's approximations - one 5 log(r·delta) term
## every planet shares, then the phase-angle polynomial whose shape is the planet's
## own (Mercury's and Venus's are curved, the outer planets' nearly flat). Saturn's
## rings are not modelled; they swing it by half a magnitude, which is not what a
## wallpaper's mark is for.
static func _magnitude(index: int, sun_distance: float, distance: float,
		phase_deg: float) -> float:
	var base := 5.0 * log(sun_distance * distance) * LOG10
	match index:
		0:
			return -0.42 + base + 0.0380 * phase_deg - 0.000273 * phase_deg * phase_deg \
					+ 0.000002 * pow(phase_deg, 3)
		1:
			return -4.40 + base + 0.0009 * phase_deg + 0.000239 * phase_deg * phase_deg \
					- 0.00000065 * pow(phase_deg, 3)
		2:
			return -1.52 + base + 0.016 * phase_deg
		3:
			return -9.40 + base + 0.005 * phase_deg
		4:
			return -8.88 + base
		5:
			return -7.19 + base
		_:
			return -6.87 + base


# --------------------------------------------------------------------- marks

const SHADER := "res://backgrounds/sky/shaders/sun.gdshader"
## Where the marks hang: outside the Sun's shell and the Moon's, inside the stars'.
const RADIUS := 458.0
## The disc's share of its quad, the way sun.gdshader reads it.
const CORE := 0.45
## The ramps the mark's size and brightness are read off the apparent magnitude: a
## planet of MARK_FAINT_MAG or fainter is the smallest the sky draws, MARK_BRIGHT_MAG
## or brighter the largest, and Venus and Jupiter sit on the top of both.
const MARK_BRIGHT_MAG := 3.0
const MARK_FAINT_MAG := -4.0
const MARK_MIN := 1.5
const MARK_MAX := 3.6
const DISC_BRIGHTNESS := 4.2
const HALO_BRIGHTNESS := 1.1


## 0 for a planet at the faint end of the ramp, 1 at the bright end: the one place
## the magnitude is turned into a mark, shared with the dial's own planet marks so
## the wallpaper and the card agree on which planet is the big one.
static func mark_norm(magnitude: float) -> float:
	return clampf((MARK_BRIGHT_MAG - magnitude) / (MARK_BRIGHT_MAG - MARK_FAINT_MAG),
			0.0, 1.0)

## The trail: how far either side of the drawn instant it is walked, how many
## points it is walked in, and how it is drawn. A month is most of a sign for
## Mercury and a smudge for Neptune, which is the truth of it.
const TRAIL_DAYS := 30.0
const TRAIL_STEPS := 48
## The same width the constellation figures are drawn at: a ribbon under a pixel
## wide aliases into a dotted ghost of itself, and this one is meant to be read.
const TRAIL_WIDTH := 0.42
const TRAIL_COLOUR := Color(0.052, 0.070, 0.115)

## The seven PlanetState of the drawn instant, in DRAWABLE order - what the HUD's
## marks and the sky's labels read. Empty until the first place().
var states: Array = []

var _marks: Array = []      ## one MeshInstance3D per DRAWABLE entry
var _trail: MeshInstance3D
var _jd := 0.0
var _trail_day := NAN
var _night := 1.0
var _zoom := 1.0


func _init() -> void:
	for index in DRAWABLE.size():
		var mark := MeshInstance3D.new()
		mark.name = "Planet%s" % String(DRAWABLE[index][0])
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh := PlaneMesh.new()
		# a quad across the line of sight: the default PlaneMesh lies flat
		mesh.orientation = PlaneMesh.FACE_Z
		mesh.size = Vector2.ONE * MARK_MAX
		mark.mesh = mesh
		# the sky's own map puts a mark wherever its direction lands, which reaches
		# outside the camera's frustum: bounds that hold the camera keep it on the
		# wallpaper at any bearing (SkyProjection)
		SkyProjection.keep_visible(mark)
		var material := ShaderMaterial.new()
		material.shader = load(SHADER)
		material.set_shader_parameter("core", CORE)
		# the mark does not redden as it goes down the way the Sun does: it is a
		# point of light, not a disc, and its colour is the planet's own
		material.set_shader_parameter("disc_colour", COLOURS[index])
		material.set_shader_parameter("sunset_colour", COLOURS[index])
		mark.material_override = material
		mark.visible = false
		add_child(mark)
		_marks.append(mark)


## Places all seven for `jd` (dynamical time) and walks the trails again when the
## day has turned. The marks themselves are never rebuilt, only moved: each is two
## triangles and a transform.
func place(jd: float) -> void:
	_jd = jd
	states.clear()
	for index in DRAWABLE.size():
		states.append(state(index, jd))
	_apply_marks()
	if is_nan(_trail_day) or absf(floor(jd) - _trail_day) >= 1.0:
		_trail_day = floor(jd)
		_build_trail()


## How much of the night is left, the same number the star layers are given: a
## planet is a point of light too, so daylight dims it rather than taking it away.
func set_night(night: float) -> void:
	_night = night
	_apply_marks()
	_apply_trail()


## The field of view over the sky's own 60 deg one: a mark is meant to keep its
## size on screen (the other half is CameraRig.BASE_FOV).
func set_zoom(zoom: float) -> void:
	_zoom = zoom
	_apply_marks()
	_apply_trail()


func _apply_marks() -> void:
	for index in _marks.size():
		var mark: MeshInstance3D = _marks[index]
		if index >= states.size():
			mark.visible = false
			continue
		var state: PlanetState = states[index]
		var norm := mark_norm(state.magnitude)
		var mesh := mark.mesh as PlaneMesh
		mesh.size = Vector2.ONE * lerpf(MARK_MIN, MARK_MAX, norm) * _zoom
		mark.transform = Transform3D(Basis.looking_at(state.direction,
				_up_for(state.direction)), state.direction * RADIUS)
		var material := mark.material_override as ShaderMaterial
		material.set_shader_parameter("core_brightness",
				DISC_BRIGHTNESS * (0.14 + 0.86 * norm) * _night)
		material.set_shader_parameter("halo_brightness",
				HALO_BRIGHTNESS * (0.08 + 0.92 * norm) * _night)
		mark.visible = true


## An up vector that is never parallel to the direction, for looking_at().
static func _up_for(direction: Vector3) -> Vector3:
	return Vector3.RIGHT if absf(direction.y) > 0.999 else Vector3.UP


## The seven trails, one layer: the same ribbon the constellation figures are drawn
## as (SkyLines), so they lie on the sphere and take the horizon mask and the zoom
## with everything else. One colour for all seven - they are a guide to where each
## planet has been, and seven colours over the stars would read as seven more
## figures.
func _build_trail() -> void:
	if _trail != null:
		_trail.queue_free()
		_trail = null
	var lines := []
	for index in DRAWABLE.size():
		var arc := []
		for step in TRAIL_STEPS + 1:
			var days := -TRAIL_DAYS + 2.0 * TRAIL_DAYS * float(step) / float(TRAIL_STEPS)
			arc.append(direction_of(index, _jd + days))
		lines.append(arc)
	_trail = SkyLines.polyline_layer(self, lines, TRAIL_WIDTH, TRAIL_COLOUR, "PlanetTrails")
	_apply_trail()


func _apply_trail() -> void:
	if _trail == null:
		return
	_trail.material_override.set_shader_parameter("night", _night)
	_trail.material_override.set_shader_parameter("size_scale", _zoom)
