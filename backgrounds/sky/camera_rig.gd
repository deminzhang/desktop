## Where the observer looks from, inside the star sphere (计划 §6.5 S3).
##
## Azimuth is degrees from north towards east and altitude degrees above the
## horizon, because those are the two readings the compass HUD (S7) puts on its
## dial - face_cardinal("east") has to leave the view at azimuth 90 for the dial
## to be telling the truth. The rig owns the camera's basis and field of view;
## nothing else in the sky touches them.
##
## Input arrives through feed(). S3 wires it to the wallpaper viewport, which only
## receives anything in a windowed dev run (the wallpaper is behind the desktop
## icons by design); S7 forwards the HUD's drag, wheel and cardinal buttons here.
## Any accepted event stops the idle sweep.
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

var azimuth := 180.0
var altitude := 6.0
var fov := BASE_FOV
var auto_sweep := false

var camera: Camera3D

var _sweep_time := 0.0
var _sweep_azimuth := 0.0
var _sweep_altitude := 0.0
var _dragging := false


## Takes the camera and applies the opening view: the field defaults above are
## where the wallpaper starts looking - due south, a little above the horizon,
## 60 degrees wide.
func setup(camera_3d: Camera3D) -> void:
	camera = camera_3d
	_apply()


# ------------------------------------------------------------------ pointing

## Points the view at a bearing and stops any sweep.
func face(azimuth_deg: float, altitude_deg: float) -> void:
	azimuth = fposmod(azimuth_deg, 360.0)
	altitude = clampf(altitude_deg, ALTITUDE_MIN, ALTITUDE_MAX)
	stop_sweep()
	_apply()
	moved.emit()


## Turns to a compass point, keeping the present altitude. Unknown names are a
## bug in the caller, not something to paper over.
func face_cardinal(cardinal: String) -> void:
	if not CARDINALS.has(cardinal):
		push_error("CameraRig: no such cardinal '%s'" % cardinal)
		return
	face(CARDINALS[cardinal], altitude)


func face_zenith() -> void:
	face(azimuth, ALTITUDE_MAX)


func nudge(delta_azimuth: float, delta_altitude: float) -> void:
	face(azimuth + delta_azimuth, altitude + delta_altitude)


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
	_sweep_time = 0.0
	_sweep_azimuth = azimuth
	_sweep_altitude = altitude
	auto_sweep = true


func stop_sweep() -> void:
	auto_sweep = false


## One step of the idle sweep. Split out of _process so a test can wind the sky
## without a scene running.
func advance(delta: float) -> void:
	if not auto_sweep or camera == null:
		return
	_sweep_time += delta
	azimuth = fposmod(_sweep_azimuth + SWEEP_AZIMUTH * _sweep_time, 360.0)
	altitude = clampf(_sweep_altitude
			+ SWEEP_ALTITUDE * sin(TAU * _sweep_time / SWEEP_PERIOD),
			ALTITUDE_MIN, ALTITUDE_MAX)
	_apply()
	moved.emit()


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
