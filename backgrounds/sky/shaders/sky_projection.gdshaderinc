// Where a vertex of the sky goes on the frame. Include from the sky's spatial
// shaders with
//   #include "res://backgrounds/sky/shaders/sky_projection.gdshaderinc"
//
// The engine's camera is a rectilinear lens, and this sky is a sphere seen from its
// centre: through that lens what is off the view axis is magnified by sec^2, so the
// frame's sides come out at 58 px per degree where the middle is drawn at 10.6 - five and
// a half times - and the corners worse still. The wallpaper showed exactly that and it is
// wrong for a sky: the middle looked squeezed, the Moon's disc grew as it drifted out to
// the side, and the stars spread apart with it (2026-10-10, and again 2026-10-14:
// "当前中心正常，周围被拉伸放大").
//
// The map in use since 2026-10-14 is the fisheye (mode 3, --sky-map): the azimuthal
// equidistant a dome master is drawn with, its pole on the *view axis* - the angle a
// direction stands off that axis, at one constant scale, laid out as the frame's radius
// in the direction the direction lies. A degree of sky is a degree of pixel radially, in
// every direction, so nothing grows for standing away from the middle of the frame - what
// the map stretches instead is the *across* direction, by rho/sin(rho): 1.00 at the axis,
// 1.571 at the horizon's own ring, 1.72 at the frame's own corners at the opening (97.9 deg
// off the axis, past that ring and still 15 deg of sky). The two motions 用户 reads the sky
// by both come out right: a turn of the view is a rigid rotation of the picture about the
// axis' own point (the zenith, with the view up), and the day wheels the sky about the pole
// with the map's scale field standing still. The sky's geometry is a ball either way - the
// stars are pinned to a sphere of radius 480 inside the dome of 500 - and what the fisheye
// bends instead is a line of the sky that does not pass through the view axis: with the
// view at the zenith that is the horizon, which is drawn as the ring 90 deg out from the
// middle of the frame, the ground beyond it filling the frame's own corners.
//
// The three other maps were measured against it and kept, so the trade can be looked at
// rather than argued about. The numbers are the map's own scale at the middle of the
// frame, the worst its scale reaches over the sky it draws on a 2560x1440 frame at the
// opening (backgrounds/sky/projection_probe.gd carries them, and everywhere in this file
// the "grid" is the pair of angles a map puts on the frame):
//
//   map         px/deg   worst    what it buys, and what it charges
//   fisheye      15.00   1.52x    a degree is a degree in every direction radially, a
//     (default)                   turn is a rotation of the picture, and the day keeps
//                                 the sky's shape - the charge is the horizon as a ring
//                                 and 1.571x across a shape of sky at the horizon
//   lens         11.31   4.40x    no map at all: the engine's own `projection * view`,
//                                 the horizon a straight line - at sec^2, 9.5x at the
//                                 corners of the frame it is pointed at, and the same
//                                 turn at a tilted view leaves 68 per cent of a star's
//                                 distance from the zenith behind
//   pan          15.00   1.49x    the frame's own two axes, one constant scale each: the
//                                 flattest of the four, at 38 per cent of the
//                                 zenith-to-horizon walk from side to side
//   cylinder     15.00  11.46x    the world's altitude down the frame and its azimuth
//                                 across: the horizon exactly a line, and the zenith a
//                                 whole row - a turn of the view slides the sky instead
//                                 of turning it (95 per cent off at the opening)
//
// The one that was here before the fisheye - the ball drawn about the *zenith* rather
// than about the view axis (--sky-map=sphere until 2026-10-14) - is gone: it drew the
// same picture as the fisheye with the view up, and nothing else, because a pole that
// does not follow the view axis leaves the rig's tilt and zoom dead. It was also written
// by hand twice in one day and came out turned over in the shader both times (the plain
// form drew the *point-inverse* of its own arithmetic: the Moon's disc 648 px from where
// the CPU side places it, its antipode about the frame's centre), which cost a negated
// rewrite and a Moon's-disc check to find; the fisheye's two angles are the camera's own
// frame's, so there is nothing to get turned over.
//
// The map cannot be a *camera*, so it is written as POSITION - the modelview and
// projection transforms are overridden rather than added to. Two consequences, both
// wanted:
//   * the mapped vertex is handed to PROJECTION_MATRIX keeping the distance it had
//     from the camera, so the depth pipeline and the sky's layer order are exactly
//     what they were;
//   * a mesh's own bounds are no longer where its geometry lands on screen, so a
//     mesh hung off the sphere's centre - the Sun's quad, the Moon's disc, a
//     planet's mark - wants SkyProjection.keep_visible(), or the frustum culls it
//     while it is still on the frame.
//
// The grid has one seam and it is behind the observer: `turn` wraps at the half
// plane straight behind the view. The sky's meshes wrap the whole sphere - the dome,
// the star field, the ribbons - so the few triangles that straddle that half plane
// have their vertices placed on opposite sides of the frame. They come out harmless,
// by the arithmetic if not by a targeted test: the dome's are culled (the winding
// flips on the way across) and the additive ones keep their flux spread thin - a
// straddling star spends its 8 pixels' worth of brightness over a hairline 2560 px
// wide. No band shows against the field, the gradient or the horizon in the opening,
// polar and noon shots taken for this change (2026-10-10).
//
// The half-angle comes off the camera instead of being handed in: [1][1] of a
// perspective projection is 1/tan(fov/2), and Camera3D.fov is the frame's own height
// (the rig holds a vertical field), so the shader cannot drift out of step with the
// rig and there is no uniform to set. SKY_CLIP is a macro rather than a plain
// function call because a shader's own built-ins are only in scope inside its stage
// functions: PROJECTION_MATRIX does not exist in a helper, so the helper is handed
// the matrix and the macro reads it inside vertex(). The same map, on the CPU side,
// is SkyProjection - the two have to agree pixel for pixel, where the names that
// ride the sphere are placed.
//
// Every sky shader's vertex() ends with its vertex run through this. The world
// position and the view matrix come in as arguments rather than being read inside:
// a shader's own built-ins are only in scope inside its stage functions, and
// INV_VIEW_MATRIX is not among the vertex stage's anyway.
//   POSITION = SKY_CLIP(VIEW_MATRIX * MODEL_MATRIX * vec4(VERTEX, 1.0));
#define SKY_CLIP(view) sky_clip(view, MODEL_MATRIX * vec4(VERTEX, 1.0), VIEW_MATRIX, atan(1.0 / PROJECTION_MATRIX[1][1]), PROJECTION_MATRIX)

// Which of the four maps above to draw with (--sky-map, set on the sky's materials when
// the background is built). The fisheye is the default since 2026-10-14 (用户: "改用鱼眼/
// 等距柱状投影 重新校正星空"): the sky is a real sphere with the stars on it and a plain
// Camera3D stands at its centre, and every vertex of it is placed by its *angle* off the
// view axis, laid out as the frame's radius at one constant scale - the dome master's
// projection. The other three are the maps that were measured against it and kept, so the
// choice can be looked at rather than argued about (the table at the head of this file,
// backgrounds/sky/projection_probe.gd for the numbers):
//
//   0  pan and tilt   the frame's own two axes, one constant scale each
//   1  lens           the camera's rectilinear projection, no map at all: the horizon
//                     is a line and the scale swells by sec^2 away from the axis
//   2  cylinder       the world's altitude down the frame and its azimuth across, one
//                     constant scale each: the horizon is exactly a line, and the
//                     zenith is a row stretched by 1/cos instead of a point
//   3  fisheye        the azimuthal equidistant about the *view axis*: one scale in every
//                     direction radially, so nothing is drawn larger than the middle of
//                     the frame, a turn of the view is a rigid rotation of the picture
//                     about the axis' own point, and the day keeps the sky's shape - the
//                     default, and the one thing it charges is a line of the sky that
//                     does not pass through the view axis (the horizon, with the view up)
global uniform int sky_map;

// A horizontal direction's azimuth about the observer's vertical axis, measured the
// same way for the sight and for the sky's own points - their difference is the turn
// the cylinder's grid is drawn on.
float world_azimuth(vec3 horizontal) {
	return atan(horizontal.x, horizontal.z);
}

// The clip position of a vertex at `view` in camera space, `world` its position in the
// world (the sky is a sphere of radius 456..500 around the camera, which stands at the
// world's own origin), `half_angle` half the frame's vertical field in radians. The
// distance from the camera is kept and only the direction is remapped, so depth stays
// the vertex' own. A vertex on top of the camera has no direction to map and is left
// on the axis: nothing up there is within a hair of it.
vec4 sky_clip(vec4 view, vec4 world, mat4 view_matrix, float half_angle, mat4 projection) {
	float distance = length(view.xyz);
	vec3 direction = view.xyz / max(distance, 1.0e-6);
	// the frame's own shape, out of the projection: [1][1]/[0][0] is the aspect
	float aspect = projection[1][1] / projection[0][0];
	if (sky_map == 1) {
		// the camera's own lens: no map at all
		return projection * view;
	}
	// The direction and the sight in the world's own frame, which the cylinder is drawn
	// against: +Y there is the observer's zenith however the sky is turned under it. The
	// camera's world axes are the columns of its world transform, which is the view
	// matrix's rotation transposed - the camera stands at the origin, so there is no
	// translation to undo.
	vec3 world_direction = normalize(world.xyz);
	mat3 camera_world = transpose(mat3(view_matrix));
	vec3 sight = -camera_world[2];
	float altitude = asin(clamp(world_direction.y, -1.0, 1.0));
	float pitch = asin(clamp(sight.y, -1.0, 1.0));
	// How far round the world's up the direction lies from the view's own azimuth: the
	// two azimuths measured the same way about the vertical axis and subtracted, wound
	// into (-PI, PI]. Sight first, direction second, so that a direction *west* of the
	// view - which stands on its right - comes out positive: the other way round
	// mirrors the whole picture (and a mirrored map flips the winding of a sphere seen
	// from inside, so a cull_front layer's own gradient disappears - measured, on a
	// map that is no longer here).
	// (The angle *between* the two directions would do for two points at one altitude
	// and shrink towards the zenith otherwise - it draws a tent instead of a sky.)
	float turn = world_azimuth(sight) - world_azimuth(world_direction);
	turn = atan(sin(turn), cos(turn));
	if (sky_map == 2) {
		// the cylinder: the altitude straight down the frame and the azimuth straight
		// across, one constant scale each - the horizon is exactly the row the pitch
		// puts it on, and the zenith is a whole row, the sky near it stretched by 1/cos
		vec2 ndc = vec2(turn / (half_angle * aspect), (altitude - pitch) / half_angle);
		vec3 mapped = distance * vec3(ndc.x * tan(half_angle) * aspect,
				ndc.y * tan(half_angle), -1.0);
		return projection * vec4(mapped, 1.0);
	}
	if (sky_map == 3) {
		// the fisheye (用户 2026-10-14: "改用鱼眼/等距柱状投影 重新校正星空"): the
		// azimuthal equidistant a dome master is drawn with, its pole on the *view
		// axis* - the angle a direction stands off that axis, at one constant scale,
		// laid out as the frame's radius in the direction the direction lies. A degree
		// of sky is a degree of pixel radially, in every direction, so nothing grows for
		// standing away from the middle of the picture; a turn of the view is a rigid
		// rotation of the picture about the axis' own point (the zenith, when the view
		// is up), and the day wheels the sky about the pole with the local scale field
		// standing still.
		//
		// The two angles are the same ones SkyProjection._fisheye_point takes, and the
		// camera's own frame is where they live: `direction` is `view.xyz` normalised,
		// so the axis the vertex's angle is measured off is -Z, the axis itself, and the
		// frame's own up is the fisheye's own north - atan2(x, y) is the roll about the
		// axis and acos(-z) the angle off it. The pixel is the frame's centre plus that
		// angle at that roll, written in the frame's own ndc (the aspect dividing the
		// one component, which is what the projection matrix expects) and handed to the
		// projection so the depth pipeline sees the distance it always did.
		float off_axis = acos(clamp(-direction.z, -1.0, 1.0));
		float roll = atan(direction.x, direction.y);
		vec2 ndc = vec2(sin(roll) * off_axis / (half_angle * aspect),
				cos(roll) * off_axis / half_angle);
		vec3 mapped = distance * vec3(ndc.x * tan(half_angle) * aspect,
				ndc.y * tan(half_angle), -1.0);
		return projection * vec4(mapped, 1.0);
	}
	if (sky_map == 3) {
		// the fisheye (用户 2026-10-14: "改用鱼眼/等距柱状投影 重新校正星空"): the
		// azimuthal equidistant a dome master is drawn with, its pole on the *view
		// axis* - the angle a direction stands off that axis, at one constant scale,
		// laid out as the frame's radius in the direction the direction lies. A degree
		// of sky is a degree of pixel radially, in every direction, so nothing grows for
		// standing away from the middle of the picture; a turn of the view is a rigid
		// rotation of the picture about the axis' own point (the zenith, when the view
		// is up), and the day wheels the sky about the pole with the local scale field
		// standing still.
		//
		// The two angles are the same ones SkyProjection._fisheye_point takes, and the
		// camera's own frame is where they live: `direction` is `view.xyz` normalised,
		// so the axis the vertex's angle is measured off is -Z, the axis itself, and the
		// frame's own up is the fisheye's own north - atan2(x, y) is the roll about the
		// axis and acos(-z) the angle off it. The pixel is the frame's centre plus that
		// angle at that roll, written in the frame's own ndc (the aspect dividing the
		// one component, which is what the projection matrix expects) and handed to the
		// projection so the depth pipeline sees the distance it always did.
		float off_axis = acos(clamp(-direction.z, -1.0, 1.0));
		float roll = atan(direction.x, direction.y);
		vec2 ndc = vec2(sin(roll) * off_axis / (half_angle * aspect),
				cos(roll) * off_axis / half_angle);
		vec3 mapped = distance * vec3(ndc.x * tan(half_angle) * aspect,
				ndc.y * tan(half_angle), -1.0);
		return projection * vec4(mapped, 1.0);
	}
	// the frame's own two angles: the turn about the camera's up axis and the rise off
	// its right one, each divided by the half-angle the frame's edge stands for, so the
	// frame's middle is the view axis and its vertical edge is `half` away from it
	float frame_turn = atan(direction.x, -direction.z) / half_angle;
	float rise = asin(clamp(direction.y, -1.0, 1.0)) / half_angle;
	// the point on the axis' tangent plane whose perspective projection lands there
	vec3 mapped = distance * vec3(frame_turn * tan(half_angle), rise * tan(half_angle),
			-1.0);
	return projection * vec4(mapped, 1.0);
}
