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
##
## The card's two lower corners are this strip's too - they hang up into the card's
## own rectangle, which is why those chips' y is negative. Each corner is a **column of
## three rows** since 2026-10-12 第二十一轮: 星座 / 星宿 (the sky's own line switches) over
## the shell's 桌面 switch on the left, and 时辰− / 时辰+ / 现在 on the right. The sky's
## two switches belong to the sky - the chip says one was thrown (`switch_toggled`) and
## the sky hands the resulting state back with `set_switch()` - and the third left row
## is a seat the *shell* fills with a chip of its own (`shell_switch_slot`), so the card
## carries a switch it knows nothing about.
class_name SkyTimeBar
extends Control

const SHICHEN_SECONDS := 7200.0

## Where the readout lines sit inside the strip: the two readout lines only (they
## are what the dial is read as), and the strip is just their height. The bar starts
## right under the card's own rectangle (SkyBackground.HUD_COMPASS_HEIGHT), so the
## lines hug the card and nothing is left empty above them.
const CLOCK_BASELINE := 12.0
const PILLAR_BASELINE := 29.0
## The card's two lower corners are **two columns of three rows each** (用户 2026-10-12
## 第二十一轮: "星座与星宿按扭用开关样式,两个上下排列" / "菜单里的桌面显隐开关也转出来,放在星座
## 星宿开关下,上中下三个排一起,时辰−,时辰+,现在也是上中下排一起,对齐行间距一致贴上"):
##
##   左列 星座 · 星宿 · 桌面(座)        右列 时辰− · 时辰+ · 现在
##
## All six are 38 x 24 and the three rows of a column **touch** — one pitch, one size,
## so the two columns read as one strip under the card. The coordinates are in this
## strip's frame, which begins one card below (y 300), hence the negative y; the rows
## are the window's y 248…272 / 272…296 / 296…320, i.e. the last one hangs 20 px into
## the strip, over the readout lines' own rows but clear of their text: the first line
## runs to x 248 at its very worst (a 闰月 date) and the second to 240, while the
## columns stand at x 12…50 and 250…288.
##
## 38 rather than 40 is that worst case: the widest line and a column's edge are then 2
## px apart instead of touching.
const ROW_SIZE := Vector2(38.0, 24.0)
const ROW_LEFT := 12.0
const ROW_RIGHT := 250.0    ## the card's own width (300) less the 12 px it leaves
const ROW_TOP := -52.0
const ROW_MIDDLE := -28.0
const ROW_BOTTOM := -4.0
## 现在 is the right column's **third row** (2026-10-12 第二十一轮: 现在也跟 时辰± 上中下排
## 一起), so it has no constants of its own any more: it is a ROW_SIZE chip at
## (ROW_RIGHT, ROW_BOTTOM), and the lane reasoning it used to need - the strip being
## only as tall as its two readout lines, and the first line's 196 px worst case - is
## what puts the columns at 38 px wide and 12 px in from either side (see above).
## It hangs over the readout rows but not over their text: the second line ends at
## x 240 and this column starts at 250.

const C_TEXT := Color(0.88, 0.96, 0.99)
const C_DIM := Color(0.44, 0.63, 0.70)
const C_ACCENT := Color(0.30, 0.85, 1.00)
const C_FILL := Color(0.09, 0.21, 0.26, 0.80)
const C_FILL_HOVER := Color(0.14, 0.31, 0.38, 0.90)
const C_BORDER := Color(0.30, 0.72, 0.82, 0.32)
const C_BORDER_HOVER := Color(0.40, 0.85, 0.95, 0.55)
## The look a layer switch wears while it is on: the accent it also writes its name
## in, over a fill a shade brighter than the hover - a switch has to say which way it
## is thrown from across the desk, and the accent is what the card says "live" with.
const C_FILL_ON := Color(0.16, 0.40, 0.48, 0.92)
const C_ON_BORDER := Color(0.40, 0.85, 0.95, 0.85)

## One of the card's two layer switches has been thrown: `id` is the sky's own
## switch id ("figures" / "mansions", the pair `Background` used to hand the 菜单)
## and `on` the state it was thrown to. The state is the sky's, not the chip's: what
## the chip shows is what the sky tells it with `set_switch`, so a switch the sky
## itself changed again (a rebuild, a command line) cannot leave the chip lying about
## it.
signal switch_toggled(id: String, on: bool)

var clock: TimeCore

var _font: Font
## The empty seat the shell's own switch goes in: the left column's third row, sized and
## placed by this bar, filled by the shell (see `_build_controls` and
## `shell_switch_slot`). Null until `_ready` has built the chips.
var _shell_slot: Control
## The two layer switches, by the sky's own switch id: {"figures": the 星座 chip,
## "mansions": the 星宿 chip}, each a SwitchChip. Built with the rest of the chips in
## `_ready`, shown the state the sky hands over with `set_switch`.
var _switches := {}
## That state as it arrives, id -> bool, kept before the chips exist (`set_switch`).
var _switch_state := {}
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
	# 时辰− / 时辰+ / 现在: the right column, top to bottom.
	var steps := [
		{"text": "时辰−", "at": Vector2(ROW_RIGHT, ROW_TOP), "action": _step.bind(-1)},
		{"text": "时辰+", "at": Vector2(ROW_RIGHT, ROW_MIDDLE), "action": _step.bind(1)},
	]
	for spec: Dictionary in steps:
		var step := _chip(String(spec["text"]), 12)
		step.pressed.connect(spec["action"])
		add_child(step)
		step.position = spec["at"]
		step.size = ROW_SIZE

	# 星座 / 星宿: the two layers of the sky's line work, as switches on the card, in
	# the left column's first two rows. They are the sky's own pair (the ids are what
	# SkyBackground.set_layer_switch takes), so the bar only says one was thrown - the
	# sky turns the layer and hands the state back through set_switch().
	var toggles := [
		{"id": "figures", "text": "星座", "at": Vector2(ROW_LEFT, ROW_TOP)},
		{"id": "mansions", "text": "星宿", "at": Vector2(ROW_LEFT, ROW_MIDDLE)},
	]
	for spec: Dictionary in toggles:
		var chip := SwitchChip.new()
		chip.setup(_font, String(spec["text"]))
		var id := String(spec["id"])
		# the id is *bound*, not closed over: a lambda over the loop's own variable
		# handed every chip the first one's id (measured 2026-10-12: both switches
		# reported 'figures'), and the two are told apart by nothing else
		chip.toggled.connect(_thrown.bind(id))
		add_child(chip)
		chip.position = spec["at"]
		chip.size = ROW_SIZE
		# the sky's own state, which it may have handed over before this bar was in
		# the tree (see set_switch); a layer nobody said anything about is on, which
		# is the sky's own default
		chip.show_state(bool(_switch_state.get(id, true)))
		_switches[id] = chip

	# the left column's third row is the **shell's seat** (2026-10-12 第二十一轮): the
	# shell puts its own 桌面 switch here (Background.hud_shell_slot), so that switch
	# stands with the card's own two instead of in the menu - and the card does not
	# know what it is.
	# The seat itself is inert (MOUSE_FILTER_IGNORE): a child of an IGNORE control still
	# takes its own presses (measured with .tmp/tests/_seat_probe.gd: IGNORE, PASS and STOP
	# all let the chip's press through), so nothing is paid for leaving an unfilled seat
	# out of the hit test - it cannot swallow a drag on the HUD.
	_shell_slot = Control.new()
	_shell_slot.name = "ShellSwitch"
	_shell_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shell_slot)
	_shell_slot.position = Vector2(ROW_LEFT, ROW_BOTTOM)
	_shell_slot.size = ROW_SIZE

	var now := _chip("现在", 12)
	now.pressed.connect(_now)
	add_child(now)
	now.position = Vector2(ROW_RIGHT, ROW_BOTTOM)
	now.size = ROW_SIZE


## The seat the shell's own switch goes in - the left column's third row, under 星座 and
## 星宿 (用户 2026-10-12 第二十一轮: 菜单里的 桌面 显隐开关也搬到这里,上中下三个排一起). The
## seat is this card's because the column is: its size, its position and the look around
## it are the sky's, while the chip in it belongs to the shell (`Background.hud_shell_slot`
## hands this Control up). Null until `_ready` has run, which is after `build_hud()`
## returns but before the shell asks for it.
func shell_switch_slot() -> Control:
	return _shell_slot


## One layer switch, thrown by the user: `state` is the chip's own new state and `id`
## the sky's switch it stands for, bound to the chip as it is built. The pair is
## handed on as the bar's own signal - the sky is the one that owns what a layer is.
func _thrown(state: bool, id: String) -> void:
	switch_toggled.emit(id, state)


## What the sky's own switches are set to, drawn on the chips: `id` is
## `switch_toggled`'s own, and an id this bar does not carry is ignored (the sky
## decides what it offers, the bar what it draws). Set without emitting - the sky is
## telling the chip what it already did, not asking it for anything.
##
## The state is kept whether or not the chip is up yet: the sky hands it over from
## `build_hud()`, and the HUD is not in the tree at that point - its chips are built
## in `_ready`, which runs when the shell puts the content in its window, so a state
## that were only applied to a live chip would be dropped on the floor and every
## switch would come up off.
func set_switch(id: String, on: bool) -> void:
	_switch_state[id] = on
	var chip: SwitchChip = _switches.get(id)
	if chip != null:
		chip.show_state(on)


func _chip(text: String, font_size := 13) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", font_size)
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
