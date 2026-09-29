## Procedural mesh factory.
##
## The aquarium ships no external assets — every mesh is generated at load time
## so the project stays self-contained and diffable.
class_name MeshFactory
extends RefCounted

## Fish species table. Meshes are built at unit length (nose -Z, tail +Z) and
## scaled per instance, so one mesh serves a whole school.
##   stripe_mix   how strongly the lateral band colour is blended into the body
##   stripe_alpha emissive mask for the band (neon fish glow, others do not)
const SPECIES := [
	{
		"name": "neon",
		"back": Color(0.05, 0.24, 0.48),
		"belly": Color(0.76, 0.89, 0.96),
		"fin": Color(0.36, 0.56, 0.70),
		"stripe": Color(0.22, 0.93, 1.00),
		"stripe_mix": 0.92,
		"stripe_alpha": 0.85,
		"flat": 0.72,
		"tall": 1.16,
		"tail": 0.20,
		"size": 0.115,
	},
	{
		"name": "guppy",
		"back": Color(0.68, 0.20, 0.04),
		"belly": Color(0.98, 0.74, 0.34),
		"fin": Color(0.94, 0.42, 0.12),
		"stripe": Color(0.0, 0.0, 0.0),
		"stripe_mix": 0.0,
		"stripe_alpha": 0.0,
		"flat": 0.78,
		"tall": 1.14,
		"tail": 0.26,
		"size": 0.125,
	},
	{
		"name": "angel",
		"back": Color(0.28, 0.32, 0.38),
		"belly": Color(0.78, 0.81, 0.85),
		"fin": Color(0.60, 0.64, 0.70),
		"stripe": Color(0.03, 0.04, 0.07),
		"stripe_mix": 0.88,
		"stripe_alpha": 0.0,
		"flat": 0.52,
		"tall": 1.62,
		"tail": 0.30,
		"size": 0.175,
	},
]

## Radius profile along t (0 = nose, 1 = tail tip), in units of body length.
## Peak half-height is ~0.13 * tall, i.e. a fish roughly 3.5:1 length to height.
static func body_radius(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return 0.035 + 0.115 * sin(PI * pow(u, 0.62)) * (1.0 - 0.5 * u)


## Whole fish: lathe body, forked tail, dorsal/anal/pectoral fins and eyes.
static func fish_mesh(kind: int) -> ArrayMesh:
	var spec: Dictionary = SPECIES[kind % SPECIES.size()]
	var flat: float = spec["flat"]
	var tall: float = spec["tall"]
	var tail_len: float = spec["tail"]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)

	# ---- body: surface of revolution around the Z axis -------------------
	var rings := 26
	var segs := 22
	for i in rings:
		var t0 := float(i) / float(rings)
		var t1 := float(i + 1) / float(rings)
		for j in segs:
			var a0 := TAU * float(j) / float(segs)
			var a1 := TAU * float(j + 1) / float(segs)
			var p00 := _body_point(t0, a0, flat, tall)
			var p01 := _body_point(t0, a1, flat, tall)
			var p10 := _body_point(t1, a0, flat, tall)
			var p11 := _body_point(t1, a1, flat, tall)
			_add_tri(st, p00, p10, p11, spec, tall)
			_add_tri(st, p00, p11, p01, spec, tall)
	# nose + tail caps
	var nose := Vector3(0.0, 0.0, -0.5)
	var tail_tip := Vector3(0.0, 0.0, 0.5)
	for j in segs:
		var a0 := TAU * float(j) / float(segs)
		var a1 := TAU * float(j + 1) / float(segs)
		_add_tri(st, nose, _body_point(0.0, a1, flat, tall), _body_point(0.0, a0, flat, tall),
				spec, tall)
		_add_tri(st, tail_tip, _body_point(1.0, a0, flat, tall), _body_point(1.0, a1, flat, tall),
				spec, tall)

	# ---- fins (single sided; the shader disables culling) ----------------
	var fin_col: Color = spec["fin"]
	var root := Vector3(0.0, 0.0, 0.44)
	var spread := tail_len / 0.20
	var fork := [
		Vector3(0.0, 0.22 * spread, 0.5 + tail_len),
		Vector3(0.0, 0.075 * spread, 0.5 + tail_len * 0.62),
		Vector3(0.0, 0.0, 0.5 + tail_len * 0.80),
		Vector3(0.0, -0.075 * spread, 0.5 + tail_len * 0.62),
		Vector3(0.0, -0.22 * spread, 0.5 + tail_len),
	]
	for i in fork.size() - 1:
		_fin_tri(st, root, fork[i], fork[i + 1], fin_col)

	# dorsal fin: attached along the back, rising ~40% of the body half-height
	var d0 := Vector3(0.0, _top(0.20, tall), -0.20)
	var d1 := Vector3(0.0, _top(0.74, tall), 0.18)
	var d2 := Vector3(0.0, _top(0.42, tall) * 1.45, -0.02)
	_fin_tri(st, d0, d1, d2, fin_col)
	# anal fin
	var a0v := Vector3(0.0, -_top(0.44, tall), 0.10)
	var a1v := Vector3(0.0, -_top(0.68, tall), 0.28)
	var a2v := Vector3(0.0, -_top(0.56, tall) * 1.40, 0.26)
	_fin_tri(st, a0v, a1v, a2v, fin_col)
	# pectoral fins
	for s: float in [-1.0, 1.0]:
		var px := _side(0.26, flat) * 0.85 * s
		var p0 := Vector3(px, -0.015, -0.18)
		var p1 := Vector3(px + 0.085 * s, -0.085, 0.02)
		var p2 := Vector3(px + 0.020 * s, -0.030, 0.12)
		_fin_tri(st, p0, p1, p2, fin_col)

	# ---- eyes ------------------------------------------------------------
	var eye_x := _side(0.17, flat) * 0.88
	for s: float in [-1.0, 1.0]:
		_sphere(st, Vector3(eye_x * s, 0.030, -0.33), 0.024, 8, 6,
				Color(0.02, 0.03, 0.05), Color(0.70, 0.86, 0.96, 0.35))

	st.generate_normals()
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	return mesh


static func _body_point(t: float, angle: float, flat: float, tall: float) -> Vector3:
	var r := body_radius(t)
	var y := -0.035 * sin(PI * t)
	return Vector3(cos(angle) * r * flat, sin(angle) * r * tall + y, t - 0.5)


static func _top(t: float, tall: float) -> float:
	return body_radius(t) * tall


static func _side(t: float, flat: float) -> float:
	return body_radius(t) * flat


static func _body_color(p: Vector3, spec: Dictionary, tall: float) -> Color:
	var t := p.z + 0.5
	var r := body_radius(t)
	var up := clampf((p.y + 0.035 * sin(PI * t)) / maxf(r * tall, 0.001), -1.0, 1.0)
	var k := clampf((up + 1.0) * 0.5, 0.0, 1.0)
	var col: Color = (spec["belly"] as Color).lerp(spec["back"] as Color, pow(k, 0.85))
	var band := 1.0 - smoothstep(0.0, 0.44, absf(up - 0.12))
	band *= smoothstep(-0.06, 0.14, t) * (1.0 - smoothstep(0.46, 0.88, t))
	var mix: float = spec["stripe_mix"]
	if mix > 0.0 and band > 0.001:
		col = col.lerp(spec["stripe"] as Color, band * mix)
	# vertex colours reach the shader in linear space, so author in sRGB first
	return Color(col.r, col.g, col.b, band * float(spec["stripe_alpha"])).srgb_to_linear()


static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, spec: Dictionary,
		tall: float) -> void:
	for p in [a, b, c]:
		st.set_color(_body_color(p, spec, tall))
		st.add_vertex(p)


static func _fin_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	# normals are generated in one pass at the end of fish_mesh()
	var lin := Color(col.r, col.g, col.b, 0.0).srgb_to_linear()
	for p in [a, b, c]:
		st.set_color(lin)
		st.add_vertex(p)


static func _sphere(st: SurfaceTool, center: Vector3, radius: float, segs: int, rings: int,
		col: Color, col_top: Color) -> void:
	for i in rings:
		var t0 := PI * float(i) / float(rings)
		var t1 := PI * float(i + 1) / float(rings)
		for j in segs:
			var a0 := TAU * float(j) / float(segs)
			var a1 := TAU * float(j + 1) / float(segs)
			var p00 := center + _sph(t0, a0) * radius
			var p01 := center + _sph(t0, a1) * radius
			var p10 := center + _sph(t1, a0) * radius
			var p11 := center + _sph(t1, a1) * radius
			var c0 := col.lerp(col_top, 1.0 - absf(cos(t0))).srgb_to_linear()
			var c1 := col.lerp(col_top, 1.0 - absf(cos(t1))).srgb_to_linear()
			st.set_color(c0)
			st.add_vertex(p00)
			st.set_color(c1)
			st.add_vertex(p10)
			st.set_color(c1)
			st.add_vertex(p11)
			st.set_color(c0)
			st.add_vertex(p00)
			st.set_color(c1)
			st.add_vertex(p11)
			st.set_color(c0)
			st.add_vertex(p01)


static func _sph(theta: float, phi: float) -> Vector3:
	return Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))


## One plant blade: a tapered, bent, twisted ribbon. The vertex colour carries a
## base->tip gradient in rgb and a tip-glow mask in alpha, so one mesh serves a
## whole palette of instances.
static func blade_mesh(segments: int, height: float, width: float, bend: float,
		twist: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var t0 := float(i) / float(segments)
		var t1 := float(i + 1) / float(segments)
		var l0 := _blade_row(t0, height, width, bend, twist)
		var l1 := _blade_row(t1, height, width, bend, twist)
		var c0 := Color(t0, t0, t0, pow(t0, 0.55))
		var c1 := Color(t1, t1, t1, pow(t1, 0.55))
		_quad(st, l0[0], l1[0], l1[1], l0[1], c0, c1, l0[2], l1[2])
		_quad(st, l0[1], l1[1], l1[0], l0[0], c0, c1, -l0[2], -l1[2])
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	return mesh


static func _blade_row(t: float, height: float, width: float, bend: float,
		twist: float) -> Array:
	var w := width * (1.0 - 0.78 * t) * 0.5
	var ang := twist * t
	var off := Vector3(bend * t * t, height * t, 0.0)
	var ax := Vector3(cos(ang), 0.0, sin(ang)) * w
	var n := Vector3(sin(ang), 0.0, -cos(ang))
	return [off - ax, off + ax, n]


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ca: Color, cb: Color, na: Vector3, nb: Vector3) -> void:
	st.set_normal(na)
	st.set_color(ca)
	st.add_vertex(a)
	st.set_normal(nb)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_normal(nb)
	st.set_color(cb)
	st.add_vertex(c)
	st.set_normal(na)
	st.set_color(ca)
	st.add_vertex(a)
	st.set_normal(nb)
	st.set_color(cb)
	st.add_vertex(c)
	st.set_normal(na)
	st.set_color(ca)
	st.add_vertex(d)


## Noise-displaced sphere used for rocks. `fn` maps a unit direction to a radius
## multiplier, which keeps neighbouring rocks distinct.
static func rock_mesh(radial: int, rings: int, fn: Callable) -> ArrayMesh:
	var src := SphereMesh.new()
	src.radial_segments = radial
	src.rings = rings
	src.radius = 1.0
	src.height = 2.0
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var out := PackedVector3Array()
	out.resize(verts.size())
	for i in verts.size():
		var v := verts[i]
		var dir := v.normalized()
		var scale: float = fn.call(dir)
		var p := dir * scale
		# squash into a boulder silhouette
		p.y *= 0.78
		p.y += 0.12 * (1.0 - p.length())
		out[i] = p
	var normals := _face_normals(out, idx)
	var mesh := ArrayMesh.new()
	var new_arrays := []
	new_arrays.resize(Mesh.ARRAY_MAX)
	new_arrays[Mesh.ARRAY_VERTEX] = out
	new_arrays[Mesh.ARRAY_NORMAL] = normals
	new_arrays[Mesh.ARRAY_TEX_UV] = uvs
	if idx.size() > 0:
		new_arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)
	return mesh


## Soft round sprite for particles: a lit disc, optionally with a bright rim so
## the same texture reads as a bubble or as a drifting mote.
static func dot_texture(ring: float) -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2((float(x) + 0.5) / float(n), (float(y) + 0.5) / float(n)) * 2.0 - Vector2.ONE
			var r := p.length()
			var a := smoothstep(1.0, 0.62, r)
			var core := smoothstep(0.55, 0.0, r)
			var rim := 0.0
			if ring > 0.0:
				rim = smoothstep(0.42, 0.16, absf(r - 0.74)) * ring
			var v := clampf(core * 0.75 + rim + a * 0.12, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.6 + 0.4 * v, 0.78 + 0.22 * v, 1.0, v * a))
	return ImageTexture.create_from_image(img)


static func _face_normals(verts: PackedVector3Array, idx: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in verts.size():
		normals[i] = Vector3.ZERO
	var tri_count := (idx.size() / 3) if idx.size() > 0 else (verts.size() / 3)
	for f in tri_count:
		var a := idx[f * 3] if idx.size() > 0 else f * 3
		var b := idx[f * 3 + 1] if idx.size() > 0 else f * 3 + 1
		var c := idx[f * 3 + 2] if idx.size() > 0 else f * 3 + 2
		var n := (verts[b] - verts[a]).cross(verts[c] - verts[a])
		normals[a] += n
		normals[b] += n
		normals[c] += n
	for i in normals.size():
		var n := normals[i]
		normals[i] = n.normalized() if n.length_squared() > 1e-12 else Vector3.UP
	return normals
