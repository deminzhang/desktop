## The Moon: a sphere the Sun lights, so its phase is real geometry (计划 §6.5 S4).
##
## The disc is a unit sphere scaled to the apparent radius the ephemeris gives,
## hung on SkyRoot just inside the Sun - a solar eclipse should stack the right
## way round - and shaded by the direction to the Sun, which is what puts the
## terminator where it belongs and the bright limb towards the Sun. Placed again,
## never rebuilt, whenever the clock steps; while it is below the horizon its
## shader cuts it off at the horizon line like every other layer.
class_name SkyMoon
extends Node3D

const SHADER := "res://backgrounds/sky/shaders/moon.gdshader"
## Distance from the camera, inside the Sun's disc and the stars.
const RADIUS := 456.0

## Unit direction of the Moon in this sphere's own frame.
var direction := Vector3.ZERO

var _disc: MeshInstance3D
var _material: ShaderMaterial


func _init() -> void:
	_disc = MeshInstance3D.new()
	_disc.name = "Disc"
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 48
	mesh.rings = 24
	_disc.mesh = mesh
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER)
	_disc.material_override = _material
	add_child(_disc)


## Places the Moon for `jd` (dynamical time) and tells its shader where the Sun
## is, in the same frame - the mesh's own, since the node is never turned.
func place(jd: float, sun_direction: Vector3) -> void:
	var state := Astro.moon_state(jd)
	direction = Astro.local_from_date(jd, state.ra, state.dec)
	_material.set_shader_parameter("sun_dir", sun_direction)
	var radius := RADIUS * tan(deg_to_rad(state.radius_deg))
	transform = Transform3D(Basis().scaled(Vector3.ONE * radius),
			direction * RADIUS)
