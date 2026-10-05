## The compass dial of the sky HUD (计划 §6.4, §6.5 S7): the horizon drawn as the
## card the sky is seen against, with a live 奇门 chart and a live 大六壬 chart
## laid out on it.
##
## The card stands still, 南 at the top and 北 at the bottom - the 上南下北 a 罗盘
## is read at (2026-10-10 第十五轮; it used to turn under a fixed index at the top
## that read the view's bearing, 计划 A12's dial). What says where the camera looks
## is now an **arc outside the rim** centred on the view's own bearing, and the
## four **direction triangles** on the card's own axes are the controls that aim
## it: they are the 北/东/南/西 chip row that used to stand under the dial, moved
## onto the points they name. The charts are cast for the sky's own instant by
## `QiMen.pan()` / `LiuRen.pan()` and recomputed when the 时辰 turns:
##
##   卦 ring      后天八卦的卦符 (the eight palaces the 奇门 chart is cast on)
##   八宫块 3 行    the 奇门 chart itself, one block per 宫 on that 宫's bearing:
##               神 / 星 / 门 从上到下、**正写**（2026-10-09 第十一轮起不再按环
##               排内外），每行后面跟着跟它走的那个 干，值符星/值使门/值符神仍描金
##   环五 12 分   大六壬 天盘支 + 遁干 + 贵人 - the one plate still drawn as a ring
##   环外        the Sun outside the degree ticks and the Moon inside them, each on
##               the bearing the sky has it on - the two marks the card carries
##               for something that is not a ring - and the seven planets, which
##               the sky hands over the same way (2026-10-09: 行星指针)
##
## and the middle is a 太极 in place of a bearing readout.
##
## When the 时辰 turns, the chart it is cast for turns with it, and the card's characters
## **fly** to their new places rather than the whole plate being redrawn (2026-10-13,
## 换字飞转): a name that stands where it stood does not move, the next slot or two is
## walked round the card (同心转), anything further crosses in a straight line with a
## small rise (直线飞), and a name the new chart has no place for fades out where it was
## while a new one is born in. That is what `_plate` / `_fly` / `_retarget` are, and why
## the two charts are one list of characters keyed by name instead of two sets of draw
## calls.
##
## The tick ring is the card's own clock and the card's only scale: 12 大 x 5 小, and
## the card carries that clock's hand - one 6 deg step per second of sky time
## (`TimeCore.changed`), its tip landing on the 小刻 it reads. The 二十八宿's own marks
## ran over the same band until 2026-10-14 (用户: "HUD里的分野刻度去掉,只留时钟刻度") and
## are gone from the card: the 宿 are the sky's own scale (its equator carries both the
## 分野 names and their 距星 marks), and a second division laid over the clock's own band
## only made the clock harder to read. The 驿马 stirs on the same
## beat. The card stands still, so every ring on it stands still with it; what
## moves is the sky's own doing (the hand, the 驿马, the Sun, the Moon and
## the planets) and the view arc, which is the camera's.
##
## The 卦 ring draws its eight trigrams as bars rather than as the ☰ U+2630..☷
## U+2637 characters: the system's CJK font (Fonts.CANDIDATES) carries none of
## them, so a character ring would come out as eight empty boxes. The 左转/右转
## chips are ← U+2190 and → U+2192 for the same reason - the font has no ◀ U+25C0
## or ▶ U+25B6 either, and no hollow variant of them.
##
## The card is display only apart from its own controls - 左转/右转 in its two upper
## corners, the time bar's 时辰 chips in the two lower ones, and the four direction
## triangles on its axes - and every control is a real Button, so HudWindow can tell
## them from the drag handle of the window.
class_name SkyCompassHud
extends Control

## The 后天 (King Wen) arrangement with the 洛书 palace each trigram heads, one
## entry per ring slot from 坎 at due north: the same eight palaces the 奇门 chart
## is cast on, which is why the chart's stars and doors land under them. The third
## field is the trigram's own shape, a 乾-to-坤 bit mask of its three 爻 read from
## the bottom up, 1 for a solid 爻 - 坎 010 is 2, 乾 111 is 7, 坤 000 is 0. It
## names the glyph the ring draws (the Unicode ☰..☷ are not in the system font).
const BAGUA := [["坎", 1, 2], ["艮", 8, 4], ["震", 3, 1], ["巽", 4, 6],
		["离", 9, 5], ["坤", 2, 0], ["兑", 7, 3], ["乾", 6, 7]]

## How far one 左转/右转 press turns the view: one 山 (15 deg).
const TURN_STEP := 15.0
## The 左转/右转 chips hold one arrow each (↙ U+2199 / ↘ U+2198, 2026-10-10 第十八轮).
## 16 px is as large as the glyph can be with the chip still exactly 24 px tall - the
## system font is 22 px high at that size - and the chip draws it with a 1 px outline
## in its own ink, because a thin diagonal stroke reads lighter than the two-character
## chips the time bar carries at 13 px.
const ARROW_SIZE := 16
const ARROW_OUTLINE := 1

## The card's geometry: the disc, the tick ring the view arc is read against, the 奇门's
## eight 宫 blocks, the two body marks and the 太极 in the middle. The 大六壬 plate
## outside the blocks is the one chart still drawn as a ring of its own; the two
## body marks have the strips either side of the degree ticks.
const CENTRE := Vector2(150.0, 150.0)
const R_DISC := 138.0
const R_TICK_OUT := 129.0
const R_TICK_IN := 119.0
const R_SUN := 134.0    ## outside the ticks, inside the rim
const R_MOON := 115.0   ## inside the ticks
## The view arc (2026-10-10 第十五轮): where the camera looks, drawn outside the rim
## on that bearing - it replaced the index triangle that stood over the top of the
## dial. Its reach is the window's: the rim leaves 12 px either side and the four
## direction marks use 8 of them, so it is drawn between the rim and their tips. A
## view landing exactly on a cardinal hides the arc's middle behind that point's
## own triangle; the rest of the arc still says which way the turn went.
##
## The arc's own width is the **frame's** (2026-10-12 第二十一轮: "弧做长点，跟实际3D
## 场景中的视角一致，宽屏的弧就长点，窄屏就短点"): it spans the horizontal field of
## view the 3D camera actually shows, worked out from the rig's vertical fov and the
## wallpaper viewport's shape (`_view_arc_span`), so the arc is as long as the slice
## of sky on screen is wide. It used to be a fixed 40 deg mark that said where the
## view was and nothing about how much sky it held; ARC_SPAN is what is left of it -
## the fallback for a rig with no camera (a probe), which has no frame to measure.
const R_VIEW_ARC := R_DISC + 5.0
const ARC_SPAN := 40.0
const ARC_WIDTH := 3.0
## The bearing the card is read at: 南 on top, 北 at the bottom (上南下北).
const SOUTH_UP := 180.0
## One direction triangle's own size - a 10 x 8 px mark - and the button around it,
## 24 x 24 so the thing can actually be hit: the rim is only 12 px from the window's
## edge, so the button is laid flush with that edge and the mark sits inside it
## where the point is, rather than the button being centred on the mark and hanging
## outside the window.
const DIR_BUTTON := 24.0
## A 左转/右转 chip's own box (2026-10-12 第二十一轮: 做方、收窄、下移). Square and the
## same 24 px as a direction button - the arrow is the whole control, so it wants a
## target rather than a box - and hung ROTATE_TOP down from the card's top edge
## instead of the 8 px it started at, and ROTATE_INSET in from the window's side
## instead of 12: the rim is 138 px round, so the card's top corners stay empty down
## to about y 70, and a chip that sits *in* that corner (8 px off the rim at its inner
## corner) reads as belonging to the card where one on the window's own margin does
## not. Measured from the disc's centre, the inner corner is 146 px out: clear of the
## rim by 8, and 12 px closer to it than the 12/16 corner the chips started in.
const ROTATE_CHIP := 24.0
const ROTATE_TOP := 30.0
const ROTATE_INSET := 16.0
## How far past the rim a direction mark's centre stands: the mark is 8 px deep, so
## its base sits a px off the rim and its tip ends 9 px out - just inside the 12 px
## the window leaves, with the view arc's own band crossing the middle of it.
const DIR_MARK := 5.0
const R_LIUREN := 106.0
## The 驿马's own ring (2026-10-09 第十二轮: 块往里收，给马留出一圈): outside the 宫
## blocks and inside the 大六壬 ring, at r 92 - the four branches the horse rides
## fall between two 宫, so its mark lands in the gap either way.
const R_HORSE := 92.0
## The 奇门's eight 宫 blocks: the anchor of a block is where its 宫's bearing is, and
## its three lines stand this far apart, centred on the anchor. 64 (pulled in from
## 74) so the block occupies r 43…85 and leaves the 马 its own band at 86…98 - inside
## the 卦 ring (which ends at 41) and clear of the 大六壬 ring (which starts at 99).
## The pitch is one px more than the line is tall, which is what keeps two lines of
## CJK glyphs from touching.
const R_PALACE := 64.0
const LINE_PITCH := 14.0
const LINE_SIZE := 13
## The 八分盘 behind those blocks (用户 2026-10-10 第二十轮): the disc carries the
## chart's eight 宫 as eight sectors, and the 内盘 half of them is 微亮, so which
## half of the chart is inside is read off the card itself - 阳遁 lights the 阳宫
## (洛书 8/3/4/1), 阴遁 the 阴宫 (2/9/6/7). The band runs from just outside the 卦
## ring to just inside the 驿马's own circle: it carries the blocks (r 43…85) with a
## little air either side, and the two colours are the card's own cyan at two alphas
## - the step between them is the whole readout, so both are kept faint.
const R_PANEL_IN := 34.0
const R_PANEL_OUT := 90.0
const PANEL_SEG := 16
const C_PANEL_INNER := Color(0.34, 0.72, 0.86, 0.13)
const C_PANEL_OUTER := Color(0.34, 0.72, 0.86, 0.045)
const R_BAGUA := 26.0   ## 2026-10-09 第十二轮：34 → 26（朝太极贴近一半），贴着太极那一圈
const ROW := 7.0   ## half a label row: how far a ring's own grid lines reach
## The hands, read off the card's own clock face: the 地支 ring is the hour face -
## 午 is the top, so the top is noon or midnight, and a 大刻 is an hour - and the 60
## 小刻 are the minutes and the seconds, which is the scale the second hand already
## read (2026-10-09 第八轮). The hour hand is the short heavy one, the minute hand
## reaches into the 大六壬 ring, and the second hand is the long thin one whose tip
## lands on the 小刻's own inner end: its stem has the 奇门's blocks and both rings to
## cross and is drawn faint, only the outer half of it solid (用户 2026-10-10 第十九轮
## 加时针分针).
const HAND_HOUR := 74.0
const HAND_MINUTE := 98.0
const HAND_TIP := 124.0
const HAND_STEM := 112.0
## The 驿马's twitch: on the clock's beat it swings sideways for this long and this
## far at its widest (the mark is 12 px, so 3 px reads as a shake and not a move),
## at this many shakes a second inside the window.
const TWITCH_SEC := 0.35
const TWITCH_PX := 3.0
const TWITCH_HZ := 5.0
## 换字飞转 (2026-10-13, 计划 §6.5 换字飞转): when a 时辰 turns the chart over, the
## characters that stand somewhere else go to it - **同心转** round the card while it is
## the next slot or two, **直线飞** straight across with a small rise when it is further,
## and a character the new chart has no name for (or has one the old chart did not) is
## born or dies in place. A character that stands where it stood does not move at all.
## The three tuning numbers are lingwang's (`compass_3d.gd`, the 3D dial this card was
## ported from); FLY_LIFT is in px here, where that dial lifted its characters in world
## units.
const FLY_TIME := 0.42       ## 飞转时长(秒)
## 位次差 ≤ 这个值 × 本环扇宽 → 同心转，否则直线飞. 2.25 而不是 lingwang 的 1.25: 奇门的
## 星/门/神 一个时辰走**两宫**(90 度, 值符随时干那次实测), 1.25 会让整盘 24 行每次都横穿
## 盘面; 两格以内绕着转才像"盘在转"(实测那一档: 环上 12 字同心转、24 行里 16 行同心转、
## 其余 8 行跨 3 宫以上走直线飞).
const FLY_ARC_SLOT := 2.25
const FLY_LIFT := 6.0        ## 直线飞中途抬起的高度(px)
const BORN_SCALE := 0.35     ## 新生/消失的字起止时的大小
## What a character in flight is doing (`_fly`): sweep its bearing round the card, fly
## straight, or be born in place. A character the new chart has no name for is not in
## `_fly` at all - it is one of `_fading`, which only ever fades out.
const FLY_ARC := 0
const FLY_STRAIGHT := 1
const FLY_IN := 2
## The 太极 is the card's own centre mark and 2/3 of the 26 px it was: the 卦 ring
## closes in behind it and the three chart rings stay where they are.
const TAIJI_R := 17.3
const TAIJI_SEG := 48
## One trigram's bars: how wide the 爻 are, how tall, how far apart, and how much
## of a broken 爻's middle is left out.
const TRIGRAM_W := 13.0
const TRIGRAM_H := 2.0
const TRIGRAM_PITCH := 4.5
const TRIGRAM_GAP := 4.5

## The card's own plate (用户 2026-10-13: "HUD背景太黑了,透一点"): 0.72 → 0.55. The
## ink, the rings and the chips are unchanged - this is only how much of the sky the
## plate lets through, which is what makes the card read as a card rather than a hole.
const C_DISC := Color(0.012, 0.035, 0.052, 0.55)
const C_RIM := Color(0.30, 0.72, 0.82, 0.42)
const C_RING := Color(0.30, 0.72, 0.82, 0.20)
const C_TICK := Color(0.44, 0.63, 0.70, 0.55)
const C_TICK_MAJOR := Color(0.66, 0.86, 0.94, 0.85)
const C_BAGUA := Color(0.88, 0.96, 0.99, 0.90)
const C_STAR := Color(0.72, 0.84, 0.92, 0.86)
const C_DOOR := Color(0.62, 0.80, 0.90, 0.86)
const C_GOD := Color(0.82, 0.76, 0.98, 0.86)
const C_ZHI := Color(0.98, 0.78, 0.52, 0.88)
const C_DUTY := Color(1.00, 0.84, 0.45, 0.95)   ## 金: 值符星 / 值使门 / 值符神, and the 大六壬 月将支
## 大六壬's other mark, the 贵人's own red (用户 2026-10-12: 月将支标用金色，贵人用红色).
## It is the card's red - the one the 北 triangle already writes with - rather than a
## second red invented beside it.
const C_GUIDE := Color(0.95, 0.38, 0.34, 0.95)
## 驿马: the one mark on the card that is a *place*, not a name - an orange-brass of
## its own, warm enough to read as a travelling mark and clear of the duty gold.
const C_HORSE := Color(0.98, 0.62, 0.30, 0.95)
## The second hand: a pale needle of the instrument's own rather than a mark of a
## chart, so it stays out of the ring colours and the cyan of the index. The stem
## is the same ink at a low alpha - it crosses the rings, the tip does not.
const C_HAND := Color(0.80, 0.94, 1.00, 0.80)
const C_HAND_STEM := Color(0.80, 0.94, 1.00, 0.26)
## The four cardinal points, drawn as triangles outside the rim (计划 §6.4) - since
## 2026-10-10 第十五轮 they are the card's own direction buttons, one triangle on
## each axis of the card. 东 淡绿, 北 红, 西 白 as asked; 南 was left uncoloured in
## the brief, so it keeps the card's own accent rather than inventing a fourth
## colour.
const C_EAST := Color(0.62, 0.95, 0.66, 0.95)
const C_NORTH := Color(0.95, 0.38, 0.34, 0.95)
const C_WEST := Color(0.95, 0.97, 1.00, 0.95)
const C_SUN := Color(1.00, 0.84, 0.40, 0.95)
const C_MOON := Color(0.88, 0.92, 0.99, 0.95)
## How much of a body mark is drawn while that body is below the horizon: the card
## is read against the horizon, so a mark under it is a hint, not a position.
const C_BELOW := 0.30
const C_INDEX := Color(0.30, 0.85, 1.00)
const C_TEXT := Color(0.88, 0.96, 0.99)
const C_DIM := Color(0.44, 0.63, 0.70)
const C_FILL := Color(0.09, 0.21, 0.26, 0.80)
const C_FILL_HOVER := Color(0.14, 0.31, 0.38, 0.90)
const C_BORDER := Color(0.30, 0.72, 0.82, 0.32)
const C_BORDER_HOVER := Color(0.40, 0.85, 0.95, 0.55)
const C_TAIJI_WHITE := Color(0.94, 0.92, 0.88)
const C_TAIJI_BLACK := Color(0.08, 0.08, 0.11)

## The card's four direction triangles (2026-10-10 第十五轮): the 北/东/南/西 chip
## row that used to stand under the dial, moved onto the points it names. `cardinal`
## is what `CameraRig.face_cardinal()` is called with, `bearing` where that point
## stands - which is also where the button goes, the card being fixed - and
## `colour` the ink its triangle is drawn in.
const DIRECTIONS := [
	{"cardinal": "north", "bearing": 0.0, "colour": C_NORTH},
	{"cardinal": "east", "bearing": 90.0, "colour": C_EAST},
	{"cardinal": "south", "bearing": 180.0, "colour": C_INDEX},
	{"cardinal": "west", "bearing": 270.0, "colour": C_WEST},
]

var rig: CameraRig
## The sky's clock, handed over by the sky (`SkyBackground.clock`): its beat is
## what steps the 马 and stirs it - one `changed` per `step_seconds` of sky time,
## which is one second at rate 1 and never at rate 0. The card's *hands* do not
## read it: they are the observer's own wall clock (see `_hands`).
var clock: TimeCore
## Whose wall clock the hands keep, handed over by the sky. Null means the hands
## read UTC, which is only what a probe gets.
var observer: Observer

var _font: Font
var _palaces: Array = []    ## index = 洛书宫, the catalogue of the 奇门 chart
var _slots: Array = []      ## index = 地盘子, the 大六壬 天盘 over it
## Where the Sun and the Moon stand, each Vector2(altitude, azimuth) - the two
## readings the dial marks them by. Empty until the sky hands them over.
var _bodies: Dictionary = {}
## The 驿马's branch (0 = 子), or -1 before a chart arrives: the 时辰's 三合 horse.
var _horse := -1
## The 奇门 旬空 as 神盘 slots (index into `BAGUA`, i.e. 坎艮震巽离坤兑乾), empty when
## no chart has arrived: those palaces' 神 are drawn with a 〇 before the name.
var _kong: Array = []
## The 局 number of that chart, kept for its sign: 阳遁 is positive and 阴遁 negative
## (`QiMen.ju_name`), and which four 宫 are 内盘 follows from it. 0 before a chart
## arrives, which is also when the 八分盘 is not drawn at all.
var _ju := 0
## Seconds since the last beat, and so how far into its twitch the 马 is; at
## TWITCH_SEC and past it the mark is at rest and nothing asks for a redraw.
var _twitch := TWITCH_SEC
## The last real second the card was drawn at: `_process` asks for a frame when it
## turns, which is what keeps the hands moving while the sky stands still.
var _ticked := -1
## The card's characters as one list (换字飞转, 2026-10-13): one entry per mark that can
## move when the 时辰 turns - a key to match two charts' names by, the bearing / radius /
## row offset it stands on, and how to draw it once it is there (`_build_plate`). Rebuilt
## by `set_chart`, which the sky calls on each 时辰 turn and once more after the HUD is
## built (for the chart cast before it existed).
var _plate: Array = []
## key -> how that character gets to its new place (see `_retarget`); empty means the card
## stands still, which is the state the wallpaper's ON_DEMAND policy wants it in.
var _fly: Dictionary = {}
## The characters the new chart has no name for: they keep the place they stood on while
## they fade out, for as long as the fly lasts.
var _fading: Array = []
## 0..1 through the fly; 1 = standing.
var _fly_t := 1.0
## Whether any chart has been drawn yet: the first one lands without flying in, there
## being no card to fly from.
var _plate_built := false


# --------------------------------------------------------------------- setup

func setup(camera_rig: CameraRig, sky_clock: TimeCore = null,
		from: Observer = null) -> void:
	rig = camera_rig
	clock = sky_clock
	observer = from
	if rig != null:
		rig.moved.connect(_refresh)
	if clock != null:
		clock.changed.connect(_beat)
	_refresh()


## One beat of the sky clock (`TimeCore.changed`, one per sky second at rate 1):
## the 马 is put back at the start of its twitch. The hands do not need it - they
## read the observer's own clock at draw time, and `_process` is what asks for a
## frame when their second turns (用户 2026-10-10 第十九轮: 时辰加减时秒针乱飞,
## 让秒针独立运行).
func _beat() -> void:
	_twitch = 0.0
	_refresh()


## The twitch has to be animated between beats, and the hands have to be turned by
## the *real* second, which the sky's clock spends 7200 of at a time when a 时辰 is
## pressed. So the control ticks for the last 0.35 s of each real second and asks
## for one frame at the turn of each one, and is otherwise idle: the card is static
## in between and the wallpaper behind it is on demand.
func _process(delta: float) -> void:
	var second := int(wall_clock()["second"])
	if second != _ticked:
		_ticked = second
		queue_redraw()
	if _fly_t < 1.0:
		_step_fly(delta)
	if _twitch >= TWITCH_SEC:
		return
	_twitch = minf(_twitch + delta, TWITCH_SEC)
	queue_redraw()


## One frame of the fly, FLY_TIME long. The card asks for these frames itself, the way it
## does for the twitch: the card has the HUD window to itself, so a frame it draws costs
## the wallpaper nothing - which is why this needs none of lingwang's `anim_started` /
## `anim_finished` (that dial shared a scene with the sky it had to keep redrawing).
func _step_fly(delta: float) -> void:
	_fly_t = minf(_fly_t + delta / FLY_TIME, 1.0)
	if _fly_t >= 1.0:
		# the new chart's own places are exactly where the fly ends, mode by mode (see
		# `_entry_now`), so dropping the fly here moves nothing - the card just stops
		# asking for frames again
		_fly.clear()
		_fading.clear()
	queue_redraw()


## Cubic ease-out, the curve lingwang's fly runs on (`Tween.TRANS_CUBIC`/`EASE_OUT`): most
## of a character's move happens in the first half of FLY_TIME.
func _eased() -> float:
	return 1.0 - pow(1.0 - _fly_t, 3.0)


## A new chart has arrived: work out where each of its characters comes from. What a turn
## animates is a move from the place the character is drawn at *now* - the fly's own
## progress included, so two turns in a row fly from where the card is, not from where the
## first one started - to the place the new chart gives it (`_build_plate` keys the two
## charts' names together). A name the new chart has no place for fades out where it
## stands; a name the old chart did not have is born in. A chart handed over twice with
## nothing changed (the sky only pushes on a turn now, but the card does not depend on
## that) leaves `_fly` empty and the card standing still.
func _retarget() -> void:
	var was := {}
	for entry in _snapshot():
		was[String(entry["key"])] = entry
	var next := _build_plate()
	var fly := {}
	var fading: Array = []
	if _plate_built:
		var settled := {}
		for entry in next:
			var key := String(entry["key"])
			settled[key] = true
			var old: Dictionary = was.get(key, {})
			if old.is_empty():
				fly[key] = {"mode": FLY_IN}
				continue
			# 同位不动: a character the new chart keeps in the slot it is already in - the
			# common case, since most of a plate does stand still between two 时辰
			var delta := wrapf(float(entry["a"]) - float(old["a"]), -180.0, 180.0)
			if absf(delta) < 0.01 and (old["at"] as Vector2) == (entry["at"] as Vector2):
				continue
			var arc := absf(delta) <= float(entry["cell"]) * FLY_ARC_SLOT
			fly[key] = {"mode": FLY_ARC if arc else FLY_STRAIGHT,
					"a0": float(old["a"]), "at0": old["at"]}
		for entry in was.values():
			if not settled.has(String(entry["key"])):
				fading.append(entry)
	_plate = next
	_fading = fading
	_fly = fly
	_fly_t = 1.0 if fly.is_empty() else 0.0
	if fly.is_empty():
		# nothing to fly: whoever drew the plate last may be waiting on `_fly_t` to come
		# back - `_step_fly` never runs when it starts at 1
		_fading.clear()
	_plate_built = true


## The plate as it stands on the screen right now - each entry at whatever the fly has it
## at, plus the ones already fading out. This is the "from" side `_retarget` matches the
## new chart against.
func _snapshot() -> Array:
	var out: Array = []
	for entry in _plate:
		var now := _entry_now(entry)
		var shown: Dictionary = entry.duplicate()
		shown["a"] = rad_to_deg(float(now["angle"]))
		shown["at"] = now["at"]
		out.append(shown)
	for entry in _fading:
		out.append(entry)
	return out


## The charts the card is drawn from, handed over by the sky whenever the 时辰
## turns: `pan` is `QiMen.pan()`'s palaces, `liuren` is `LiuRen.pan()`'s slots, and
## `kong` the 奇门 旬空's two 支 (the 神盘 writes a 〇 before the 神 of the palace
## they fall in). Handing a chart over is also what starts the 换字飞转: the new plate is
## matched against the one on the card (`_retarget`).
func set_chart(pan: Array, liuren: Array, horse := -1, kong: Array = []) -> void:
	_palaces = pan
	_slots = liuren
	_horse = horse
	_kong = []
	for branch in kong:
		var index := Branches.NAMES.find(String(branch))
		if index >= 0 and not _kong.has(kong_slot(index)):
			_kong.append(kong_slot(index))
	_retarget()
	_refresh()


## Which 局 the chart was cast in, handed over with it: only the sign is read here
## (the 八分盘's 内盘 is the 阳宫 under a 阳遁 and the 阴宫 under a 阴遁), but the number
## itself is what the sign is carried in, so the dial keeps the 局 whole.
func set_ju(ju: int) -> void:
	_ju = ju
	_refresh()


## Which 神盘 slot a 空亡 支 marks: the 神 ring's eight 45 deg sectors are the 后天八宫,
## so the slot is the palace whose sector holds that branch - 子 坎, 丑寅 艮, 卯 震,
## 辰巳 巽, 午 离, 未申 坤, 酉 兑, 戌亥 乾. The four corner palaces cover two branches
## and are 空 when either of them is (which is why the two 空亡 支 can share a slot).
static func kong_slot(branch: int) -> int:
	return int(round(2.0 * float(branch) / 3.0)) % 8


## The bodies the dial marks, handed over by the sky on every time step
## (`SkyBackground._bodies`): Vector2(altitude, azimuth) each, the same pair
## `Astro.altaz()` reports. They move with the clock, not with the 时辰, so they are
## set outside set_chart(). `planets` is one {at, colour, norm} for each of the sky's
## **五星** (2026-10-14 用户: "日月金木水火土星保留,月用月牙图标,五行星用五行色点" -
## the card carries the Sun, the Moon as a crescent and the five planets as points of
## their own 五行 colour; 天王/海王 are on the sky's own layer, not here), `norm` the
## magnitude ramp `SkyPlanets.mark_norm` gives (0 faint, 1 bright).
func set_bodies(sun: Vector2, moon: Vector2, planets: Array = []) -> void:
	_bodies = {"sun": sun, "moon": moon, "planets": planets}
	_refresh()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = Fonts.ui_font()
	_build_controls()


func _refresh() -> void:
	queue_redraw()


# ------------------------------------------------------------ dial arithmetic

## Where a bearing is drawn on the card: the card stands still with 南 at the top
## and 北 at the bottom (`SOUTH_UP`, 上南下北, 2026-10-10 第十五轮), so this is only
## how far clockwise from the top a bearing sits - 北 reads 180 (the bottom), 东 270
## (the left), 西 90 (the right). It used to be measured against the view's own
## bearing, and that difference is what turned the card; the camera's own reading is
## the view arc's business now, not the card's.
static func dial_offset_deg(bearing_deg: float) -> float:
	return fposmod(bearing_deg - SOUTH_UP, 360.0)


# ------------------------------------------------------------------- controls

func _build_controls() -> void:
	# 左转 / 右转 sit in the card's own **upper** corners (用户 2026-10-10 第十八轮:
	# 移到罗盘左上/右上角), the two corners the rim leaves free - the card's lower two
	# are the time bar's chips (时辰± on the right, 星座/星宿 on the left since
	# 2026-10-12 第二十一轮). They carry arrows rather than words, and the arrows point
	# the way the card turns under the view: ↙ U+2199 at the top left is 左转, ↘
	# U+2198 at the top right is 右转 (the ◀ U+25C0 family is not in the system font,
	# ↙↘ are). One glyph in the box, so a size up. The box is square and a little
	# lower down the corner than it was (2026-10-12 第二十一轮: 窄一点、做成方的、向下移一移).
	# The chips are added to the tree *before* their box is set: a Button is never
	# smaller than its minimum size, and until it is in the tree that minimum is the
	# default theme's (31 px tall, whatever the font), which would clamp a 24 x 24 chip
	# to 24 x 31 and never let it shrink back (measured 2026-10-10 第十八轮).
	var left := _chip("↙", ARROW_SIZE)
	left.pressed.connect(turn.bind(-1))
	add_child(left)
	left.position = Vector2(ROTATE_INSET, ROTATE_TOP)
	left.size = Vector2(ROTATE_CHIP, ROTATE_CHIP)

	var right := _chip("↘", ARROW_SIZE)
	right.pressed.connect(turn.bind(1))
	add_child(right)
	# the card's own width rather than this Control's, which is only the same number
	# once the sky has laid the card out at its full size
	right.position = Vector2(CENTRE.x * 2.0 - ROTATE_INSET - ROTATE_CHIP, ROTATE_TOP)
	right.size = Vector2(ROTATE_CHIP, ROTATE_CHIP)

	# The four direction triangles, on the card's own four axes (2026-10-10 第十五轮):
	# the 北/东/南/西 chip row that used to stand under the dial, moved onto the
	# points it names. 南 is the top of the card and 北 the bottom, so pressing 北
	# turns the view to the bottom of the card, which is where the view arc walks to.
	for direction: Dictionary in DIRECTIONS:
		_add_direction(direction)


## One direction triangle's button: a 24 x 24 target with the mark drawn where the
## point actually stands inside it. The mark's centre is the point's own place on the
## rim (the rim plus DIR_MARK) and the button is laid flush with the window's edge
## along the axis it faces, because a box centred on a mark that is only 7 px from
## that edge would hang off the card.
func _add_direction(direction: Dictionary) -> void:
	var at := CENTRE + out_of(float(direction["bearing"])) * (R_DISC + DIR_MARK)
	var origin := Vector2(clampf(at.x - DIR_BUTTON * 0.5, 0.0, size.x - DIR_BUTTON),
			clampf(at.y - DIR_BUTTON * 0.5, 0.0, size.y - DIR_BUTTON))
	var button := DirectionButton.new()
	button.out = out_of(float(direction["bearing"]))
	button.at = at - origin
	button.colour = direction["colour"]
	button.focus_mode = Control.FOCUS_NONE
	button.position = origin
	button.size = Vector2(DIR_BUTTON, DIR_BUTTON)
	button.pressed.connect(rig_face.bind(String(direction["cardinal"])))
	# the triangle is the whole control and the theme draws nothing of it, so the
	# mark has to be repainted when the pointer enters or leaves it
	button.mouse_entered.connect(button.queue_redraw)
	button.mouse_exited.connect(button.queue_redraw)
	add_child(button)


## The unit vector from the card's centre towards a bearing's place on it, in the
## card's own frame.
static func out_of(bearing_deg: float) -> Vector2:
	var angle := deg_to_rad(dial_offset_deg(bearing_deg))
	return Vector2(sin(angle), -cos(angle))


## A point on the card: along `angle`'s own direction (already a dial offset, in radians)
## out to `r`, then the entry's own screen offset - a 宫块's line stands a row above or
## below the anchor of its 宫 (`off`), and a 大六壬 label stands on its slot's anchor.
## 换字飞转 sweeps `angle` and leaves `off` alone, which is what keeps a block's three
## lines a row apart while it carries them round the card.
static func _place(angle: float, r: float, off: Vector2) -> Vector2:
	return CENTRE + Vector2(sin(angle), -cos(angle)) * r + off


## Which way round a label's own run lies on the card: along the tangent, except on the
## lower half, where pointing it outwards would hang the name upside down - there it is
## turned the other way round, so the five names from 120 to 240 deg still read left to
## right (用户 2026-10-10 第十六轮: 下方5组字反着的，改成正过来方便读).
static func _run_turn(angle: float) -> float:
	return angle + PI if angle > PI * 0.5 and angle < PI * 1.5 else angle


func _chip(text: String, font_size := 12) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", C_DIM)
	button.add_theme_color_override("font_hover_color", C_TEXT)
	button.add_theme_color_override("font_pressed_color", C_INDEX)
	button.add_theme_constant_override("outline_size", ARROW_OUTLINE)
	button.add_theme_color_override("font_outline_color", C_DIM)
	button.add_theme_stylebox_override("normal", _box(C_FILL, C_BORDER))
	button.add_theme_stylebox_override("hover", _box(C_FILL_HOVER, C_BORDER_HOVER))
	button.add_theme_stylebox_override("pressed", _box(C_FILL_HOVER, C_BORDER_HOVER))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(5)
	box.set_border_width_all(1)
	box.border_color = border
	# A Button cannot be smaller than its own minimum size, and the default content
	# margins would push a chip several px past the box it was asked for (measured
	# 2026-10-10 第十八轮: 60 x 24 came out 60 x 31, whatever the font size). These
	# chips are placed by hand in the card's corners, so they get exactly the box the
	# layout says and the text is centred in it.
	box.set_content_margin_all(0.0)
	return box


# --------------------------------------------------------------- the turning

## One press of 左转 (direction -1) or 右转 (+1): the view turns one 山 the way
## the button's arrow points - facing south and turning right means facing west,
## so the bearing grows.
func turn(direction: int) -> void:
	if rig != null:
		rig.nudge(TURN_STEP * float(direction), 0.0)


func rig_face(cardinal: String) -> void:
	if rig != null:
		rig.face_cardinal(cardinal)


# ------------------------------------------------------------------- drawing

func _draw() -> void:
	if _font == null:
		return
	draw_circle(CENTRE, R_DISC, C_DISC)
	draw_arc(CENTRE, R_DISC, 0.0, TAU, 128, C_RIM, 1.2, true)
	_draw_ticks()
	_draw_bodies()

	# the 奇门's own eight blocks in the middle, the 大六壬 ring outside them - and the
	# 八分盘 under both, which is what says which half of the chart is 内盘. The blocks
	# and the ring are one list of characters now (换字飞转), so they are drawn by
	# `_draw_plate`; the 卦 ring is fixed and stays on its own.
	_draw_panels()
	_draw_bagua_ring()
	_draw_plate()

	_draw_hands()
	_draw_view_arc()
	_draw_taiji()


## The Sun and the Moon on the card: the Sun outside the degree ticks, the Moon
## inside them (their bearings are the card's own, so both stand on the card like
## the rings do). A body the sky has below the horizon is dimmed rather than
## dropped - the mark is the one thing on the card that says where a body is, and
## "it is down" is worth reading off the card.
func _draw_bodies() -> void:
	for which in ["sun", "moon"]:
		if not _bodies.has(which):
			continue
		var at: Vector2 = _bodies[which]
		var dir := out_of(at.y)
		var alpha := 1.0 if at.x > 0.0 else C_BELOW
		if which == "sun":
			_draw_sun(CENTRE + dir * R_SUN, Color(C_SUN, C_SUN.a * alpha))
		else:
			_draw_moon(CENTRE + dir * R_MOON, Color(C_MOON, C_MOON.a * alpha))
	# the five planets, in the Sun's own lane: a planet and the Sun can stand
	# together on the card, and seeing that is the point of the mark (2026-10-09 行星指针)
	for planet: Dictionary in _bodies.get("planets", []):
		var at: Vector2 = planet["at"]
		var dir := out_of(at.y)
		var alpha := 1.0 if at.x > 0.0 else C_BELOW
		_draw_planet(CENTRE + dir * R_SUN, planet["colour"], alpha, planet["norm"])


## One planet's mark: a plain disc in the planet's own colour, sized by the same
## magnitude ramp the sky's own mark is read off (`SkyPlanets.mark_norm`). No ring
## and no crescent - those two belong to the Sun and the Moon, which are discs; a
## planet is a point of light.
func _draw_planet(at: Vector2, colour: Color, alpha: float, norm: float) -> void:
	draw_circle(at, lerpf(1.3, 2.6, norm), Color(colour, alpha * 0.95))


## A filled disc inside a thin ring, about 7 px across: the Sun.
func _draw_sun(at: Vector2, colour: Color) -> void:
	draw_circle(at, 2.2, colour)
	draw_arc(at, 3.4, 0.0, TAU, 24, colour, 1.0, true)


## A thick crescent opening to the right, about 7 px across: the Moon.
func _draw_moon(at: Vector2, colour: Color) -> void:
	draw_arc(at, 2.6, deg_to_rad(35.0), deg_to_rad(325.0), 20, colour, 2.2, true)


## Degree ticks, clock-face style: a 大 mark every 30 deg - one per 地支, which is
## also where the 大六壬 ring cuts its twelve sectors - each of the five 小 marks
## between two of them 6 deg apart, so the card carries 12 大 and 60 小 in all. The
## north mark is the one accent on the card: without it nothing says which way the
## scale runs (a ring of identical ticks reads the same at 0 and at 180), and since
## the card is fixed 上南下北 it is now the bottom of the dial.
func _draw_ticks() -> void:
	for i in 60:
		var dir := out_of(6.0 * float(i))
		var major := i % 5 == 0
		var inner := R_TICK_IN if major else R_TICK_IN + 5.0
		var colour := C_TICK_MAJOR if major else C_TICK
		var width := 1.0
		if i == 0:
			inner = R_TICK_IN - 5.0
			colour = C_INDEX
			width = 1.8
		draw_line(CENTRE + dir * inner, CENTRE + dir * R_TICK_OUT, colour, width, true)


## 环一: the eight palaces' trigrams, as their own glyphs - the ring the 奇门 chart is
## cast on, so the 门 and 星 blocks below it read straight out to their own palace. The
## bars are the one ring on the card that is not characters (the 大六壬's names are plate
## entries, `_build_plate`), so this is a function of its own rather than a layer
## description - and it never moves, a trigram being fixed to its palace.
func _draw_bagua_ring() -> void:
	for i in BAGUA.size():
		var dir := out_of(22.5 + 45.0 * float(i))
		draw_line(CENTRE + dir * (R_BAGUA - ROW), CENTRE + dir * (R_BAGUA + ROW),
				C_RING, 1.0, true)
	for i in BAGUA.size():
		var angle := deg_to_rad(dial_offset_deg(45.0 * float(i)))
		var dir := Vector2(sin(angle), -cos(angle))
		_trigram(CENTRE + dir * R_BAGUA, angle, int(BAGUA[i][2]), C_BAGUA)


## The 八分盘: the disc's eight 45 deg sectors, one per 奇门 宫, standing under the 卦
## ring and the 宫块 - the inner four 微亮, the outer four faint (用户 2026-10-10
## 第二十轮). Which half is which is the chart's own 阴阳遁 (`QiMen.is_inner`): a 阳遁
## lights the 阳宫 (洛书 8/3/4/1), a 阴遁 the 阴宫 (2/9/6/7), so the shading of the
## whole card turns over when a 节 turns the 局. Every sector is exactly 45 deg wide
## on the same band, so they tile the disc with no seam double-drawn where two of
## them meet. Nothing is drawn until a chart arrives: the sectors are that chart's,
## not decoration.
func _draw_panels() -> void:
	if _palaces.is_empty():
		return
	var half := deg_to_rad(22.5)
	for i in BAGUA.size():
		var middle := deg_to_rad(dial_offset_deg(45.0 * float(i)))
		var inner := QiMen.is_inner(int(BAGUA[i][1]), _ju > 0)
		var points := PackedVector2Array()
		# out along the inner edge, back along the outer one, so the ring sector is
		# one closed outline (a concave polygon, which is what draw_colored_polygon
		# triangulates the same way it does the 太极's two fish)
		for step in PANEL_SEG + 1:
			var at := middle - half + 2.0 * half * float(step) / float(PANEL_SEG)
			points.append(CENTRE + Vector2(sin(at), -cos(at)) * R_PANEL_IN)
		for step in PANEL_SEG + 1:
			var at := middle + half - 2.0 * half * float(step) / float(PANEL_SEG)
			points.append(CENTRE + Vector2(sin(at), -cos(at)) * R_PANEL_OUT)
		draw_colored_polygon(points, C_PANEL_INNER if inner else C_PANEL_OUTER)


## The plate: every character the chart turns over, each drawn where the fly has it
## (换字飞转). The order is the card's own - the 奇门's 八宫块 first, then the 大六壬 ring's
## slot lines over them, then its names, then the characters the new chart dropped, which
## keep the place they stood on while they fade out.
func _draw_plate() -> void:
	for entry in _plate:
		if String(entry["payload"]["kind"]) == "block":
			_draw_entry(entry, _entry_now(entry))
	for i in int(round(360.0 / 30.0)):
		var dir := out_of(15.0 + 30.0 * float(i))
		draw_line(CENTRE + dir * (R_LIUREN - ROW), CENTRE + dir * (R_LIUREN + ROW),
				C_RING, 1.0, true)
	for entry in _plate:
		if String(entry["payload"]["kind"]) != "block":
			_draw_entry(entry, _entry_now(entry))
	var e := _eased()
	for entry in _fading:
		_draw_entry(entry, {"angle": deg_to_rad(float(entry["a"])), "at": entry["at"],
				"alpha": 1.0 - e, "scale": lerpf(1.0, BORN_SCALE, e)})


## One character of the plate, drawn where the fly has it: a 大六壬 slot's own run
## (神 + 遁干 + 天盘支, along the card or down it on the two exact sides), one line of a
## 奇门 宫's block, or the 驿马. A block line is upright and runs down the screen wherever
## its 宫 sits - the chart's names are read, not followed round the dial - so it is drawn
## from a canvas put on its own anchor, which is also what lets a line being born or dying
## be scaled about itself.
func _draw_entry(entry: Dictionary, now: Dictionary) -> void:
	var payload: Dictionary = entry["payload"]
	var at: Vector2 = now["at"]
	var alpha := float(now["alpha"])
	match String(payload["kind"]):
		"ring":
			if bool(payload["side"]):
				_upright_column(at, String(payload["text"]), 13, C_ZHI, payload["ink"],
						alpha, float(now["scale"]))
			else:
				_radial_label(at, float(now["angle"]), String(payload["text"]), 13,
						C_ZHI, payload["ink"], alpha, float(now["scale"]))
		"block":
			var scale := float(now["scale"])
			if is_equal_approx(scale, 1.0):
				# 静止或飞行中的那一行(不缩放)直接给绝对锚点: 把画布搬到锚点上再画字,
				# 字的边缘栅格化会挪一丁点 - 实测 24 行的墨各差 3..57 px, 而这份盘的
				# 排法一个像素都不该动(2026-10-13, 出图 A/B 逮到的)
				_upright_pair(at, String(payload["mark"]), String(payload["head"]),
						payload["head_colour"], String(payload["tail"]),
						payload["tail_colour"], alpha)
			else:
				draw_set_transform(at, 0.0, Vector2.ONE * scale)
				_upright_pair(Vector2.ZERO, String(payload["mark"]),
						String(payload["head"]), payload["head_colour"],
						String(payload["tail"]), payload["tail_colour"], alpha)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"horse":
			# the 驿马 lands where the fly puts it and shivers on the clock's beat from
			# there (TWITCH_*): one mark, the two motions one after the other
			var dir := Vector2(sin(float(now["angle"])), -cos(float(now["angle"])))
			var shiver := Vector2.ZERO
			if _twitch < TWITCH_SEC:
				var decay := 1.0 - _twitch / TWITCH_SEC
				shiver = Vector2(-dir.y, dir.x) \
						* sin(TAU * TWITCH_HZ * _twitch) * TWITCH_PX * decay
			_upright_label(at + shiver, "马", 12, C_HORSE, alpha)


## Where a plate entry is drawn **right now**: its own place while the card stands, and
## the half-way value of its fly while one is running - the bearing swept round the card
## (同心转), a straight line with a rise (直线飞), or the size and the solidity of a name
## being born or dying (淡入/淡出). Every mode lands exactly on the entry's own place at
## t = 1, which is what lets `_step_fly` drop the whole fly without the card jumping.
func _entry_now(entry: Dictionary) -> Dictionary:
	var angle := deg_to_rad(float(entry["a"]))
	var at: Vector2 = entry["at"]
	var alpha := 1.0
	var scale := 1.0
	var fly: Dictionary = _fly.get(String(entry["key"]), {})
	if not fly.is_empty():
		var e := _eased()
		match int(fly["mode"]):
			FLY_ARC:
				var sweep := wrapf(float(entry["a"]) - float(fly["a0"]), -180.0, 180.0)
				angle = deg_to_rad(float(fly["a0"]) + sweep * e)
				at = _place(angle, float(entry["r"]), entry["off"])
			FLY_STRAIGHT:
				at = (fly["at0"] as Vector2).lerp(at, e) \
						+ Vector2.UP * FLY_LIFT * sin(PI * e)
			FLY_IN:
				alpha = e
				scale = lerpf(BORN_SCALE, 1.0, e)
	return {"angle": angle, "at": at, "alpha": alpha, "scale": scale}


## One 宫's three lines, top to bottom: its 神 (with the 空亡's 〇 in the margin when
## the 旬空 falls in the 宫), its 星 with the 天盘干 it carries, and its 门 with the
## 地盘干. Each line is `[mark, name, name colour, stem, stem colour]`: the mark is
## the 〇 or empty, the name takes the duty gold when the 时辰 turns on it, and the
## stem keeps the line's own colour.
func _palace_block(index: int) -> Array:
	var palace: Dictionary = _palace(int(BAGUA[index][1]))
	if palace.is_empty():
		return []
	var duty_star := bool(palace.get("duty_star", false))
	var lines: Array = []
	var god := str(palace.get("god", ""))
	if god != "":
		lines.append(["〇" if _kong.has(index) else "", god,
				C_DUTY if duty_star else C_GOD, "", C_GOD])
	lines.append(["", _core(str(palace.get("star", "")), "天"),
			C_DUTY if duty_star else C_STAR, str(palace.get("tian_gan", "")), C_STAR])
	lines.append(["", _core(str(palace.get("door", "")), "门"),
			C_DUTY if bool(palace.get("duty_door", false)) else C_DOOR,
			str(palace.get("di_gan", "")), C_DOOR])
	return lines


## The card's characters as one list, which is what the fly matches two charts up by
## (换字飞转, 2026-10-13): a key, the bearing / radius / own offset it stands on, and how
## to draw it once it gets there. Two charts are compared through these keys, so a turn
## reads as the characters moving rather than as the whole card being redrawn - and the
## key is always what the chart itself says the character is, never a position.
##
## 奇门 八宫块: one entry per line (神 over 星 over 门, each with the 干 that rides with
## it, 2026-10-09 第十一轮), keyed by that line's own name; the three lines of a 宫 stand
## a row apart about the 宫's anchor (`off`), and each keeps its own row offset while it
## flies.
## 大六壬 环五: one entry per slot - 贵人, 遁干 and the 天盘支 standing over that 地盘支,
## keyed by the whole label, because the three move together: measured on this sky, the
## whole triple is one slot further on every 时辰 (`Branches.bearing(i)` is the slot's own
## bearing and the label's 支/干 ride the 天盘, which turns a slot an hour). They come apart
## only when the **day** turns (子时): the 贵人宫 is the day 干's own answer, so the twelve
## 天将 then jump further than their 干支 do - and the whole-label key reads that as the
## ring being recast, which is what it is (each label fades out where it stood and the new
## one is born in, no match by text). The colours are the chart's own (`_slot_ink`; the two
## slots on the card's exact sides are written down the card as columns instead, 用户
## 2026-10-10 第十七轮).
## 驿马: one entry, keyed by the mark itself - the horse the 时辰's 三合 sends to 寅 巳 申
## 亥, on the 神盘's own radius (those four branches fall between the eight palace slots,
## so it never lands on a ring label; it is the one mark that says where the chart is
## travelling rather than what stands where, and it shivers sideways for TWITCH_SEC on
## every beat, `_draw_entry`).
## The 卦 ring is not here - a trigram never moves.
func _build_plate() -> Array:
	var plate: Array = []
	for i in BAGUA.size():
		var lines := _palace_block(i)
		if lines.is_empty():
			continue
		var a := dial_offset_deg(45.0 * float(i))
		for row in lines.size():
			var line: Array = lines[row]
			# centred on the 宫's anchor, so the block reads out from the 宫's own point
			var off := Vector2(0.0,
					(float(row) - float(lines.size() - 1) * 0.5) * LINE_PITCH)
			plate.append({
				"key": "block:%s" % line[1],
				"cell": 45.0, "a": a, "r": R_PALACE, "off": off,
				"at": _place(deg_to_rad(a), R_PALACE, off),
				"payload": {
					"kind": "block", "mark": String(line[0]),
					"head": String(line[1]), "head_colour": line[2],
					"tail": String(line[3]), "tail_colour": line[4],
				},
			})
	for i in Branches.NAMES.size():
		var slot: Dictionary = _slot(i)
		if slot.is_empty():
			continue
		var bearing := dial_offset_deg(Branches.bearing(i))
		var text := "%s%s%s" % [slot.get("god", ""), slot.get("stem", ""),
				slot.get("branch", "")]
		plate.append({
			"key": "ring:%s" % text,
			"cell": 30.0, "a": bearing, "r": R_LIUREN, "off": Vector2.ZERO,
			"at": _place(deg_to_rad(bearing), R_LIUREN, Vector2.ZERO),
			"payload": {"kind": "ring", "text": text, "ink": _slot_ink(slot),
				"side": is_side(bearing)},
		})
	if _horse >= 0 and _horse < Branches.NAMES.size():
		var a := dial_offset_deg(Branches.bearing(_horse))
		plate.append({
			"key": "horse", "cell": 30.0, "a": a, "r": R_HORSE, "off": Vector2.ZERO,
			"at": _place(deg_to_rad(a), R_HORSE, Vector2.ZERO),
			"payload": {"kind": "horse"},
		})
	return plate


## One 大六壬 slot's label ink, character by character: 神 (the 贵人's own red on the
## slot it rides), 遁干 (the ring's own warm amber), 天盘支 (the card's 金 on the slot
## the 月将 was laid on). The three fields are one character each - 遁干 is a 干 or the
## 空亡's 〇 - so the ink lines up with the label `_build_plate` writes.
func _slot_ink(slot: Dictionary) -> Array:
	var fields := [[str(slot.get("god", "")),
				C_GUIDE if bool(slot.get("guide", false)) else C_ZHI],
			[str(slot.get("stem", "")), C_ZHI],
			[str(slot.get("branch", "")),
				C_DUTY if bool(slot.get("general", false)) else C_ZHI]]
	var ink: Array = []
	for field: Array in fields:
		for i in String(field[0]).length():
			ink.append(field[1])
	return ink


## The name a line or ring draws: the chart's own is the full one (天蓬, 休门), and a
## line that shows it beside a stem has room for the character that names it - the
## 天 in front, the 门 behind.
static func _core(name: String, affix: String) -> String:
	if name.begins_with(affix):
		return name.substr(affix.length())
	if name.ends_with(affix):
		return name.substr(0, name.length() - affix.length())
	return name


func _palace(number: int) -> Dictionary:
	return _palaces[number] if number < _palaces.size() and _palaces[number] is Dictionary \
			else {}


func _slot(index: int) -> Dictionary:
	return _slots[index] if index < _slots.size() and _slots[index] is Dictionary else {}


## The observer's own wall clock, as Godot's datetime dictionary in their local
## time. The sky's clock is deliberately not consulted: a 时辰 press walks the sky
## two hours in about a second, and a hand that read it flew round 120 times
## (用户 2026-10-10 第十九轮: 时辰加减时秒针乱飞，让秒针独立运行，不受旋转影响).
func wall_clock() -> Dictionary:
	var offset := observer.utc_offset if observer != null else 0.0
	return Time.get_datetime_dict_from_unix_time(
			int(Time.get_unix_time_from_system() + offset * 3600.0))


## The three hands, on the card's own face: 12 o'clock is the top - 午, noon - and
## they turn clockwise from there, the same way the tick ring and the view arc are
## counted. The hour and minute hands are solid; the second hand's stem is faint
## where it crosses the 八宫块 and the two chart rings.
func _draw_hands() -> void:
	var now := wall_clock()
	var hour := float(now["hour"]) + float(now["minute"]) / 60.0
	var minute := float(now["minute"]) + float(now["second"]) / 60.0
	var second := float(now["second"])
	_hand(hour / 12.0 * 360.0, HAND_HOUR, 2.6, C_HAND)
	_hand(minute / 60.0 * 360.0, HAND_MINUTE, 1.8, C_HAND)
	_hand(second / 60.0 * 360.0, HAND_STEM, 1.0, C_HAND_STEM)
	_hand(second / 60.0 * 360.0, HAND_TIP, 1.2, C_HAND)


## One hand: a line from just outside the 太极 out to `reach`, turned
## `degrees_clockwise_from_top` round the card.
func _hand(degrees_clockwise_from_top: float, reach: float, width: float,
		colour: Color) -> void:
	var angle := deg_to_rad(degrees_clockwise_from_top)
	var dir := Vector2(sin(angle), -cos(angle))
	draw_line(CENTRE + dir * (TAIJI_R + 3.0), CENTRE + dir * reach, colour, width, true)


## The view arc: where the 3D scene's camera looks, as an arc outside the rim
## centred on that bearing (2026-10-10 第十五轮, replacing the index triangle that
## used to stand over the top of the dial). With the card fixed, the camera's own
## reading has to be the thing that moves - turning the view, one 山 at a time or
## by pressing a direction triangle, walks this arc round the rim, and pointing the
## view at 北 puts its middle at the bottom of the card, where 北 is.
func _draw_view_arc() -> void:
	if rig == null:
		return
	# draw_arc measures from +x towards +y (screen down), this card's dial angle
	# from the top towards the east, so the two differ by a quarter turn
	var middle := deg_to_rad(dial_offset_deg(rig.azimuth)) - PI * 0.5
	var half := deg_to_rad(_view_arc_span() * 0.5)
	draw_arc(CENTRE, R_VIEW_ARC, middle - half, middle + half, 64, C_INDEX, ARC_WIDTH,
			true)


## How long the arc is: the horizontal field of view the wallpaper is actually
## showing, in degrees of bearing. It is the *map's* own width, not the camera's
## (SkyProjection.frame_span): the rig holds a vertical field (its `_apply` writes
## `Camera3D.fov`, and the camera keeps its height) and the map decides what that comes
## to across the frame - 170.7 deg for the fisheye at the opening field, 126.3 for the
## camera's own lens, either way wider on a wider frame. A 16:9 wallpaper therefore
## shows about 171 deg across - and that is what the arc is drawn as, so the card says
## "this much of the sky is on screen" as well as "on this bearing" (用户 2026-10-12
## 第二十一轮: 宽屏的弧就长点，窄屏就短点).
##
## It is a *bearing* span: the card is drawn in bearings, and the frame's own
## horizontal field is only the same thing along the horizon. Close enough for a
## wallpaper whose frame is under its own horizon, and the alternative - projecting
## two frame edges through the camera - would swing the arc's ends about with the
## altitude, which is not what the mark is read for.
func _view_arc_span() -> float:
	var camera := rig.camera
	if camera == null or not is_instance_valid(camera):
		return ARC_SPAN
	var rect := camera.get_viewport().get_visible_rect().size
	if rect.y <= 0.0:
		return ARC_SPAN
	return SkyProjection.frame_span(camera, rect)


## The 太极 in the middle of the card, where the bearing readout used to be: two
## fish one S-curve apart, the white one the left half plus the bulge over the top
## and minus the notch under it, and an eye in each head (the reference compass
## builds its own the same way).
func _draw_taiji() -> void:
	draw_colored_polygon(_fish(true), C_TAIJI_WHITE)
	draw_colored_polygon(_fish(false), C_TAIJI_BLACK)
	draw_circle(CENTRE + Vector2(0.0, -TAIJI_R * 0.5), TAIJI_R * 0.16, C_TAIJI_BLACK)
	draw_circle(CENTRE + Vector2(0.0, TAIJI_R * 0.5), TAIJI_R * 0.16, C_TAIJI_WHITE)


## One fish's outline in screen coordinates, its boundary walked in order: the S is
## top → half circle → centre → half circle → bottom, and the two fish share it.
func _fish(white: bool) -> PackedVector2Array:
	var r := TAIJI_R
	var r2 := r * 0.5
	var points := PackedVector2Array()
	if white:
		for i in range(TAIJI_SEG + 1):
			var t := PI * float(i) / float(TAIJI_SEG)
			points.append(Vector2(r2 * sin(t), -r2 - r2 * cos(t)))
		for i in range(1, TAIJI_SEG + 1):
			var t := PI * (1.0 - float(i) / float(TAIJI_SEG))
			points.append(Vector2(-r2 * sin(t), r2 + r2 * cos(t)))
		for i in range(1, TAIJI_SEG + 1):
			var a := PI + PI * float(i) / float(TAIJI_SEG)
			points.append(Vector2(r * sin(a), -r * cos(a)))
	else:
		for i in range(TAIJI_SEG + 1):
			var a := PI * float(i) / float(TAIJI_SEG)
			points.append(Vector2(r * sin(a), -r * cos(a)))
		for i in range(1, TAIJI_SEG + 1):
			var t := PI * float(i) / float(TAIJI_SEG)
			points.append(Vector2(-r2 * sin(t), r2 + r2 * cos(t)))
		for i in range(1, TAIJI_SEG + 1):
			var t := PI * (1.0 - float(i) / float(TAIJI_SEG))
			points.append(Vector2(r2 * sin(t), -r2 - r2 * cos(t)))
	for i in points.size():
		points[i] = CENTRE + points[i]
	return points


## Whether a dial angle is one of the card's two exact sides - 正左 (270, 东) or
## 正右 (90, 西). The 大六壬 ring writes the two names there as columns instead of
## along the tangent (用户 2026-10-10 第十七轮).
static func is_side(dial_deg: float) -> bool:
	return is_equal_approx(fposmod(dial_deg, 180.0), 90.0)


## One em of the label font at `size`: what a CJK glyph advances, and so the pitch
## every label written character by character is laid out at.
func _em(size: int) -> float:
	return _font.get_string_size("〇", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## One name of the 大六壬 ring written **down the card as a column**: 神 over 干 over
## 支, every character the right way up and read downwards (用户 2026-10-10 第十七轮:
## 正左/正右两宫从上到下竖着正写 神/干/支). The three characters are the same ones the
## tangential label carries and in the same order - the ring's own name is only ever
## 神 + 遁干 + 天盘支 (三字, see `_build_plate`) - and the column stands in the same
## 13 x 39 px box the tangential label does at those two slots, so nothing else on
## the card moves. `ink` is the same per-character colour list the tangential label
## takes, so a column writes its 贵人 and its 月将支 in the same two inks the rest of
## the ring does.
func _upright_column(at: Vector2, text: String, size: int, colour: Color,
		ink: Array = [], alpha := 1.0, scale := 1.0) -> void:
	# a CJK glyph advances one em, which is the pitch the tangential label lays its
	# characters out at too - the column ends up exactly as long as the row was. The
	# canvas goes on the column's own centre, so a column being born or dying is scaled
	# about itself and stays where it stands (2026-10-13, 换字飞转).
	var pitch := _em(size)
	draw_set_transform(at, 0.0, Vector2(scale, scale))
	var top := -pitch * float(text.length() - 1) * 0.5
	for i in text.length():
		_upright_label(Vector2(0.0, top + pitch * float(i)), text.substr(i, 1), size,
				ink[i] if i < ink.size() else colour, alpha)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## One pass of a label's characters, laid out from `at` towards the east: a single
## `draw_string` while the whole label is written in one ink, and one per character
## otherwise, each in `ink`'s own colour (a slot's 神, 遁干 and 支 can be three
## different inks). `at` is the top-left of the run's box, the same corner
## `draw_string` is handed, and the characters are pitched at one em - the advance a
## CJK glyph takes - so the coloured pass lands in the box the single one does.
func _draw_run(at: Vector2, text: String, size: int, colour: Color,
		ink: Array, alpha := 1.0) -> void:
	if ink.is_empty():
		draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size,
				Color(colour, colour.a * alpha))
		return
	var pitch := _em(size)
	var x := at.x
	for i in text.length():
		var ink_colour: Color = ink[i] if i < ink.size() else colour
		draw_string(_font, Vector2(x, at.y), text.substr(i, 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, size,
				Color(ink_colour, ink_colour.a * alpha))
		x += pitch


## One label on the card, its top pointing radially outwards so a name stands the
## way round the dial does - **except on the lower half of the dial**, where pointing
## it outwards would hang the name upside down: there it is turned the other way
## round instead, so the five names from 120 to 240 deg still read left to right
## (用户 2026-10-10 第十六轮: 下方5组字反着的，改成正过来方便读). The two names on the
## exact sides never reach here: they are written as columns (`_upright_column`).
##
## The turn is 180 deg, and a label that follows the dial's tangent is the same box
## whichever way round it is written, so nothing moves: same box, same reach, same
## clearance from the 奇门 blocks, the tick ring and the 驿马's own ring. Only the ink
## changes hands - `ink`, when the label's characters are not all one colour, is
## handed on to `_draw_run` and the box stays the one this measures.
func _radial_label(at: Vector2, angle: float, text: String, size: int,
		colour: Color, ink: Array = [], alpha := 1.0, scale := 1.0) -> void:
	var extent := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_set_transform(at, _run_turn(angle), Vector2(scale, scale))
	_draw_run(Vector2(-extent.x * 0.5, extent.y * 0.34), text, size, colour, ink, alpha)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## One label drawn the right way up: for the marks that are read as marks rather
## than as a ring's own name - the 驿马 is where it is, not part of the ring it
## happens to sit on, so it is not turned with the card the way `_radial_label`
## turns the rings' names.
func _upright_label(at: Vector2, text: String, size: int, colour: Color,
		alpha := 1.0) -> void:
	var extent := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(_font, at + Vector2(-extent.x * 0.5, extent.y * 0.34), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color(colour, colour.a * alpha))


## One line of a 宫's block, the right way up and centred on `at`: the name in its
## own colour and the 干 that rides with it in the line's ring colour, laid out as
## one run so the pair reads as a single label. `mark` is the 空亡's 〇, and it hangs
## in the margin to the left of the label rather than joining it - so a 宫 that is 空
## still lines its 神 up with the 星 and the 门 under it (用户 2026-10-09 第十二轮).
func _upright_pair(at: Vector2, mark: String, head: String, head_colour: Color,
		tail: String, tail_colour: Color, alpha := 1.0) -> void:
	var head_size := _font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_SIZE)
	var tail_size := _font.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_SIZE)
	var left := at.x - (head_size.x + tail_size.x) * 0.5
	var baseline := at.y + head_size.y * 0.34
	if mark != "":
		var mark_size := _font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1,
				LINE_SIZE)
		draw_string(_font, Vector2(left - mark_size.x, baseline), mark,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, LINE_SIZE,
				Color(head_colour, head_colour.a * alpha))
	draw_string(_font, Vector2(left, baseline), head, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			LINE_SIZE, Color(head_colour, head_colour.a * alpha))
	if tail != "":
		draw_string(_font, Vector2(left + head_size.x, baseline), tail,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, LINE_SIZE,
				Color(tail_colour, tail_colour.a * alpha))


## One trigram, drawn as its three 爻 rather than written. The bars are turned with
## the card (用户 2026-10-09 第十二轮: 八卦符号还是旋转的) - a 卦 reads the way round
## the dial does, unlike the 神/星/门 blocks beside it. `mask` has one bit per 爻, bit
## 0 the bottom one - set means the 爻 is solid (天/阳), clear means it is broken
## (地/阴), and the broken one leaves a gap in its middle as the character does.
## 13 x 11 px, centred on `at` (the font has no ☰..☷, so this is the only way the
## dial can carry the 卦).
func _trigram(at: Vector2, angle: float, mask: int, colour: Color) -> void:
	draw_set_transform(at, angle, Vector2.ONE)
	var half := TRIGRAM_W * 0.5
	var break_half := TRIGRAM_GAP * 0.5
	for line in 3:
		var y := (1.0 - float(line)) * TRIGRAM_PITCH - TRIGRAM_H * 0.5
		if mask & (1 << line) != 0:
			draw_rect(Rect2(-half, y, TRIGRAM_W, TRIGRAM_H), colour, true)
		else:
			draw_rect(Rect2(-half, y, half - break_half, TRIGRAM_H), colour, true)
			draw_rect(Rect2(break_half, y, half - break_half, TRIGRAM_H), colour, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## One of the card's four direction triangles (2026-10-10 第十五轮). It is a real
## Button because that is how the HUD window tells a control a background put up
## from its own drag handle (`HudWindow._control_at`) - and the theme is made to draw
## nothing of it: the triangle is the whole control, so every stylebox is emptied
## here rather than a box being painted around the mark. `out` is the way the point
## faces (away from the card's centre) and `at` where the mark stands inside the
## button; the parent hands both over, so neither the drawing nor the geometry has to
## guess at the other.
class DirectionButton extends Button:
	const TIP := 4.0    ## the apex, this far past the mark's centre along `out`
	const BASE := 4.0   ## the base, this far behind it
	const SIDE := 5.0   ## and half the base's width

	var out := Vector2.ZERO
	var at := Vector2.ZERO
	var colour := Color.WHITE

	func _init() -> void:
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())

	func _draw() -> void:
		var side := Vector2(-out.y, out.x) * SIDE
		var ink := colour.lightened(0.45) if is_hovered() or button_pressed else colour
		draw_colored_polygon(PackedVector2Array([at + out * TIP, at - out * BASE + side,
				at - out * BASE - side]), ink)
