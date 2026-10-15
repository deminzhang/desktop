## VSOP87B for the two planetary rows JPL's approximate elements cannot hold
## (README「验证」, 2026-10-10).
##
## The element rows in planets.gd are a straight-rate fit: they follow Mercury
## through Neptune to a few arcseconds *except* where the great inequality of
## Jupiter and Saturn lives. Measured against JPL Horizons over 1800-2050 the fit
## misses 木星 by 425" and 土星 by 631" - over the five arcminutes README「验证」 asserts, and
## nothing a better fit of the same kind fixes (both element sets were measured,
## README G33).
##
## So those two rows come from VSOP87 instead: the Bureau des Longitudes' series,
## whose "B" version is heliocentric spherical ecliptic and equinox J2000 - the
## frame ELEMENTS is written in, so a row swap needs no conversion at all, only the
## Kepler solve (which the series replaces) and the light-time pass (which stays in
## planets.gd).
##
## The file is truncated at A >= 1e-6 rad, which drops 4,400 of the 5,300 terms and
## leaves at most 0.43" (木星) / 0.24" (土星) of position error over 1800-2050 - two
## orders of magnitude inside what the two planets need, and still forty kilobytes
## rather than the four hundred the untruncated tables take.
class_name Vsop87
extends RefCounted

const DATA := "res://backgrounds/sky/data/vsop87b.dat"
## The bodies the file carries, keyed the way it writes them.
const BODIES := ["J", "S"]
## Powers of T the series is summed over: VSOP87 terminates at T^5.
const POWERS := 6
## One Julian millennium (VSOP87's own T unit, 365250 days) is ten Julian centuries,
## which is what planets.gd's t is.
const MILLENNIA := 10.0

## body+variable+power -> the terms A, B, C of  A*cos(B + C*T), three per term.
static var _series := {}
static var _loaded := false


## Reads the table once. A missing file is a loud error, not a silent zero: a body
## with no terms would put its planet at the Sun.
static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var text := FileAccess.get_file_as_string(DATA)
	if text.is_empty():
		push_error("Vsop87: table missing at %s" % DATA)
		return
	var collected := {}
	for line in text.split("\n"):
		var fields := line.split(" ", false)
		if fields.size() < 6 or fields[0].begins_with("#"):
			continue
		var key := fields[0] + fields[1] + fields[2]
		var terms: Array = collected.get(key, [])
		terms.append(float(fields[3]))
		terms.append(float(fields[4]))
		terms.append(float(fields[5]))
		collected[key] = terms
	for key in collected:
		var packed := PackedFloat64Array()
		packed.resize(0)
		packed.append_array(collected[key] as Array)
		_series[key] = packed


## How many terms a body's three coordinates are summed from - what a probe reads
## to tell a truncated table from a missing one.
static func term_count(body: String) -> int:
	_load()
	var total := 0
	for variable in ["L", "B", "R"]:
		for power in POWERS:
			var terms: PackedFloat64Array = _series.get(body + variable + str(power),
					PackedFloat64Array())
			total += terms.size() / 3
	return total


## Heliocentric position of `body` ("J" or "S") at `centuries` Julian centuries past
## J2000, in astronomical units in the J2000 ecliptic frame: the same pair of
## quantities - and the same frame - that planets.gd's heliocentric() returns for an
## ELEMENTS row, so the two are interchangeable.
static func heliocentric(body: String, centuries: float) -> Vector3:
	_load()
	var t := centuries / MILLENNIA
	var longitude := _sum(body, "L", t)
	var latitude := _sum(body, "B", t)
	var radius := _sum(body, "R", t)
	var flat := cos(latitude)
	return Vector3(radius * flat * cos(longitude), radius * flat * sin(longitude),
			radius * sin(latitude))


## One coordinate of one body: the six powers of T, each the sum of its own terms.
## The terms are three floats each in a packed array - this is the hot loop of the
## whole ephemeris (the trail re-walks a month of positions every day).
static func _sum(body: String, variable: String, t: float) -> float:
	var total := 0.0
	var power := 1.0
	for exponent in POWERS:
		var terms: PackedFloat64Array = _series.get(body + variable + str(exponent),
				PackedFloat64Array())
		var part := 0.0
		var index := 0
		while index < terms.size():
			part += terms[index] * cos(terms[index + 1] + terms[index + 2] * t)
			index += 3
		total += part * power
		power *= t
	return total
