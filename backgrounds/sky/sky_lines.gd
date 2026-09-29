## Constellation figures and IAU boundaries, drawn as thin ribbons on the sphere.
##
## A segment becomes one quad laid in the plane tangent to the sphere at its
## midpoint, so from the centre of the sphere - where the camera always sits - it
## reads as a hairline without any screen-space trickery, and the whole layer is
## static geometry that turns with SkyRoot.
##
## Figures come from Constellations (self-authored, 计划 §6.3); boundaries come
## from the IAU/Delporte data in data/bound_20.dat (see data/SOURCES.md).
class_name SkyLines
extends RefCounted

const SHADER := "res://backgrounds/sky/shaders/line.gdshader"
const BOUNDARY_CORNERS := "res://backgrounds/sky/data/constbnd.dat"

## Just inside the stars, so the ribbon never fights them for depth.
const RADIUS := 476.0
const FIGURE_WIDTH := 0.42   ## world units at RADIUS, ~1.1 px at 2560x1440
const BOUNDARY_WIDTH := 0.26
## Linear colours, kept low: these are additive, and anything brighter blooms into
## the stars instead of sitting under them.
const FIGURE_COLOUR := Color(0.030, 0.055, 0.095)
const BOUNDARY_COLOUR := Color(0.010, 0.016, 0.028)


## Adds the figure and boundary layers under `parent` (the SkyRoot) and returns
## them, figures first, so the sky can keep feeding their materials the light of
## day.
static func build(parent: Node3D, catalogue: StarCat) -> Array:
	var vertices := PackedVector3Array()
	for abbrev in Constellations.abbreviations():
		for seg in Constellations.figure(catalogue, abbrev):
			_ribbon(vertices, StarCat.direction(catalogue.ra[seg.x], catalogue.dec[seg.x]),
					StarCat.direction(catalogue.ra[seg.y], catalogue.dec[seg.y]),
					FIGURE_WIDTH)
	var figures := _mesh(vertices, FIGURE_COLOUR, "Figures")
	parent.add_child(figures)

	var bounds := _ribbon_polylines(_boundary_loops())
	var boundaries := _mesh(bounds, BOUNDARY_COLOUR, "Boundaries")
	parent.add_child(boundaries)
	return [figures, boundaries]


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


static func _ribbon_polylines(polylines: Array) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	for line in polylines:
		for i in line.size() - 1:
			_ribbon(vertices, line[i], line[i + 1], BOUNDARY_WIDTH)
	return vertices


# ------------------------------------------------------------------ data

## The IAU boundaries, one closed polyline per constellation.
##
## constbnd.dat lists each constellation's boundary corners in order - its first
## entry is that constellation's origin, the rest carry the neighbouring
## constellation - referred to B1875, so they are precessed to J2000 here. The
## J2000 file (bound_20.dat) holds the same corners sorted by right ascension,
## which is neither the order they connect in nor, once precession has moved them
## off the 1930 constant-RA/Dec grid, recoverable from geometry; it is kept only
## to check the precession against.
static func _boundary_loops() -> Array:
	var text := FileAccess.get_file_as_string(BOUNDARY_CORNERS)
	if text.is_empty():
		push_warning("SkyLines: boundary corners missing at %s" % BOUNDARY_CORNERS)
		return []
	var per := {}
	var order := []
	for line in text.split("\n"):
		var parts := line.split(" ", false)
		if parts.size() < 3:
			continue
		if not per.has(parts[2]):
			per[parts[2]] = []
			order.append(parts[2])
		# this file gives right ascension in hours
		per[parts[2]].append(Precession.direction(Precession.B1875, Precession.J2000,
				float(parts[0]) * 15.0, float(parts[1])))
	var out := []
	for abbrev in order:
		var loop: Array = per[abbrev]
		if loop.size() < 3:
			continue
		out.append(_densify(loop))
	return out


## Straight lines between corners let a long arc sag inside the sphere, so each
## leg is walked along its great circle in steps no larger than a degree - and
## the loop is closed on the way out.
static func _densify(loop: Array) -> Array:
	var out := []
	for i in loop.size():
		var a: Vector3 = loop[i]
		var b: Vector3 = loop[(i + 1) % loop.size()]
		var steps := maxi(1, ceili(rad_to_deg(a.angle_to(b))))
		for k in steps:
			out.append(a.slerp(b, float(k) / float(steps)))
	out.append(loop[0])
	return out
