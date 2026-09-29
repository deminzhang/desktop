## The BSC5 star field: every catalogue star as one billboarded quad on a single
## MultiMesh, so ~9000 stars are one draw call.
##
## Magnitude drives both the quad's size and its brightness, B-V drives the
## colour - computed here rather than in the shader so the mapping stays
## testable - and each star carries a random twinkle phase. The shader masks out
## everything below the observer's horizon, so the sphere needs no ground plane.
class_name StarField
extends RefCounted

const SHADER := "res://backgrounds/sky/shaders/star.gdshader"
## Radius the stars sit at, just inside the dome.
const RADIUS := 480.0
## Magnitude range the ramps are stretched over.
const MAG_BRIGHT := -1.5
const MAG_LIMIT := 6.5
## Quad size in world units at RADIUS (~2.6 px per unit at 2560x1440, 60° fov).
const SIZE_MIN := 0.8
const SIZE_MAX := 2.8
const SEED := 20240929


## 0 for the catalogue's faintest star, 1 for the brightest.
static func normalize_mag(mag: float) -> float:
	return clampf((MAG_LIMIT - mag) / (MAG_LIMIT - MAG_BRIGHT), 0.0, 1.0)


## Faint stars stay visible as small dots, bright ones grow super-linearly.
static func star_size(mag: float) -> float:
	return lerpf(SIZE_MIN, SIZE_MAX, pow(normalize_mag(mag), 0.55))


## Screen brightness. Not the physical 2.512^-mag: that leaves mag 5 stars
## invisible on a monitor, so the flux is compressed into a perceptual ramp.
static func star_brightness(mag: float) -> float:
	return 0.06 + 1.15 * pow(normalize_mag(mag), 1.6)


## B-V colour index -> linear RGB, sRGB conversion included because shader
## colours are linear (计划 §2.3 G4). Blue-white at B-V 0, orange at 1.85.
static func star_color(bv: float) -> Color:
	var kelvin := 4600.0 * (1.0 / (0.92 * bv + 1.7) + 1.0 / (0.92 * bv + 0.62))
	return _black_body_srgb(kelvin).srgb_to_linear()


static func _black_body_srgb(kelvin: float) -> Color:
	var t := clampf(kelvin, 1000.0, 40000.0) / 100.0
	var red := 255.0
	var green := 99.4708025861 * log(t) - 161.1195681661
	var blue := 0.0
	if t > 66.0:
		red = 329.698727446 * pow(t - 60.0, -0.1332047592)
		green = 288.1221695283 * pow(t - 60.0, -0.0755148492)
		blue = 255.0
	elif t > 19.0:
		blue = 138.5177312231 * log(t - 10.0) - 305.0447927307
	return Color(clampf(red, 0.0, 255.0) / 255.0, clampf(green, 0.0, 255.0) / 255.0,
			clampf(blue, 0.0, 255.0) / 255.0)


## Builds the field under `parent` (the SkyRoot) and returns the layer, so the
## sky can keep feeding its material the light of day.
##
## Each star becomes one quad already perpendicular to its own direction, so the
## field needs no billboarding in the shader and no per-frame vertex work: the
## camera only ever turns inside the sphere, never leaves its centre.
static func build(parent: Node3D, catalogue: StarCat) -> MeshInstance3D:
	var count := catalogue.count()
	var vertices := PackedVector3Array()
	var colours := PackedColorArray()
	var corners := PackedVector2Array()
	var phases := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(count * 4)
	colours.resize(count * 4)
	corners.resize(count * 4)
	phases.resize(count * 4)
	indices.resize(count * 6)

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in count:
		var dir := StarCat.direction(catalogue.ra[i], catalogue.dec[i])
		var centre := dir * RADIUS
		var half := star_size(catalogue.mag[i]) * 0.5
		# any two axes across the line of sight will do: the disc is round
		var side := dir.cross(Vector3.UP)
		if side.length_squared() < 1.0e-8:
			side = Vector3.RIGHT
		side = side.normalized() * half
		var up := dir.cross(side).normalized() * half

		var v := i * 4
		vertices[v] = centre - side - up
		vertices[v + 1] = centre + side - up
		vertices[v + 2] = centre + side + up
		vertices[v + 3] = centre - side + up
		corners[v] = Vector2(0.0, 0.0)
		corners[v + 1] = Vector2(1.0, 0.0)
		corners[v + 2] = Vector2(1.0, 1.0)
		corners[v + 3] = Vector2(0.0, 1.0)
		var colour := star_color(catalogue.bv[i]) * star_brightness(catalogue.mag[i])
		var phase := Vector2(rng.randf(), rng.randf_range(0.08, 0.30))
		for k in 4:
			colours[v + k] = colour
			phases[v + k] = phase

		var t := i * 6
		indices[t] = v
		indices[t + 1] = v + 1
		indices[t + 2] = v + 2
		indices[t + 3] = v
		indices[t + 4] = v + 2
		indices[t + 5] = v + 3

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = corners
	arrays[Mesh.ARRAY_TEX_UV2] = phases
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var instance := MeshInstance3D.new()
	instance.name = "Stars"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3.ONE * -RADIUS * 1.1, Vector3.ONE * RADIUS * 2.2)
	var material := ShaderMaterial.new()
	material.shader = load(SHADER)
	material.set_shader_parameter("sphere_radius", RADIUS)
	instance.material_override = material
	parent.add_child(instance)
	return instance
