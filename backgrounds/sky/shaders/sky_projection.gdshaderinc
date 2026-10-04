// Where a vertex of the sky goes on the frame. Include from the sky's spatial
// shaders with
//   #include "res://backgrounds/sky/shaders/sky_projection.gdshaderinc"
//
// The engine's camera is a rectilinear lens, and this sky is a sphere seen from its
// centre: through that lens what is off the view axis is magnified by sec^2, so at
// the opening 100 deg field the frame's sides are drawn at 58 px per degree where
// the middle is drawn at 10.6 - five and a half times - and the corners are worse
// still. The wallpaper showed exactly that and it is wrong for a sky: the middle
// looked squeezed, the Moon's disc grew as it drifted out to the side, and the
// stars spread apart with it (2026-10-10).
//
// The default is the camera's own lens (2026-10-12, 用户: "3D摄像机看天球要真3D投射啊,
// 你看看sample.tscn的Camera3D啊"): mode 1 *is* `projection * view`, the engine's own
// transform, and nothing else - a plain Camera3D in front of a sphere. The horizon is the
// straight line a plane through the eye projects to, the field is the rig's own (110 deg:
// the horizon's row reaches 79 deg either side of south, so the Sun enters at the lower
// left instead of arriving from the side), and the sky's geometry is a ball either way -
// the stars are pinned to a sphere of radius 480 inside the dome of 500. The three grids
// below are the ones that bend one or the other, kept so the trade can be looked at rather
// than argued about: the cylinder and the pan grid put the *angle* on the frame, and the
// sphere is the closest to "the whole sky on a ball".
//
// The numbers below are the deviation of the local scale from the middle of the frame's,
// in the strongest of the two local directions, on the opening view over a 2560x1440
// frame (backgrounds/sky/projection_probe.gd carries them, and everywhere in this file the
// "grid" is the pair of angles a map puts on the frame):
//
//   map                      rms    worst   where the worst is, and what it buys
//   lens (the default)       2.37    6.87   the sides: 5.5x, 2.6x tangentially - the
//                                           horizon is a line and 15 per cent of the
//                                           frame is ground; the Sun slides across the
//                                           frame rather than climbing it, which is the
//                                           one thing a camera cannot help
//   pan and tilt             1.14    1.55   the tops and bottoms of the frame - the
//                                           flattest of the four, at 634 px of horizon
//                                           curve ("太阳横着过", 2026-10-12)
//   azimuthal equidistant    1.18    1.81   everywhere off centre, tangentially - a
//                                           degree is a degree in every direction, and
//                                           the horizon is a circle about the zenith,
//                                           90 deg out from it (--sky-map=sphere, the
//                                           "sky on a ball")
//   cylinder                 1.18    17.1   one scale each way, the horizon exactly a
//                                           line - and the zenith a whole row, stretched
//                                           17x across the frame's top
//
// The ball's own grid (--sky-map=sphere) was written by hand twice in one day and came out
// turned over in the shader both times: the plain form of it drew the *point-inverse* of
// its own arithmetic - the Moon's disc 648 px from where the CPU side places it, i.e. its
// antipode about the frame's centre. It looks like a ball either way, so what showed it
// was the names drifting off their stars (the names and discs are placed on the CPU side,
// the sphere is drawn here). It is written negated now and agrees with
// SkyProjection._sphere_point to 1.8 px, measured with the Moon's disc.
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
// the background is built). The camera's own lens is the default (用户 2026-10-12: "要真 3D
// 投射啊"): the sky is a real sphere with the stars on it and a plain Camera3D stands at
// its centre, so mode 1 - the engine's own `projection * view` - is the whole of it, and
// the frame is what a 3D camera in front of a sphere draws. The other three are the grids
// that were measured against it and kept, so the choice can be looked at rather than
// argued about (the table at the head of this file,
// backgrounds/sky/projection_probe.gd for the numbers):
//
//   0  pan and tilt   the frame's own two axes, one constant scale each
//   1  lens           the camera's rectilinear projection, no map at all: the horizon
//                     is a line and the scale swells by sec^2 away from the axis - the
//                     default
//   2  cylinder       the world's altitude down the frame and its azimuth across, one
//                     constant scale each: the horizon is exactly a line, and the
//                     zenith is a row stretched by 1/cos instead of a point
//   3  sphere         the ball (the dome master's projection): the zenith's point above
//                     the frame's top edge, one scale in every direction radially - and
//                     the horizon a circle about the zenith, i.e. the one thing the
//                     default buys with its straight line
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
		// the sky on a ball (用户 2026-10-12: "你做个真正的天球,把星投射到球上" / "使用天球
		// 模式"): the sphere's own projection, the equidistant dome master's - a degree of
		// sky is a degree of pixel in *every* direction radially - with the zenith's point
		// above the frame's top edge, so the horizon's whole circle and the day are in the
		// picture. The constants are SkyProjection's own (SPHERE_REACH 1.39 frame heights,
		// the horizon on HORIZON_ROW 0.95 of the height) written out in ndc-y: the reach
		// is 2.78, the scale 1.7698, the zenith's row 1.88.
		//
		// The two components are written as the *negative* of that offset, and not for a
		// reason in the arithmetic - it is the same map as SkyProjection._sphere_point,
		// which is the side the names, the branch rings and the discs are placed with.
		// Measured: the plain form comes out on the *point-inverse* of itself - the Moon's
		// disc 648 px from the CPU side's prediction, exactly its antipode about the
		// frame's centre, a star likewise, and the horizon's circle fits the frame with
		// its centre 0.44 frame heights *below* the top edge where this map puts it *above*.
		// The other three grids do not do this (each checked the same way: four bright
		// stars on their CPU positions, none on their antipodes), so it is this branch's
		// shape the compiler turns over - the family 计划 §6.5 already hit once, on the
		// dome's radius. Negated, it lands the Moon's disc within 3 px of the CPU side.
		float radius = 1.7698 * (0.5 * PI - altitude);
		float ball_x = -radius * sin(turn) / aspect;
		float ball_y = radius * cos(turn) - 1.88;
		vec3 mapped = distance * vec3(ball_x * tan(half_angle) * aspect,
				ball_y * tan(half_angle), -1.0);
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
