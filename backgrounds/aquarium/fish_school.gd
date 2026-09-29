## Boid-driven fish school rendered through a single MultiMesh.
##
## Each school owns its own steering weights so the three species read as
## different animals: tight/fast, loose/slow, and territorial/near cover.
class_name FishSchool
extends Node3D

## Steering weights, tuned per species.
var cohesion := 0.9
var alignment := 1.1
var separation := 2.4
var wander := 0.8
var bounds_push := 3.2
var avoid_push := 6.0
var speed := 0.55
var turn := 2.2
var beat_rate := 1.6
var size := 0.115

var bounds := AABB(Vector3(-4.0, -1.9, -2.5), Vector3(8.0, 3.6, 5.0))
var obstacles: Array[Vector4] = []  # xyz = centre, w = radius

var multimesh: MultiMesh
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _phase := PackedFloat32Array()
var _beat := PackedFloat32Array()
var _scale := PackedFloat32Array()
var _wander := PackedVector3Array()

const UP := Vector3.UP


func setup(mesh: Mesh, material: Material, count: int, rng: RandomNumberGenerator,
		start: Vector3, spread: Vector3) -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Fish"
	mmi.multimesh = multimesh
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-6.0, -3.0, -4.0), Vector3(12.0, 6.0, 8.0))
	add_child(mmi)

	_pos.resize(count)
	_vel.resize(count)
	_phase.resize(count)
	_beat.resize(count)
	_scale.resize(count)
	_wander.resize(count)
	for i in count:
		_pos[i] = start + Vector3(
			rng.randf_range(-spread.x, spread.x),
			rng.randf_range(-spread.y, spread.y),
			rng.randf_range(-spread.z, spread.z))
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.25, 0.25),
				rng.randf_range(-1.0, 1.0)).normalized()
		_vel[i] = dir * speed * rng.randf_range(0.75, 1.2)
		_phase[i] = rng.randf_range(0.0, TAU)
		_beat[i] = rng.randf_range(0.85, 1.15)
		_scale[i] = size * rng.randf_range(0.82, 1.18)
		_wander[i] = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0),
				rng.randf_range(-1.0, 1.0))
		_apply(i, Transform3D(Basis().scaled(Vector3.ONE * _scale[i]), _pos[i]))


func update(delta: float) -> void:
	var n := _pos.size()
	if n == 0:
		return
	var cohesion_radius := 3.2
	var sep_radius := 0.55
	for i in n:
		var p := _pos[i]
		var v := _vel[i]
		var centre := Vector3.ZERO
		var avg_vel := Vector3.ZERO
		var push := Vector3.ZERO
		var neighbours := 0
		for j in n:
			if i == j:
				continue
			var d := _pos[j] - p
			var dist := d.length()
			if dist > cohesion_radius or dist < 0.0001:
				continue
			neighbours += 1
			centre += _pos[j]
			avg_vel += _vel[j]
			if dist < sep_radius:
				push -= d / (dist * dist)
		var steer := Vector3.ZERO
		if neighbours > 0:
			centre /= float(neighbours)
			avg_vel /= float(neighbours)
			steer += (centre - p).normalized() * cohesion
			steer += (avg_vel - v) * alignment
		steer += push * separation

		# keep inside the tank
		var bmin := bounds.position
		var bmax := bounds.position + bounds.size
		if p.x < bmin.x:
			steer.x += (bmin.x - p.x) * bounds_push
		elif p.x > bmax.x:
			steer.x -= (p.x - bmax.x) * bounds_push
		if p.y < bmin.y:
			steer.y += (bmin.y - p.y) * bounds_push
		elif p.y > bmax.y:
			steer.y -= (p.y - bmax.y) * bounds_push
		if p.z < bmin.z:
			steer.z += (bmin.z - p.z) * bounds_push
		elif p.z > bmax.z:
			steer.z -= (p.z - bmax.z) * bounds_push

		# dodge boulders and plant clumps
		for o in obstacles:
			var c := Vector3(o.x, o.y, o.z)
			var d := p - c
			var dist := d.length()
			var r: float = o.w
			if dist < r and dist > 0.0001:
				steer += (d / dist) * (r - dist) * avoid_push

		# lazy wander so schools never freeze
		_wander[i] = (_wander[i] + Vector3(
				randf_range(-1.0, 1.0), randf_range(-0.6, 0.6), randf_range(-1.0, 1.0)) * delta * 1.4)
		_wander[i] = _wander[i].limit_length(1.0)
		steer += _wander[i] * wander

		# steering is an acceleration; speed is clamped so fish glide
		v += steer * delta * turn
		var target := speed * _scale[i] / size
		var s := v.length()
		if s > 0.0001:
			var clamped := clampf(s, target * 0.55, target * 1.5)
			v *= clamped / s
		else:
			v = Vector3.FORWARD * target
		_vel[i] = v
		p += v * delta

		# bounce off the glass rather than clipping through it
		p.x = clampf(p.x, bmin.x - 0.25, bmax.x + 0.25)
		p.y = clampf(p.y, bmin.y - 0.2, bmax.y + 0.2)
		p.z = clampf(p.z, bmin.z - 0.25, bmax.z + 0.25)
		_pos[i] = p

		var dir := v.normalized()
		if absf(dir.dot(UP)) > 0.98:
			dir = (dir + Vector3.FORWARD * 0.2).normalized()
		var basis := Basis.looking_at(dir, UP)
		# bank into the turn
		var roll := clampf(-steer.dot(basis.x) * 0.25, -0.5, 0.5)
		basis = basis.rotated(basis.z, roll)
		_apply(i, Transform3D(basis.scaled(Vector3.ONE * _scale[i]), p))


func _apply(i: int, xf: Transform3D) -> void:
	multimesh.set_instance_transform(i, xf)
	multimesh.set_instance_custom_data(i, Color(_phase[i], _beat[i] * beat_rate, 0.5, 0.0))
