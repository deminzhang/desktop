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
const FOV_MAX := 110.0
const ALTITUDE_MIN := 0.0
const ALTITUDE_MAX := 90.0

const CARDINALS := {
	"north": 0.0,
	"east": 90.0,
	"south": 180.0,
	"west": 270.0,
}

## The opening view is the whole sky at once (S7): the frame's top edge is past
## the zenith and its bottom edge past the horizon, so turning in azimuth alone -
## the HUD's 左转/右转 - walks every star above the horizon past the observer and
## no star is ever left over the top of the frame. Ninety degrees of field would
## be the least that does it (a camera at 45 deg sees exactly zenith-to-horizon,
## with star quads rolling off both edges); the field is a little wider so the
## zenith itself sits inside the frame and S4's sliver of ground stays at the
## bottom.
##
## What the sky sends to the wallpaper is a camera looking up, not a sky with a
## low horizon - the horizon itself is where the observer's own is.
const OPENING_ALTITUDE := 45.0
const OPENING_FOV := 100.0
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
## where the wallpaper starts looking - due south, a little above the horizon,
## 60 degrees wide.
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
