## Constellation figures, drawn as thin ribbons on the sphere.
##
## A segment becomes one quad laid in the plane tangent to the sphere at its
## midpoint, so from the centre of the sphere - where the camera always sits - it
## reads as a hairline without any screen-space trickery, and the whole layer is
## static geometry that turns with SkyRoot.
##
## Figures come from Constellations (self-authored, README「数据源与许可」). The IAU boundary
## layer this file used to build beside them, its `--sky-boundaries` switch and the
## Delporte/B1875 corner data behind it are gone (2026-10-15 用户: "constbnd 是干嘛的,没用
## 就删了"): it was off by default and drew a fence the user had already said they did not
## want (README: 用户要的是星座本身,不是边界). The ribbon builder itself stays - the
## ecliptic, the 宿度 ticks and the planets' trails are all built with it.
class_name SkyLines
extends RefCounted

const SHADER := "res://backgrounds/sky/shaders/line.gdshader"

## Just inside the stars, so the ribbon never fights them for depth.
const RADIUS := 476.0
const FIGURE_WIDTH := 0.42   ## world units at RADIUS, ~1.1 px at 2560x1440
## Linear colours, kept low: these are additive, and anything brighter blooms into
## the stars instead of sitting under them.
const FIGURE_COLOUR := Color(0.030, 0.055, 0.095)


## Adds the figure layer under `parent` (the SkyRoot) and returns it.
static func build(parent: Node3D, catalogue: StarCat) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	for abbrev in Constellations.abbreviations():
		for seg in Constellations.figure(catalogue, abbrev):
			_ribbon(vertices, StarCat.direction(catalogue.ra[seg.x], catalogue.dec[seg.x]),
					StarCat.direction(catalogue.ra[seg.y], catalogue.dec[seg.y]),
					FIGURE_WIDTH)
	var figures := _mesh(vertices, FIGURE_COLOUR, "Figures")
	parent.add_child(figures)
	return figures


## Builds a layer of ribbon polylines under `parent` and returns it: every
## consecutive pair in every line becomes one quad. Shared with the ecliptic
## (a great circle plus its solar-term ticks).
static func polyline_layer(parent: Node3D, lines: Array, width: float, colour: Color,
		node_name: String) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	for line in lines:
		for i in line.size() - 1:
			_ribbon(vertices, line[i], line[i + 1], width)
	var layer := _mesh(vertices, colour, node_name)
	parent.add_child(layer)
	return layer


## The constellation figure centroids, as unit directions on the sphere: where
## the Chinese names go.
static func figure_anchors(catalogue: StarCat) -> Dictionary:
	var out := {}
	for abbrev in Constellations.abbreviations():
		var sum := Vector3.ZERO
		var used := {}
		for seg in Constellations.figure(catalogue, abbrev):
			for index in [seg.x, seg.y]:
				if used.has(index):
					continue
				used[index] = true
				sum += StarCat.direction(catalogue.ra[index], catalogue.dec[index])
		if sum.length_squared() < 1.0e-6:
			continue
		out[abbrev] = sum.normalized()
	return out


# ------------------------------------------------------------------ geometry

## One quad per segment: the two endpoints pushed apart sideways in the plane
## tangent to the sphere at the segment's midpoint.
static func _ribbon(vertices: PackedVector3Array, a: Vector3, b: Vector3,
		width: float) -> void:
	var mid := (a + b).normalized()
	var side := mid.cross(b - a).normalized() * (width * 0.5)
	if side.length_squared() < 1.0e-12:
		return
	var half := side
	var pa := a * RADIUS
	var pb := b * RADIUS
	var v := vertices.size()
	vertices.resize(v + 4)
	vertices[v] = pa - half
	vertices[v + 1] = pb - half
	vertices[v + 2] = pb + half
	vertices[v + 3] = pa + half


static func _mesh(vertices: PackedVector3Array, colour: Color,
		node_name: String) -> MeshInstance3D:
	var segments := vertices.size() / 4
	var indices := PackedInt32Array()
	indices.resize(segments * 6)
	var colours := PackedColorArray()
	colours.resize(segments * 4)
	colours.fill(colour)
	for s in segments:
		var v := s * 4
		var t := s * 6
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
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3.ONE * -RADIUS * 1.1, Vector3.ONE * RADIUS * 2.2)
	var material := ShaderMaterial.new()
	material.shader = load(SHADER)
	material.set_shader_parameter("sphere_radius", RADIUS)
	instance.material_override = material
	return instance
