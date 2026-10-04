## The sky as a scene: a real celestial sphere with the stars on it, and one Camera3D
## looking at it from the middle of the sphere (用户 2026-10-12: "我要在sky/下看到sample.tscn
## 相同格式的tscn,用这个tscn实现,在SphereMesh上布上星星,用Camera3D看").
##
## The scene is the same shape as .tmp/tests/sample.tscn - one MeshInstance3D carrying a
## SphereMesh, one Camera3D, nothing else - and underneath it is the wallpaper's own code:
## StarField pins the catalogue's 9096 stars to *this* mesh, dome.gdshader paints the
## sphere those stars are on (sky above its horizon, ground below), SkySun hangs off it,
## and Astro.sky_basis turns it to the instant. There is no map between the two halves:
## the camera's own lens does the projection, which is SkyProjection.Map.LENS - the
## engine's own transform - so what this draws is what a plain 3D camera in front of a
## sphere draws.
##
##   "$G" --path . res://backgrounds/sky/sky_view.tscn \
##       -- --shot=.tmp/shots/sky_view.png --sky-time=2026-03-20T04:00:00 --sky-view=180,45
##
## The switches are the wallpaper's own (--sky-time, --sky-rate, --sky-view, --sky-fov)
## plus --shot=<png> / --frames=<n> / --live=1. Opening the scene in the *editor* shows
## the sphere and the camera but no stars - they are built at run time - so run it (F6);
## `backgrounds/sky/sky.gd` is the same sky plus the wallpaper's extra layers (the
## branch rings, the names, the sundial HUD).
extends Node3D

## The wallpaper's observer and sphere (observer.gd's default: Beijing;
## SkyBackground.SPHERE_RADIUS, StarField.RADIUS).
const LATITUDE := 39.9042
const LONGITUDE := 116.4074
const SHOT_FRAMES := 8

@onready var _sky: MeshInstance3D = $SkySphere
@onready var _camera: Camera3D = $Camera3D

var _stars: MeshInstance3D
var _sun: SkySun
var _view := Vector2(180.0, 45.0)
var _fov := CameraRig.OPENING_FOV


func _ready() -> void:
	var opts := Args.parse(OS.get_cmdline_user_args())
	_choose_map(opts)
	if opts.has("sky_view"):
		var bearing := opts.text("sky_view", "").split(",", false)
		if bearing.size() == 2:
			_view = Vector2(float(bearing[0]), float(bearing[1]))
	_fov = opts.num("sky_fov", SkyProjection.preferred_fov())
	var unix := Time.get_unix_time_from_system()
	if opts.has("sky_time"):
		unix = SkyBackground.time_from_text(opts.text("sky_time", ""))

	_grade()
	# the stars go *on* the sphere: StarField builds one quad per catalogue star, already
	# facing the sphere's centre, and hangs them under this mesh - so the sphere carries
	# its own sky and turning it turns the stars with it
	_stars = StarField.build(_sky, StarCat.load_default())
	_sun = SkySun.new()
	_sun.name = "Sun"
	_sky.add_child(_sun)

	_place(unix)
	_frame()

	if opts.flag("live", false):
		return
	await Shots.capture(get_viewport(), opts.text("shot", ".tmp/shots/sky_view.png"),
			int(opts.num("frames", SHOT_FRAMES)), "sky_view")
	get_tree().quit()


## Hands the shaders the map this scene draws with - the same switch, read the same way
## and defaulting the same way, as the wallpaper's sky.gd _choose_map(). It has to be set
## *and registered* before any sky material is built, because `sky_map` is a global
## uniform - unregistered it reads 0, which is the pan-and-tilt grid. (This scene shipped
## without it for one round: the sphere drew that grid's bowed horizon while the CPU side
## went on placing names with another map.)
static var _map_registered := false


func _choose_map(opts: Args) -> void:
	var chosen := SkyProjection.Map.LENS
	match opts.text("sky_map", "lens"):
		"lens":
			chosen = SkyProjection.Map.LENS
		"cylinder":
			chosen = SkyProjection.Map.CYLINDER
		"pan":
			chosen = SkyProjection.Map.PAN
		"sphere":
			chosen = SkyProjection.Map.SPHERE
	SkyProjection.map = chosen
	if not _map_registered:
		RenderingServer.global_shader_parameter_add(SkyBackground.MAP_PARAMETER,
				RenderingServer.GLOBAL_VAR_TYPE_INT, int(chosen))
		_map_registered = true
	RenderingServer.global_shader_parameter_set(SkyBackground.MAP_PARAMETER, int(chosen))


## The wallpaper's grade (sky.gd's _build_environment), so the scene and the wallpaper
## are shot the same way.
func _grade() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SkyBackground.NIGHT_ZENITH
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = env
	add_child(world)


## Turns the sphere to the instant and lights it - the wallpaper's _apply_time and
## _light, in the small: the sphere's basis is Astro.sky_basis, the shader's horizon is
## the world's own, and the light comes from the Sun's altitude.
func _place(unix: float) -> void:
	var ut := Astro.julian_day_from_unix(unix)
	_sky.basis = Astro.sky_basis(ut, LATITUDE, LONGITUDE)
	var jd := Astro.tt_from_ut(ut)
	_sun.place(jd)

	var material := _sky.material_override as ShaderMaterial
	material.set_shader_parameter("galactic_pole",
			StarCat.direction(SkyBackground.GALACTIC_POLE.x, SkyBackground.GALACTIC_POLE.y))
	material.set_shader_parameter("galactic_centre",
			StarCat.direction(SkyBackground.GALACTIC_CENTRE.x,
					SkyBackground.GALACTIC_CENTRE.y))
	material.set_shader_parameter("night_zenith", SkyBackground.NIGHT_ZENITH)
	material.set_shader_parameter("day_zenith", SkyBackground.DAY_ZENITH)
	var sun_world := _sky.basis * _sun.direction
	var altitude := Astro.altitude_of(sun_world)
	var day := Astro.daylight(altitude)
	material.set_shader_parameter("day", day)
	material.set_shader_parameter("twilight", Astro.twilight(altitude))
	material.set_shader_parameter("sun_world", sun_world)
	var night := lerpf(SkyBackground.DAY_STAR_FLOOR, 1.0, 1.0 - day)
	material.set_shader_parameter("band_night",
			lerpf(SkyBackground.DAY_BAND_FLOOR, 1.0, 1.0 - day))
	var stars := _stars.material_override as ShaderMaterial
	stars.set_shader_parameter("night", night)
	# a star has to stay a point at any field: the quads are built for the sky's own
	# 60 deg, and CameraRig scales them by the field in use (CameraRig.BASE_FOV)
	stars.set_shader_parameter("size_scale", _fov / CameraRig.BASE_FOV)


## The camera: inside the sphere, at its centre, looking at the view's own bearing with
## the horizon level (Astro.horizon_up, so the horizon comes out level) - a plain
## Camera3D, and nothing else is asked of it.
func _frame() -> void:
	_camera.position = Vector3.ZERO
	_camera.near = 0.1
	_camera.far = 1200.0
	_camera.current = true
	_camera.fov = _fov
	_camera.basis = Basis.looking_at(Astro.horizon_direction(_view.x, _view.y),
			Astro.horizon_up(_view.x, _view.y))
