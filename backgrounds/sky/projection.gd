## The sky's map to the frame, on the CPU side (2026-10-10; the fisheye since
## 2026-10-14).
##
## The shader half of this is shaders/sky_projection.gdshaderinc, and it is where the
## reasoning lives: the sky is a sphere seen from its centre, an engine camera is a
## rectilinear lens, and through that lens what is off the view axis is magnified by
## sec^2 - the frame's sides came out at 58 px per degree where the middle of the frame
## was drawn at 10.6, so the Moon's disc grew as it drifted to the side and the stars
## spread apart with it (2026-10-10 "星星近大远小"; again 2026-10-14: "当前中心正常，
## 周围被拉伸放大"). Two and a half days of drawing the sky with a *grid* instead
## (pan, cylinder, the ball) bought the scale back and paid for it in a horizon that is
## a curve; what the sky is drawn with now is the fisheye - the azimuthal equidistant a
## dome master is drawn with, its pole on the view axis - so a degree of sky is a degree
## of pixel in *every* direction radially, what is off the middle of the frame is drawn
## smaller rather than larger, and both of 用户's two motions come out right: a turn
## swings the sky rigidly about the zenith, and the day wheels it about the pole.
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
## The default is the fisheye (用户 2026-10-14: "改用鱼眼/等距柱状投影 重新校正星空"): the
## sky is a real sphere with the stars pinned to it and a plain Camera3D at its centre,
## and every vertex is placed by its *angle* off the view axis, folded onto the frame's
## radius at one constant scale - the dome master's projection. What it buys is that a
## turn of the view is a rigid rotation of the picture about the zenith and that a day
## wheels it about the pole with the sky holding its shape; what it costs is that a line
## of the sky that is not through the view axis - the horizon, when the view is not the
## zenith - comes out a curve. The other three were measured against it and kept as
## switches (the table at the head of the include), and the camera's own lens is among
## them: 用户 2026-10-12 asked for it ("要真 3D 投射啊"), 2026-10-14 named its price.
enum Map { PAN, LENS, CYLINDER, FISHEYE }
static var map: Map = Map.FISHEYE


## The field each map is composed for, in degrees, for a caller that has just switched to
## it - and the field the wallpaper *runs* at, because build() hands the rig this number
## (sky.gd::_build_clock). The fisheye is composed at the rig's own opening field (96:
## a directed window onto the southern sky, the zenith on the frame's own top edge and the
## ground under the horizon clearing the desktop's taskbar by a 地支 mark - both ends of the
## frame are set by that pair, see CameraRig.OPENING_ALTITUDE); the pan grid and the
## cylinder put the *angle* on the frame with a wider horizontal edge, so they open at 100;
## and the camera's own lens is composed at the same field as the fisheye so the two can be
## flipped between and compared.
static func preferred_fov() -> float:
	match map:
		Map.PAN, Map.CYLINDER:
			return 100.0
		_:
			return CameraRig.OPENING_FOV


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
	if map == Map.FISHEYE:
		return _fisheye_point(camera, direction, size)
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


## The fisheye (用户 2026-10-14: "改用鱼眼/等距柱状投影 重新校正星空"): the azimuthal
## equidistant a dome master is drawn with, its pole on the *view axis* - the angle a
## direction stands off that axis, at one constant scale, laid out as the frame's radius
## in the direction the direction lies. A degree of sky is a degree of pixel radially, in
## every direction, so nothing grows for standing away from the middle of the picture:
## the pixels per degree are the same at the frame's edge as at its centre.
##
## Three of the properties the two of 用户's motions are read off come out of that one
## line. A turn of the view by `a` degrees turns the *picture* by exactly `a` about the
## point the view axis lands on - the zenith's own point, when the view is up - because a
## rotation about that axis is a relabelling of the polar angle alone: the sky's shape,
## and with it every star separation, is untouched. The day wheels the sky about the pole
## with the local scale field standing still (the pole is a point of the frame, 50.1 deg
## out from the zenith at Beijing's latitude). And what is *tangential* - the direction
## around the ring at a given angle - is stretched by `rho/sin rho`, 1.00 at the middle
## and 1.57 at the horizon's ring, where the lens had 9.5 at its own corners; a line of
## the sky that is not through the pole (the horizon, once the view is not the zenith)
## is drawn as the curve that stretch makes of it.
##
## `direction` comes in in the camera's own frame (the caller's `view`, normalised), which
## is where the pole is: the camera looks down -Z, so the angle off the axis is the
## arccosine of -z and the azimuth about it is atan2(x, y) - the frame's own up being the
## fisheye's own "north". The shader draws the same two angles (sky_projection.gdshaderinc,
## mode 3).
static func _fisheye_point(camera: Camera3D, direction: Vector3, size: Vector2) -> Vector2:
	var off_axis := acos(clampf(-direction.z, -1.0, 1.0))
	var roll := atan2(direction.x, direction.y)
	var radius := off_axis / half_angle(camera) * size.y * 0.5
	return size * 0.5 + Vector2(sin(roll), -cos(roll)) * radius


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
## camera's own scale away from the axis (the lens), or the one degree a degree of the
## grids - the fisheye and the two angle-on-the-frame grids all put the angle on the
## frame at `half_angle` for the frame's half-height. Only the Moon's name lift rides on
## this.
static func pixels_per_radian(camera: Camera3D, size: Vector2) -> float:
	var half := half_angle(camera)
	if map == Map.LENS:
		return size.y * 0.5 / tan(half)
	return size.y * 0.5 / half


## The angular width the frame's middle row spans, in degrees, under the map in use: what
## the wallpaper is *showing*, which is what the card's view arc is drawn as (用户
## 2026-10-12 第二十一轮: "盘外的视角方向弧...跟实际3D场景中的视角一致"). The fisheye, the
## pan grid and the cylinder put the angle on the frame, so it is `2 * half * aspect`; the
## lens compresses it to `2 atan(tan(half) * aspect)`, which is a different number for the
## same frame - 195.6 deg against 177.8 at the opening.
static func frame_span(camera: Camera3D, size: Vector2) -> float:
	var half := half_angle(camera)
	var aspect := size.x / maxf(size.y, 1.0e-6)
	if map == Map.LENS:
		return rad_to_deg(2.0 * atan(tan(half) * aspect))
	return rad_to_deg(2.0 * half * aspect)


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
