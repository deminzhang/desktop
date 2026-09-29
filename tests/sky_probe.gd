## Acceptance probe for S3 (计划 §6.5): the sky's clockwork, checked against
## references that do not come out of this code - Meeus' worked sidereal-time
## example, the pole-at-the-latitude law, the spherical trigonometry alt/az is
## supposed to agree with, and the physical behaviour of Polaris over a day.
##
##   tools/godot_console.exe --headless --path . --script res://tests/sky_probe.gd
##
## Headless-safe: only arithmetic and the star catalogue, no mesh is read back
## (计划 §2.3 G17). Exits non-zero if any check fails.
extends SceneTree

const LATITUDE := 39.9042
const LONGITUDE := 116.4074
## Meeus, Astronomical Algorithms, example 12.a: 1987 April 10.0 UT.
const GMST_JD := 2446895.5
const GMST_REFERENCE_DEG := (13.0 * 3600.0 + 10.0 * 60.0 + 46.3668) / 240.0
## Sidereal seconds in a degree: 24 h / 360.
const SECONDS_PER_DEGREE := 240.0
## Vector2, Vector3 and Basis are float32 in Godot: at 360 deg the spacing is
## 3.1e-5 deg, and a rotation chain accumulates a few times that. This is the
## floor, so it is the tightest tolerance any check of a bearing can hold - and
## still three orders of magnitude under the arcminute targets of 计划 §8.
const FLOAT32_STEP := 3.1e-5

var _failures := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	print("XuanDesk: sky probe %s (%d failure%s)"
			% ["OK" if _failures == 0 else "FAILED", _failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)
	return true


func _run() -> void:
	_check_calendar()
	_check_sidereal_time()
	_check_orientation()
	_check_polaris()
	_check_ecliptic()
	_check_rig()
	_check_clock()
	_check_delta_t()
	_check_references()
	_check_bodies()
	_check_phases()
	_check_date_positions()
	_check_daylight()


# ---------------------------------------------------------------- references

## The calendar to Julian date conversion, on two dates that define the scale:
## Meeus' example 12.a and the J2000.0 epoch itself.
func _check_calendar() -> void:
	var meeus := Astro.julian_day(1987, 4, 10)
	_check(meeus == GMST_JD, "calendar -> Julian date", "1987-04-10 = %.1f" % meeus)
	var epoch := Astro.julian_day(2000, 1, 1, 12)
	_check(epoch == Astro.J2000, "J2000.0 epoch", "2000-01-01 12h = %.1f" % epoch)


## Greenwich mean sidereal time against Meeus example 12.a, and local sidereal
## time against its own definition. The polynomial's accuracy is ~0.1 s of time;
## the example pins it to a few 1e-5 s.
func _check_sidereal_time() -> void:
	var gmst := Astro.gmst_deg(GMST_JD)
	var error_seconds := fposmod(gmst - GMST_REFERENCE_DEG + 180.0, 360.0) - 180.0
	error_seconds *= SECONDS_PER_DEGREE
	_check(absf(error_seconds) < 1.0, "GMST vs Meeus 12.a",
			"13h10m46.3668s, error %.8f s" % error_seconds)
	var lst := Astro.lst_deg(GMST_JD, LONGITUDE)
	var shift := fposmod(lst - gmst, 360.0)
	_check(absf(shift - LONGITUDE) < 1.0e-9, "LST = GMST + east longitude",
			"+%.4f deg" % shift)


## The law that fixes the whole sphere: at any instant the celestial pole of date
## stands due north at an altitude equal to the observer's latitude, and a star
## whose hour angle is zero and whose declination is the latitude is overhead.
## Then the same rotation against the plain spherical trigonometry of 计划 §6.2.
func _check_orientation() -> void:
	var jd := Astro.julian_day(2026, 9, 29, 12)
	var worst_altitude := 0.0
	var worst_azimuth := 0.0
	var worst_zenith := 0.0
	for latitude in [0.0, 23.5, LATITUDE, 66.5]:
		var basis := Astro.sky_basis(jd, latitude, LONGITUDE)
		var pole := basis * Precession.direction(jd, Precession.J2000, 0.0, 90.0)
		worst_altitude = maxf(worst_altitude, absf(Astro.altitude_of(pole) - latitude))
		# at the equator the pole sits on the horizon, where a bearing has no
		# meaning; anywhere else it has to read due north
		if latitude >= 1.0:
			worst_azimuth = maxf(worst_azimuth,
					absf(fposmod(Astro.azimuth_of(pole) + 180.0, 360.0) - 180.0))
		var lst := Astro.lst_deg(jd, LONGITUDE)
		var zenith := basis * Precession.direction(jd, Precession.J2000, lst, latitude)
		worst_zenith = maxf(worst_zenith, 90.0 - Astro.altitude_of(zenith))
	_check(worst_altitude < FLOAT32_STEP, "pole altitude = observer latitude",
			"worst error %.8f deg over 4 latitudes" % worst_altitude)
	_check(worst_azimuth < FLOAT32_STEP, "pole azimuth = north",
			"worst error %.8f deg" % worst_azimuth)
	_check(worst_zenith < FLOAT32_STEP, "RA = LST, dec = latitude is overhead",
			"worst error %.8f deg" % worst_zenith)

	var basis := Astro.sky_basis(jd, LATITUDE, LONGITUDE)
	var lst := Astro.lst_deg(jd, LONGITUDE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260929
	var worst := 0.0
	for i in 200:
		var ra := rng.randf_range(0.0, 360.0)
		var dec := rng.randf_range(-89.0, 89.0)
		var world: Vector3 = basis * StarCat.direction(ra, dec)
		# the same star in the epoch of date, for the trigonometry path
		var dated := Precession.direction(Astro.J2000, jd, ra, dec)
		var date_ra := fposmod(rad_to_deg(atan2(-dated.z, dated.x)), 360.0)
		var date_dec := rad_to_deg(asin(dated.y))
		var reference := Astro.altaz(date_ra, date_dec, lst, LATITUDE)
		var bearing := Vector2(Astro.altitude_of(world), Astro.azimuth_of(world))
		worst = maxf(worst, absf(bearing.x - reference.x))
		worst = maxf(worst, absf(fposmod(bearing.y - reference.y + 180.0, 360.0) - 180.0))
	_check(worst < 1.0e-3, "sky_basis vs spherical trigonometry",
			"worst of 200 stars %.8f deg" % worst)


## Polaris over a sidereal day: circumpolar at this latitude, circling the pole at
## its polar distance, crossing due north at upper transit and due south at lower
## transit, and averaging out to the latitude.
##
## 计划's A2 ("北极星高度 = 观测纬度 ±0.1°") is not what the sky does: Polaris sits
## 0.74 deg from the J2000 pole - 0.63 deg by 2026, since precession is carrying
## the pole towards it - so its altitude swings by that much around the latitude.
## The exact law is the pole's (checked above); this is its observable
## consequence, the way A9 was restated in S2.
func _check_polaris() -> void:
	var catalogue := StarCat.load_default()
	if catalogue == null:
		_check(false, "star catalogue", "missing")
		return
	var index := catalogue.find("α", "UMi")
	if index < 0:
		_check(false, "Polaris in the catalogue", "α UMi not found")
		return
	var ra := catalogue.ra[index]
	var dec := catalogue.dec[index]
	var j2000_polar := 90.0 - dec
	var start := Astro.julian_day(2026, 9, 29, 12)
	# Polaris' declination *of date*: precession carries the pole past the star,
	# so the circle it draws in 2026 is not the J2000 one. Taking the expectation
	# from here is also what makes this check notice the sphere being precessed at
	# all - leaving precession out moves the swing by 0.11 deg, twenty times the
	# tolerance below.
	var date_polar := 90.0 - rad_to_deg(asin(
			Precession.direction(Astro.J2000, start, ra, dec).y))
	var lowest := 90.0
	var highest := -90.0
	var sum := 0.0
	var transit_azimuth := 0.0
	var samples := 0
	var jd := start
	while jd < start + 1.0:
		var basis := Astro.sky_basis(jd, LATITUDE, LONGITUDE)
		var world: Vector3 = basis * StarCat.direction(ra, dec)
		var altitude := Astro.altitude_of(world)
		if altitude > highest:
			highest = altitude
			transit_azimuth = Astro.azimuth_of(world)
		lowest = minf(lowest, altitude)
		sum += altitude
		samples += 1
		jd += 5.0 / (24.0 * 60.0)   # every five minutes
	var mean := sum / float(samples)
	_check(lowest > 0.0, "Polaris is circumpolar here", "lowest %.4f deg" % lowest)
	_check(highest - lowest <= 2.0 * date_polar + 0.02,
			"Polaris circles at its polar distance",
			"swing %.4f deg, 2x polar distance %.4f (J2000 %.4f)"
					% [highest - lowest, 2.0 * date_polar, 2.0 * j2000_polar])
	_check(absf(highest - (LATITUDE + date_polar)) < 0.02,
			"upper transit = latitude + polar distance",
			"%.4f deg vs %.4f" % [highest, LATITUDE + date_polar])
	_check(absf(mean - LATITUDE) < 0.02, "Polaris averages out to the latitude",
			"mean %.4f deg, latitude %.4f" % [mean, LATITUDE])
	var transit_error := fposmod(transit_azimuth + 180.0, 360.0) - 180.0
	_check(absf(transit_error) < 1.0, "upper transit is due north",
			"azimuth %.4f deg" % transit_azimuth)


## Ecliptic coordinates, for S4-S6: the obliquity at J2000, the solstice point
## that defines it, and a round trip.
func _check_ecliptic() -> void:
	var obliquity := Astro.obliquity_deg(Astro.J2000)
	_check(absf(obliquity - 23.4392911) < 1.0e-6, "obliquity at J2000",
			"%.7f deg" % obliquity)
	var solstice := Astro.ecliptic_to_equatorial(90.0, 0.0, Astro.J2000)
	var solstice_error := maxf(absf(solstice.x - 90.0), absf(solstice.y - obliquity))
	_check(solstice_error < FLOAT32_STEP, "ecliptic longitude 90 = June solstice",
			"RA %.4f, dec %.4f" % [solstice.x, solstice.y])
	var worst := 0.0
	for lambda in [0.0, 47.0, 133.0, 250.0, 359.0]:
		for beta in [-60.0, -12.0, 0.0, 12.0, 60.0]:
			var equatorial := Astro.ecliptic_to_equatorial(lambda, beta, Astro.J2000)
			var back := Astro.equatorial_to_ecliptic(equatorial.x, equatorial.y,
					Astro.J2000)
			worst = maxf(worst, absf(fposmod(back.x - lambda + 180.0, 360.0) - 180.0))
			worst = maxf(worst, absf(back.y - beta))
	_check(worst < FLOAT32_STEP, "ecliptic round trip", "worst %.8f deg" % worst)


## The camera rig: the four compass points (S7's dial reads az/alt off this),
## the zenith, zoom limits, the drag, and the idle sweep giving way to input.
func _check_rig() -> void:
	var camera := Camera3D.new()
	var rig := CameraRig.new()
	rig.setup(camera)
	var worst := 0.0
	for cardinal in CameraRig.CARDINALS:
		rig.face_cardinal(cardinal)
		var want: float = CameraRig.CARDINALS[cardinal]
		worst = maxf(worst, absf(fposmod(Astro.azimuth_of(-camera.basis.z) - want + 180.0,
				360.0) - 180.0))
	_check(worst < 0.5, "cardinal bearings on the camera",
			"worst of 4 %.8f deg" % worst)

	rig.face_zenith()
	var zenith := 90.0 - Astro.altitude_of(-camera.basis.z)
	_check(zenith < 1.0e-6, "zenith", "error %.8f deg" % zenith)

	# the roll: the camera's own up has to be the tangent to the vertical circle,
	# which is what keeps the horizon level. A wrong sign in horizon_up() leaves
	# the forward axis perfect and only turns the image, so nothing else here
	# would notice it.
	var worst_up := 0.0
	for cardinal in CameraRig.CARDINALS:
		for altitude in [20.0, 45.0, 70.0]:
			rig.face(CameraRig.CARDINALS[cardinal], altitude)
			var want := Astro.horizon_up(rig.azimuth, rig.altitude)
			worst_up = maxf(worst_up, 1.0 - camera.basis.y.dot(want))
	_check(worst_up < 1.0e-6, "the view stays level at the four cardinal points",
			"worst up axis error %.8f over 4 bearings x 3 altitudes" % worst_up)

	rig.face(0.0, 30.0)
	rig.zoom(3.0)
	_check(is_equal_approx(rig.fov, camera.fov) and rig.fov < 60.0, "zoom narrows the view",
			"%.3f deg after 3 notches" % rig.fov)
	rig.zoom(100.0)
	var narrow := rig.fov
	rig.zoom(-100.0)
	_check(narrow == CameraRig.FOV_MIN and rig.fov == CameraRig.FOV_MAX, "zoom limits",
			"%.1f .. %.1f deg" % [narrow, rig.fov])

	rig.face(0.0, 30.0)
	rig.drag(Vector2(100.0, 50.0))
	_check(is_equal_approx(rig.azimuth, 360.0 - 100.0 * CameraRig.DRAG)
			and is_equal_approx(rig.altitude, 30.0 + 50.0 * CameraRig.DRAG),
			"drag pulls the sky under the pointer",
			"azimuth %.2f, altitude %.2f" % [rig.azimuth, rig.altitude])

	rig.face(10.0, 20.0)
	rig.start_sweep()
	for i in 120:
		rig.advance(1.0 / 60.0)
	var panned := absf(fposmod(rig.azimuth - 10.0 + 180.0, 360.0) - 180.0)
	_check(panned > 0.25, "sweep pans the sky", "%.3f deg in 2 s" % panned)

	var stopped := rig.azimuth
	rig.feed(_wheel(MOUSE_BUTTON_WHEEL_UP))
	for i in 120:
		rig.advance(1.0 / 60.0)
	_check(not rig.auto_sweep and is_equal_approx(rig.azimuth, stopped),
			"input stops the sweep", "azimuth frozen at %.3f deg" % rig.azimuth)

	rig.face(200.0, 40.0)
	rig.start_sweep()
	rig.feed(_button(MOUSE_BUTTON_LEFT, true))
	var dragged := rig.azimuth
	rig.feed(_motion(Vector2(-20.0, 0.0)))
	_check(rig.azimuth > dragged and not rig.auto_sweep, "drag after the sweep stopped",
			"%.2f -> %.2f deg" % [dragged, rig.azimuth])

	rig.free()
	camera.free()


## The clock: it advances by `rate` sky seconds per real second, emits only when
## a redraw is worth it, and rate 0 freezes it.
func _check_clock() -> void:
	var clock := TimeCore.new()
	clock.set_time_unix(1.7e9)
	var emitted := [0]
	clock.changed.connect(func() -> void: emitted[0] += 1)
	clock._process(0.5)
	clock._process(0.5)
	_check(emitted[0] == 1 and is_equal_approx(clock.unix(), 1.7e9 + 1.0),
			"clock ticks at rate 1", "%d redraws after 1 s" % emitted[0])
	clock.rate = 0.0
	for i in 10:
		clock._process(1.0)
	_check(emitted[0] == 1 and is_equal_approx(clock.unix(), 1.7e9 + 1.0),
			"rate 0 freezes the sky", "still %.1f" % clock.unix())
	clock.move_by(3600.0)
	_check(emitted[0] == 2 and is_equal_approx(clock.unix(), 1.7e9 + 3601.0),
			"stepping the instant", "+3600 s now %.1f" % clock.unix())
	clock.free()


# ------------------------------------------------------------ the Sun and Moon

## Geocentric apparent positions from JPL Horizons, the authority 计划 §8 A4/A5
## names. Fetched 2026-09-28 from
##   https://ssd.jpl.nasa.gov/api/horizons.api  with
##   COMMAND='10' (Sun) and '301' (Moon), CENTER='500@399' (geocentric),
##   QUANTITIES='2' (apparent RA/Dec of date, airless) and for the Moon also
##   '10' (illuminated fraction) and '13' (angular diameter, arcsec),
##   ANG_FORMAT='DEG', EXTRA_PREC='YES', first row of a one-minute step.
## `time` is UT, which the probe converts through Astro.tt_from_ut.
const HORIZONS := [
	{"time": "2026-09-29T12:00", "sun_ra": 185.844118, "sun_dec": -2.527365,
		"moon_ra": 38.491796, "moon_dec": 20.310817, "moon_illuminated": 0.902554,
		"moon_diameter": 1930.330},
	{"time": "2026-12-21T00:00", "sun_ra": 269.036712, "sun_dec": -23.434474,
		"moon_ra": 42.232486, "moon_dec": 21.565531, "moon_illuminated": 0.865682,
		"moon_diameter": 1952.715},
	{"time": "2025-01-01T00:00", "sun_ra": 281.760093, "sun_dec": -22.998208,
		"moon_ra": 296.680296, "moon_dec": -25.860479, "moon_illuminated": 0.014673,
		"moon_diameter": 1877.517},
	{"time": "2020-06-15T06:00", "sun_ra": 84.117384, "sun_dec": 23.326200,
		"moon_ra": 16.970172, "moon_dec": 1.755609, "moon_illuminated": 0.316843,
		"moon_diameter": 1771.756},
	{"time": "2030-12-25T18:00", "sun_ra": 274.341350, "sun_dec": -23.373943,
		"moon_ra": 289.480638, "moon_dec": -18.734384, "moon_illuminated": 0.016816,
		"moon_diameter": 1998.179},
	{"time": "2000-01-01T12:00", "sun_ra": 281.278375, "sun_dec": -23.032430,
		"moon_ra": 222.452201, "moon_dec": -10.900654, "moon_illuminated": 0.230064,
		"moon_diameter": 1781.067},
	{"time": "1992-04-12T00:00", "sun_ra": 20.658495, "sun_dec": 8.696708,
		"moon_ra": 134.697203, "moon_dec": 13.765131, "moon_illuminated": 0.678619,
		"moon_diameter": 1945.321},
	{"time": "1992-10-13T00:00", "sun_ra": 198.378753, "sun_dec": -7.784067,
		"moon_ra": 30.700253, "moon_dec": 16.552046, "moon_illuminated": 0.983317,
		"moon_diameter": 1822.086},
]

## Delta T against the observed values NASA publishes with the polynomials: table
## 1 of SEhelp/deltat2004.html for the historical years (with its own standard
## error as the tolerance) and table 2 for the modern ones.
const DELTA_T_TABLE := [
	{"year": 1500.0, "seconds": 200.0, "tolerance": 20.0},
	{"year": 1600.0, "seconds": 120.0, "tolerance": 20.0},
	{"year": 1700.0, "seconds": 9.0, "tolerance": 5.0},
	{"year": 1800.0, "seconds": 14.0, "tolerance": 1.0},
	{"year": 1900.0, "seconds": -3.0, "tolerance": 1.0},
	{"year": 1955.0, "seconds": 31.1, "tolerance": 0.5},
	{"year": 2000.0, "seconds": 63.8, "tolerance": 0.5},
	{"year": 2005.0, "seconds": 64.7, "tolerance": 0.5},
]

## Which of the eight phase names each Horizons instant has to come out as,
## worked out from the illuminated fraction alone (the bands are the elongation
## boundaries 22.5/67.5/112.5/157.5 deg, that is 0.0381/0.3087/0.6913/0.9619 of
## the disc) plus, where the disc is not nearly new, which side of the Sun the
## Moon is on - its apparent right ascension against the Sun's. The 1992-04-12
## row is the one Meeus calls a waxing gibbous; at 0.6786 it is 1.9 deg short of
## the band that word names, which starts at 112.5 deg of elongation.
const EXPECTED_PHASE := ["亏凸月", "盈凸月", "新月", "下弦月", "新月", "残月", "上弦月", "满月"]


## Meeus' own worked examples, which pin the algorithms independently of any
## tolerance this project chose:
##   example 25.b, 1992 October 13.0 TD - apparent longitude 199.90895 deg,
##     apparent RA 13h13m31.4s (198.380833 deg), declination -7 47' 06"
##   example 47.a, 1992 April 12.0 TD - longitude 133.162655, latitude
##     -3.229126, distance 368409.7 km, apparent RA 134.688470, declination
##     13.768368
## Both examples are given in dynamical time, so they are handed to the
## ephemeris as they stand, without a Delta T correction.
func _check_references() -> void:
	var sun_example := Astro.julian_day(1992, 10, 13)
	var longitude := Astro.sun_apparent_longitude_deg(sun_example)
	var position := Astro.sun_position(sun_example)
	_check(absf(longitude - 199.90895) < 0.011, "Sun apparent longitude, Meeus 25.b",
			"%.5f vs 199.90895 deg" % longitude)
	_check(absf(position.x - 198.380833) < 0.015, "Sun RA, Meeus 25.b",
			"%.5f vs 198.380833 deg" % position.x)
	_check(absf(position.y + 7.785000) < 0.015, "Sun declination, Meeus 25.b",
			"%.5f vs -7.785000 deg" % position.y)

	var moon_example := Astro.julian_day(1992, 4, 12)
	var moon := Astro.moon_state(moon_example)
	var nutation := Astro.nutation_longitude_deg(moon_example)
	_check(absf(moon.lambda - nutation - 133.162655) < 0.001,
			"Moon longitude, Meeus 47.a",
			"%.6f vs 133.162655 deg" % (moon.lambda - nutation))
	_check(absf(moon.beta + 3.229126) < 0.001, "Moon latitude, Meeus 47.a",
			"%.6f vs -3.229126 deg" % moon.beta)
	_check(absf(moon.distance_km - 368409.7) < 1.0, "Moon distance, Meeus 47.a",
			"%.1f vs 368409.7 km" % moon.distance_km)
	_check(absf(moon.ra - 134.688470) < 0.002, "Moon RA, Meeus 47.a",
			"%.6f vs 134.688470 deg" % moon.ra)
	_check(absf(moon.dec - 13.768368) < 0.002, "Moon declination, Meeus 47.a",
			"%.6f vs 13.768368 deg" % moon.dec)


## The Sun and the Moon against Horizons, at eight instants spread over 1992-2030
## and over the phases, plus the Moon's apparent size and illuminated fraction.
##
## The mean residual is checked as well as the worst: a Moon computed for the
## wrong time scale lags Horizons by 0.55 deg/hour, which is 35 arcsec at every
## one of these instants, so a systematic bias is what says the clock conversion
## (Astro.tt_from_ut) is doing its work, where the worst case alone would hide it
## inside the two-arcminute target.
func _check_bodies() -> void:
	var worst_sun := 0.0
	var worst_moon := 0.0
	var sum_moon := 0.0
	var worst_size := 0.0
	var worst_illuminated := 0.0
	var worst_phase := ""
	var names := []
	for row in HORIZONS:
		var jd := Astro.tt_from_ut(Astro.julian_day_from_unix(
				Time.get_unix_time_from_datetime_string(row.time + ":00")))
		var sun := Astro.sun_position(jd)
		worst_sun = maxf(worst_sun, _separation(sun, Vector2(row.sun_ra, row.sun_dec)))
		var moon := Astro.moon_state(jd)
		var error := _separation(Vector2(moon.ra, moon.dec),
				Vector2(row.moon_ra, row.moon_dec))
		if error > worst_moon:
			worst_moon = error
			worst_phase = row.time
		sum_moon += error
		var size_error: float = absf(moon.radius_deg * 7200.0 - row.moon_diameter) \
				/ float(row.moon_diameter)
		worst_size = maxf(worst_size, size_error)
		worst_illuminated = maxf(worst_illuminated,
				absf(moon.illuminated - row.moon_illuminated))
		names.append(Astro.moon_phase_name(moon.elongation_deg))
	var mean_moon := sum_moon / float(HORIZONS.size())
	_check(worst_sun * 3600.0 < 60.0, "Sun vs JPL Horizons, 8 instants",
			"worst %.2f arcsec of the 60 allowed" % (worst_sun * 3600.0))
	_check(worst_moon * 3600.0 < 120.0, "Moon vs JPL Horizons, 8 instants",
			"worst %.2f arcsec at %s, of the 120 allowed"
					% [worst_moon * 3600.0, worst_phase])
	_check(mean_moon * 3600.0 < 25.0, "Moon has no systematic lag",
			"mean %.2f arcsec (35 without the Delta T correction)"
					% (mean_moon * 3600.0))
	_check(worst_size * 100.0 < 0.5, "Moon apparent diameter vs Horizons",
			"worst %.3f %% of the true diameter" % (worst_size * 100.0))
	_check(worst_illuminated < 0.01, "Moon illuminated fraction vs Horizons",
			"worst %.5f of the disc" % worst_illuminated)
	_check(names == EXPECTED_PHASE, "phase names over eight real phases",
			"%s" % [names])


## The phase geometry itself: the eight names on their boundaries, and the
## illuminated fraction going from nothing at new moon to the whole disc at full.
func _check_phases() -> void:
	var boundaries := [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
	var names := []
	for elongation in boundaries:
		names.append(Astro.moon_phase_name(elongation))
	_check(names == Astro.PHASE_NAMES, "one name per 45 deg of elongation",
			"%s" % [names])
	_check(Astro.illuminated_fraction(0.0) == 0.0
			and Astro.illuminated_fraction(180.0) == 1.0,
			"new moon is dark, full moon is whole",
			"%.1f / %.1f" % [Astro.illuminated_fraction(0.0),
					Astro.illuminated_fraction(180.0)])
	var worst := 0.0
	for i in 181:
		var elongation := float(i)
		# the illuminated fraction is the sphere's lit cross-section: the
		# distance between the disc's edges along the terminator's axis
		var expected := (1.0 - cos(deg_to_rad(elongation))) * 0.5
		worst = maxf(worst, absf(Astro.illuminated_fraction(elongation) - expected))
		if i > 0:
			worst = maxf(worst, 0.0 if Astro.illuminated_fraction(elongation)
					>= Astro.illuminated_fraction(elongation - 1.0) else 1.0)
	_check(worst == 0.0, "illuminated fraction rises from 0 to 1 and no further",
			"monotone over 0..180 deg")


## The Sun's and Moon's ecliptic geometry against the sphere: a position given for
## the equinox of date, put through the date-to-catalogue conversion and then
## through SkyRoot's own basis, has to land where the plain spherical
## trigonometry of 计划 §6.2 says it does. This is the half of the bridge the S3
## check does not cover - the one the two bodies are drawn through.
func _check_date_positions() -> void:
	var jd := Astro.julian_day(2026, 9, 29, 12)
	var basis := Astro.sky_basis(jd, LATITUDE, LONGITUDE)
	var lst := Astro.lst_deg(jd, LONGITUDE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260930
	var worst := 0.0
	var places := [Astro.sun_position(Astro.tt_from_ut(jd)),
			Vector2(Astro.moon_state(Astro.tt_from_ut(jd)).ra,
					Astro.moon_state(Astro.tt_from_ut(jd)).dec)]
	for i in 40:
		places.append(Vector2(rng.randf_range(0.0, 360.0), rng.randf_range(-89.0, 89.0)))
	for place in places:
		var world: Vector3 = basis * Astro.local_from_date(jd, place.x, place.y)
		var reference := Astro.altaz(place.x, place.y, lst, LATITUDE)
		worst = maxf(worst, absf(Astro.altitude_of(world) - reference.x))
		worst = maxf(worst, absf(fposmod(Astro.azimuth_of(world) - reference.y + 180.0,
				360.0) - 180.0))
	_check(worst < 1.0e-3, "positions of date land on the sphere",
			"worst of %d %.8f deg" % [places.size(), worst])


## The light the sky takes from the Sun's altitude: none at night, all of it by
## the time the Sun is up, and the glow at the horizon only while it is low.
func _check_daylight() -> void:
	_check(Astro.daylight(-18.0) == 0.0 and Astro.daylight(1.0) == 1.0,
			"dark at astronomical twilight, full day with the Sun up",
			"%.3f below the horizon, %.3f above" % [Astro.daylight(-18.0),
					Astro.daylight(1.0)])
	_check(absf(Astro.daylight(-6.0) - 0.5) < 1.0e-6,
			"civil twilight is half the day's light",
			"%.3f at -6 deg" % Astro.daylight(-6.0))
	_check(Astro.twilight(-4.0) > 0.9 and Astro.twilight(20.0) < 0.05
			and Astro.twilight(-30.0) < 0.01,
			"the horizon glow stays near the horizon",
			"%.2f at -4, %.3f at 20, %.4f at -30 deg"
					% [Astro.twilight(-4.0), Astro.twilight(20.0),
							Astro.twilight(-30.0)])


## Delta T against the observed values, one epoch per polynomial piece.
func _check_delta_t() -> void:
	var worst := 0.0
	var detail := ""
	for row in DELTA_T_TABLE:
		var jd: float = Astro.J2000 + (float(row.year) - 2000.0) * 365.25
		var formula := Astro.delta_t_seconds(jd)
		var error: float = absf(formula - float(row.seconds)) / float(row.tolerance)
		if error > worst:
			worst = error
			detail = "worst year %.0f: %.1f s for %.1f observed (%.2f of the tolerance)" \
					% [row.year, formula, row.seconds, error]
	_check(worst <= 1.0, "Delta T vs the values it was fitted to", detail)


# ------------------------------------------------------------------- helpers

## Angular distance between two RA/Dec pairs, in degrees.
func _separation(a: Vector2, b: Vector2) -> float:
	return absf(rad_to_deg(StarCat.direction(a.x, a.y).angle_to(
			StarCat.direction(b.x, b.y))))


func _button(index: int, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	return event


func _wheel(index: int) -> InputEventMouseButton:
	return _button(index, true)


func _motion(relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	return event


func _check(ok: bool, label: String, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s %-40s %s" % ["pass" if ok else "FAIL", label, detail])
