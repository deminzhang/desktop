## The 大六壬 chart's sky plate, cast for the dial (README「HUD 罗盘规格（自内向外）」): the 月将 the
## solar term in force puts on the board, the heaven plate 月将加时 turns over the
## twelve earth branches, the 旬遁 stems the day's 旬 pairs with those heaven
## branches, and the 十二天将 the day stem's 贵神 leads round it.
##
## Ported from the reference project's compass data
## (`DaLiuRenAlgo.calc` in Scripts/Algorithm/daliuren.gd, read by
## QimenSLG/compass/compass_data.gd's `liuren_at`), keeping its tables - 中气 -> 月将,
## the 贵人 branch of each day stem, 旬空 - exactly as they are written there. What
## neither ring draws is left behind: 月建 and the 十二建星, and the whole
## 四课/三传/课体 apparatus.
##
## The reference indexed its twelve-slot arrays from 午 (slot 0 = 地盘午); the
## slots here run from 地盘子, the way the rest of xuandesk indexes the sky.
##
## The calendar is the caller's job (`GanZhi.of`): all this needs is the day
## pillar, the 时辰's branch index and the term in force.
class_name LiuRen
extends RefCounted

const ZHI := GanZhi.ZHI
const GAN := GanZhi.GAN

## 中气 -> 月将, verbatim: the 月将 is the sign the Sun has just left behind, so
## each 中气 carries the branch two 中气 back down the zodiac.
const JIANG_OF_QI: Dictionary = {
	"雨水": "亥", "春分": "戌", "谷雨": "酉", "小满": "申",
	"夏至": "未", "大暑": "午", "处暑": "巳", "秋分": "辰",
	"霜降": "卯", "小雪": "寅", "冬至": "丑", "大寒": "子",
}

## 十二天将, in the order they ride out from the 贵人 and round the plate: the one
## character the dial's cramped ring writes, and the full name the heaven ring over
## the horizon writes. Index-aligned - `GODS[i]` is `GOD_NAMES[i]` abbreviated.
const GODS: PackedStringArray = ["贵", "蛇", "朱", "合", "勾", "龙", "空", "虎", "常", "玄", "阴", "后"]
const GOD_NAMES: PackedStringArray = ["贵人", "螣蛇", "朱雀", "六合", "勾陈", "青龙", "天空", "白虎", "太常", "玄武", "太阴", "天后"]

## 贵人歌诀 (甲戊庚牛羊 / 乙己鼠猴乡 / 丙丁猪鸡位 / 壬癸兔蛇藏 / 六辛逢马虎): the
## branch the 贵人 rides by day, the 卯..申 half of the 时辰 cycle.
const GUIDE_DAY: Dictionary = {
	"甲": "丑", "戊": "丑", "庚": "丑", "乙": "子", "己": "子",
	"丙": "亥", "丁": "亥", "壬": "卯", "癸": "卯", "辛": "午",
}

## ... and the branch it rides by night (酉..寅) - the same song's second couplet.
const GUIDE_NIGHT: Dictionary = {
	"甲": "未", "戊": "未", "庚": "未", "乙": "申", "己": "申",
	"丙": "酉", "丁": "酉", "壬": "巳", "癸": "巳", "辛": "寅",
}

## 六甲旬空亡 (the reference's XuanConsts.KONG_WANG): the ten stems of a 旬 reach
## only ten of the twelve branches; the last two are the 空亡.
const KONG_WANG: Dictionary = {
	"甲子": ["戌", "亥"], "甲戌": ["申", "酉"], "甲申": ["午", "未"],
	"甲午": ["辰", "巳"], "甲辰": ["寅", "卯"], "甲寅": ["子", "丑"],
}


## 月将加时: the twelve earth-branch slots of the dial for the chart of `pillars`
## (`GanZhi.of`), each carrying the heaven branch over it, the stem the day's 旬
## 遁s there, and the 天将 riding it - the dial's one-character name in `god` and
## the full one in `god_name`. `slots[0]` is 地盘子; 空亡 stems come out 〇.
##
## Two of the twelve are the ones the plate is read for, and each says so itself
## rather than leaving the dial to work it out: `guide` is true on the slot the
## 贵人 rides, and `general` on the slot the 月将 has been laid on - which is the
## 时辰's own 支, 月将加时 standing the 月将 over it.
static func pan(pillars: Dictionary) -> Dictionary:
	var hour_branch := int(pillars.get("hour_branch", 0))
	var day: String = str(pillars.get("day", "甲子"))

	# 月将 is set by the 中气, never by the 节: a 节 (odd index, 15 deg) still stands
	# under the 中气 before it - the reference's "previous 气" scan, which wraps
	# from 小寒 to 冬至. Even indices of Ecliptic.TERMS are the 中气.
	var index := int(pillars.get("term_index", 0))
	var month_general: String = JIANG_OF_QI[Ecliptic.TERMS[index - index % 2]]

	# 月将加时: the 月将 is laid on the 时辰's branch, so the heaven plate is the
	# earth plate turned by how far apart the two are.
	var turn := posmod(ZHI.find(month_general) - hour_branch, 12)

	var day_gan := day.substr(0, 1)
	var day_branch := ZHI.find(day.substr(1, 1))
	# The day's own stem is the stem its branch owns in the 旬, so the 旬首支 is the
	# day branch walked back by the stem's rank within the 旬 (甲 is rank 0).
	# Every heaven branch then carries the stem it is paired with in that 旬 - the
	# reference walks 地盘 forward from the palace holding the 日支 with the day
	# stem in hand, which lays down the same stems.
	var xun_start := posmod(day_branch - GAN.find(day_gan), 12)
	var kong: Array = KONG_WANG["甲" + ZHI[xun_start]]

	var home := _guide_home(day_gan, hour_branch, turn)
	var gods := _gods(home)
	var slots: Array = []
	for b in 12:
		var branch: String = ZHI[(b + turn) % 12]
		slots.append({
			"branch": branch,
			"stem": "〇" if kong.has(branch) else GAN[posmod(ZHI.find(branch) - xun_start, 12)],
			"god": GODS[gods[b]],
			"god_name": GOD_NAMES[gods[b]],
			"guide": b == home,
			"general": branch == month_general,
		})
	return {"month_general": month_general, "slots": slots}


## The 地盘子 the 贵人 rides. 起贵人: the 贵人歌诀 gives the day stem a branch,
## whichever of the two the 时辰's half of the day calls for (卯..申 昼, 酉..寅 夜),
## and 月将加时 leaves the earth palace holding that branch this far round from 子.
## So the 贵人 is drawn on the slot whose 天盘支 is its own branch, and that palace is
## where `_gods` counts the twelve 天将 out from (reference `_calc_gui_ren`).
static func _guide_home(day_gan: String, hour_branch: int, turn: int) -> int:
	var daytime := hour_branch >= 3 and hour_branch <= 8
	var guide := ZHI.find((GUIDE_DAY if daytime else GUIDE_NIGHT)[day_gan])
	return posmod(guide - turn, 12)


## 布天将: from the 贵人's own palace (`home`) the twelve ride round the plate - 顺行
## from 亥子丑寅卯辰 and 逆行 from 巳午未申酉戌, the way the reference has it. They
## come back as indexes into `GODS`/`GOD_NAMES`, one per 地盘子; `home`'s own is 0,
## the 贵人.
static func _gods(home: int) -> PackedInt32Array:
	var forward := home >= 9 or home <= 4
	var gods := PackedInt32Array()
	gods.resize(12)
	for b in 12:
		gods[b] = posmod(b - home, 12) if forward else posmod(home - b, 12)
	return gods
