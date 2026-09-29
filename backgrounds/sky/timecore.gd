## The clock the sky runs on: real UTC to begin with, moved on by `rate` seconds
## of sky time per second of real time.
##
## The wallpaper idles between frames (计划 §7), so this is not a frame clock:
## `step_seconds` is how much sky time has to pass before re-orienting the sphere
## is worth a redraw. At rate 1 that is one redraw a second for a sky that turns
## 0.0002 deg in it - the real sky, unnoticed; at 3600 it is every frame.
##
## rate 0 is the frozen sky (the HUD's 静止, S8). The instant itself only ever
## moves through set_time_unix() and move_by(), so the time bar (S7) can step
## hours, days or years without fighting the ticker.
class_name TimeCore
extends Node

signal changed   ## the sky's instant moved: re-orient the sphere

var rate := 1.0           ## seconds of sky time per second of real time
var step_seconds := 1.0   ## sky seconds between redraws

var _unix := 0.0          ## the sky's UTC instant, Unix seconds
var _emitted := 0.0       ## instant `changed` was last emitted for


func _ready() -> void:
	if _unix == 0.0:
		_unix = Time.get_unix_time_from_system()


func unix() -> float:
	return _unix


func julian_day() -> float:
	return Astro.julian_day_from_unix(_unix)


func set_time_unix(value: float) -> void:
	_unix = value
	_emitted = value
	changed.emit()


## Steps the instant, for the HUD's 时/日/月/年 buttons.
func move_by(seconds: float) -> void:
	set_time_unix(_unix + seconds)


func _process(delta: float) -> void:
	if is_zero_approx(rate):
		return
	if _unix == 0.0:
		_unix = Time.get_unix_time_from_system()
		_emitted = _unix
	_unix += delta * rate
	if absf(_unix - _emitted) >= step_seconds:
		_emitted = _unix
		changed.emit()
