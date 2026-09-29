## The clockwork under the star sphere: calendar to Julian date, sidereal time,
## and the one rotation that carries the catalogue's J2000 coordinates into the
## observer's horizon (计划 §6.2).
##
## Two frames meet here, and nowhere else:
##   * the catalogue frame, which StarCat.direction() defines (+X = RA 0h,
##     +Y = the pole, +Z = RA 18h) - every star, figure and boundary is stored in
##     it;
##   * the engine world frame, +Y = zenith, +Z = north, +X = west, the frame
##     sky.gd's camera already faces south in.
## sky_basis() is the whole bridge: the rotation to put on SkyRoot, so moving the
## sky to any date and place is one basis assignment.
##
## Azimuth runs from north towards east, the reading the compass HUD (S7) puts on
## its dial. Everything here is local arithmetic: no ephemeris, no network.
##
## Precision: only the scalars are double. Vector3, Basis and Vector2 are single
## precision in Godot, so any position that passes through one carries of order
## 1e-5 deg of rounding - 0.04 arcsec, three orders of magnitude inside the
## arcminute targets S4-S6 are held to (计划 §8). That floor is where the probe's
## tolerances come from, and it is why the exact laws are stated to 1e-6 deg
## rather than to machine epsilon.
class_name Astro
extends RefCounted

## Julian date of J2000.0.
const J2000 := 2451545.0
## Julian date of the Unix epoch, 1970-01-01T00:00Z.
const UNIX_EPOCH := 2440587.5
const DAY := 86400.0


# ------------------------------------------------------------------ calendars

## Julian date from a UTC calendar date (Meeus, chapter 7), Gregorian calendar.
static func julian_day(year: int, month: int, day: int, hour := 0, minute := 0,
		second := 0.0) -> float:
	var y := year
	var m := month
	if m <= 2:
		y -= 1
		m += 12
	var a := floori(float(y) / 100.0)
	var b := 2 - a + floori(float(a) / 4.0)
	var days := floori(365.25 * float(y + 4716)) + floori(30.6001 * float(m + 1)) \
			+ day + b
	var fraction := (float(hour) + (float(minute) + second / 60.0) / 60.0) / 24.0
	return float(days) - 1524.5 + fraction


static func julian_day_from_unix(unix: float) -> float:
	return UNIX_EPOCH + unix / DAY


static func unix_from_julian_day(jd: float) -> float:
	return (jd - UNIX_EPOCH) * DAY


# -------------------------------------------------------------- sidereal time

## Greenwich mean sidereal time in degrees (计划 §6.2). U.T. in, 0.1 s of arc of
## the polynomial's own accuracy - it reproduces Meeus' worked example 12.a to
## 2e-5 s (tests/sky_probe.gd).
static func gmst_deg(jd: float) -> float:
	var t := (jd - J2000) / 36525.0
	var turns := 280.46061837 + 360.98564736629 * (jd - J2000) + 0.000387933 * t * t \
			- t * t * t / 38710000.0
	return fposmod(turns, 360.0)


## Local mean sidereal time in degrees; `longitude_east` is degrees east of
## Greenwich.
static func lst_deg(jd: float, longitude_east: float) -> float:
	return fposmod(gmst_deg(jd) + longitude_east, 360.0)


## Mean obliquity of the ecliptic in degrees (IAU 1976).
static func obliquity_deg(jd: float) -> float:
	var t := (jd - J2000) / 36525.0
	return 23.4392911 - 0.0130042 * t - 1.64e-7 * t * t + 5.04e-7 * t * t * t


# ---------------------------------------------------------------- orientations

## Rotation from the catalogue frame at J2000 to the catalogue frame at `jd`,
## built from the images of its three axes and reusing Precession's own angles.
static func precession_basis(jd: float) -> Basis:
	return Basis(
		Precession.direction(J2000, jd, 0.0, 0.0),
		Precession.direction(J2000, jd, 0.0, 90.0),
		Precession.direction(J2000, jd, 270.0, 0.0))


## Rotation from the catalogue frame to world, with the pole already tilted by
## the observer's latitude: the sky is turned by local sidereal time so RA =
## LST sits on the meridian, then the whole sphere is tipped so the celestial
## pole stands at an altitude of `latitude_deg` due north.
static func sky_basis(jd: float, latitude_deg: float, longitude_east: float) -> Basis:
	var lst := deg_to_rad(lst_deg(jd, longitude_east))
	var lat := deg_to_rad(latitude_deg)
	var cos_lst := cos(lst)
	var sin_lst := sin(lst)
	var cos_lat := cos(lat)
	var sin_lat := sin(lat)
	# (g1, g2, g3) = (cos d cos H, cos d sin H, sin d): the hour-angle frame
	var hour := Basis(Vector3(cos_lst, sin_lst, 0.0), Vector3(0.0, 0.0, 1.0),
			Vector3(-sin_lst, cos_lst, 0.0))
	var tilt := Basis(Vector3(0.0, cos_lat, -sin_lat), Vector3(1.0, 0.0, 0.0),
			Vector3(0.0, sin_lat, cos_lat))
	return tilt * hour * precession_basis(jd)


## World direction of a bearing: azimuth in degrees from north towards east,
## altitude in degrees above the horizon.
static func horizon_direction(azimuth_deg: float, altitude_deg: float) -> Vector3:
	var azimuth := deg_to_rad(azimuth_deg)
	var altitude := deg_to_rad(altitude_deg)
	return Vector3(-cos(altitude) * sin(azimuth), sin(altitude),
			cos(altitude) * cos(azimuth))


## The up of a nivelated camera looking along that bearing: the tangent to the
## sky's vertical circle there - the direction altitude grows in - so the horizon
## stays level however high the view is. It has to be perpendicular to
## horizon_direction(); looking_at() resolves whatever is handed to it, so a
## wrong sign here does not fail loudly, it rolls the camera.
static func horizon_up(azimuth_deg: float, altitude_deg: float) -> Vector3:
	var azimuth := deg_to_rad(azimuth_deg)
	var altitude := deg_to_rad(altitude_deg)
	return Vector3(sin(altitude) * sin(azimuth), cos(altitude),
			-sin(altitude) * cos(azimuth))


static func altitude_of(direction: Vector3) -> float:
	return rad_to_deg(asin(clampf(direction.normalized().y, -1.0, 1.0)))


static func azimuth_of(direction: Vector3) -> float:
	var level := direction.normalized()
	return fposmod(rad_to_deg(atan2(-level.x, level.z)), 360.0)


## Altitude and azimuth of an equatorial position, straight from the spherical
## trigonometry (计划 §6.2) rather than through sky_basis(). Returns
## Vector2(altitude, azimuth); the two paths agreeing is what tests/sky_probe.gd
## checks. `ra_deg`/`dec_deg` must be for the same equinox as `sidereal_deg`,
## which is local sidereal time in degrees (lst_deg() above).
static func altaz(ra_deg: float, dec_deg: float, sidereal_deg: float,
		latitude_deg: float) -> Vector2:
	var hour_angle := deg_to_rad(sidereal_deg - ra_deg)
	var ra := deg_to_rad(ra_deg)
	var dec := deg_to_rad(dec_deg)
	var lat := deg_to_rad(latitude_deg)
	var altitude := asin(clampf(sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(hour_angle),
			-1.0, 1.0))
	var azimuth := atan2(-cos(dec) * sin(hour_angle),
			sin(dec) * cos(lat) - cos(dec) * sin(lat) * cos(hour_angle))
	return Vector2(rad_to_deg(altitude), fposmod(rad_to_deg(azimuth), 360.0))


# -------------------------------------------------------------------- ecliptic

## Equatorial from ecliptic coordinates. Returns Vector2(right ascension,
## declination), both degrees (Meeus 13.3).
static func ecliptic_to_equatorial(lambda_deg: float, beta_deg: float, jd: float) -> Vector2:
	var eps := deg_to_rad(obliquity_deg(jd))
	var lambda := deg_to_rad(lambda_deg)
	var beta := deg_to_rad(beta_deg)
	var ra := atan2(sin(lambda) * cos(eps) - tan(beta) * sin(eps), cos(lambda))
	var dec := asin(clampf(sin(beta) * cos(eps) + cos(beta) * sin(eps) * sin(lambda),
			-1.0, 1.0))
	return Vector2(fposmod(rad_to_deg(ra), 360.0), rad_to_deg(dec))


## Ecliptic from equatorial coordinates. Returns Vector2(longitude, latitude).
static func equatorial_to_ecliptic(ra_deg: float, dec_deg: float, jd: float) -> Vector2:
	var eps := deg_to_rad(obliquity_deg(jd))
	var ra := deg_to_rad(ra_deg)
	var dec := deg_to_rad(dec_deg)
	var lambda := atan2(sin(ra) * cos(eps) + tan(dec) * sin(eps), cos(ra))
	var beta := asin(clampf(sin(dec) * cos(eps) - cos(dec) * sin(eps) * sin(ra),
			-1.0, 1.0))
	return Vector2(fposmod(rad_to_deg(lambda), 360.0), rad_to_deg(beta))


# ----------------------------------------------------------------- time scales

## TT from UT. The Sun and Moon below are written for dynamical time, which is
## what their periodic terms describe, while the clock and the sidereal time are
## UT - so the two scales meet here rather than being folded into one instant.
static func tt_from_ut(jd_ut: float) -> float:
	return jd_ut + delta_t_seconds(jd_ut) / DAY


## Delta T = TT - UT in seconds: the polynomial set Espenak & Meeus derived for
## NASA's Five Millennium Canon, which spans -1999..+3000. `y` is the Julian
## year; the published form reads it at the middle of a month, which moves the
## result by a fraction of a second.
##
## The modern piece is an extrapolation made in 2005, and the Earth has been
## turning faster than it assumed since 2016 (no leap second since 2017), so it
## reads some 6 s high today - 3 arcsec of Moon. Nothing else here depends on it.
static func delta_t_seconds(jd_ut: float) -> float:
	var y := 2000.0 + (jd_ut - J2000) / 365.25
	var u := 0.0
	if y < -500.0:
		u = (y - 1820.0) / 100.0
		return -20.0 + 32.0 * u * u
	if y < 500.0:
		u = y / 100.0
		return 10583.6 - 1014.41 * u + 33.78311 * u * u - 5.952053 * u * u * u \
				- 0.1798452 * pow(u, 4) + 0.022174192 * pow(u, 5) \
				+ 0.0090316521 * pow(u, 6)
	if y < 1600.0:
		u = (y - 1000.0) / 100.0
		return 1574.2 - 556.01 * u + 71.23472 * u * u + 0.319781 * u * u * u \
				- 0.8503463 * pow(u, 4) - 0.005050998 * pow(u, 5) \
				+ 0.0083572073 * pow(u, 6)
	if y < 1700.0:
		u = y - 1600.0
		return 120.0 - 0.9808 * u - 0.01532 * u * u + u * u * u / 7129.0
	if y < 1800.0:
		u = y - 1700.0
		return 8.83 + 0.1603 * u - 0.0059285 * u * u + 0.00013336 * u * u * u \
				- pow(u, 4) / 1174000.0
	if y < 1860.0:
		u = y - 1800.0
		return 13.72 - 0.332447 * u + 0.0068612 * u * u + 0.0041116 * u * u * u \
				- 0.00037436 * pow(u, 4) + 0.0000121272 * pow(u, 5) \
				- 0.0000001699 * pow(u, 6) + 0.000000000875 * pow(u, 7)
	if y < 1900.0:
		u = y - 1860.0
		return 7.62 + 0.5737 * u - 0.251754 * u * u + 0.01680668 * u * u * u \
				- 0.0004473624 * pow(u, 4) + pow(u, 5) / 233174.0
	if y < 1920.0:
		u = y - 1900.0
		return -2.79 + 1.494119 * u - 0.0598939 * u * u + 0.0061966 * u * u * u \
				- 0.000197 * pow(u, 4)
	if y < 1941.0:
		u = y - 1920.0
		return 21.20 + 0.84493 * u - 0.076100 * u * u + 0.0020936 * u * u * u
	if y < 1961.0:
		u = y - 1950.0
		return 29.07 + 0.407 * u - u * u / 233.0 + u * u * u / 2547.0
	if y < 1986.0:
		u = y - 1975.0
		return 45.45 + 1.067 * u - u * u / 260.0 - u * u * u / 718.0
	if y < 2005.0:
		u = y - 2000.0
		return 63.86 + 0.3345 * u - 0.060374 * u * u + 0.0017275 * u * u * u \
				+ 0.000651814 * pow(u, 4) + 0.00002373599 * pow(u, 5)
	if y < 2050.0:
		u = y - 2000.0
		return 62.92 + 0.32217 * u + 0.005589 * u * u
	u = (y - 1820.0) / 100.0
	if y < 2150.0:
		return -20.0 + 32.0 * u * u - 0.5628 * (2150.0 - y)
	return -20.0 + 32.0 * u * u


# -------------------------------------------------------------------- the sun

## Nutation in longitude in degrees: the four largest terms of Meeus 22, good to
## half an arcsecond. It is what carries a longitude into the true equinox of
## date, the frame the apparent positions below are given in.
static func nutation_longitude_deg(jd: float) -> float:
	var t := (jd - J2000) / 36525.0
	var node := deg_to_rad(125.04452 - 1934.136261 * t + 0.0020708 * t * t
			+ t * t * t / 450000.0)
	var sun_mean := deg_to_rad(280.4665 + 36000.7698 * t)
	var moon_mean := deg_to_rad(218.3165 + 481267.8813 * t)
	return (-17.20 * sin(node) - 1.32 * sin(2.0 * sun_mean)
			- 0.23 * sin(2.0 * moon_mean) + 0.21 * sin(2.0 * node)) / 3600.0


## The Sun's geometric longitude in degrees, mean equinox of date (Meeus 25):
## the mean longitude plus the equation of the centre.
static func sun_true_longitude_deg(jd: float) -> float:
	var t := (jd - J2000) / 36525.0
	var anomaly := 357.52911 + 35999.05029 * t - 0.0001537 * t * t
	return fposmod(280.46646 + 36000.76983 * t + 0.0003032 * t * t \
			+ _solar_centre_deg(t, anomaly), 360.0)


## Apparent longitude of the Sun in degrees, true equinox of date: the true
## longitude, the equinox moved by nutation, and the 8.3 minutes the light took.
## Meeus 25's own 0.01 deg rests on the truncated equation of the centre.
static func sun_apparent_longitude_deg(jd: float) -> float:
	var t := (jd - J2000) / 36525.0
	var anomaly := 357.52911 + 35999.05029 * t - 0.0001537 * t * t
	return fposmod(sun_true_longitude_deg(jd) + nutation_longitude_deg(jd) \
			- 20.4898 / sun_radius_au(jd) / 3600.0, 360.0)


## The Sun's distance from the Earth in astronomical units (Meeus 25: the radius
## vector of the orbit, from the true anomaly).
static func sun_radius_au(jd: float) -> float:
	var t := (jd - J2000) / 36525.0
	var anomaly := 357.52911 + 35999.05029 * t - 0.0001537 * t * t
	var eccentricity := 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t
	var true_anomaly := deg_to_rad(anomaly + _solar_centre_deg(t, anomaly))
	return 1.000001018 * (1.0 - eccentricity * eccentricity) \
			/ (1.0 + eccentricity * cos(true_anomaly))


## Apparent geocentric position of the Sun: Vector2(right ascension, declination)
## in degrees, true equinox of date.
static func sun_position(jd: float) -> Vector2:
	return ecliptic_to_equatorial(sun_apparent_longitude_deg(jd), 0.0, jd)


## The equation of the centre in degrees, from the Sun's mean anomaly in degrees.
static func _solar_centre_deg(t: float, mean_anomaly_deg: float) -> float:
	var anomaly := deg_to_rad(mean_anomaly_deg)
	return (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(anomaly) \
			+ (0.019993 - 0.000101 * t) * sin(2.0 * anomaly) \
			+ 0.000289 * sin(3.0 * anomaly)


# ------------------------------------------------------------------- the moon

## Where the Moon is at one instant: apparent geocentric position, distance,
## apparent size, and how much of the disc the Sun lights. One result rather than
## four functions, so a consumer never sums the periodic terms twice.
class MoonState extends RefCounted:
	var lambda := 0.0          ## apparent geocentric ecliptic longitude, degrees
	var beta := 0.0            ## ecliptic latitude, degrees
	var ra := 0.0              ## apparent right ascension, degrees
	var dec := 0.0             ## apparent declination, degrees
	var distance_km := 0.0     ## between the centres
	var radius_deg := 0.0      ## apparent angular radius of the disc
	var elongation_deg := 0.0  ## Moon minus Sun in longitude: 0 new, 180 full
	var illuminated := 0.0     ## fraction of the disc the Sun lights


## Geocentric position of the Moon (Meeus 47). The 60 periodic terms are
## LunarTerms' data; the sum, and the additive terms for Venus, Jupiter and the
## flattening of the Earth, are here.
static func moon_state(jd: float) -> MoonState:
	var t := (jd - J2000) / 36525.0
	var mean_longitude := 218.3164477 + 481267.88123421 * t - 0.0015786 * t * t \
			+ t * t * t / 538841.0 - t * t * t * t / 65194000.0
	var mean_elongation := 297.8501921 + 445267.1114034 * t - 0.0018819 * t * t \
			+ t * t * t / 545868.0 - t * t * t * t / 113065000.0
	var sun_anomaly := 357.5291092 + 35999.0502909 * t - 0.0001536 * t * t \
			+ t * t * t / 24490000.0
	var moon_anomaly := 134.9633964 + 477198.8675055 * t + 0.0087414 * t * t \
			+ t * t * t / 69699.0 - t * t * t * t / 14712000.0
	var latitude_argument := 93.2720950 + 483202.0175233 * t - 0.0036539 * t * t \
			- t * t * t / 3526000.0 + t * t * t * t / 863310000.0
	# the Earth's orbit is slowly circularising, which scales every term that
	# carries the Sun's anomaly
	var eccentricity := 1.0 - 0.002516 * t - 0.0000074 * t * t
	var arguments := [deg_to_rad(mean_elongation), deg_to_rad(sun_anomaly),
			deg_to_rad(moon_anomaly), deg_to_rad(latitude_argument)]
	var mean_longitude_rad := deg_to_rad(mean_longitude)
	var latitude_argument_rad := deg_to_rad(latitude_argument)
	var moon_anomaly_rad := deg_to_rad(moon_anomaly)

	var sum_longitude := 0.0
	var sum_distance := 0.0
	for term in LunarTerms.LONGITUDE_DISTANCE:
		var angle := _term_angle(term, arguments)
		var scale := pow(eccentricity, absi(term[1]))
		sum_longitude += float(term[4]) * scale * sin(angle)
		sum_distance += float(term[5]) * scale * cos(angle)
	# Venus, Jupiter, and the flattening of the Earth: the additive terms of
	# Meeus' table, which the 60 rows above do not include
	var a1 := deg_to_rad(119.75 + 131.849 * t)
	var a2 := deg_to_rad(53.09 + 479264.290 * t)
	sum_longitude += 3958.0 * sin(a1) \
			+ 1962.0 * sin(mean_longitude_rad - latitude_argument_rad) \
			+ 318.0 * sin(a2)

	var sum_latitude := 0.0
	for term in LunarTerms.LATITUDE:
		sum_latitude += float(term[4]) * pow(eccentricity, absi(term[1])) \
				* sin(_term_angle(term, arguments))
	var a3 := deg_to_rad(313.45 + 481266.484 * t)
	sum_latitude += -2235.0 * sin(mean_longitude_rad) + 382.0 * sin(a3) \
			+ 175.0 * sin(a1 - latitude_argument_rad) \
			+ 175.0 * sin(a1 + latitude_argument_rad) \
			+ 127.0 * sin(mean_longitude_rad - moon_anomaly_rad) \
			- 115.0 * sin(mean_longitude_rad + moon_anomaly_rad)

	var state := MoonState.new()
	state.lambda = fposmod(mean_longitude + sum_longitude / 1000000.0
			+ nutation_longitude_deg(jd), 360.0)
	state.beta = sum_latitude / 1000000.0
	state.distance_km = 385000.56 + sum_distance / 1000.0
	# Meeus 47: s = 358473400 / Delta arcseconds, from the Moon's radius
	state.radius_deg = 358473400.0 / state.distance_km / 3600.0
	var position := ecliptic_to_equatorial(state.lambda, state.beta, jd)
	state.ra = position.x
	state.dec = position.y
	state.elongation_deg = fposmod(state.lambda - sun_apparent_longitude_deg(jd),
			360.0)
	state.illuminated = illuminated_fraction(state.elongation_deg)
	return state


## One periodic term's angle: its four integer multipliers against (D, M, M', F).
static func _term_angle(term: Array, arguments: Array) -> float:
	return float(term[0]) * arguments[0] + float(term[1]) * arguments[1] \
			+ float(term[2]) * arguments[2] + float(term[3]) * arguments[3]


## Illuminated fraction of a disc whose elongation from the Sun is
## `elongation_deg`: 0 at new moon, 1 at full. The terminator is the ellipse a
## sphere lit from that angle shows, which is what the sky draws too.
static func illuminated_fraction(elongation_deg: float) -> float:
	return (1.0 - cos(deg_to_rad(elongation_deg))) * 0.5


## The traditional names, on the 45 deg boundaries the quarters are named for:
## 上弦月 is the point 90 deg east of the Sun, where the Moon is a quarter of the
## way round.
const PHASE_NAMES := ["新月", "蛾眉月", "上弦月", "盈凸月", "满月", "亏凸月", "下弦月", "残月"]


static func moon_phase_name(elongation_deg: float) -> String:
	return PHASE_NAMES[int(floor(fposmod(elongation_deg + 22.5, 360.0) / 45.0))]


# ------------------------------------------------------------- the day's light

## How much of the day's light the sky has, from the Sun's altitude in degrees:
## full with the Sun up, gone by the end of astronomical twilight. The dome
## crosses its two palettes by this, and the star layers take 1 - this.
static func daylight(sun_altitude_deg: float) -> float:
	return smoothstep(-12.0, 0.0, sun_altitude_deg)


## Strength of the glow that hugs the horizon while the Sun is just below it,
## strongest near the end of civil twilight.
static func twilight(sun_altitude_deg: float) -> float:
	return exp(-pow((sun_altitude_deg + 4.0) / 6.0, 2.0))


# ------------------------------------------------------- date into the sphere

## A position given for the equinox of date, expressed in the frame the star
## catalogue is kept in (StarCat.direction) - the frame SkyRoot holds. It is the
## inverse of the precession sky_basis() applies, so the Sun, the Moon and the
## planets are computed for the equinox of date and drawn through this, and the
## sphere still turns as one piece.
static func local_from_date(jd: float, ra_deg: float, dec_deg: float) -> Vector3:
	return precession_basis(jd).transposed() * StarCat.direction(ra_deg, dec_deg)
