## Where the observer looks from, inside the star sphere (计划 §6.5 S3).
##
## Azimuth is degrees from north towards east and altitude degrees above the
## horizon, because those are the two readings the compass HUD (S7) carries: the
## view arc outside its card is drawn from the azimuth, and
## face_cardinal("east") has to leave the view at azimuth 90 for that arc to be
## telling the truth. The rig owns the camera's basis and field of view; nothing
## else in the sky touches them.
##
## Input arrives through feed(). S3 wires it to the wallpaper viewport, which only
## receives anything in a windowed dev run (the wallpaper is behind the desktop
## icons by design); S7 forwards the HUD's drag, wheel and cardinal buttons here.
## Any accepted event stops the idle sweep.
##
## The discrete turns - S7's cardinal buttons, its left/right nudges and its
## zenith button - slew rather than cut: the rig keeps the bearing it is heading
## for in an aim beside the view, and advance() eases the view towards it. face()
## is the other, unanimated path, for anything that must land under the observer
## at once (a dragging pointer, the dev switches).
class_name CameraRig
extends Node

signal moved   ## the view changed: the sky re-projects its labels

## Idle sweep, for a wallpaper nobody is looking at: degrees of pan per second,
## and the slower pendulum in altitude around the starting height.
const SWEEP_AZIMUTH := 0.30
const SWEEP_ALTITUDE := 3.5
const SWEEP_PERIOD := 96.0
## Mouse motion in degrees of view per pixel, and the field of view per wheel
## notch.
const DRAG := 0.14
const ZOOM_PER_NOTCH := 1.10
## A turn eases out: every second it closes 1 - exp(-TURN_RATE * delta) of what
## is left of the gap, so it covers most of the distance in the first few frames
## and creeps the last hair. Because the fraction is of what is *left*, a button
## pressed again while the view is still moving retargets from where the view has
## got to instead of restarting the turn.
const TURN_RATE := 9.0
## Both axes inside this many degrees of the aim and the turn is over: snapping
## the last fraction of a degree beats creeping after it forever.
const TURN_SNAP := 0.02
## The field the sky's own geometry is built for: star quads and figure ribbons
## are drawn in world units, so the sky scales them by fov / BASE_FOV to keep a
## point a point and a hairline a hairline at any zoom.
const BASE_FOV := 60.0
const FOV_MIN := 12.0
## The widest field the rig will hold: 179, which is the engine's own ceiling
## (`Camera3D.fov` refuses anything past it), so a caller asking for 180 gets the
## widest there is instead of a rejected set that leaves the camera where it was.
##
## What a field that wide is *for*: the maps that put the angle itself on the frame
## (`pan`, `cylinder`, `sphere`) hold it without trouble, and 用户 asked for it
## (2026-10-12: "fov改180") to get the horizon's whole southern half on the frame at
## once. The camera's own lens is past the useful part of its range long before this -
## it diverges at 180, and at 179 it crams everything within ~45 deg of the axis into
## a few pixels in the middle (measured) - so the opening stays OPENING_FOV, and the
## ceiling is a capability rather than a composition.
const FOV_MAX := 179.0
const ALTITUDE_MIN := 0.0
const ALTITUDE_MAX := 90.0

const CARDINALS := {
	"north": 0.0,
	"east": 90.0,
	"south": 180.0,
	"west": 270.0,
}

## The opening view is a *directed* one: due south, 42.5 deg up, 96 deg of field - a
## window onto the southern sky with the observer's own horizon across its bottom, not
## the whole sky at once (用户 2026-10-14: "我要的是要从整体中截取东西南北天的部分显示,
## 不是一直仰头正能天顶"). Turning in azimuth then walks the whole sky past that window -
## 171 deg of bearing across the frame, so 东/南/西/北 each get their own picture.
##
## The two numbers are tied to each other: altitude + half the field = 90.5, i.e. the
## frame's own top edge stands half a degree *past* the observer's zenith, so the zenith's
## own point lands 7.5 px inside it (用户 2026-10-14: "能不能压一下让他在屏顶露个头").
## That is deliberately not "on the edge": a one-pixel line exactly on row 0 is lost by the
## rasteriser (measured - at the 92 deg framing the cross's own bar fell a row outside the
## frame and only its lower arm was drawn), so the point is given a row of its own, and what
## shows is the hollow cross's bar, its whole lower arm, and the first dash of the upper arm
## with the rest of it cut by the frame (SkyLabels::_draw_zenith). Until this round the
## framing was 35/80, which put the point 270 px above the top edge - the turn's arcs curled
## about a point off the picture, and the sky's own mark for it was never drawn at all.
##
## The horizon is the frame's *other* end, and it answers to the desktop rather than to the
## sky: the wallpaper window is the whole screen, the taskbar is drawn over its bottom
## TASKBAR px, and one 字 of the 地支 ring - which stands SkyBranches.GAP below the horizon
## - has to stay visible above that bar (用户 2026-10-14: "桌面任务栏以上,地平线以下要露一
## 个字的高度"). The two requirements are the same knob apart: the horizon's own row is
## `(0.5 + altitude / fov) * FRAME.y`, which the zenith's half degree turns into
## `90.5 * FRAME.y / fov`, so the field alone decides where the ground ends - 93 deg puts it
## 9 px *under* the bar (which is what 用户 saw: the 地支 mark at the middle of the frame
## hidden), 95 puts it 20 px over, and the pair taken here clears the mark's own box. See
## backgrounds/sky/projection_probe.gd, which asserts both ends of the frame and prints the
## pixels either side of the bar.
##
## What the field costs is measured rather than chosen (`--sky-fov`/`--sky-view` in
## README「投影」): the horizon's own arc deepens 272 -> 414 px and the sky is drawn 15.00 px
## per degree instead of 18.00, while the share of the frame the ground takes is 16 per cent
## against the 13.77 the narrower window left. Every other way of getting the zenith onto
## the frame costs more: a narrower field takes the horizon itself off the bottom (72 deg of
## field puts the ground at 0.2 per cent of the frame).
##
## Under the fisheye the view axis is the map's own pole, so this framing is what makes
## the sky's two motions read on screen: a turn swings the picture about the zenith's
## point - which sits at the top edge here, its cross showing there - and the day wheels it
## about the pole. The horizon is the one line the fisheye bends (it is not through the
## pole): at this field it comes out as the arc 414 px deep that 用户 2026-10-14 asked about
## ("地平线是弯的,能不能拉成直的"); the whole of that argument, with the numbers of every
## way out of it, is in backgrounds/sky/projection_probe.gd and README「投影」.
const OPENING_ALTITUDE := 42.5
## The bottom of the frame the desktop does not show: the taskbar. Read off the usable area
## on this machine - 0,0,2560x1392 of the 0,0,2560x1440 frame (计划 A45) - and only ever
## used to say what the ground under the horizon has to clear (the probe asserts it against
## the wallpaper's own 1440; nothing in the projection reads it).
const TASKBAR := 48.0
## 96 deg: the southern sky from the zenith itself down to 5.5 deg of ground, 171 deg of
## bearing across a 16:9 frame, and 15.00 px per degree wherever you look (the map's own
## `half the frame's height over half the field`). Wide enough that the frame holds the sky
## the eye reads a landscape by, that the zenith rides its own top edge and that the ground
## clears the taskbar by a whole 地支 box at the middle of the frame (34.5 px of ground
## there against the 21 the mark needs); narrow enough that turning 90 deg is a *different*
## sky rather than a shift of the same one, and that the map's own stretch stays within
## 1.57x over the sky it draws (rho/sin(rho) at the horizon's ring; the frame's own corners
## reach 1.72, 97.9 deg off the axis).
const OPENING_FOV := 96.0
var azimuth := 180.0
var altitude := OPENING_ALTITUDE
var fov := OPENING_FOV
var auto_sweep := false

var camera: Camera3D

var _sweep_time := 0.0
var _sweep_azimuth := 0.0
var _sweep_altitude := 0.0
## Where a turn is heading. It leads the view while _turning, and is the same
## thing as the view the rest of the time: face() moves both at once, the sweep
## drags both along, and setup() mirrors the opening view into it. The defaults
## repeat the opening view so a rig that was never set up still aims where it
## points.
var _aim_azimuth := 180.0
var _aim_altitude := OPENING_ALTITUDE
var _turning := false
var _dragging := false


## Takes the camera and applies the opening view: the field defaults above are
## where the wallpaper starts looking - due south, 44 degrees up, 92 wide, the
## zenith on the frame's top edge.
func setup(camera_3d: Camera3D) -> void:
	camera = camera_3d
	# The opening view is the aim too: nothing is in flight and nothing is
	# sweeping until a caller asks for either.
	_aim_azimuth = azimuth
	_aim_altitude = altitude
	_turning = false
	_apply()


# ------------------------------------------------------------------ pointing

## Points the view at a bearing and stops any sweep. The view lands there on the
## spot - this is the path a dragging pointer, the dev switches and the opening
## view take, and a pointer must not lag the hand - so any turn in flight is
## abandoned rather than finished.
func face(azimuth_deg: float, altitude_deg: float) -> void:
	azimuth = fposmod(azimuth_deg, 360.0)
	altitude = clampf(altitude_deg, ALTITUDE_MIN, ALTITUDE_MAX)
	_aim_azimuth = azimuth
	_aim_altitude = altitude
	_turning = false
	stop_sweep()
	_apply()
	moved.emit()


## Asks for a bearing and lets the view travel there: the aim moves now, the view
## follows over the next few frames of advance(). This is the path behind the
## HUD's buttons, where a slew reads better than a cut - it also means the turn
## is silent until it is stepped, so a headless probe drives it by winding
## advance() rather than by waiting.
func turn_to(azimuth_deg: float, altitude_deg: float) -> void:
	_aim_azimuth = fposmod(azimuth_deg, 360.0)
	_aim_altitude = clampf(altitude_deg, ALTITUDE_MIN, ALTITUDE_MAX)
	stop_sweep()
	_turning = true


## Turns to a compass point, keeping the altitude the view is already heading
## for - a cardinal pressed while a climb is still in flight must not quietly
## cancel that climb. Unknown names are a bug in the caller, not something to
## paper over.
func face_cardinal(cardinal: String) -> void:
	if not CARDINALS.has(cardinal):
		push_error("CameraRig: no such cardinal '%s'" % cardinal)
		return
	turn_to(CARDINALS[cardinal], _aim_altitude)


func face_zenith() -> void:
	turn_to(_aim_azimuth, ALTITUDE_MAX)


## Steps the view a fixed angle sideways and/or up. Both deltas are taken from
## the aim rather than from the view: three quick presses of the HUD's left
## button, each landing while the last turn is still in flight, are a 45 degree
## turn and not three fifths of one.
func nudge(delta_azimuth: float, delta_altitude: float) -> void:
	turn_to(_aim_azimuth + delta_azimuth, _aim_altitude + delta_altitude)


## Drags the sky under the pointer: pulling right turns the view west, pulling
## down lifts it towards the zenith.
func drag(motion: Vector2) -> void:
	face(azimuth - motion.x * DRAG, altitude + motion.y * DRAG)


## Sets the field of view in degrees, clamped like the zoom, and leaves the view
## pointing where it was: the dev switch --sky-fov and the HUD's zoom both come
## through here.
func set_fov(degrees: float) -> void:
	fov = clampf(degrees, FOV_MIN, FOV_MAX)
	stop_sweep()
	_apply()
	moved.emit()


## Positive notches are wheel-up, which narrows the field. Zooming does not
## change where the view points, but it is still the observer taking over.
func zoom(notches: float) -> void:
	set_fov(fov * pow(ZOOM_PER_NOTCH, -notches))


# -------------------------------------------------------------------- sweep

func start_sweep() -> void:
	# Idling and turning are both the rig steering itself, and only one of them
	# may own the view: a sweep left to run under a turn would fight it for the
	# azimuth. Going idle gives the turn up.
	_turning = false
	_sweep_time = 0.0
	_sweep_azimuth = azimuth
	_sweep_altitude = altitude
	auto_sweep = true


func stop_sweep() -> void:
	auto_sweep = false


## One step of whatever the rig does on its own - the turn the HUD asked for, or
## the idle sweep when nothing is aimed at. Split out of _process so a test can
## wind the sky without a scene running.
func advance(delta: float) -> void:
	if camera == null:
		return
	if _turning:
		_step_turn(delta)
		return
	if not auto_sweep:
		return
	_sweep_time += delta
	azimuth = fposmod(_sweep_azimuth + SWEEP_AZIMUTH * _sweep_time, 360.0)
	altitude = clampf(_sweep_altitude
			+ SWEEP_ALTITUDE * sin(TAU * _sweep_time / SWEEP_PERIOD),
			ALTITUDE_MIN, ALTITUDE_MAX)
	# The sweep carries the aim with it: a nudge arriving mid-sweep adds to where
	# the view is now, not to wherever the sweep happened to begin.
	_aim_azimuth = azimuth
	_aim_altitude = altitude
	_apply()
	moved.emit()


## One frame of a turn. Both axes close the same fraction of what is left of
## their gap, the azimuth along the shorter way round, until the aim is close
## enough to call reached - at which point the view is put exactly on it and the
## turn is over, so the rig can go back to idling. The wallpaper redraws on
## demand, so a step that moved the view has to say so.
func _step_turn(delta: float) -> void:
	var eased := 1.0 - exp(-TURN_RATE * delta)
	var gap_azimuth := _bearing_gap(azimuth, _aim_azimuth)
	var gap_altitude := _aim_altitude - altitude
	azimuth = fposmod(azimuth + gap_azimuth * eased, 360.0)
	altitude += gap_altitude * eased
	if (absf(_bearing_gap(azimuth, _aim_azimuth)) <= TURN_SNAP
			and absf(_aim_altitude - altitude) <= TURN_SNAP):
		azimuth = _aim_azimuth
		altitude = _aim_altitude
		_turning = false
	_apply()
	moved.emit()


## How far one bearing is from another along the shorter way round, signed, in
## (-180, 180]: a turn from 350 to 10 is 20 degrees clockwise, not 340 the other
## way about.
func _bearing_gap(from_deg: float, to_deg: float) -> float:
	return fposmod(to_deg - from_deg + 180.0, 360.0) - 180.0


func _process(delta: float) -> void:
	advance(delta)


# -------------------------------------------------------------------- input

## Takes a view-changing event; returns whether the rig used it. Any event it
## uses also stops the sweep - the observer has taken over.
func feed(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = button.pressed
				stop_sweep()
				return true
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					zoom(1.0)
				return true
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					zoom(-1.0)
				return true
		return false
	if event is InputEventMouseMotion and _dragging:
		drag((event as InputEventMouseMotion).relative)
		return true
	return false


# ------------------------------------------------------------------- camera

func _apply() -> void:
	if camera == null:
		return
	camera.fov = fov
	camera.basis = Basis.looking_at(Astro.horizon_direction(azimuth, altitude),
			Astro.horizon_up(azimuth, altitude))
