## The Moon: a sphere the Sun lights, so its phase is real geometry (计划 §6.5 S4),
## and the orbit it runs - drawn out of scale, at the user's request (2026-10-10).
##
## The disc is a unit sphere scaled to the apparent radius the ephemeris gives,
## times MAGNIFY, hung on SkyRoot just inside the Sun - a solar eclipse should stack
## the right way round - and shaded by the direction to the Sun, which is what puts
## the terminator where it belongs and the bright limb towards the Sun.
##
## The orbit is the 白道: the path the Moon's own ephemeris walks in one revolution,
## a ribbon on the sphere 5.1 deg off the ecliptic - the one line up there that is
## the Moon's rather than the Sun's. It is walked again when the day turns, because
## the node regresses 0.05 deg a day and nothing else about it moves that fast.
##
## It is drawn only while the Moon itself is in the frame (2026-10-12, at the user's
## asking): it is the Moon's own line, and a 白道 sweeping across a frame the Moon
## is not in says the Moon is there - the plainer reading is that a body's track
## belongs on screen with the body. Where the Moon is in frame the whole loop is
## drawn as before; the cut is the disc's position in the camera's frustum, which
## the sky hands over whenever the view moves (set_view).
##
## The disc is placed again on every time step and never rebuilt; while the Moon is
## below the horizon its shader cuts it off at the horizon line like every other
## layer, and the orbit takes the same cut through the line shader.
class_name SkyMoon
extends Node3D

const SHADER := "res://backgrounds/sky/shaders/moon.gdshader"
## Distance from the camera, inside the Sun's disc and the stars.
const RADIUS := 456.0

## How many times its true apparent size the disc is drawn. The true disc is 0.26
## deg of radius - three pixels of it at the wallpaper's opening 100 deg field, a
## point of light among the planets' marks - and the Moon is the one thing up there
## with a face on it. The phase is the same geometry either way; what it costs is the
## eclipse, where the Moon now covers more of the Sun than it would.
const MAGNIFY := 3.0

## One revolution, walked in ORBIT_SAMPLES steps of ecliptic longitude and drawn at
## the width the planet trails are. Longitude and not time: the Moon's longitude runs
## 11.8 to 15.4 deg a day, so a revolution walked in equal days would leave the ends
## of the loop some 6 deg apart. Three degrees a step facets the loop by 0.02 deg -
## a fifth of a pixel at the deepest zoom - and costs about three Astro.moon_state()
## calls a step, which is the bargain the planets' own trail makes.
const ORBIT_SAMPLES := 120
const ORBIT_WIDTH := 0.42
## Pale, dim and cool: additive ink that must not bloom, and must be told from the
## warm ecliptic it rides beside.
const ORBIT_COLOUR := Color(0.088, 0.098, 0.124)

## The Moon's mean motion in longitude, degrees a day (the rate of Meeus 47's own mean
## longitude): what the search for the instant a given longitude is reached starts
## from.
const MEAN_MOTION := 13.176358

## Unit direction of the Moon in this sphere's own frame.
var direction := Vector3.ZERO
## World radius of the drawn disc (RADIUS x tan(apparent radius) x MAGNIFY): what
## SkyLabels lifts the name clear of.
var disc_radius := 0.0

var _disc: MeshInstance3D
var _material: ShaderMaterial
var _orbit: MeshInstance3D
var _jd := 0.0
var _orbit_day := NAN
var _night := 1.0
var _zoom := 1.0
## Whether the Moon's disc is inside the camera's frame, which is what decides
## whether the orbit is drawn at all. True until a view is handed over: a camera
## that has not been looked through yet is not a reason to drop the line.
var _in_view := true


func _init() -> void:
	_disc = MeshInstance3D.new()
	_disc.name = "Disc"
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 48
	mesh.rings = 24
	_disc.mesh = mesh
	# the sky's own map puts this disc wherever its direction lands, which reaches
	# outside the camera's frustum: bounds that hold the camera keep it on the
	# wallpaper at any bearing (SkyProjection)
	SkyProjection.keep_visible(_disc)
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER)
	_disc.material_override = _material
	add_child(_disc)


## Places the Moon for `jd` (dynamical time) and tells its shader where the Sun
## is, in the same frame - the mesh's own, since the node is never turned. The orbit
## is walked again when the day has turned, the way the planets' trails are; the
## first walk is the one that reports itself in the log.
func place(jd: float, sun_direction: Vector3) -> void:
	var state := Astro.moon_state(jd)
	direction = Astro.local_from_date(jd, state.ra, state.dec)
	_material.set_shader_parameter("sun_dir", sun_direction)
	disc_radius = RADIUS * tan(deg_to_rad(state.radius_deg)) * MAGNIFY
	transform = Transform3D(Basis().scaled(Vector3.ONE * disc_radius),
			direction * RADIUS)
	_jd = jd
	if is_nan(_orbit_day) or absf(floor(jd) - _orbit_day) >= 1.0:
		_build_orbit(is_nan(_orbit_day))
		_orbit_day = floor(jd)


## Where the disc stands against the camera's frame: the sky hands the camera over
## every time the view moves, and the orbit is drawn only if the Moon is in frame
## (the class comment). The test is the disc's own place, so "in view" means the Moon
## is - the ribbon is a hairline across the whole sky and has no bearing on it.
##
## The disc itself needs no such test: the map draws it wherever its direction lands
## and keep_visible keeps the frustum off it (SkyProjection) - so the ribbon only has
## to ask about the Moon. The map's frame is the wallpaper's, so the size comes from
## the camera's own viewport; before there is one - the sky builds its layers before
## the frame it will be drawn in exists - the ribbon is drawn, which is what a view
## nothing has asked anything of yet does.
func set_view(camera: Camera3D) -> void:
	var viewport := camera.get_viewport()
	if viewport == null:
		_in_view = true
		_apply_orbit()
		return
	var size := viewport.get_visible_rect().size
	# the disc's own reach on the frame, so a Moon whose centre has just crossed the
	# edge - half of it still on the wallpaper - keeps its ribbon
	var reach := disc_radius * SkyProjection.pixels_per_unit(camera, size, RADIUS)
	_in_view = SkyProjection.in_frame(camera, _disc.global_position, size, reach)
	_apply_orbit()


## How much of the night is left, the same number the star layers are given: the
## orbit is ink on the sky and dims with it. The disc does not - it is a body with a
## shader of its own.
func set_night(night: float) -> void:
	_night = night
	_apply_orbit()


## The field of view over the sky's own 60 deg one (CameraRig.BASE_FOV): the orbit is
## a ribbon built at that field, scaled like the figures and the trails so it stays a
## hairline at any zoom.
func set_zoom(zoom: float) -> void:
	_zoom = zoom
	_apply_orbit()


## The 白道, from the Moon's present place: one revolution of its own ephemeris,
## sampled by ecliptic longitude so that the last point lands back on the first, and
## folded into the catalogue frame by Ecliptic.point - the same fold the ecliptic and
## its term ticks take, which is what leaves this loop 5.1 deg off that circle rather
## than on it.
##
## The orbit hangs on the Moon's parent (SkyRoot) and not on the Moon: this node is
## scaled to the disc, and a child would inherit that scale.
func _build_orbit(report: bool) -> void:
	if _orbit != null:
		_orbit.queue_free()
		_orbit = null
	var walk: Array[Vector3] = []
	var south := 90.0
	var north := -90.0
	var jd := _jd
	var target := Astro.moon_state(jd).lambda
	for _step in ORBIT_SAMPLES + 1:
		var state := Astro.moon_state(jd)
		walk.append(Ecliptic.point(jd, state.lambda, state.beta))
		south = minf(south, state.beta)
		north = maxf(north, state.beta)
		target += 360.0 / float(ORBIT_SAMPLES)
		jd = _instant_of_longitude(jd, target)
	# One revolution does not bring the Moon's latitude back to where it started -
	# the node walks 1.4 deg in that time, which is about a fifth of a degree of
	# latitude on this loop - so the loop is closed by spreading that difference
	# round it instead of leaving a step at the join. The first point, the Moon's own
	# place, is held exact.
	var seam := walk[0].angle_to(walk[walk.size() - 1])
	var gap := walk[0] - walk[walk.size() - 1]
	var last := float(walk.size() - 1)
	for i in walk.size():
		walk[i] = (walk[i] + gap * (float(i) / last)).normalized()
	_orbit = SkyLines.polyline_layer(get_parent(), [walk], ORBIT_WIDTH, ORBIT_COLOUR,
			"MoonOrbit")
	_apply_orbit()
	if report:
		print("XuanDesk: sky: 月球轨道 %d 点，接缝 %.3f° 摊到整圈，β %+.2f°..%+.2f°；视半径 ×%.1f"
				% [ORBIT_SAMPLES, rad_to_deg(seam), south, north, MAGNIFY])


## The instant after `from_jd` at which the Moon's ecliptic longitude reaches
## `target`: seeded from the mean motion, then walked in on the rate the ephemeris
## gives - which is the mean motion to within 12 per cent either way (the Moon is
## never retrograde in longitude), so three passes land it well inside an arcminute.
static func _instant_of_longitude(from_jd: float, target_deg: float) -> float:
	var jd := from_jd + _gap_deg(Astro.moon_state(from_jd).lambda, target_deg) \
			/ MEAN_MOTION
	for _pass in 4:
		var gap := _gap_deg(Astro.moon_state(jd).lambda, target_deg)
		if absf(gap) < 1.0e-4:
			break
		jd += gap / MEAN_MOTION
	return jd


## `to` measured from `from`, the short way round, in (-180, 180].
static func _gap_deg(from_deg: float, to_deg: float) -> float:
	return fposmod(to_deg - from_deg + 180.0, 360.0) - 180.0


func _apply_orbit() -> void:
	if _orbit == null:
		return
	_orbit.visible = _in_view
	_orbit.material_override.set_shader_parameter("night", _night)
	_orbit.material_override.set_shader_parameter("size_scale", _zoom)
