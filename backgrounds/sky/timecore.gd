## The clock the sky runs on: real UTC to begin with, moved on by `rate` seconds
## of sky time per second of real time.
##
## The wallpaper idles between frames (README「性能与静默」), so this is not a frame clock:
## `step_seconds` is how much sky time has to pass before re-orienting the sphere
## is worth a redraw. At rate 1 that is one redraw a second for a sky that turns
## 0.0002 deg in it - the real sky, unnoticed; at 3600 it is every frame.
##
## rate 0 is the frozen sky (the HUD's 静止, part of the polish). The instant itself only ever
## moves through set_time_unix() and move_by(), so the time bar (the compass HUD) can step
## hours, days or years without fighting the ticker.
##
## A 时辰 is two hours, which is a quarter of the way round the dial: putting the
## instant there in one frame is a cut, so move_by() *glides* - the step moves an
## aim and the instant eases towards it over about a second, emitting `changed` on
## every frame of it, which is what makes the whole sky (stars, branches, 排盘 and
## all) turn under the button. set_time_unix() is still the instant path: 现在 and
## the dev switches have to land at once.
class_name TimeCore
extends Node

signal changed   ## the sky's instant moved: re-orient the sphere

## Fraction of what is left of a step closed per second, and the sky seconds close
## enough to call it arrived. 7200 s of sky is 30.08 deg of turn, so a second of it
## is 0.004 deg - the snap is a twentieth of the smallest thing on the dial.
const GLIDE_RATE := 7.0
const GLIDE_SNAP := 1.0

var rate := 1.0           ## seconds of sky time per second of real time
var step_seconds := 1.0   ## sky seconds between redraws

var _unix := 0.0          ## the sky's UTC instant, Unix seconds
var _emitted := 0.0       ## instant `changed` was last emitted for
## Where a step is taking the instant. It leads the clock while a step is in
## flight and is the same thing as the clock the rest of the time: the ticker moves
## both, and set_time_unix() drops both on the same value.
var _aim_unix := 0.0
var _gliding := false


func _ready() -> void:
	if _unix == 0.0:
		_unix = Time.get_unix_time_from_system()
	# not unconditional: a step can be asked for before the node's first frame
	# (anything built and stepped in one go), and that aim is the whole point of it
	if not _gliding:
		_aim_unix = _unix


func unix() -> float:
	return _unix


## Where the step in flight is taking the instant; the same as the instant at rest.
## A stepper that lands part of its step and glides the rest measures from here rather
## than from the clock (the time bar's 日/月/年, `SkyTimeBar._step`), so pressing twice in
## quick succession is two whole steps and not two steps less whatever the first one has
## not closed yet - the same reason move_by() takes its step off the aim.
func aim_unix() -> float:
	return _aim_unix


func julian_day() -> float:
	return Astro.julian_day_from_unix(_unix)


## Puts the instant on `value` on the spot, abandoning any step in flight: 现在 and
## the dev switches are the callers that mean it.
func set_time_unix(value: float) -> void:
	_unix = value
	_aim_unix = value
	_emitted = value
	_gliding = false
	changed.emit()


## Steps the instant, for the HUD's step chips - 时辰−/时辰+ and the 日/月/年 forms the
## `>>` switch walks them to (`SkyTimeBar._step`, which lands the whole turns of a long
## step itself and sends only the remainder through here): the aim moves now, the
## instant follows over the next second. The aim takes the step rather than the
## clock, so three quick presses are three 时辰 and not the fraction of one the
## clock has got through; a step started from rest anchors on the clock first.
func move_by(seconds: float) -> void:
	if not _gliding:
		_aim_unix = _unix
	_aim_unix += seconds
	_gliding = true


func _process(delta: float) -> void:
	if _unix == 0.0:
		_unix = Time.get_unix_time_from_system()
		_emitted = _unix
		_aim_unix = _unix
	var ran := false
	if not is_zero_approx(rate):
		var elapsed := delta * rate
		_unix += elapsed
		# the aim runs with the clock, so a step taken while the sky is turning
		# still lands a whole 时辰 from where the sky has got to
		_aim_unix += elapsed
		ran = true
	if _gliding:
		var gap := _aim_unix - _unix
		if absf(gap) <= GLIDE_SNAP:
			_unix = _aim_unix
			_gliding = false
		else:
			_unix += gap * (1.0 - exp(-GLIDE_RATE * delta))
		ran = true
	if not ran:
		return
	# a step draws every frame - it is over inside a second - while the running
	# clock keeps the redraw gate it has always had
	if _gliding or absf(_unix - _emitted) >= step_seconds:
		_emitted = _unix
		changed.emit()
