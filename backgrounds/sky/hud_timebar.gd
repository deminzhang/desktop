## The sky HUD's time bar (计划 §3.4, §6.5 S7): the sky's own clock, with the step
## buttons that move it and the two lines the sky's instant is read off - the 三元九运
## with the 道历 date under it, and the 排盘 the 时辰 is cast from. The wall clock
## itself is on the card: its three hands (SkyCompassHud), which keep the observer's
## own time rather than the sky's.
##
## The step is one 时辰 - the traditional double hour - because that is the unit
## the sky itself is read in; each press is 7200 seconds of sky time forward or
## back, through TimeCore.move_by(), so the running clock and the stepped instant
## never fight. That quarter turn of the sky is *watched*, not cut: move_by()
## eases the instant there over about a second, drawing every frame of it. 现在 is
## the other kind of step - it lands on the real clock at once - and it sits at the
## end of the clock line rather than in a row of its own: the 时辰−/时辰+ chips are the
## card's own lower corners now, and the strip under the card is only as tall as its
## two readout lines (用户 2026-10-10 第十八轮).
##
## Two lines, read off under the card (用户 2026-10-10 第二十轮):
##
##   三元九运 + 道历日期   九紫离火 道历四七二三年八月十九 - the 运 the 立春-turned year
##                        stands in, named by its 玄空 星 (GanZhi.jiu_yun_name), then
##                        the 农历 date. It used to be 农历日期 alone on the first
##                        line and "下元九运 · 四柱 · 节气" on the second.
##   四柱 + 节气三元 + 局   丙午 戊戌 庚子 己亥 秋分上元 阴九局 - the four pillars,
##                        then the term in force with the 三元 the day sits in and
##                        the 奇门 局 that makes (QiMen.yuan_name / ju_name).
##
## The first line comes from the pillars the sky hands over with `set_pillars()`;
## the second one's 局 comes over with it in `set_ju()`.
class_name SkyTimeBar
extends Control

const SHICHEN_SECONDS := 7200.0

## Where the readout lines sit inside the strip: the two readout lines only (they
## are what the dial is read as), and the strip is just their height - the button
## row that used to live under them is gone: 时辰−/时辰+ moved into the card's two
## lower corners and 现在 into the clock's own row (用户 2026-10-10 第十八轮: 时辰加减
## 移到罗盘左下右下角、缩小 HUD 整体高度). The bar starts right under the card's own
## rectangle (SkyBackground.HUD_COMPASS_HEIGHT), so the lines hug the card and
## nothing is left empty above them.
const CLOCK_BASELINE := 12.0
const PILLAR_BASELINE := 29.0
## The two 时辰 chips: the card's own lower corners, in this strip's coordinates -
## which begin one card below, so they are negative here. The card's upper corners
## are the compass's own 左转/右转 (see SkyCompassHud).
const CORNER_LEFT := Vector2(12.0, -32.0)
const CORNER_RIGHT := Vector2(228.0, -32.0)
const CORNER_SIZE := Vector2(60.0, 24.0)
## 现在, at the end of the 四柱/局 line: with the strip only as tall as its two readout
## lines there is no row left for it, so it parks in whichever of them leaves a lane
## free. That used to be the first line - the 农历 date was short and the 排盘 line
## under it ran to x 239. 2026-10-10 第二十轮 the two lines traded places: the first
## one now carries the 三元九运 as well and runs to **x 248** at its worst (a 闰月 +
## 冬月/腊月 + 廿九 date: `九紫离火 道历四七二三年闰冬月廿九` = 196 px), while the
## second is a fixed 180 px (all its fields are two or three characters wide), so it
## is the second line that leaves the lane, and 现在 hangs there - at the row of that
## line, which is also where its own text sits. Placed by hand, so it gets exactly
## this box (see `_chip`).
const NOW_AT := Vector2(244.0, 14.0)
const NOW_SIZE := Vector2(44.0, 22.0)

const C_TEXT := Color(0.88, 0.96, 0.99)
const C_DIM := Color(0.44, 0.63, 0.70)
const C_ACCENT := Color(0.30, 0.85, 1.00)
const C_FILL := Color(0.09, 0.21, 0.26, 0.80)
const C_FILL_HOVER := Color(0.14, 0.31, 0.38, 0.90)
const C_BORDER := Color(0.30, 0.72, 0.82, 0.32)
const C_BORDER_HOVER := Color(0.40, 0.85, 0.95, 0.55)

var clock: TimeCore

var _font: Font
var _pillars: Dictionary = {}
## The 奇门 chart's 三元 (1..3) and 局数, handed over by the sky beside the pillars
## (`SkyBackground._chart`): 0 until a chart has been cast, which is also when the
## second line is not drawn at all.
var _yuan := 0
var _ju := 0
## The 道历 date line the sky hands over (`SkyBackground._lunar_date`), drawn after
## the 三元九运 on the bar's first line.
var _lunar := ""


func setup(sky_clock: TimeCore) -> void:
	clock = sky_clock
	if clock != null:
		clock.changed.connect(_refresh)
	_refresh()


## The four pillars, the term and the year the 三元九运 counts off, handed over by
## the sky on every time step (`SkyBackground._chart`).
func set_pillars(pillars: Dictionary) -> void:
	_pillars = pillars
	_refresh()


## The 农历 date the sky worked out for its own instant, drawn after the 三元九运 on
## the bar's first line.
func set_lunar(text: String) -> void:
	_lunar = text
	_refresh()


## The 三元 and the 局 the 奇门 chart of that instant was cast in, handed over with the
## pillars: the second line's tail is 节气 + 三元 + 阴阳局 (用户 2026-10-10 第二十轮).
func set_ju(yuan: int, ju: int) -> void:
	_yuan = yuan
	_ju = ju
	_refresh()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = Fonts.ui_font()
	_build_controls()
	_refresh()


func _refresh() -> void:
	queue_redraw()


# ------------------------------------------------------------------- controls

func _build_controls() -> void:
	# 时辰− and 时辰+ stand in the card's own lower corners (用户 2026-10-10 第十八轮),
	# the two corners the rim leaves free and the card's own 左转/右转 do not use - they
	# are placed in *this* strip's frame, which begins one card below, so their y is
	# negative. 现在 sits at the end of the readout line that leaves a lane free rather
	# than in a row of its own, which is what let the strip drop to the height of its
	# two readout lines (which line that is, see NOW_AT).
	# Each chip is added to the tree *before* its box is set: a Button is never
	# smaller than its minimum size, and until it is in the tree that minimum is the
	# default theme's - which would clamp these to 31 px tall and never let them back
	# (measured 2026-10-10 第十八轮, see SkyCompassHud._box for the other half of it).
	var steps := [
		{"text": "时辰−", "at": CORNER_LEFT, "action": _step.bind(-1)},
		{"text": "时辰+", "at": CORNER_RIGHT, "action": _step.bind(1)},
	]
	for spec: Dictionary in steps:
		var step := _chip(String(spec["text"]))
		step.pressed.connect(spec["action"])
		add_child(step)
		step.position = spec["at"]
		step.size = CORNER_SIZE

	var now := _chip("现在")
	now.pressed.connect(_now)
	add_child(now)
	now.position = NOW_AT
	now.size = NOW_SIZE


func _chip(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", C_DIM)
	button.add_theme_color_override("font_hover_color", C_TEXT)
	button.add_theme_color_override("font_pressed_color", C_ACCENT)
	var fill := StyleBoxFlat.new()
	fill.bg_color = C_FILL
	fill.set_corner_radius_all(5)
	fill.set_border_width_all(1)
	fill.border_color = C_BORDER
	# the chips are placed by hand in the card's corners and at the end of the clock
	# line, so they get exactly the box the layout asks for (see SkyCompassHud._box)
	fill.set_content_margin_all(0.0)
	var hover := fill.duplicate() as StyleBoxFlat
	hover.bg_color = C_FILL_HOVER
	hover.border_color = C_BORDER_HOVER
	button.add_theme_stylebox_override("normal", fill)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


# ------------------------------------------------------------------- stepping

## One press: the instant is sent a 时辰 - `direction` +1 is forward in time. The
## clock glides there rather than cutting (TimeCore.move_by), so the sky is seen to
## turn; a second press before it lands adds another 时辰 to the same glide.
func _step(direction: int) -> void:
	if clock != null:
		clock.move_by(float(direction) * SHICHEN_SECONDS)


## Back to the real sky, on the spot: "now" is not a step, it is a place.
func _now() -> void:
	if clock != null:
		clock.set_time_unix(Time.get_unix_time_from_system())


## The first line: the 三元九运 the year stands in, then the sky's own 农历 date with
## its year counted 道历 - e.g. "九紫离火 道历四七二三年八月十九" (用户 2026-10-10
## 第二十轮: 三元九运写成一白坎水这种，放在上面，下面跟道历日期). The 运 is named by
## its 玄空 星 rather than counted ("下元九运" is what it used to read), and it comes
## off the same 立春-turned year the 年柱 does. The wall clock is not written here:
## the card's hands are that reading, and they are the observer's own clock rather
## than the sky's (see SkyCompassHud.wall_clock). Either half can be missing - the
## date arrives once per local day and the pillars with the sky's chart - and the
## line that is left is drawn alone.
func read_date() -> String:
	var yun := ""
	if not _pillars.is_empty():
		yun = GanZhi.jiu_yun_name(int(_pillars.get("year_number", 0)))
	return (yun + " " + _lunar).strip_edges()


## The second line: the four pillars in 年/月/日/时 order, then the term in force with
## the 三元 the day sits in and the 局 that makes it - e.g.
## "丙午 戊戌 庚子 己亥 秋分上元 阴九局". Empty until the sky hands the pillars over,
## which is when the bar draws its second line at all.
func read_chart() -> String:
	if _pillars.is_empty():
		return ""
	return "%s %s %s %s %s%s %s" % [
			_pillars.get("year", ""), _pillars.get("month", ""),
			_pillars.get("day", ""), _pillars.get("hour", ""),
			_pillars.get("term", ""), QiMen.yuan_name(_yuan), QiMen.ju_name(_ju)]


# -------------------------------------------------------------------- drawing

## The two lines are centred on the bar, which is as wide as the card: the 三元九运 and
## its 道历 date over the 四柱 and 局 line read as one block under the dial rather
## than as two left-aligned rows. The 现在 chip sits at the end of the first line.
func _draw() -> void:
	if _font == null:
		return
	var date_text := read_date()
	if date_text != "":
		draw_string(_font, Vector2(0.0, CLOCK_BASELINE), date_text,
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, C_TEXT)
	var chart_text := read_chart()
	if chart_text != "":
		draw_string(_font, Vector2(0.0, PILLAR_BASELINE), chart_text,
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, C_DIM)
