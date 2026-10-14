## The Chinese calendar the sky is read in (README「HUD 罗盘规格（自内向外）」): the four pillars
## (年/月/日/时 干支), the solar term in force, the 三元九运 the year sits in and
## the 旬 the day sits in - the inputs every 术数 chart is cast from, handed to
## `QiMen.pan()` and `LiuRen.pan()` as one dictionary.
##
## The terms come out of astro.gd's own Sun: a term begins the instant the apparent
## solar longitude crosses a 15 deg step, the same definition the ecliptic and 宿
## marks and the equinox and solstice readings README「验证」 lists are held to, so
## no third-party almanac is needed (the reference project
## leans on the lunar-calendar plugin for this). Everything else counts off that
## and off the day cycle: the year turns at 立春, the month at each 节, the day on
## the 60-cycle of the Julian day number, the hour by 五鼠遁 from the day stem.
## 23:00 starts the next 术数日 - the day pillar turning at 子时初 is older than
## the civil midnight and is what 排盘 is done on.
##
## `local` is the observer's own civil date and time (`Observer.local_datetime`),
## because the pillars are read in local time even though the terms are instants.
class_name GanZhi
extends RefCounted

const GAN := ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
const ZHI := ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]

## Where the 60-cycle sits on the Julian day number: 甲子 is the day with
## JDN ≡ -49 (mod 60). Anchored against the reference almanac - 2026-01-22 comes
## out 丙申 and 2026-09-29 丙午 by it, as the oracle in front of this port has it.
const DAY_ANCHOR := 49

## The 中气 of `Ecliptic.TERMS` are the even indices and the 节 the odd ones; 立春
## is index 21 (λ = 315 deg), and it is the 节 the year pillar turns at.
const LICHUN := 21

## 立春 turns the month into 寅, and the 五虎遁 counts the month stems from there.
const YIN := 2


## The four pillars, the 时辰's branch index and the term in force.
static func of(jd_ut: float, local: Dictionary) -> Dictionary:
	var index := term_index(jd_ut)
	var civil := int(local.get("year", 2000))
	var year := civil - (1 if jd_ut < lichun_jd(civil) else 0)
	var year_gan := posmod(year - 4, 60)

	# 五虎遁: the 寅 month's stem follows the year stem (甲己之年丙作首 …), and
	# the months run on from it one per 节
	var month := ((index - LICHUN + 24) % 24) / 2
	var month_gan := posmod((year_gan % 5) * 2 + 2 + month, 10)

	var hour := int(local.get("hour", 0))
	var hour_branch := Branches.index_of_hour(hour)
	# 23:00 is already the next day, which is the same rollover 术数 practice makes
	var jdn := int(Astro.julian_day(int(local.get("year", 2000)),
			int(local.get("month", 1)), int(local.get("day", 1)))) + 1 \
			+ (1 if hour >= 23 else 0)
	var day := posmod(jdn + DAY_ANCHOR, 60)

	# 五鼠遁: 甲己还加甲 - the hour stem counts from the day stem by the 时辰
	var hour_gan := posmod((day % 10) * 2 + hour_branch, 10)

	return {
		"year": GAN[year_gan % 10] + ZHI[year_gan % 12],
		"month": GAN[month_gan] + ZHI[(YIN + month) % 12],
		"day": GAN[day % 10] + ZHI[day % 12],
		"hour": GAN[hour_gan] + ZHI[hour_branch],
		"hour_branch": hour_branch,
		"term": Ecliptic.TERMS[index],
		"term_index": index,
		# the 立春-turned year itself, which the 三元九运 below counts off
		"year_number": year,
	}


# ------------------------------------------------------------- 三元九运

## 1864 (甲子年, 立春) opens 上元一运, and the 180-year cycle runs on from it in
## twenty-year 运: 1984-2003 is 下元七运, 2004-2023 八运, 2024-2043 九运. The 运
## turns with the same 立春 the 年柱 does, which is why it is called with
## `year_number` and not with the civil year. Every three 运 make one 元
## (`index / 60`), which is what the 三元 in 三元九运 names.
const YUAN_START := 1864
## The 运 written the way the HUD carries it (用户 2026-10-10 第二十轮): the 玄空 name
## of the 运's own palace - 星名 + 卦 + 五行, 一白坎水 … 九紫离火 - rather than the
## count "下元九运". The 三元 is still what the cycle is counted in; only the name
## that goes on the line is this one.
const YUN_NAMES := ["一白坎水", "二黑坤土", "三碧震木", "四绿巽木", "五黄中土",
		"六白乾金", "七赤兑金", "八白艮土", "九紫离火"]


static func jiu_yun_name(xuan_year: int) -> String:
	return YUN_NAMES[int(posmod(xuan_year - YUAN_START, 180)) / 20]


## The instant 立春 of a civil year falls on: that year's own February, which is
## where the 干支 year turns. The term index alone cannot answer "is it before this
## January's 立春" because it wraps where the zodiac does (at 春分), so a September
## day carries a λ in the spring half of the circle: the instant has to be compared
## with the 立春 itself.
static func lichun_jd(civil_year: int) -> float:
	return term_jd(LICHUN, Astro.julian_day(civil_year, 2, 1), true)


## The term in force at an instant: its index into `Ecliptic.TERMS`, where 0 is
## 春分 at λ = 0 and every following index is another 15 deg of longitude.
static func term_index(jd_ut: float) -> int:
	return int(floor(fposmod(_longitude_at(jd_ut), 360.0) / 15.0))


## The instant term `index` begins, on the `next` side of `jd_ut`: bisection on
## astro.gd's own longitude, the way the equinox and solstice readings
## README「验证」 lists are found. The Sun moves about a degree a day, so the
## bracket holds that crossing and no other.
static func term_jd(index: int, jd_ut: float, next := false) -> float:
	var target := fposmod(15.0 * float(index), 360.0)
	var ahead := fposmod(target - _longitude_at(jd_ut), 360.0)
	var low := jd_ut if next else jd_ut - (360.0 - ahead) - 2.0
	var high := jd_ut + ahead + 2.0 if next else jd_ut
	for _step in 60:
		var mid := (low + high) * 0.5
		if fposmod(_longitude_at(mid) - target + 180.0, 360.0) < 180.0:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5


## The Sun's apparent longitude at a UT instant. astro.gd's own longitude is a
## function of TT (the Sun is placed through tt_from_ut), and the terms are TT
## instants like any other ephemeris event - leaving ΔT out would put every 节气
## about a minute early, which is a minute at the edge of a 局数 boundary.
static func _longitude_at(jd_ut: float) -> float:
	return Astro.sun_apparent_longitude_deg(Astro.tt_from_ut(jd_ut))
