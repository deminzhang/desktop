## The Chinese lunar calendar the HUD's date line is written in (README「HUD 罗盘规格（自内向外）」): the
## 农历 month and day, with the year counted in 道历 (黄帝纪年 = 农历年 + 2697).
##
## Nothing here is a table of published dates: a lunar month begins at the 朔 (the
## instant the Moon's longitude catches the Sun's), the month holding the 冬至 is the
## 十一月, and - in a span of thirteen months between two 冬至 - the first month that
## holds no 中气 is the 闰 one. Those are the rules the modern calendar is defined
## by, run here on this sky's own Sun and Moon (`Astro`), the way the 节气 and the
## four pillars are; the reference project leans on an almanac plugin for this.
##
## Months and terms are compared as *local civil days*, which is what a calendar is
## counted in: two instants on the same side of midnight are the same day even if
## the 朔 itself lands between them. The observer's own offset is used (`tz_hours`),
## so an observer at UTC+8 gets the official 农历, and one elsewhere gets their own
## sky's - the HUD is read where it stands.
##
## Cost: a date costs about 13 朔 and 13 中气 searches, each a walk of one day steps
## and a bisection - some 900 calls into `Astro.moon_state()` - so the sky caches it
## per local day rather than per time step.
class_name Lunar
extends RefCounted

## 道历 counts the years of the 黄帝 era: 农历 2026 is 道历 4723.
const DAO_EPOCH := 2697

const MONTH_NAMES := ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月",
		"九月", "十月", "冬月", "腊月"]
## 初一 to 三十, the way a 农历 day is read out.
const DAY_NAMES := ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九",
		"初十", "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九",
		"二十", "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
## Digit by digit, as a year is read: 四七二三.
const DIGITS := ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

## How far before a local day a 朔 must be searched for (a synodic month and a
## little), how far back a 冬至 can be, and how far a 中气 can be from a month's end.
const MOON_WINDOW := 33.0
const SUN_WINDOW := 370.0


## The 农历 date of a UT instant, read in the observer's civil days: the month, its
## leap flag, the day of the month, the 农历 year and the 道历 year, plus the line the
## HUD draws (`text`, e.g. 道历四七二三年九月初九).
static func date(jd_ut: float, tz_hours: float) -> Dictionary:
	var day := local_day(jd_ut, tz_hours)
	var winter := local_day(_solstice_at_or_before(day, tz_hours), tz_hours)
	var months := _months_of_winter(winter, tz_hours)
	var month: Dictionary = months[0]
	for entry in months:
		if int(entry["start"]) <= day:
			month = entry
	var year := int(month["year"])
	var text := "道历%s年%s%s" % [_year_text(year + DAO_EPOCH),
			"闰" if bool(month["leap"]) else "", MONTH_NAMES[int(month["number"]) - 1]]
	text += DAY_NAMES[day - int(month["start"])]
	return {
		"year": year,
		"dao_year": year + DAO_EPOCH,
		"month": int(month["number"]),
		"leap": bool(month["leap"]),
		"day": day - int(month["start"]) + 1,
		"text": text,
	}


## The civil day number (a JDN) an instant falls on, in the observer's own time.
static func local_day(jd_ut: float, tz_hours: float) -> int:
	return int(floor(jd_ut + 0.5 + tz_hours / 24.0))


## The months of the lunar year the 冬至 falls in, from that winter's 十一月 to the
## next winter's 十一月: `[{start: JDN, number: 1..12, leap: bool, year: int}]`, the
## last entry being the next winter's own 十一月. Thirteen months in the span means
## one of them is a 闰 month, and it is the first one with no 中气 inside it.
static func _months_of_winter(winter: int, tz_hours: float) -> Array:
	var last := _month_start(local_day(_solstice_after(winter, tz_hours), tz_hours),
			tz_hours)
	var starts: Array[int] = [_month_start(winter, tz_hours)]
	while starts[-1] < last:
		starts.append(_month_start(starts[-1] + 30, tz_hours))
	var leap := -1
	if starts.size() == 14:
		for i in range(starts.size() - 1):
			if _term_at_or_before(int(starts[i + 1]) - 1, tz_hours) < int(starts[i]):
				leap = i
				break
	# 十一月 first - the winter month - then 十二月, then the 正月 the year turns at,
	# and a 闰 month keeps the number of the month it follows
	var months: Array = []
	var number := 10
	var year := int(Time.get_date_dict_from_unix_time(_unix_of_day(winter))["year"])
	for i in range(starts.size() - 1):
		var is_leap := i == leap
		if not is_leap:
			number += 1
			if number > 12:
				number = 1
				year += 1
		months.append({"start": starts[i], "number": number, "leap": is_leap,
				"year": year})
	return months


## The local day a month begins on: the 朔 (new moon) at or before `day`.
static func _month_start(day: int, tz_hours: float) -> int:
	var end := float(day) + 0.5 - tz_hours / 24.0
	var crossings := _crossings(end - MOON_WINDOW, end, _phase)
	return local_day(crossings[-1], tz_hours)


## The instant of the 冬至 (the Sun's longitude 270 deg) at or before a local day.
static func _solstice_at_or_before(day: int, tz_hours: float) -> float:
	var end := float(day) + 0.5 - tz_hours / 24.0
	return _crossings(end - SUN_WINDOW, end, _winter)[-1]


## The instant of the next 冬至 after the one at or before a local day.
static func _solstice_after(day: int, tz_hours: float) -> float:
	var before := _solstice_at_or_before(day, tz_hours)
	return _crossings(before + 1.0, before + SUN_WINDOW, _winter)[0]


## The local day of the last 中气 (a multiple of 30 deg of solar longitude) at or
## before a local day: the term a month is tested for.
static func _term_at_or_before(day: int, tz_hours: float) -> int:
	var end := float(day) + 0.5 - tz_hours / 24.0
	return local_day(_crossings(end - 40.0, end, _term)[-1], tz_hours)


## Every rising zero crossing of `f` between two instants, in order: each is where
## a phase or a longitude passes the angle it is measured from. Walked a day at a
## time - the Moon's elongation rises 12.2 deg a day and the Sun's 1 - so no
## crossing is missed, then bisected.
static func _crossings(from: float, to: float, f: Callable) -> Array[float]:
	var found: Array[float] = []
	var jd := from
	var value := float(f.call(jd))
	while jd < to:
		var next := jd + 1.0
		var next_value := float(f.call(next))
		if value < 0.0 and next_value >= 0.0:
			found.append(_bisect(jd, next, f))
		jd = next
		value = next_value
	if found.is_empty():
		# the angle was already past its crossing when the window opened, so the
		# window is too narrow for these callers: every one of them is wider than a
		# whole cycle of the angle it looks for
		push_error("Lunar: no crossing of the angle in (%.2f, %.2f]" % [from, to])
		found.append(from)
	return found


## The Moon's elongation from the Sun as a signed angle in (-180, 180]: negative
## before a 朔, positive after. Its rising zero crossing *is* the new moon.
static func _phase(jd: float) -> float:
	return fposmod(Astro.moon_state(jd).elongation_deg + 180.0, 360.0) - 180.0


## The Sun's distance from 270 deg of longitude, same convention: its rising zero
## crossing is the 冬至.
static func _winter(jd: float) -> float:
	return fposmod(Astro.sun_apparent_longitude_deg(jd) - 270.0 + 180.0, 360.0) - 180.0


## The Sun's distance from the nearest 中气, same convention.
static func _term(jd: float) -> float:
	return fposmod(Astro.sun_apparent_longitude_deg(jd) + 15.0, 30.0) - 15.0


## The instant inside (lo, hi] where `f` rises through zero, f(lo) < 0 < f(hi).
static func _bisect(lo: float, hi: float, f: Callable) -> float:
	for i in 40:
		var mid := (lo + hi) * 0.5
		if float(f.call(mid)) < 0.0:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


## A year in Chinese numerals, digit by digit: 4723 -> 四七二三.
static func _year_text(year: int) -> String:
	var text := ""
	for digit in str(year):
		text += DIGITS[int(digit)]
	return text


## The Unix instant of the midnight a civil day begins at, only used to read a
## year back: the JDN of a day is the Julian day that *starts* at its noon, so its
## midnight is half a day before it.
static func _unix_of_day(day: int) -> int:
	return int((float(day) - 0.5 - Astro.UNIX_EPOCH) * Astro.DAY)
