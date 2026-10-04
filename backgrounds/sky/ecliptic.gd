## The ecliptic - the Sun's yearly path on the celestial sphere - and the
## divisions that hang off it (计划 §6.4 rings, §6.5 S6).
##
## One number runs through all of it: solar longitude λ, the same angle the Sun's
## ephemeris reports. The twelve 宫 are λ in 30 deg steps from the vernal equinox,
## the twenty-four 节气 λ in 15 deg steps - and the 中气 are exactly the 宫
## boundaries. The sphere's ticks and any ring a dial puts round them read these
## from here rather than each keeping a copy, so the drawn circle and the dial
## stay the same sky.
##
## λ is measured from the equinox *of the instant the sky is showing*, so the
## divisions are folded from that equinox's frame into the catalogue's own J2000
## one (Astro.local_from_date) once, and the layer is static geometry on SkyRoot
## that turns with the sky - the same reason the stars and the figures are.
##
## The fold matters because the two equinoxes are not the same point: general
## precession walks the vernal equinox 50.3 arcsec a year along the ecliptic, so
## a circle built from the J2000 equinox puts its 春分 tick 0.366 deg (2026) from
## where the Sun actually reaches λ = 0 - nine hours of the Sun's own motion, and
## one degree by 2100. The plane is the same either way (0.001 deg); only the
## origin of λ moves. The circle and its ticks therefore have to be built for an
## instant, which is why `build()` takes one - and why the drawn circle and the
## HUD's readings of λ, which come from the Sun's ephemeris, agree.
class_name Ecliptic
extends RefCounted

## Thin-ribbon shader shared with SkyLines: additive hairlines with the
## world-space horizon mask.
const SHADER := "res://backgrounds/sky/shaders/line.gdshader"

## Just inside the constellation figures (SkyLines.RADIUS = 476).
const RADIUS := 470.0
const WIDTH := 0.45          ## the great circle itself, world units at RADIUS
const TICK_WIDTH := 0.40
## Half-length of a tick across the ecliptic, degrees of latitude: the 中气 ticks
## reach further than the 节令 ones that sit between them.
const TICK_LONG := 0.75
const TICK_SHORT := 0.45

## Additive and dim like the figures, but warm: the ecliptic is the one line on
## the sky that is about the Sun. Linear, like every vertex colour in the sky
## (计划 §2.3 G4).
const COLOUR := Color(0.130, 0.092, 0.030)

## The twelve signs, 30 deg of λ each, from the vernal equinox (白羊 = Aries).
const SIGNS := ["白羊", "金牛", "双子", "巨蟹", "狮子", "处女",
		"天秤", "天蝎", "人马", "摩羯", "宝瓶", "双鱼"]

## The twenty-four solar terms, 15 deg of λ apart, from the vernal equinox. Even
## indices are the 中气 (春分, 谷雨, …), odd ones the 节令 (清明, 立夏, …) - and
## the 中气 are exactly the sign boundaries.
const TERMS := ["春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至", "小暑",
		"大暑", "立秋", "处暑", "白露", "秋分", "寒露", "霜降", "立冬",
		"小雪", "大雪", "冬至", "小寒", "大寒", "立春", "雨水", "惊蛰"]


# ------------------------------------------------------------------- divisions

## Longitude at which sign `index` begins: 0 = 白羊, at the vernal equinox.
static func sign_longitude(index: int) -> float:
	return float(index) * 30.0


## Longitude at which solar term `index` begins: 0 = 春分, at λ = 0.
static func term_longitude(index: int) -> float:
	return float(index) * 15.0


## The two equinoxes and the two solstices (2026-10-12): the four signs' quarters,
## λ = 0 / 90 / 180 / 270. They are four of the 中气, and λ = 0 carries a tick like
## every other term - a tick among twenty-four says nothing about which way the
## circle is read, so the four points are named on the sky as well (SkyLabels). The
## names come off TERMS, every sixth entry, rather than a second table that could
## drift from it.
const CARDINAL_STEP := 90.0


## The four cardinal points as [name, direction] pairs, at λ = 90° x index, in the
## catalogue frame of the equinox of `jd` - the same fold the circle and its ticks
## take, so a name stands on the point the HUD's own readings of λ are measured from.
static func cardinal_points(jd: float) -> Array:
	var points := []
	for quarter in 4:
		points.append({"name": TERMS[quarter * 6],
				"direction": direction(jd, CARDINAL_STEP * float(quarter))})
	return points


## Which sign a longitude falls in (0..11), and its name.
static func sign_of(lambda_deg: float) -> int:
	return int(floor(fposmod(lambda_deg, 360.0) / 30.0))


static func sign_name(lambda_deg: float) -> String:
	return SIGNS[sign_of(lambda_deg)]


## Which solar term is in force at a longitude (0..23), and its name.
static func term_of(lambda_deg: float) -> int:
	return int(floor(fposmod(lambda_deg, 360.0) / 15.0))


static func term_name(lambda_deg: float) -> String:
	return TERMS[term_of(lambda_deg)]


# -------------------------------------------------------------------- geometry

## Unit direction, in the catalogue frame, of the point at longitude λ, latitude
## β, as of the equinox of `jd`. β = 0 is the ecliptic itself; β > 0 is north of
## it.
static func point(jd: float, lambda_deg: float, beta_deg: float) -> Vector3:
	var equatorial := Astro.ecliptic_to_equatorial(lambda_deg, beta_deg, jd)
	return Astro.local_from_date(jd, equatorial.x, equatorial.y)


## A point of the ecliptic itself.
static func direction(jd: float, lambda_deg: float) -> Vector3:
	return point(jd, lambda_deg, 0.0)


## North pole of the ecliptic of `jd`.
static func pole(jd: float) -> Vector3:
	return Astro.local_from_date(jd, 270.0, 90.0 - Astro.obliquity_deg(jd))


## The ecliptic as geometry under `parent` (SkyRoot) for the instant `jd`: the
## great circle walked in one-degree steps and a tick across it at each of the
## twenty-four solar terms. Returns the two layers so the sky can feed them the
## light of day and the zoom, the way it does the figures.
##
## Static from here on: the wall clock's own drift through the precession is
## 0.0001 deg a day, so the layer is built once and only ever turns with SkyRoot.
static func build(parent: Node3D, jd: float) -> Array:
	var walk := []
	for i in 361:
		walk.append(direction(jd, float(i)))
	var circle := SkyLines.polyline_layer(parent, [walk], WIDTH, COLOUR, "Ecliptic")

	var ticks := []
	for i in TERMS.size():
		var lambda := term_longitude(i)
		var reach := TICK_LONG if i % 2 == 0 else TICK_SHORT
		ticks.append([point(jd, lambda, -reach), point(jd, lambda, reach)])
	var marks := SkyLines.polyline_layer(parent, ticks, TICK_WIDTH, COLOUR, "EclipticTerms")
	return [circle, marks]
