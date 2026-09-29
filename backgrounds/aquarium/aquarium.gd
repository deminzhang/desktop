## The "aquarium" background: builds the whole tank procedurally — glass, frame,
## sand, boulders, plants, water surface, lighting and three fish schools — plus
## the clock/monitor HUD that sits in the floating window.
##
## The camera sits *inside* the tank, so the glass, the waterline and the hood
## frame the view — the scene reads as an aquarium rather than open water.
## Tank proportions are chosen so the sand bed, the stone backdrop and the
## underside of the water surface all fit in one 62° vertical frame.
class_name Aquarium
extends Background

const SHADER_DIR := "res://backgrounds/aquarium/shaders/"

const TANK_W := 9.0
const TANK_H := 3.4
const TANK_D := 5.0
const HALF_W := 4.5
const HALF_H := 1.7
const HALF_D := 2.5
const SAND_Y := -1.7
const CEIL_Y := 1.7
const WATER_Y := 1.42

var sun: DirectionalLight3D
var camera: Camera3D
var schools: Array[FishSchool] = []
var obstacles: Array[Vector4] = []

var _water_mat: ShaderMaterial
var _t := 0.0
var _cam_base := Vector3(0.0, -1.10, 1.55)
var _cam_look := Vector3(0.0, -0.26, -1.45)


# -------------------------------------------------------- background interface

func id() -> String:
	return "aquarium"


func display_name() -> String:
	return "水族箱"


func build(_host: Node) -> void:
	_build_environment()
	_build_lights()
	_build_sand()
	_build_backdrop()
	_build_rocks()
	_build_plants()
	_build_water()
	_build_glass()
	_build_frame()
	_build_fish()
	_build_particles()
	_build_camera()


func _process(delta: float) -> void:
	_t += delta
	var t := _t
	# slow, non-repeating drift so the wallpaper never looks like a loop
	var px := sin(t * 0.043) * 0.36 + sin(t * 0.017 + 1.1) * 0.18
	var py := sin(t * 0.031 + 1.7) * 0.10
	var pz := sin(t * 0.026 + 0.6) * 0.26
	camera.position = _cam_base + Vector3(px, py, pz)
	var look := _cam_look + Vector3(
		sin(t * 0.021 + 2.2) * 0.50, sin(t * 0.037) * 0.18, sin(t * 0.019 + 0.4) * 0.22)
	camera.look_at(look, Vector3.UP)
	camera.rotate_object_local(Vector3.MODEL_FRONT, sin(t * 0.017) * 0.030)
	for s in schools:
		s.update(delta)


## Mirrors dune_height() in backgrounds/aquarium/shaders/underwater.gdshaderinc
## so props sit exactly on the sand bed.
static func dune_height(x: float, z: float) -> float:
	return (0.22 * sin(x * 0.31) * cos(z * 0.27)
		+ 0.14 * sin((x + z * 0.7) * 0.53 + 1.7)
		+ 0.07 * cos((x * 0.8 - z) * 1.13 + 0.4))


func build_hud() -> Control:
	var hud := Hud.new()
	hud.name = "Hud"
	# the clock and monitors read from the shell's metric stream
	hud.attach(metrics)
	return hud


func hud_size() -> Vector2i:
	return Vector2i(Hud.PANEL)


func render_policy() -> int:
	return Policy.CONTINUOUS


func vignette_shader() -> Shader:
	return load(SHADER_DIR + "vignette.gdshader")


func _mat(path: String, params: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


# --------------------------------------------------------------- environment

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.006, 0.020, 0.032)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.14, 0.30, 0.40)
	env.ambient_light_energy = 0.40
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.24, 0.30)
	env.fog_light_energy = 0.9
	env.fog_density = 0.030
	env.fog_sky_affect = 0.0
	env.fog_depth_begin = 1.5
	env.fog_depth_end = 26.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.020
	env.volumetric_fog_albedo = Color(0.42, 0.76, 0.86)
	env.volumetric_fog_emission = Color(0.012, 0.045, 0.060)
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_gi_inject = 0.6
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.20
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.ssao_enabled = true
	env.ssao_intensity = 1.0
	env.ssao_radius = 1.1
	env.ssao_power = 1.2
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.8
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.10

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)


func _build_lights() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-34.0, 22.0, 0.0)
	sun.light_color = Color(0.96, 0.99, 1.0)
	sun.light_energy = 0.85
	sun.light_angular_distance = 2.0
	sun.light_volumetric_fog_energy = 3.0
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 22.0
	sun.shadow_bias = 0.03
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)

	for i in 2:
		var sp := SpotLight3D.new()
		sp.name = "Lamp%d" % i
		sp.position = Vector3(-2.3 + float(i) * 4.6, CEIL_Y + 0.30, -0.25)
		sp.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		sp.light_color = Color(0.80, 0.96, 1.0)
		sp.light_energy = 3.4
		sp.spot_range = 7.5
		sp.spot_angle = 42.0
		sp.spot_angle_attenuation = 0.7
		sp.spot_attenuation = 1.1
		sp.light_volumetric_fog_energy = 5.0
		sp.shadow_enabled = false
		add_child(sp)

	var fill := OmniLight3D.new()
	fill.name = "Fill"
	fill.position = Vector3(0.0, -1.1, 1.3)
	fill.light_color = Color(0.35, 0.72, 0.85)
	fill.light_energy = 0.9
	fill.omni_range = 6.0
	fill.light_volumetric_fog_energy = 0.4
	add_child(fill)


# ------------------------------------------------------------------ surfaces

func _build_sand() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(TANK_W, TANK_D)
	pm.subdivide_width = 110
	pm.subdivide_depth = 64
	var mi := MeshInstance3D.new()
	mi.name = "Sand"
	mi.mesh = pm
	mi.position = Vector3(0.0, SAND_Y, 0.0)
	mi.material_override = _mat(SHADER_DIR + "sand.gdshader")
	add_child(mi)


## Stone wall closing off the back of the tank, so the view has a lit backdrop
## for the caustics instead of empty water.
func _build_backdrop() -> void:
	var pm := PlaneMesh.new()
	pm.orientation = PlaneMesh.FACE_Z
	pm.size = Vector2(TANK_W + 0.2, TANK_H - 0.25)
	pm.subdivide_width = 96
	pm.subdivide_depth = 56
	var mi := MeshInstance3D.new()
	mi.name = "Backdrop"
	mi.mesh = pm
	mi.position = Vector3(0.0, -0.125, -HALF_D + 0.32)
	mi.material_override = _mat(SHADER_DIR + "rock.gdshader", {
		"stone_dark": Color(0.070, 0.085, 0.080),
		"stone_light": Color(0.240, 0.255, 0.225),
		"algae": Color(0.105, 0.225, 0.140),
		"caustic_strength": 0.70,
		"caustic_scale": 1.50,
		"relief": 0.50,
		"noise_scale": 0.55,
		"vertical_fade": 0.75,
	})
	add_child(mi)


func _build_water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(TANK_W, TANK_D)
	pm.subdivide_width = 96
	pm.subdivide_depth = 56
	var mi := MeshInstance3D.new()
	mi.name = "WaterSurface"
	mi.mesh = pm
	mi.position = Vector3(0.0, WATER_Y, 0.0)
	_water_mat = _mat(SHADER_DIR + "water_surface.gdshader", {
		"light_dir": Vector3(0.25, 0.94, 0.22),
	})
	mi.material_override = _water_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_glass() -> void:
	var mat := _mat(SHADER_DIR + "glass.gdshader")
	var panes := [
		{"size": Vector2(TANK_W, TANK_H), "pos": Vector3(0.0, 0.0, -HALF_D)},
		{"size": Vector2(TANK_W, TANK_H), "pos": Vector3(0.0, 0.0, HALF_D)},
		{"size": Vector2(TANK_D, TANK_H), "pos": Vector3(-HALF_W, 0.0, 0.0), "rot": 90.0},
		{"size": Vector2(TANK_D, TANK_H), "pos": Vector3(HALF_W, 0.0, 0.0), "rot": 90.0},
	]
	for i in panes.size():
		var p: Dictionary = panes[i]
		var qm := QuadMesh.new()
		qm.size = p["size"]
		var mi := MeshInstance3D.new()
		mi.name = "Glass%d" % i
		mi.mesh = qm
		mi.position = p["pos"]
		if p.has("rot"):
			mi.rotation_degrees = Vector3(0.0, float(p["rot"]), 0.0)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _beam(pos: Vector3, size: Vector3, mat: Material) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	# the frame must not cast shadows: the beams sit right under the sun and their
	# hard bands across the backdrop read as rendering artefacts
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_frame() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.045, 0.052, 0.062)
	metal.metallic = 0.85
	metal.roughness = 0.32

	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_beam(Vector3(HALF_W * sx, 0.0, HALF_D * sz), Vector3(0.13, TANK_H, 0.13), metal)
	for y: float in [CEIL_Y, SAND_Y]:
		_beam(Vector3(0.0, y, -HALF_D), Vector3(TANK_W + 0.13, 0.13, 0.13), metal)
		_beam(Vector3(0.0, y, HALF_D), Vector3(TANK_W + 0.13, 0.13, 0.13), metal)
		_beam(Vector3(-HALF_W, y, 0.0), Vector3(0.13, 0.13, TANK_D + 0.13), metal)
		_beam(Vector3(HALF_W, y, 0.0), Vector3(0.13, 0.13, TANK_D + 0.13), metal)

	# hood: an open frame above the waterline so sunlight still reaches the tank
	var hood := CEIL_Y + 0.42
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_beam(Vector3(HALF_W * sx, hood, HALF_D * sz), Vector3(0.09, 0.42, 0.09), metal)
	for sz: float in [-1.0, 1.0]:
		_beam(Vector3(0.0, hood, HALF_D * sz), Vector3(TANK_W + 0.09, 0.09, 0.09), metal)
	for sx: float in [-1.0, 1.0]:
		_beam(Vector3(HALF_W * sx, hood, 0.0), Vector3(0.09, 0.09, TANK_D + 0.09), metal)

	var led := StandardMaterial3D.new()
	led.albedo_color = Color(0.92, 0.98, 1.0)
	led.emission_enabled = true
	led.emission = Color(0.72, 0.94, 1.0)
	led.emission_energy_multiplier = 2.6
	_beam(Vector3(-2.3, CEIL_Y + 0.26, -0.25), Vector3(2.6, 0.06, 0.15), led)
	_beam(Vector3(2.3, CEIL_Y + 0.26, -0.25), Vector3(2.6, 0.06, 0.15), led)


# -------------------------------------------------------------------- props

func _build_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240924
	var rock_mat := _mat(SHADER_DIR + "rock.gdshader")
	var specs := [
		[-3.10, -1.30, 0.72], [-2.30, -2.00, 0.40], [3.20, -1.70, 0.80],
		[2.45, -0.55, 0.34], [-0.60, -2.10, 0.52], [0.95, -1.95, 0.30],
		[-3.90, 0.80, 0.46], [3.90, 1.20, 0.38], [1.85, 1.70, 0.24],
		[-1.75, 0.30, 0.20],
	]
	for i in specs.size():
		var s: Array = specs[i]
		var seed_v := float(i) * 3.77
		var gen := func(dir: Vector3) -> float:
			return (1.0
				+ 0.30 * sin(dir.x * 3.1 + seed_v) * cos(dir.y * 2.4 + seed_v * 0.7)
				+ 0.22 * sin(dir.z * 2.7 + dir.x * 1.9 + seed_v * 1.3)
				+ 0.14 * sin(dir.y * 5.3 + dir.z * 3.1 + seed_v * 2.1))
		var mi := MeshInstance3D.new()
		mi.name = "Rock%d" % i
		mi.mesh = MeshFactory.rock_mesh(30, 15, gen)
		var r: float = s[2]
		var y := SAND_Y + dune_height(s[0], s[1]) + r * 0.42
		mi.position = Vector3(s[0], y, s[1])
		mi.rotation = Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)
		mi.scale = Vector3(r, r * rng.randf_range(0.72, 1.0), r)
		mi.material_override = rock_mat
		add_child(mi)
		obstacles.append(Vector4(s[0], y, s[1], r * 1.3))


func _build_plants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 771
	var plant_mat := _mat(SHADER_DIR + "plant.gdshader")

	# tall ribbons: back thickets plus two foreground tufts that frame the view
	_add_blades(rng, plant_mat, MeshFactory.blade_mesh(10, 1.0, 0.165, 0.26, 1.05),
		[
			[-3.40, -1.85, 0.95, 34, 1.15, 0.24],
			[3.35, -2.00, 0.90, 30, 1.10, 0.24],
			[-2.00, -2.20, 0.65, 20, 1.00, 0.22],
			[1.30, -2.25, 0.60, 18, 0.95, 0.20],
			[-4.05, 1.40, 0.55, 22, 1.25, 0.26],
			[4.05, 1.70, 0.50, 20, 1.20, 0.26],
		])
	# short carpet
	_add_blades(rng, plant_mat, MeshFactory.blade_mesh(6, 1.0, 0.075, 0.20, 1.6),
		[
			[-2.60, -0.50, 1.80, 90, 0.24, 0.26],
			[2.20, -1.10, 1.70, 80, 0.22, 0.26],
			[-0.40, -1.60, 1.40, 60, 0.26, 0.26],
			[0.60, 1.30, 1.30, 60, 0.20, 0.26],
		])


func _add_blades(rng: RandomNumberGenerator, mat: ShaderMaterial, mesh: ArrayMesh,
		clusters: Array) -> void:
	var total := 0
	for c: Array in clusters:
		total += int(c[3])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = total
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.custom_aabb = AABB(Vector3(-HALF_W - 1.0, SAND_Y - 0.5, -HALF_D - 1.0),
			Vector3(TANK_W + 2.0, TANK_H + 1.0, TANK_D + 2.0))
	add_child(mmi)

	var i := 0
	for c: Array in clusters:
		var cx: float = c[0]
		var cz: float = c[1]
		var cr: float = c[2]
		var count: int = c[3]
		var height: float = c[4]
		var wideness: float = c[5]
		for k in count:
			var ang := rng.randf_range(0.0, TAU)
			var rad := sqrt(rng.randf_range(0.0, 1.0)) * cr
			var x := cx + cos(ang) * rad
			var z := cz + sin(ang) * rad
			x = clampf(x, -HALF_W + 0.15, HALF_W - 0.15)
			z = clampf(z, -HALF_D + 0.15, HALF_D - 0.15)
			var y := SAND_Y + dune_height(x, z) - 0.05
			var h := height * rng.randf_range(0.62, 1.35)
			var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
			basis = basis.scaled(Vector3(
				wideness * rng.randf_range(0.8, 1.3), h, wideness * rng.randf_range(0.8, 1.3)))
			mm.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)))
			mm.set_instance_custom_data(i, Color(
				rng.randf_range(0.0, TAU), rng.randf_range(0.7, 1.35),
				pow(rng.randf_range(0.0, 1.0), 2.0), 0.0))
			i += 1
		obstacles.append(Vector4(cx, SAND_Y + 0.5, cz, cr * 0.8))


func _build_fish() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var fish_mat := _mat(SHADER_DIR + "fish.gdshader")
	var specs := [
		# kind, count, cohesion, alignment, separation, speed, beat, size, y, spread
		[0, 22, 1.45, 1.55, 3.2, 0.55, 2.05, 0.100, -0.15, Vector3(1.3, 0.40, 0.70)],
		[1, 16, 0.80, 0.95, 2.0, 0.38, 1.45, 0.108, 0.70, Vector3(1.8, 0.22, 0.90)],
		[2, 10, 0.32, 0.45, 1.6, 0.26, 1.05, 0.150, -0.55, Vector3(2.2, 0.35, 1.00)],
	]
	for s: Array in specs:
		var school := FishSchool.new()
		school.name = "School%d" % int(s[0])
		school.cohesion = s[2]
		school.alignment = s[3]
		school.separation = s[4]
		school.speed = s[5]
		school.beat_rate = s[6]
		school.size = s[7]
		school.obstacles = obstacles
		school.bounds = AABB(
			Vector3(-HALF_W + 0.55, SAND_Y + 0.40, -HALF_D + 0.45),
			Vector3(TANK_W - 1.10, WATER_Y - SAND_Y - 0.85, 2.55))
		add_child(school)
		school.setup(MeshFactory.fish_mesh(int(s[0])), fish_mat, int(s[1]), rng,
				Vector3(0.0, s[8], -0.55), s[9])
		schools.append(school)


func _build_particles() -> void:
	# bubble streams from two points on the bed
	for bx in [-2.70, 2.50]:
		_emitter({
			"tex": MeshFactory.dot_texture(1.0),
			"color": Color(0.48, 0.74, 0.94),
			"amount": 90,
			"lifetime": 5.0,
			"size": 0.032,
			"pos": Vector3(bx, SAND_Y + 0.20, -0.30),
			"extents": Vector3(0.16, 0.08, 0.16),
			"dir": Vector3(0.0, 1.0, 0.0),
			"spread": 9.0,
			"vmin": 0.22,
			"vmax": 0.40,
			"gravity": Vector3(0.0, 0.10, 0.0),
			"scale_min": 0.4,
			"scale_max": 1.25,
			"turbulence": 0.30,
		})
	# marine snow drifting through the whole tank
	_emitter({
		"tex": MeshFactory.dot_texture(0.0),
		"color": Color(0.50, 0.72, 0.84),
		"amount": 420,
		"lifetime": 22.0,
		"size": 0.020,
		"pos": Vector3(0.0, 0.0, 0.0),
		"extents": Vector3(HALF_W - 0.4, HALF_H - 0.3, HALF_D - 0.4),
		"dir": Vector3(0.0, -1.0, 0.0),
		"spread": 80.0,
		"vmin": 0.008,
		"vmax": 0.030,
		"gravity": Vector3(0.0, -0.004, 0.0),
		"scale_min": 0.5,
		"scale_max": 1.6,
		"turbulence": 0.06,
	})


func _emitter(cfg: Dictionary) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = cfg["extents"]
	pm.direction = cfg["dir"]
	pm.spread = cfg["spread"]
	pm.initial_velocity_min = cfg["vmin"]
	pm.initial_velocity_max = cfg["vmax"]
	pm.gravity = cfg["gravity"]
	pm.scale_min = cfg["scale_min"]
	pm.scale_max = cfg["scale_max"]
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = cfg["turbulence"]
	pm.turbulence_noise_scale = 1.6
	pm.damping_min = 0.0
	pm.damping_max = 0.15

	var quad := QuadMesh.new()
	quad.size = Vector2(cfg["size"], cfg["size"])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.albedo_texture = cfg["tex"]
	mat.albedo_color = cfg["color"]
	mat.vertex_color_use_as_albedo = true
	mat.disable_receive_shadows = true
	quad.material = mat

	var p := GPUParticles3D.new()
	p.amount = cfg["amount"]
	p.lifetime = cfg["lifetime"]
	p.preprocess = 4.0
	p.process_material = pm
	p.draw_pass_1 = quad
	p.position = cfg["pos"]
	p.visibility_aabb = AABB(Vector3(-HALF_W - 2.0, SAND_Y - 2.0, -HALF_D - 2.0),
			Vector3(TANK_W + 4.0, TANK_H + 4.0, TANK_D + 4.0))
	add_child(p)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 66.0
	camera.near = 0.05
	camera.far = 80.0
	camera.position = _cam_base
	camera.basis = Basis.looking_at((_cam_look - _cam_base).normalized(), Vector3.UP)
	camera.current = true
	add_child(camera)
