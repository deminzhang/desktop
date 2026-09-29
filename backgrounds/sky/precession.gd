## Precession between standard equinoxes, IAU 1976 angles (Meeus, Astronomical
## Algorithms, chapter 21).
##
## The constellation boundaries are published for B1875 (Delporte 1930) while the
## star catalogue is J2000, so the boundary corners have to be carried forward
## before they can sit on the same sphere as the stars. S3 will want the same
## machinery to move the whole sky to an arbitrary date.
class_name Precession
extends RefCounted

const J2000 := 2451545.0
## Julian date of B1875.0, the equinox the boundary catalogue is referred to.
const B1875 := 2405889.25855


## Precess equatorial degrees from one equinox to another and return the
## direction on the sphere.
static func direction(from_jd: float, to_jd: float, ra_deg: float,
		dec_deg: float) -> Vector3:
	var angles := _angles(from_jd, to_jd)
	var zeta := deg_to_rad(angles.x)
	var z := deg_to_rad(angles.y)
	var theta := deg_to_rad(angles.z)
	var ra := deg_to_rad(ra_deg)
	var dec := deg_to_rad(dec_deg)
	var x := cos(dec) * cos(ra)
	var y := cos(dec) * sin(ra)
	var up := sin(dec)

	# Meeus 21.4: the equinox moves, so the coordinates rotate by Rz(-z)Ry(theta)Rz(-zeta)
	var out_x := (cos(zeta) * cos(theta) * cos(z) - sin(zeta) * sin(z)) * x \
			+ (-sin(zeta) * cos(theta) * cos(z) - cos(zeta) * sin(z)) * y \
			+ (-sin(theta) * cos(z)) * up
	var out_y := (cos(zeta) * cos(theta) * sin(z) + sin(zeta) * cos(z)) * x \
			+ (-sin(zeta) * cos(theta) * sin(z) + cos(zeta) * cos(z)) * y \
			+ (-sin(theta) * sin(z)) * up
	var out_up := (cos(zeta) * sin(theta)) * x + (-sin(zeta) * sin(theta)) * y \
			+ cos(theta) * up
	return StarCat.direction(rad_to_deg(atan2(out_y, out_x)), rad_to_deg(asin(out_up)))


## (zeta, z, theta) in degrees for the interval, positive from `from_jd` to
## `to_jd`.
static func _angles(from_jd: float, to_jd: float) -> Vector3:
	var big_t := (from_jd - J2000) / 36525.0
	var t := (to_jd - from_jd) / 36525.0
	var zeta := (2306.2181 + 1.39656 * big_t - 0.000139 * big_t * big_t) * t \
			+ (0.30188 - 0.000344 * big_t) * t * t + 0.017998 * t * t * t
	var z := (2306.2181 + 1.39656 * big_t - 0.000139 * big_t * big_t) * t \
			+ (1.09468 + 0.000066 * big_t) * t * t + 0.018203 * t * t * t
	var theta := (2004.3109 - 0.85330 * big_t - 0.000217 * big_t * big_t) * t \
			- (0.42665 + 0.000217 * big_t) * t * t - 0.041833 * t * t * t
	return Vector3(zeta / 3600.0, z / 3600.0, theta / 3600.0)
