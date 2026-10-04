## The sky's map to the frame, on the CPU side (2026-10-10).
##
## The shader half of this is shaders/sky_projection.gdshaderinc, and it is where
## the reasoning lives: the sky is a sphere seen from its centre, an engine camera is
## a rectilinear lens, and through that lens what is off the view axis is magnified
## by sec^2 - the frame's sides come out at 58 px per degree where the middle of the
## frame is drawn at 10.6, so the Moon's disc grew as it drifted to the side and the
## stars spread apart with it. Every vertex of the sky is therefore placed by
## direction on the rig's own two axes: the frame's x is the angle about the frame's
## up axis and its y the angle about its right axis, each at one constant scale. The
## vertical scale is exact at every point of the frame, and so is the whole
## horizontal band through the middle - the band the horizon lies in - so nothing
## grows for standing away from the middle of the picture.
##
## Three things about the sky are 2D and computed here rather than by the engine, and
## they have to land on the same pixels the shader draws the sphere on:
##   * the names that ride the sphere - the 88 constellations, the 宿, the planets and
##     the Moon (SkyLabels), and the two branch rings on the horizon (SkyBranches);
##   * the frame's own scale, in pixels per world unit (the Moon's name is lifted
##     clear of a disc that is drawn MAGNIFY times its true size);
##   * the bounds of a mesh hung off the sphere's centre, which the frustum would
##     otherwise cull while the map still has it on the frame (keep_visible).
##
## Only the camera is asked anything, so the map is right at any field of view, any
## frame shape and any view the rig is pointed at.
class_name SkyProjection
extends RefCounted

## How far a body's own bounds have to reach to hold the camera: the sky is drawn
## from the sphere's centre and its meshes hang 456..500 units out, so a box this
## size around any of them has the camera inside it and can never be culled. The
## sphere's own layers (stars, figures, the dome) are centred on the camera already.
const REACH := 600.0

## Which map the frame is drawn with - the shader's own `sky_map` (the include), and
## this side has to be the same one, because the names, the branch rings and the
## bodies' boxes are placed here while the sphere is drawn there. Set once, when the
## background is built (--sky-map).
##
## The default is the camera's own lens (用户 2026-10-12: "要真 3D 投射啊"): the sky is a
## real sphere with the stars on it and a plain Camera3D stands at its centre, so what
## the frame shows is what the engine's own transform draws - no map at all, and the
## only one of the four that is not a grid invented for the picture. The three grids
## beside it were measured against it and kept, so the trade can be looked at rather
## than argued about (the table at the head of the include).
enum Map { PAN, LENS, CYLINDER, SPHERE }
static var map: Map = Map.LENS


## The row the composition wants the horizon on, as a fraction of the frame's height:
## the pan-and-tilt grid's own - the view axis 45 deg up and the field 100 deg put it
## there - and the ball's grid is scaled to land on the same row (its zenith is the
## centre of its own grid, so it sits a little above the frame's top edge).
const HORIZON_ROW := 0.95

## How far the horizon's circle stands from the zenith's point, in frame heights - the
## one knob between "a real camera" (infinite: the horizon a straight line, the sky
## swelling at the sides) and "the sky on a ball" (small: the horizon a circle about
## the zenith). At 1.39 the zenith's point sits 0.44 of a frame *above* the top edge -
## "屏高正上方为天顶" - the horizon lands on the composition's own row and its whole
## circle is in the frame, so turning in azimuth walks the sky round that circle the way
## it walks round the zenith in life.
const SPHERE_REACH := 1.39


## The field each map is composed for, in degrees, for a caller that has just switched to
## it (CameraRig.OPENING_FOV is the lens' own: 110, 用户's figure for this view). The pan
## grid and the cylinder put the *angle* on the frame, so their horizontal edge is
## `fov/2 * aspect` of azimuth - 100 deg of field is 178 deg of horizon, i.e. the whole
## southern half, and anything wider wraps the sky behind the observer in at the frame's
## sides. The ball's grid ignores the field entirely: its frame is its own.
static func preferred_fov() -> float:
	match map:
		Map.LENS:
			return 110.0
		Map.SPHERE:
			return 110.0
		_:
			return 100.0


## Half the frame's vertical field, in radians: a point this far off the view axis
## lands on the frame's top or bottom edge. Camera3D.fov is the field across the
## frame's own height - the rig holds a vertical field - and the shader reads the
## same number out of its projection matrix.
static func half_angle(camera: Camera3D) -> float:
	return maxf(deg_to_rad(camera.fov) * 0.5, 1.0e-5)


## Where a world point lands on the frame, in pixels, for a frame `size` pixels
## across. The point is a direction from the camera as far as this is concerned - the
## sky's own points are all on the sphere around it - and the camera's frame is the
## reference, so this needs nothing of SkyRoot.
##
## A point anywhere but behind the camera has a place on the frame; one far enough
## off the axis lands outside it, which is the caller's business (a name tests its
## own box, the way it always has).
static func screen_point(camera: Camera3D, world: Vector3, size: Vector2) -> Vector2:
	var view := camera.global_transform.affine_inverse() * world
	var distance := view.length()
	if distance < 1.0e-6:
		return size * 0.5
	var direction := view / distance
	if map == Map.LENS:
		return _lens_point(camera, view, size)
	if map == Map.CYLINDER:
		return _cylinder_point(camera, (world - camera.global_position).normalized(),
				size)
	if map == Map.SPHERE:
		return _sphere_point(camera, (world - camera.global_position).normalized(),
				size)
	var half := half_angle(camera)
	# the two angles of the direction in the camera's own frame (it looks down -Z),
	# each over the half-angle the frame's edge stands for - the same map the shader
	# draws the sphere with
	var turn := atan2(direction.x, -direction.z) / half
	var rise := asin(clampf(direction.y, -1.0, 1.0)) / half
	# one half-height is `size.y * 0.5` pixels on both axes: the frame's shape is the
	# camera's aspect, which the map has already folded in
	return size * 0.5 + Vector2(turn, -rise) * size.y * 0.5


## The camera's own rectilinear lens: the perspective projection the map replaces, and
## the default since 2026-10-12 (the sky as a real sphere seen through a real camera:
## the horizon is a line, and what swells is the frame's sides). The probe measures it
## beside the other three, because that swell is the price of the line.
static func _lens_point(camera: Camera3D, view: Vector3, size: Vector2) -> Vector2:
	if view.z > -1.0e-6:
		return Vector2(INF, INF)
	var clip := camera.get_camera_projection() * Vector4(view.x, view.y, view.z, 1.0)
	var ndc := Vector2(clip.x / clip.w, clip.y / clip.w)
	return Vector2((ndc.x + 1.0) * size.x * 0.5, (1.0 - ndc.y) * size.y * 0.5)


## The world's altitude straight down the frame and its azimuth straight across, one
## constant scale each: the horizon is exactly the row the pitch puts it on, and the
## sky above is stretched by 1/cos(altitude) - the zenith is a row, not a point.
static func _cylinder_point(camera: Camera3D, direction: Vector3, size: Vector2) -> Vector2:
	var altitude := asin(clampf(direction.y, -1.0, 1.0))
	var scale := size.y * 0.5 / half_angle(camera)
	return Vector2(size.x * 0.5 + _turn(camera, direction) * scale,
			size.y * 0.5 - (altitude - _pitch(camera)) * scale)


## The sky on a ball (用户 2026-10-12: "你做个真正的天球,把星投射到球上" / "使用天球模式"):
## the azimuthal equidistant a dome master is drawn with - a degree of sky is a degree of
## pixel in *every* direction, radially, so turning the view swings the sky rigidly about
## the zenith's point - with that point placed above the frame's top edge rather than on
## it, so the horizon's whole circle is in the picture and the day is spent swinging over
## it. Inside the circle is the sky, outside it the ground, and the frame is filled by
## the two.
##
## The cost of smallness is the horizon's curvature (SPHERE_REACH): at an infinite reach
## this is the camera's own lens, with a straight horizon and the sides swelling.
static func _sphere_point(camera: Camera3D, direction: Vector3, size: Vector2) -> Vector2:
	var altitude := asin(clampf(direction.y, -1.0, 1.0))
	var reach := SPHERE_REACH * size.y
	var scale := reach / (PI * 0.5)
	var centre := size.y * HORIZON_ROW - reach
	var radius := scale * (PI * 0.5 - altitude)
	var turn := _turn(camera, direction)
	return Vector2(size.x * 0.5 + radius * sin(turn), centre + radius * cos(turn))


## How far round the world's up a direction lies from the view's own azimuth: the two
## azimuths measured the same way about the vertical axis and subtracted, wound into
## (-PI, PI]. The sight comes first, so that a direction west of the view - which
## stands on its right - comes out positive; the other way round mirrors the picture.
## (The angle *between* the two directions would do for two points at one altitude and
## shrink towards the zenith otherwise - it draws a tent instead of the sky.)
static func _turn(camera: Camera3D, direction: Vector3) -> float:
	var sight := -camera.global_transform.basis.z
	return wrapf(atan2(sight.x, sight.z) - atan2(direction.x, direction.z), -PI, PI)


## The altitude the view itself holds, off the camera's own basis: both grids that
## measure from the horizon need it.
static func _pitch(camera: Camera3D) -> float:
	return asin(clampf(-camera.global_transform.basis.z.y, -1.0, 1.0))


## Whether a world point lands on the frame, with `margin` pixels of frame to spare:
## the map reaches further than the camera's own frustum does (the Moon at the side
## of the wallpaper is inside the picture and outside the frustum at once), so
## anything asking "is this in view" asks the map. `margin` is for a body with a size
## of its own - a disc whose centre has just left the frame is still half on it.
static func in_frame(camera: Camera3D, world: Vector3, size: Vector2,
		margin := 0.0) -> bool:
	return Rect2(Vector2.ZERO, size).grow(margin).has_point(
			screen_point(camera, world, size))


## Pixels one world unit covers at `radius` from the camera, at the middle of the
## frame. A tangent of `radius` units is an angle of `1/radius` radians there, and
## the map's vertical scale is that of a lens looking straight at it - the same
## number at every height on the frame, which is what lets the Moon's name be lifted
## by a fixed fraction of its own disc.
static func pixels_per_unit(camera: Camera3D, size: Vector2, radius: float) -> float:
	return pixels_per_radian(camera, size) / maxf(radius, 1.0e-6)


## Pixels one radian of sky covers at the middle of the frame under the map in use: the
## camera's own scale away from the axis (the lens), the one-degree-a-degree of the
## ball's grid, or the same over the half-angle the other two grids are drawn on. Only
## the Moon's name lift rides on this.
static func pixels_per_radian(camera: Camera3D, size: Vector2) -> float:
	var half := half_angle(camera)
	if map == Map.LENS:
		return size.y * 0.5 / tan(half)
	if map == Map.SPHERE:
		return SPHERE_REACH * size.y / (PI * 0.5)
	return size.y * 0.5 / half


## Gives `instance` bounds that hold the camera, so the frustum never culls it while
## the sky's own map still has it on the frame. The sky's grids draw a wider frame than
## the camera's own (the pan grid's horizontal edge is 89 deg off the axis where the
## lens' is 65), so a body at the side of the wallpaper can be outside the frustum and
## inside the picture at once - the Sun, the Moon and the seven marks are the meshes that
## hang off the sphere's centre and need this. Under the lens the two frames coincide and
## the bounds do nothing, which is the point of asking for them here rather than at each
## caller.
static func keep_visible(instance: GeometryInstance3D) -> void:
	instance.custom_aabb = AABB(Vector3.ONE * -REACH, Vector3.ONE * REACH * 2.0)
