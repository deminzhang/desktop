## The "sky" background: a real star sphere with the celestial machinery on top,
## built in stages (计划 §6.5).
##
## This file is the stage door: it stands up the celestial sphere - the night-sky
## dome (real geometry: an environment-only scene never presents into the
## wallpaper window, 计划 §2.2 V3) and the `SkyRoot` node every other layer hangs
## its objects from - and it owns the three pieces that say *when* and *from
## where* the sky is seen: the Observer, the TimeCore clock and the CameraRig.
## Turning the sky to a date and a place is one assignment to SkyRoot's basis
## (Astro.sky_basis), which is why the sphere can idle between frames.
##
## S1 brought the BSC5 star field, S2 the constellations, S3 this clockwork; S4
## the Sun, the Moon and the daylight they bring, S5-S6 the planets and the
## ecliptic, S7 the compass HUD.
##
## Named SkyBackground because `Sky` is the engine's sky resource.
class_name SkyBackground
extends Background

## Radius of the celestial sphere the stars are pinned to.
const SPHERE_RADIUS := 500.0

## J2000 directions of the galactic frame, for the Milky Way band on the dome.
const GALACTIC_POLE := Vector2(192.85948, 27.12825)    ## RA°, Dec°
const GALACTIC_CENTRE := Vector2(266.40499, -28.93617)

var sky_root: Node3D
var camera: Camera3D
var star_count := 0

## Where and when the sky is seen from; the clock drives SkyRoot's basis.
var observer: Observer
var clock: TimeCore
var rig: CameraRig

## The two things in the sky that are not fixed to the sphere: they are placed
## again on every time step, and the Sun's direction is what lights the Moon.
var sun: SkySun
var moon: SkyMoon

var _catalogue: StarCat
var _labels: SkyLabels
var _dome: MeshInstance3D
var _stars: MeshInstance3D
var _figures: MeshInstance3D
var _boundaries: MeshInstance3D


# -------------------------------------------------------- background interface

func id() -> String:
	return "sky"


func display_name() -> String:
	return "星空"


func build(_host: Node) -> void:
	_build_environment()
	sky_root = Node3D.new()
	sky_root.name = "SkyRoot"
	add_child(sky_root)
	_build_dome()
	_build_camera()
	_build_catalogue()
	_build_bodies()
	_build_labels()
	_build_clock()


func build_hud() -> Control:
	# The compass and the time bar arrive with the HUD stage (S7); until then
	# the floating window holds nothing but the shell's toolbar.
	return Control.new()


func hud_size() -> Vector2i:
	return Vector2i(420, 0)


func render_policy() -> int:
	# Nothing on the sphere moves between time updates: the wallpaper draws when
	# the clock ticks (_apply_time) or the camera rig moves, and idles in
	# between (计划 §7). With the clock at rate 1 that is one frame per second,
	# for a sky that turns 0.0002 deg in it.
	return Policy.ON_DEMAND


func vignette_shader() -> Shader:
	return null


# --------------------------------------------------------------------- scene

func _build_environment() -> void:
	# The night sky itself is the dome mesh below; this is the colour behind it,
	# tonemapped the way the stars are so the whole frame sits in one grade.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.06)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	# the bright stars need to bloom a little; additive star quads push them
	# over the threshold while the sky gradient stays under it
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = env
	add_child(world)


## The celestial sphere's inner surface: a gradient dome sized so it always
## fills the frame, with the horizon at its equator.
func _build_dome() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = SPHERE_RADIUS
	mesh.height = SPHERE_RADIUS * 2.0
	mesh.radial_segments = 64
	mesh.rings = 32

	var dome := MeshInstance3D.new()
	dome.name = "Dome"
	dome.mesh = mesh
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = load("res://backgrounds/sky/shaders/dome.gdshader")
	material.set_shader_parameter("galactic_pole",
			StarCat.direction(GALACTIC_POLE.x, GALACTIC_POLE.y))
	material.set_shader_parameter("galactic_centre",
			StarCat.direction(GALACTIC_CENTRE.x, GALACTIC_CENTRE.y))
	dome.material_override = material
	sky_root.add_child(dome)
	_dome = dome


## The two bodies the sphere does not carry: they are placed again on each time
## step, drawn through the same horizon as everything else, and the Sun's
## direction is what the Moon's phase is lit by.
func _build_bodies() -> void:
	sun = SkySun.new()
	sun.name = "Sun"
	sky_root.add_child(sun)
	moon = SkyMoon.new()
	moon.name = "Moon"
	sky_root.add_child(moon)


## Everything that comes out of the star catalogue: the stars themselves, the
## constellation figures and the IAU boundaries.
func _build_catalogue() -> void:
	_catalogue = StarCat.load_default()
	if _catalogue == null:
		return
	star_count = _catalogue.count()
	_stars = StarField.build(sky_root, _catalogue)
	var lines := SkyLines.build(sky_root, _catalogue)
	_figures = lines[0]
	_boundaries = lines[1]
	print("XuanDesk: sky: %d stars, %d figure segments, %d boundary segments"
			% [star_count, _ribs(_figures), _ribs(_boundaries)])


## How many ribbon quads a layer's mesh holds, one per segment.
static func _ribs(layer: MeshInstance3D) -> int:
	return layer.mesh.surface_get_array_len(0) / 4


## The Chinese constellation names, on their own canvas layer, under the shell's
## colour grade and well under its fade.
func _build_labels() -> void:
	if _catalogue == null:
		return
	var layer := CanvasLayer.new()
	layer.name = "Labels"
	layer.layer = 5
	var labels := SkyLabels.new()
	labels.name = "SkyLabels"
	layer.add_child(labels)
	add_child(layer)
	_labels = labels
	labels.setup(_catalogue, camera, sky_root)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.1
	camera.far = SPHERE_RADIUS * 2.0
	camera.position = Vector3.ZERO
	camera.current = true
	add_child(camera)

	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	# opens facing south a little above the horizon, the wallpaper's own view
	rig.setup(camera)


# --------------------------------------------------------------- where and when

## The observer, the clock and the camera rig: S3's whole point. The catalogue is
## fixed to J2000, so a change of instant is one basis on SkyRoot.
func _build_clock() -> void:
	observer = Observer.new()
	clock = TimeCore.new()
	clock.name = "TimeCore"
	add_child(clock)
	if opts != null:
		if opts.has("sky_time"):
			clock.set_time_unix(time_from_text(opts.text("sky_time", "")))
		clock.rate = opts.num("sky_rate", clock.rate)
		if opts.has("sky_fov"):
			rig.set_fov(opts.num("sky_fov", rig.fov))
		if opts.has("sky_view"):
			var bearing := opts.text("sky_view", "").split(",", false)
			if bearing.size() == 2:
				rig.face(float(bearing[0]), float(bearing[1]))

	clock.changed.connect(_apply_time)
	rig.moved.connect(_on_view_changed)
	_apply_time()


## --sky-time takes a Unix instant or an ISO 8601 UTC string, so a shot can name
## the moment it wants.
static func time_from_text(text: String) -> float:
	if text.contains(":"):
		return float(Time.get_unix_time_from_datetime_string(text))
	return float(text)


## Turns the sphere to the clock's instant - local sidereal time on the meridian,
## the celestial pole at the observer's latitude, the equinox of date on the
## catalogue's J2000 coordinates - puts the Sun and the Moon where the ephemeris
## has them, and tells the shaders how light the sky is.
##
## The two time scales split here: the sphere's rotation and its sidereal time are
## UT, which is what the clock keeps, while the Sun and the Moon are computed for
## TT, which is what their periodic terms describe.
func _apply_time() -> void:
	var ut := clock.julian_day()
	sky_root.basis = Astro.sky_basis(ut, observer.latitude, observer.longitude)
	var jd := Astro.tt_from_ut(ut)
	sun.place(jd)
	moon.place(jd, sun.direction)
	_light()
	_on_view_changed()


## The day's light, handed to the shaders that paint it: how much of the day the
## sky has, how strong the glow low over the horizon is, and which way the Sun
## lies - all three read from the Sun's altitude at the observer, which is the
## one thing about this sky that is not geometry.
func _light() -> void:
	var sun_world := sky_root.basis * sun.direction
	var altitude := Astro.altitude_of(sun_world)
	var day := Astro.daylight(altitude)
	var dome_material := _dome.material_override as ShaderMaterial
	dome_material.set_shader_parameter("day", day)
	dome_material.set_shader_parameter("twilight", Astro.twilight(altitude))
	dome_material.set_shader_parameter("sun_world", sun_world)
	var night := 1.0 - day
	for layer in [_stars, _figures, _boundaries]:
		if layer != null:
			layer.material_override.set_shader_parameter("night", night)


## The sky is redrawn only when it actually changes - a new instant, or a camera
## that moved (计划 §7) - and the names are re-projected with it.
func _on_view_changed() -> void:
	if _labels != null:
		_labels.refresh()
	_scale_marks()
	request_redraw()


## The stars and the figures are drawn in world units on the sphere, so a zoom
## would blow them up into blobs unless their materials are told the field in
## use: this is the other half of CameraRig.BASE_FOV.
func _scale_marks() -> void:
	var scale := rig.fov / CameraRig.BASE_FOV
	for layer in [_stars, _figures, _boundaries]:
		if layer != null:
			layer.material_override.set_shader_parameter("size_scale", scale)


func _unhandled_input(event: InputEvent) -> void:
	if rig != null and rig.feed(event):
		get_viewport().set_input_as_handled()
