## The 时家奇门 chart the dial draws (计划 §6.5 S7): the 拆补 局数 of the 节气 in
## force plus the 三元 the day pillar sits in, then 排盘 in the one mode the dial
## ever asks for - 时家 + 拆补 + 转盘 + 中宫寄坤 + 阴阳皆顺.
##
## Ported verbatim, names and all, from the reference project's Scripts/Algorithm/
## qimen.gd (`QimenAlgo`), with the few tables it leans on copied out of Scripts/
## Defs/xuan_consts.gd - except for one line, the 值使门's name, which the reference
## indexes wrong and which is fixed here (`_arrange_rotating` has the note and the
## evidence). The modes the dial never asks for - 日家/月家/年家, 飞盘/鸣法, the other
## 局数法, 阳艮阴坤/飞法/暗干 options - are not carried over, nor are the 暗干 and
## 驿马 the dial does not draw.
##
## Everything happens on the 洛书 nine palaces (1 坎 … 9 离), in four steps:
##   地盘三奇六仪  戊己庚辛壬癸丁丙乙, one per palace outward from the 局's palace
##                 (阳遁 ascending the palace numbers, 阴遁 descending)
##   值符/值使     值符宫 = the palace holding the 旬首's 遁干 (甲子旬 戊 … 甲寅旬 癸);
##                 值符落宫 = the palace holding the 时辰's 干, and 甲 - which has no
##                 地盘干 - hides as the 旬首's again; 值使落宫 = the 旬首宫 walked
##                 one palace per 时辰 of the 旬 until the 时辰's 支 turns up
##                 (阳遁顺行, 阴遁逆行)
##   九星/八门/八神  three rigid plates: the 值符星 and 值使门 carried by the 值符宫
##                 land on the 落宫 above and the rest follow the 转盘 order
##                 坎艮震巽离坤兑乾, 八神 running 值符…九天 from the same palace
##   天盘三奇六仪  each palace takes the 地盘干 of the palace its star came from
## 中宫 keeps 天禽 and carries no 门/神, and a 值符宫 or 落宫 that is 中宫 is read as
## 坤 2 (寄坤) - which is also how 中宫's own 星/门 are named there.
##
## The two palaces the dial paints gold - `duty_star` / `duty_door` - are the ones the
## 值符星 and 值使门 are *standing on* on the finished plate (the 值符落宫 and the 值使
## 落宫, 寄坤 folded in), which is where the 星 ring and the 神 ring can be read against
## each other: the 值符神 is put on the 值符星's palace too.
##
## The caller never does the calendar: the pillars come from GanZhi.of, and the 局数
## is keyed on the 节气's name (the reference's own 冬至-first table) - `term_index`
## is the same term in Ecliptic.TERMS order and is not what the table is indexed by.
class_name QiMen
extends RefCounted


# ================================================================ 名称表

## 三奇六仪 in the order the 地盘 lays them down, 戊 first.
const QI_6_YI := "戊己庚辛壬癸丁丙乙"

## 洛书宫号 1..9 → 宫名 / 九星 (index 0 is an unused hole, as in the reference).
const DIAGRAM_9 := "坎坤震巽中乾兑艮离"
const STAR_9 := "蓬芮冲辅禽心柱任英"

## 转盘的八宫 坎艮震巽离坤兑乾: 八星/八门/八神 run on 转宫号 1..8 there, with
## GONG_TO_ROLL / ROLL_TO_GONG translating to 洛书宫号 (中宫 has no 转宫号 at all).
const STAR_8 := "蓬任冲辅英芮柱心"
const DOOR_8 := "休生伤杜景死惊开"
const GOD_8 := "值符腾蛇太阴六合白虎玄武九地九天"
const STAR_PREFIX := "天"
const DOOR_SUFFIX := "门"

## 1..8 (resp. 1..9) with a whole further lap of padding, so a counter that runs off
## the end wraps by itself - the plates below index these with running counters.
const IDX_8: PackedInt32Array = [8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8]
const IDX_9: PackedInt32Array = [9, 1, 2, 3, 4, 5, 6, 7, 8, 9, 1, 2, 3, 4, 5, 6, 7, 8, 9]

## 转宫号 ↔ 洛书宫号; index 0 of each is padding, and 中宫 (5) has no 转宫号 (0).
const ROLL_TO_GONG: PackedInt32Array = [6, 1, 8, 3, 4, 9, 2, 7, 6]
const GONG_TO_ROLL: PackedInt32Array = [1, 1, 6, 3, 4, 0, 8, 7, 2, 5]

## The 24 节气 in the reference's own order, 冬至 first, and their [上元, 中元, 下元]
## 局数 - negative is 阴遁. 拆补 局数 is algorithm data, so it lives here and not in
## the calendar layer; every 元 is five days of the day pillar's 60-cycle.
const JIE_QI := [
	"冬至", "小寒", "大寒", "立春", "雨水", "惊蛰",
	"春分", "清明", "谷雨", "立夏", "小满", "芒种",
	"夏至", "小暑", "大暑", "立秋", "处暑", "白露",
	"秋分", "寒露", "霜降", "立冬", "小雪", "大雪",
]
const QI_MEN_JU := [
	[1, 7, 4],      # 冬至 (坎)
	[2, 8, 5],      # 小寒
	[3, 9, 6],      # 大寒
	[8, 5, 2],      # 立春 (艮)
	[9, 6, 3],      # 雨水
	[1, 7, 4],      # 惊蛰
	[3, 9, 6],      # 春分 (震)
	[4, 1, 7],      # 清明
	[5, 2, 8],      # 谷雨
	[4, 1, 7],      # 立夏 (巽)
	[5, 2, 8],      # 小满
	[6, 3, 9],      # 芒种
	[-9, -3, -6],   # 夏至 (离)
	[-8, -2, -5],   # 小暑
	[-7, -1, -4],   # 大暑
	[-2, -5, -8],   # 立秋 (坤)
	[-1, -4, -7],   # 处暑
	[-9, -3, -6],   # 白露
	[-7, -1, -4],   # 秋分 (兑)
	[-6, -9, -3],   # 寒露
	[-5, -8, -2],   # 霜降
	[-6, -9, -3],   # 立冬 (乾)
	[-5, -8, -2],   # 小雪
	[-4, -7, -1],   # 大雪
]

## 六甲旬首 → its 遁干; → its 空亡 two 支 (XuanConsts.KONG_WANG verbatim).
const XUN_HEADS := ["甲子", "甲戌", "甲申", "甲午", "甲辰", "甲寅"]
const HIDE_JIA := {"甲子": "戊", "甲戌": "己", "甲申": "庚", "甲午": "辛", "甲辰": "壬",
		"甲寅": "癸"}
const KONG_WANG := {
	"甲子": ["戌", "亥"], "甲戌": ["申", "酉"], "甲申": ["午", "未"],
	"甲午": ["辰", "巳"], "甲辰": ["寅", "卯"], "甲寅": ["子", "丑"],
}

## 三合 → 驿马 (XuanConsts.HORSE verbatim): 申子辰 马在寅, 寅午戌 马在申, 巳酉丑 马在
## 亥, 亥卯未 马在巳. The dial reads it off the 时辰's branch, the way this 时家盘
## reads everything else off the 时辰 (the 日支 is the other school's key).
const HORSE := {
	"申": "寅", "子": "寅", "辰": "寅",
	"寅": "申", "午": "申", "戌": "申",
	"巳": "亥", "酉": "亥", "丑": "亥",
	"亥": "巳", "卯": "巳", "未": "巳",
}

## 九星的原始宫 (洛书宫号): the 天盘干 travels with its star, so this is what links
## a star's new palace back to the 地盘干 it carries.
const STAR_HOME := {"蓬": 1, "芮": 2, "冲": 3, "辅": 4, "禽": 5, "心": 6, "柱": 7,
		"任": 8, "英": 9}

## The chart named the way the HUD writes it (用户 2026-10-10 第二十轮): the 三元 the
## day sits in and the 局 that makes, 节气上元 阴九局. The 局 keeps the reference's
## sign - negative is 阴遁 - so `ju_name()` only has to read it back.
const YUAN_NAMES := ["上元", "中元", "下元"]
const NUM_CN := "一二三四五六七八九"

## 阳宫: 洛书 8 艮 / 3 震 / 4 巽 / 1 坎; 阴宫: 2 坤 / 9 离 / 6 乾 / 7 兑. The two sets
## are exactly the eight palaces the 盘 is drawn on - 中宫 5 stands in neither, the
## chart 寄坤s it - and 奇门 reads 内盘/外盘 off them: a 阳遁 puts the 阳宫 inside, a
## 阴遁 the 阴宫, so the four sectors change hands when the 局 does.
const YANG_GONG := [1, 3, 4, 8]
const YIN_GONG := [2, 6, 7, 9]

## 六十甲子 (XuanConsts.GAN_ZHI_60 verbatim): the 旬, the 三元 and the 值使 walk all
## count on it.
const JIA_ZI := [
	"甲子", "乙丑", "丙寅", "丁卯", "戊辰", "己巳", "庚午", "辛未", "壬申", "癸酉",
	"甲戌", "乙亥", "丙子", "丁丑", "戊寅", "己卯", "庚辰", "辛巳", "壬午", "癸未",
	"甲申", "乙酉", "丙戌", "丁亥", "戊子", "己丑", "庚寅", "辛卯", "壬辰", "癸巳",
	"甲午", "乙未", "丙申", "丁酉", "戊戌", "己亥", "庚子", "辛丑", "壬寅", "癸卯",
	"甲辰", "乙巳", "丙午", "丁未", "戊申", "己酉", "庚戌", "辛亥", "壬子", "癸丑",
	"甲寅", "乙卯", "丙辰", "丁巳", "戊午", "己未", "庚申", "辛酉", "壬戌", "癸亥",
]


# ================================================================ 名字

## 上元/中元/下元 as the chart carries them (`pan()["yuan"]` is 1..3).
static func yuan_name(yuan: int) -> String:
	return YUAN_NAMES[clampi(yuan - 1, 0, YUAN_NAMES.size() - 1)]


## 阴九局 / 阳三局: the 阴阳遁 the 局's sign carries and the 局数 itself. A 局 of 0
## is no chart at all and reads as the 阳遁's first.
static func ju_name(ju: int) -> String:
	return ("阴" if ju < 0 else "阳") + NUM_CN[clampi(absi(ju), 1, 9) - 1] + "局"


## Whether a 洛书宫 stands on the chart's 内盘: `yang` is the chart's own 阴阳遁
## (`pan()["yang"]`), and a 阳遁 holds the 阳宫 inside where a 阴遁 holds the 阴宫.
## 中宫 is on neither half - it is 寄坤 rather than drawn - so it answers false
## either way.
static func is_inner(gong: int, yang: bool) -> bool:
	return gong in (YANG_GONG if yang else YIN_GONG)


# ================================================================ 排盘

## The 时家 chart of one instant: 拆补 局数 + 中宫寄坤 转盘, the 旬 and 空亡, the
## 值符星/值使门 of the 时辰, and the nine palaces (index = 洛书宫号, index 0
## unused). `ju` keeps the reference's sign - negative is 阴遁 (`yang` in a bool).
static func pan(pillars: Dictionary) -> Dictionary:
	var day := str(pillars.get("day", ""))
	var hour := str(pillars.get("hour", ""))
	var hour_branch := int(pillars.get("hour_branch", 0))

	var yuan := _yuan(day)
	var ju := _ju(str(pillars.get("term", "")), yuan)
	var xun := _xun(hour)
	var palaces := _palaces(ju, hour, hour_branch, xun)

	# 值符星/值使门 are read back off the finished plate: the two palaces carrying the
	# duty marks, which _arrange_rotating puts where those two names stand. Read the
	# same way as the reference, which marks the 值符宫 before its plates turn and so
	# reports whatever star ends up on it instead (see the module note); ours is the
	# star the dial draws its gold on, and the 神 standing beside it.
	var duty_star := ""
	var duty_door := ""
	for palace in palaces:
		if palace.get("duty_star", false):
			duty_star = palace["star"]
		if palace.get("duty_door", false):
			duty_door = palace["door"]

	return {
		"yuan": yuan,
		"ju": ju,
		"yang": ju > 0,
		"xun": xun,
		"kong": (KONG_WANG.get(xun, []) as Array).duplicate(),
		"duty_star": duty_star,
		"duty_door": duty_door,
		"horse": String(HORSE.get(GanZhi.ZHI[hour_branch], "")),
		"palaces": palaces,
	}


## The nine palaces of the chart, index = 洛书宫号 with index 0 left empty. The four
## steps run in the reference's order - each one needs the plate the last one left.
static func _palaces(ju: int, hour: String, hour_branch: int, xun: String) -> Array:
	var hour_gan := hour.substr(0, 1)
	var palaces := [{}]
	for i in range(1, 10):
		palaces.append({"name": DIAGRAM_9[i - 1], "di_gan": "", "tian_gan": "",
				"star": "", "door": "", "god": "",
				"duty_star": false, "duty_door": false})

	# 1. 地盘三奇六仪: 戊 on the 局's own palace, then one per palace outward - 阳遁
	#    ascending the palace numbers, 阴遁 descending. Both directions thus start on
	#    the 局's palace, which is why one loop covers them.
	var abs_ju := absi(ju)
	for step in 9:
		var palace := IDX_9[abs_ju + step] if ju > 0 else IDX_9[abs_ju + 9 - step]
		palaces[palace]["di_gan"] = _qi_6_yi(step + 1)

	# 2. 值符宫: where the 旬首's 遁干 sits on the 地盘 - the 值符星 and 值使门 are the
	#    star and 门 of that palace. The palace is found here, but the two duty marks
	#    go on last: what the dial paints is the palace each name *stands on* once
	#    the plates have turned (`_arrange_rotating`), which is the 值符宫 only when
	#    the 时辰's 干 sits on the 旬首's own 地盘干.
	var duty_gong := 0
	var hide_gan := str(HIDE_JIA.get(xun, "戊"))
	for i in range(1, 10):
		if palaces[i]["di_gan"] == hide_gan:
			duty_gong = i
			break

	# 3. 值符落宫: where the 时辰's 干 sits; 甲 hides as the 旬首's 遁干 again.
	var hour_pos_gan := hide_gan if hour_gan == "甲" else hour_gan
	var duty_star_pos := 0
	for i in range(1, 10):
		if palaces[i]["di_gan"] == hour_pos_gan:
			duty_star_pos = i
			break

	# 4. 值使落宫: the 旬首宫 walked one palace per 干支 of the 旬 (阳遁顺行, 阴遁
	#    逆行) till the 时辰's 支 turns up - the 旬 is the 时辰's own, so its ten 干支
	#    hold that 支 and the walk always stops inside the ten. (The reference's
	#    ZHI_GONG_9 fallback for a walk that misses is unreachable and not ported.)
	var xun_idx := maxi(_jia_zi(xun), 0)
	var dir_step := 1 if ju > 0 else -1
	var walked := duty_gong
	var duty_door_pos := 0
	for step in 10:
		if (xun_idx + step) % 12 == hour_branch:
			duty_door_pos = walked
			break
		walked += dir_step
		if walked > 9:
			walked = 1
		elif walked < 1:
			walked = 9

	_arrange_rotating(palaces, ju, duty_gong, duty_star_pos, duty_door_pos)
	_arrange_tian_gan(palaces)
	return palaces


## 转盘: 九星 → 八神 → 八门, three rigid plates. Both the 星 and the 门 of the 值符宫
## travel to the 落宫 above and the rest of the plate follows in 转盘 order; 八神 run
## 值符…九天 from the 值符落宫, backwards under 阴遁. 中宫寄坤: a 值符宫 / 值符落宫 /
## 值使落宫 of 中宫 is read as 坤 2, and 中宫's own 星 stays 天禽.
static func _arrange_rotating(palaces: Array, ju: int, duty_gong: int,
		duty_star_pos: int, duty_door_pos: int) -> void:
	var duty_roll := 2 if duty_gong == 5 else duty_gong
	var star_pos := 2 if duty_star_pos == 5 else duty_star_pos
	var door_pos := 2 if duty_door_pos == 5 else duty_door_pos

	palaces[5]["star"] = _star9_full(5)

	# 九星 + 八神: the plate starts on the 值符落宫 with the 值符宫's own star. The
	# 转盘 order never yields 中宫, so all eight outer palaces are covered exactly
	# once and 天禽 (already placed) is left alone.
	var star_from := GONG_TO_ROLL[star_pos]
	var star_home := GONG_TO_ROLL[duty_roll]
	for ri in range(star_from, star_from + 8):
		var palace := ROLL_TO_GONG[IDX_8[ri]]
		palaces[palace]["star"] = _star8_full(star_home)
		palaces[palace]["god"] = _god8(1 + ri - star_from) if ju > 0 \
				else _god8(1 + star_from + 8 - ri)
		star_home += 1

	# 八门: the same rigid rotation, the 值符宫's 门 onto the 值使落宫.
	var door_from := GONG_TO_ROLL[door_pos]
	var door_home := GONG_TO_ROLL[duty_roll]
	for di in range(door_from, door_from + 8):
		palaces[ROLL_TO_GONG[IDX_8[di]]]["door"] = _door8_full(door_home)
		door_home += 1

	# 值符星 / 值使门 named after the palace they came from; a 中宫 值符宫 takes 坤's
	# (天芮 / 死门) because of 寄坤.
	#
	# DEVIATION from the reference, deliberate: its 门 line reads the name off a
	# 转宫号 where the 星 line uses a 洛书宫号, so a 值符宫 of 坤/乾/艮/离 (or the
	# 中宫's 寄坤) takes a foreign palace's door. The reference's own plates show
	# it: 2026-01-22 03:00 (值符宫 中, 寄坤) carries 生门 on 坤 where 死门 belongs, so
	# that plate has 生门 twice and no 死门 at all. Both lines index through
	# GONG_TO_ROLL here, and .tmp/tests/xuan_probe.gd holds every chart to the ring
	# turning as a whole - which is what the reference's version breaks.
	palaces[star_pos]["star"] = _star9_full(duty_roll)
	palaces[door_pos]["door"] = _door8_full(GONG_TO_ROLL[duty_roll])

	# The two duty marks ride with those two lines: the dial paints the palace the
	# 值符星 / 值使门 are standing on, not the 值符宫 they came from. The 神盘's own
	# 值符神 is put on the same palace by the loop above (the god plate starts on the
	# 值符落宫), so the 星 ring and the 神 ring carry their gold together. 寄坤 is
	# already folded into star_pos/door_pos, so a 值符落宫 or 值使落宫 of 中宫 - which
	# the eight-palace dial never draws - is marked on 坤, where the name is drawn.
	palaces[star_pos]["duty_star"] = true
	palaces[door_pos]["duty_door"] = true


## 天盘三奇六仪: the 地盘干 rides with its star, so every palace takes the 地盘干 of
## the palace its star came from - 中宫's 天禽 never left, so 中宫 keeps its own. All
## nine palaces have a star by now, which is why the reference's empty-star guard is
## not carried over.
static func _arrange_tian_gan(palaces: Array) -> void:
	for i in range(1, 10):
		var star_name := str(palaces[i]["star"])
		palaces[i]["tian_gan"] = palaces[STAR_HOME[star_name.substr(1)]]["di_gan"]


# ================================================================ 局数与旬

## 三元: the 60-cycle position of the day decides it - 上元 for the first five days
## of each 15-day 三元, 中元 for the next five, 下元 for the last five (甲己日 opens a
## 元, so 甲子/己巳/甲戌/己卯… are the 上元 days).
static func _yuan(day: String) -> int:
	var index := _jia_zi(day)
	if index < 0:
		return 1
	return index % 15 / 5 + 1


## 拆补: the 节气's 局数 for that 三元. An unknown 节气 keeps the reference's answer.
static func _ju(term: String, yuan: int) -> int:
	var index := JIE_QI.find(term)
	if index < 0:
		return 1
	return QI_MEN_JU[index][yuan - 1]


## 旬首: every ten 干支 of the 60 share one of the six 甲.
static func _xun(hour: String) -> String:
	var index := _jia_zi(hour)
	if index < 0:
		return XUN_HEADS[0]
	return XUN_HEADS[index / 10]


## The 60-cycle position of a 干支, or -1 when it is not one.
static func _jia_zi(ganzhi: String) -> int:
	return JIA_ZI.find(ganzhi)


# ================================================================ 名字查表

static func _qi_6_yi(i: int) -> String:
	return QI_6_YI[i - 1]


static func _star9_full(gong: int) -> String:
	return STAR_PREFIX + STAR_9[gong - 1]


static func _star8_full(roll: int) -> String:
	return STAR_PREFIX + STAR_8[IDX_8[roll] - 1]


static func _door8_full(roll: int) -> String:
	return DOOR_8[IDX_8[roll] - 1] + DOOR_SUFFIX


static func _god8(i: int) -> String:
	return GOD_8.substr((IDX_8[i] - 1) * 2, 2)
