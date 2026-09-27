## The Sun: where the sky's daylight comes from (计划 §6.5 S4).
##
## One additive quad hung on SkyRoot, painted by shaders/sun.gdshader with the
## disc at its true apparent size and the glow around it, and placed again -
## never rebuilt - whenever the clock steps. The horizon cut and the reddening as
## it goes down are done in that shader from the fragment's own world position,
## so the ground clips the Sun exactly where the ground is drawn.
class_name SkySun
extends Node3D

const SHADER := "res://backgrounds/sky/shaders/sun.gdshader"
## Distance from the camera: outside the Moon's, which has to be able to pass in
## front of it, and inside the stars'.
const RADIUS := 460.0
## Angular radius of the quad the disc and its glow are painted on.
const HALO_DEGREES := 4.0

const SUN_RADIUS_KM := 696000.0
const AU_KM := 149597870.7

## Unit direction of the Sun in this sphere's own frame. The Moon's phase is lit
## by it, so it is worth reading back.
var direction := Vector3.ZERO

var _disc: MeshInstance3D
var _material: ShaderMaterial


func _init() -> void:
	_disc = MeshInstance3D.new()
	_disc.name = "Disc"
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var half := RADIUS * tan(deg_to_rad(HALO_DEGREES))
	var mesh := PlaneMesh.new()
	# a quad across the line of sight: the default PlaneMesh lies flat
	mesh.orientation = PlaneMesh.FACE_Z
	mesh.size = Vector2(half, half) * 2.0
	_disc.mesh = mesh
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER)
	_disc.material_override = _material
	add_child(_disc)


## Puts the Sun where the ephemeris has it at `jd` (dynamical time), with the
## disc sized from how far away it is that day.
func place(jd: float) -> void:
	var position := Astro.sun_position(jd)
	direction = Astro.local_from_date(jd, position.x, position.y)
	var radius := asin(clampf(SUN_RADIUS_KM / (Astro.sun_radius_au(jd) * AU_KM),
			0.0, 1.0))
	_material.set_shader_parameter("core",
			tan(radius) / tan(deg_to_rad(HALO_DEGREES)))
	transform = Transform3D(Basis.looking_at(direction, _up_for(direction)),
			direction * RADIUS)


## An up vector that is never parallel to the direction, for looking_at().
static func _up_for(direction: Vector3) -> Vector3:
	return Vector3.RIGHT if absf(direction.y) > 0.999 else Vector3.UP
