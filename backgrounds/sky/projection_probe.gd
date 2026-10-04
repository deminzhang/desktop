## The sky's map to the frame, measured at the wallpaper's own scale (计划 §6.5
## 天球 → 屏的投影).
##
## The map has two sides that must agree - shaders/sky_projection.gdshaderinc draws
## the sphere with it, SkyProjection places the 2D layers with it - and this probe is
## the CPU side checked against the arithmetic it claims to be, and against the
## camera's own lens: every line here is also something the lens gets wrong, which is
## why the map exists at all. The lens is measured beside the map, as the control.
##
##   "$G" --headless --path . --script res://backgrounds/sky/projection_probe.gd
##
## The exit code is the verdict; every line prints pass or FAIL. The wall is the
## wallpaper's own 2560x1440 (A14's instrument) under the opening view
## (CameraRig.OPENING_ALTITUDE/FOV), with the same panel stood on its end for the
## portrait case.
##
## One thing the map cannot do is worth knowing here too, and it is pinned below
## rather than asserted away: a frame with the zenith on it and a horizon that stays a
## straight line is not a map of a sphere. The horizon is a circle about the zenith on
## every map where turning swings the sky about it, so this map's horizon is a curve
## and what it costs is measured, in pixels and in the share of the frame the ground
## takes.
##
## The tree is not up in _initialize() (G39), so the one frame of work runs in
## _process and the probe quits from there.
extends SceneTree

## The frame everything is measured on: the wallpaper's, and the same panel stood up.
const FRAME := Vector2(2560.0, 1440.0)
const PORTRAIT := Vector2(1440.0, 2560.0)
## The observer's default (observer.gd).
const LATITUDE := 39.9042
const LONGITUDE := 116.4074
## The star sphere's radius (StarField.RADIUS). Only the direction matters to the
## map, but the points have to be out on the sphere like everything else it draws.
const RADIUS := 480.0

var _failures := 0


func _process(_delta: float) -> bool:
	_run()
	quit(_failures)
	return true


func _run() -> void:
	# the sky's own default is the lens (sky.gd); everything from here to the
	# comparison section is written for the pan-and-tilt grid - the one this sky was
	# drawn with until 2026-10-12, and the one most of these numbers were taken on -
	# and says so
	SkyProjection.map = SkyProjection.Map.PAN
	var opening := _camera(CameraRig.OPENING_ALTITUDE)
	var map := func(world: Vector3) -> Vector2:
		return SkyProjection.screen_point(opening, world, FRAME)
	var lens := func(world: Vector3) -> Vector2:
		return _lens_point(opening, world, FRAME)

	_the_zenith(map, lens)
	_the_scale(opening, map, lens)
	_the_width_is_the_frame(opening)
	_the_horizon(opening, map)
	_turning_swings_about_the_zenith(opening, map)
	_time_wheels_about_the_pole()
	_the_moon_at_the_side()
	_the_four_maps()
	_the_turn()
	_the_suns_day()

	print("XuanDesk: sky_projection_probe: %d line(s) failed" % _failures)


# ------------------------------------------------------------------ the zenith

## The zenith lands on the frame's own centre line, and the whole azimuth circle at
## the zenith closes onto that one point - the frame's top edge is 95 degrees up
## under the opening view, so the zenith is 5 per cent of the frame down from the top
## by construction and not by tuning (计划 §6.5 整片天空入画修订).
##
## What it costs to have the zenith as a point is measured with it: a three degree
## ring of sky around the zenith comes out 86 px tall - the frame's vertical scale,
## exact - and a little wider than that, which is the map's own stretch at the top of
## the frame. It is a ring, not a smear: the same ring through the lens would be the
## sky's own, too.
func _the_zenith(map: Callable, lens: Callable) -> void:
	var at: Vector2 = map.call(Vector3.UP * RADIUS)
	# derived, not pinned: the frame's top edge is OPENING_ALTITUDE + half the field, so
	# the zenith sits that much past 90 deg below it - 5 per cent of the frame at the
	# 100 deg opening, 9 once 用户 widened it to 110 (2026-10-12)
	var expected := Vector2(FRAME.x * 0.5, FRAME.y
			* (CameraRig.OPENING_ALTITUDE + CameraRig.OPENING_FOV * 0.5 - 90.0)
			/ CameraRig.OPENING_FOV)
	check("the zenith on the top centre", at.distance_to(expected) < 0.5,
			"(%.2f, %.2f) on the frame, (%.2f, %.2f) predicted"
			% [at.x, at.y, expected.x, expected.y])

	var closed := 0.0
	for step in 16:
		var bearing := float(step) * 360.0 / 16.0
		var near: Vector2 = map.call(Astro.horizon_direction(bearing, 89.9) * RADIUS)
		closed = maxf(closed, near.distance_to(at))
	check("every azimuth above closes onto the zenith", closed < 4.0,
			"the ring at altitude 89.9 is %.2f px across" % (closed * 2.0))

	var reach := 3.0 / (CameraRig.OPENING_FOV * 0.5) * FRAME.y * 0.5
	var tall := -INF
	var wide := 0.0
	for step in 32:
		var bearing := float(step) * 360.0 / 32.0
		var ring: Vector2 = map.call(Astro.horizon_direction(bearing, 87.0) * RADIUS)
		tall = maxf(tall, absf(ring.y - at.y))
		wide = maxf(wide, absf(ring.x - at.x))
	var through_lens := 0.0
	for step in 32:
		var bearing := float(step) * 360.0 / 32.0
		var ring: Vector2 = lens.call(Astro.horizon_direction(bearing, 87.0) * RADIUS)
		through_lens = maxf(through_lens, absf(ring.x - at.x))
	check("the ring around the zenith is bounded, not smeared",
			absf(tall - reach) < 1.0 and wide < tall * 1.5,
			"3 deg ring: %.1f px tall (%.1f exact), %.1f px wide (lens: %.1f)"
			% [tall, reach, wide, through_lens])


# ------------------------------------------------------------------- the scale

## The local scale over the frame, relative to the frame's middle, in the stronger of
## the two directions it has there: the measure the map was chosen on (计划 §6.5,
## the table in sky_projection.gdshaderinc).
##
## The grid is the frame's own pixels, and each projection is measured at the directions
## *it* draws there - the lens' corners are not the map's corners, they are 71 degrees
## off its axis where the map's are 89 - so the two numbers say the same thing about
## each. The lens swells by sec^2 away from its axis: 7.4x at the sides of this frame,
## 9.5x at its corners, which is the whole of the 2026-10-10 complaint. (Both numbers
## move with the opening field - they were 5.5x and 6.9x at the 100 deg one the map was
## chosen under.)
func _the_scale(camera: Camera3D, map: Callable, lens: Callable) -> void:
	var middle := _strongest(map, _frame_direction(camera, FRAME * 0.5, FRAME))
	var lens_middle := _strongest(lens, _lens_direction(camera, FRAME * 0.5, FRAME))
	var worst := 0.0
	var total := 0.0
	var count := 0
	var lens_worst := 0.0
	var lens_total := 0.0
	for column in 21:
		for row in 13:
			var pixel := Vector2(FRAME.x * float(column) / 20.0,
					FRAME.y * float(row) / 12.0)
			var through_map := _frame_direction(camera, pixel, FRAME)
			var here := _strongest(map, through_map) / middle
			worst = maxf(worst, here)
			total += here * here
			count += 1
			var through_lens := _strongest(lens,
					_lens_direction(camera, pixel, FRAME)) / lens_middle
			lens_worst = maxf(lens_worst, through_lens)
			lens_total += through_lens * through_lens
	# the bound is relative on purpose: the opening field is a composition knob (100 deg
	# until 2026-10-12, 110 after) and the absolute numbers move with it, while what the
	# map is *for* does not - it holds one scale several times better than the lens does
	# over the very same frame
	var rms := sqrt(total / count)
	var lens_rms := sqrt(lens_total / count)
	check("one scale across the frame", worst < lens_worst / 3.0 and rms < lens_rms / 3.0,
			"worst %.2fx, rms %.2fx - against the lens' own %.2fx / %.2fx over the same frame"
			% [worst, rms, lens_worst, lens_rms])
	check("the lens is the thing being replaced", lens_worst > 6.0,
			"the lens reaches %.2fx of its middle at its own corners" % lens_worst)


## The frame's width is the viewing width: the map puts `half * aspect` degrees either
## side of the view axis on the frame's own left and right edges, so what a panel
## shows follows its shape - 178 degrees across a 16:9 panel, 56 across the same panel
## stood on its end ("横屏>90, 竖屏<90").
func _the_width_is_the_frame(camera: Camera3D) -> void:
	var half := CameraRig.OPENING_FOV * 0.5
	var landscape := half * (FRAME.x / FRAME.y)
	var portrait := half * (PORTRAIT.x / PORTRAIT.y)
	var at_edge := SkyProjection.screen_point(camera,
			_local(camera, landscape, 0.0) * RADIUS, FRAME)
	var standing := SkyProjection.screen_point(camera,
			_local(camera, portrait, 0.0) * RADIUS, PORTRAIT)
	check("the width is the viewing width, landscape over 90",
			absf(at_edge.x - FRAME.x) < 0.5 and landscape * 2.0 > 90.0,
			"%.1f deg across, the edge direction lands at x %.2f of %.0f"
			% [landscape * 2.0, at_edge.x, FRAME.x])
	check("the same panel stood up is under 90",
			absf(standing.x - PORTRAIT.x) < 0.5 and portrait * 2.0 < 90.0,
			"%.1f deg across, the edge direction lands at x %.2f of %.0f"
			% [portrait * 2.0, standing.x, PORTRAIT.x])


# ----------------------------------------------------------------- the horizon

## The horizon under the view axis is arithmetic - the opening view's pitch is 45 deg,
## so the horizon is 45 deg below the axis and lands at y = (0.5 + 45/100) of the
## frame - and the map has to agree with that.
##
## Off the centre column the map's rows are the camera's own rise rather than the
## world's altitude, so the horizon climbs towards the frame's sides: that bow, and
## the share of the frame the ground takes, are the price of one constant scale and
## are pinned here. The share is sampled the way dome.gdshader cuts the ground - every
## direction below the observer's horizon, over the whole frame - so it is the same
## number the wallpaper draws, 18.8 per cent against the lens' 8 (计划 §6.5).
func _the_horizon(camera: Camera3D, map: Callable) -> void:
	var pitch := CameraRig.OPENING_ALTITUDE
	var centre: Vector2 = map.call(Astro.horizon_direction(180.0, 0.0) * RADIUS)
	var expected_y := (0.5 + pitch / CameraRig.OPENING_FOV) * FRAME.y
	check("the horizon under the view axis", absf(centre.y - expected_y) < 0.5,
			"y %.2f, %.2f predicted, x %.2f" % [centre.y, expected_y, centre.x])

	var edge := _horizon_row(camera, 0.0)
	var bow := expected_y - edge
	var ground := 0
	var total := 0
	for column in 256:
		for row in 144:
			var pixel := Vector2((float(column) + 0.5) / 256.0 * FRAME.x,
					(float(row) + 0.5) / 144.0 * FRAME.y)
			total += 1
			if _frame_direction(camera, pixel, FRAME).y <= 0.0:
				ground += 1
	var share := float(ground) / float(total)
	# both of these scale with the opening field (100 deg: 634 px and 18.8 per cent;
	# 110: 580 and 24.5) - what is being held is that the bow stays a large fraction of
	# the frame and the ground stays a band under the horizon rather than the picture
	check("the bow is the known cost of the scale",
			bow > FRAME.y * 0.35 and bow < FRAME.y * 0.5,
			"the horizon climbs %.0f px to the frame's sides (y %.0f there, %.0f in the middle)"
			% [bow, edge, centre.y])
	check("the ground is a band, not the frame", share > 0.15 and share < 0.30,
			"%.2f%% of the frame is below the horizon" % (share * 100.0))


# ----------------------------------------------------------------- the turning

## Turning swings the sky about the zenith, which is "同一时间我转方向，则星空绕天顶转":
## the zenith holds still on the frame, the sky over it barely moves, and the sky at
## the horizon sweeps past. The camera's own lens - the sky's default since 2026-10-12 -
## is that same motion for the same reason (a turn is a rotation about the world's
## vertical axis, and the zenith's own direction lies on it), with its own swell towards
## the frame's edges; the last line measures what each of the two draws of the sky's own
## arc overhead.
func _turning_swings_about_the_zenith(camera: Camera3D, map: Callable) -> void:
	var zenith: Vector2 = map.call(Vector3.UP * RADIUS)
	var drift := 0.0
	for step in 24:
		var rig := _camera(CameraRig.OPENING_ALTITUDE, float(step) * 15.0)
		var here := SkyProjection.screen_point(rig, Vector3.UP * RADIUS, FRAME)
		drift = maxf(drift, here.distance_to(zenith))
	check("the zenith holds still through the turn", drift < 0.5,
			"worst drift %.2f px over 24 bearings" % drift)

	var overhead := Astro.horizon_direction(180.0, 85.0) * RADIUS
	var low := Astro.horizon_direction(180.0, 5.0) * RADIUS
	var turned := _camera(CameraRig.OPENING_ALTITUDE, 190.0)
	var near := SkyProjection.screen_point(turned, overhead, FRAME).distance_to(
			SkyProjection.screen_point(camera, overhead, FRAME))
	var far := SkyProjection.screen_point(turned, low, FRAME).distance_to(
			SkyProjection.screen_point(camera, low, FRAME))
	var lens_near := _lens_point(turned, overhead, FRAME).distance_to(
			_lens_point(camera, overhead, FRAME))
	check("the sky moves least over the zenith", near < far * 0.2,
			"10 deg turn: %.1f px overhead, %.1f px at the horizon, ratio %.2f"
			% [near, far, near / maxf(far, 1.0e-6)])
	# How far the sky itself moves under that turn, at the frame's own middle scale: ten
	# degrees of azimuth is only cos(altitude) degrees of sky, so the star overhead is 11
	# px of sky where the one at the horizon is 129. The pan grid draws that motion a
	# third wider than it is (14.9 px); the camera's own lens - the sky's default since
	# 2026-10-12 - draws it a tenth narrow (10.0), its own swell at the top of the frame
	# doing the work. (Until 2026-10-12 this line read the other way round - the lens at
	# 17.8 px, "the map is the closer of the two". The lens was measured through
	# --headless's square viewport, which put its horizontal scale out by the frame's
	# whole aspect: the fault was in the probe, not in the lens, and it is fixed in
	# _camera().)
	var scale := FRAME.y * 0.5 / (CameraRig.OPENING_FOV * 0.5)
	var own := 10.0 * cos(deg_to_rad(85.0)) * scale
	check("the turn's overhead motion is drawn near the sky's own arc",
			lens_near < own * 1.1 and near > own * 1.15,
			"the star overhead is %.1f px of sky by the frame's own scale: the camera's own lens draws %.1f (%.2fx, the default), the pan grid %.1f (%.2fx)"
			% [own, lens_near, lens_near / own, near, near / own])


# -------------------------------------------------------------------- the time

## Time wheels the sky about the pole, which is "同一方向时间走动，则星空绕北极星转".
## The view is held on the pole (north, the observer's own latitude) and a star ten
## degrees off it is followed for three quarters of a day: it keeps its ten degrees,
## goes round the pole at 90 degrees per six hours, and goes round it anticlockwise -
## which is the way the sky turns when you stand facing north.
func _time_wheels_about_the_pole() -> void:
	var jd := Astro.julian_day(2026, 10, 22, 0, 0, 0.0)
	var camera := _camera(LATITUDE, 0.0)
	var pole: Vector2 = SkyProjection.screen_point(camera,
			Astro.horizon_direction(0.0, LATITUDE) * RADIUS, FRAME)
	var star := Vector3(sin(deg_to_rad(10.0)), cos(deg_to_rad(10.0)), 0.0)
	var at := func(jd_ut: float) -> Vector2:
		return SkyProjection.screen_point(camera,
				Astro.sky_basis(jd_ut, LATITUDE, LONGITUDE) * star * RADIUS, FRAME)
	var start: Vector2 = at.call(jd)
	var reach := start.distance_to(pole)
	var steps: Array[float] = []
	var radii: Array[float] = []
	for hours in [6.0, 12.0, 18.0]:
		var there: Vector2 = at.call(jd + float(hours) / 24.0)
		steps.append(_gap_deg(_angle_deg(start - pole), _angle_deg(there - pole)))
		radii.append(there.distance_to(pole))
	# ninety degrees per six hours, wound onto (-180, 180] as a short way round leads
	# to: the half turn reads either way, so each step is compared with where the sky
	# should have got to by then
	var turned := true
	for index in steps.size():
		turned = turned and absf(_gap_deg(steps[index], -90.0 * float(index + 1))) < 6.0
	var held := true
	for radius in radii:
		held = held and absf(radius - reach) < reach * 0.05
	check("the star wheels about the pole, a quarter turn per six hours",
			turned and held,
			"6/12/18 h: %.1f / %.1f / %.1f deg wound about the pole; radius %.1f -> %s px"
			% [steps[0], steps[1], steps[2], reach, str(radii.map(
			func(r: float) -> String: return "%.1f" % r))])
	var predicted := 10.0 / (CameraRig.OPENING_FOV * 0.5) * FRAME.y * 0.5
	check("the pole is where the observer's latitude puts it",
			absf(reach - predicted) < predicted * 0.05,
			"a ten degree star stands %.1f px from it (%.1f predicted at this frame)"
			% [reach, predicted])


# ------------------------------------------------------------------- the turn

## "同一时间我转方向，则星空绕天顶转": a turn of the view swings the sky about the zenith's
## point, so a star's screen motion falls off with its altitude and the zenith is the one
## place the sky does not drag. Measured per map, 10 degrees of view turn at the opening
## (CameraRig.OPENING_*), as pixels moved at 85/45/10 deg of altitude and by the zenith's
## own point:
##
##   map        the zenith   10 deg of turn moves (85 / 45 / 10 deg up)
##   pan        0.0 px        14.9 /  92.5 / 156.6
##   lens       0.0 px        10.0 /  62.5 / 106.6   - the default: the camera's own
##                                                     lens, which is a rotation about
##                                                     the world's vertical axis and
##                                                     so leaves the zenith's own
##                                                     direction untouched too
##   cylinder   4582 px      130.9 / 130.9 / 130.9   - a slide, the same at every
##                                                     height: its zenith is a row, not
##                                                     a point
##   sphere     0.0 px        19.4 / 174.5 / 310.1   - exact radially, but its horizon is
##                                                     a circle
func _the_turn() -> void:
	# the sky's own default (sky.gd): the camera's own lens
	SkyProjection.map = SkyProjection.Map.LENS
	var camera := _camera(CameraRig.OPENING_ALTITUDE)
	var drift: float = SkyProjection.screen_point(_faced(camera, 180.0), Vector3.UP * RADIUS,
			FRAME).distance_to(SkyProjection.screen_point(_faced(camera, 190.0),
			Vector3.UP * RADIUS, FRAME))
	var near: float = _turn_move(camera, 85.0)
	var mid: float = _turn_move(camera, 45.0)
	var far: float = _turn_move(camera, 10.0)
	check("the default's turn is a turn, not a slide",
			drift < near and near < mid and mid < far,
			"10 deg of view turn: %.1f px at 85 deg of altitude, %.1f at 45, %.1f at 10 - the sky moves least over the zenith, and the zenith's own point drifts %.1f px (a rigid slide moves every height alike - the cylinder's %.1f px each)"
			% [near, mid, far, drift, _cylinder_turn_move(camera)])
	SkyProjection.map = SkyProjection.Map.CYLINDER
	check("the cylinder is not a turn (why it is not the default)",
			_turn_move(camera, 85.0) > 100.0,
			"under the cylinder the same turn moves a star at 85 deg %.1f px - as much as one at 10 deg"
			% _turn_move(camera, 85.0))
	SkyProjection.map = SkyProjection.Map.PAN


## What the same turn does under the cylinder, for the comparison in the line above.
func _cylinder_turn_move(camera: Camera3D) -> float:
	var before := SkyProjection.map
	SkyProjection.map = SkyProjection.Map.CYLINDER
	var moved := _turn_move(camera, 85.0)
	SkyProjection.map = before
	return moved


func _faced(camera: Camera3D, azimuth: float) -> Camera3D:
	camera.basis = Basis.looking_at(Astro.horizon_direction(azimuth, CameraRig.OPENING_ALTITUDE),
			Astro.horizon_up(azimuth, CameraRig.OPENING_ALTITUDE))
	return camera


func _turn_move(camera: Camera3D, altitude: float) -> float:
	var direction := Astro.horizon_direction(180.0, altitude) * RADIUS
	var before: Vector2 = SkyProjection.screen_point(_faced(camera, 180.0), direction, FRAME)
	var after: Vector2 = SkyProjection.screen_point(_faced(camera, 190.0), direction, FRAME)
	return before.distance_to(after)


# ------------------------------------------------------------------- the menu

## The four maps the sky can draw with (--sky-map), measured against the two things
## 用户 asked for together and no map of a sphere can have together: a horizon that is
## exactly a line, and a zenith-to-horizon distance that is the same in every
## direction. The ball is the one that gives the second exactly; the camera's own lens
## is what the sky is drawn with (sky.gd), and the other two are here to be compared
## with them.
##
##   map        the horizon's bow over this frame   the zenith-to-horizon spread
##   lens       a line, 0 px                       its own frame's corners differ by
##     (default)                                   6.9x: this is the 2026-10-10 report
##   sphere     the horizon's own circle, a curve   0 per cent in every direction -
##                                                 one degree of sky is one degree
##                                                 of pixel radially; the picture is
##                                                 a ball, the zenith's point above
##                                                 the frame's top edge
##   pan        a curve, 632 px                    11 per cent (the closest of the
##                                                 straight-horizon family)
##   cylinder   a line, 0 px                       0 per cent - but the *horizontal*
##                                                 scale runs up to 1/cos, so the
##                                                 zenith is a row, not a point
##
## The chirality line is the one that caught a real bug while this was being written:
## the world-measured maps mirror the whole sky if the turn is subtracted the other way
## round, and a mirrored map flips the winding of the sphere seen from inside, so a
## cull_front layer's gradient vanished (measured then, on the dome/sky-on-a-ball pair
## that has since been removed). It is also the line that catches the ball's branch
## being turned over: measured on the frames, the plain form of that branch drew the
## point-inverse of its own arithmetic (the Moon's disc at the antipode of where the
## CPU side puts it) - the branch is now written negated, and this line plus the
## Moon's disc agreement are what say so.
func _the_four_maps() -> void:
	var names := {
		"pan": SkyProjection.Map.PAN,
		"lens": SkyProjection.Map.LENS,
		"cylinder": SkyProjection.Map.CYLINDER,
		"sphere": SkyProjection.Map.SPHERE,
	}
	var chirality := true
	var lines: Array[String] = []
	for name in names:
		SkyProjection.map = names[name]
		var camera := _camera(CameraRig.OPENING_ALTITUDE)
		# the view is due south: a bearing west of it (190) stands on its right, so its
		# place on the frame has the larger x - this is the mirror guard
		var west := SkyProjection.screen_point(camera,
				Astro.horizon_direction(190.0, 20.0) * RADIUS, FRAME).x
		var east := SkyProjection.screen_point(camera,
				Astro.horizon_direction(170.0, 20.0) * RADIUS, FRAME).x
		chirality = chirality and west > east
		# the horizon's bow: its row under the view axis against its row at the frame's
		# left edge
		var centre := SkyProjection.screen_point(camera,
				Astro.horizon_direction(180.0, 0.0) * RADIUS, FRAME)
		var side := SkyProjection.screen_point(camera,
				Astro.horizon_direction(91.4, 0.0) * RADIUS, FRAME)
		var zenith := SkyProjection.screen_point(camera, Vector3.UP * RADIUS, FRAME)
		# the walk from the zenith down to the horizon, in pixels, along eight of the
		# sky's own meridians: the distance the eye travels looking up in that
		# direction, which is the thing "从天顶到地平线从任意方向看起来都是等距的" is
		# about. A chord across the frame would measure something else.
		var lengths: Array[float] = []
		for step in 9:
			var bearing := 180.0 - 60.0 + float(step) * 15.0
			var walked := 0.0
			var last := SkyProjection.screen_point(camera,
					Astro.horizon_direction(bearing, 90.0) * RADIUS, FRAME)
			for slice in 90:
				var altitude := 90.0 - float(slice + 1)
				var here := SkyProjection.screen_point(camera,
						Astro.horizon_direction(bearing, altitude) * RADIUS, FRAME)
				if is_finite(here.x) and is_finite(last.x):
					walked += here.distance_to(last)
				last = here
			lengths.append(walked)
		var low: float = lengths.min()
		var high: float = lengths.max()
		# and the shape: the worst a degree of sky is stretched against the other
		# direction at the same point, over a grid of the frame - 1.0 is a circle
		var worst_shape := 0.0
		for column in 21:
			for row in 13:
				var pixel := Vector2(FRAME.x * float(column) / 20.0,
						FRAME.y * float(row) / 12.0)
				# each map is measured where it draws: the lens' frame is its own
				# (its corner is 68 deg off its axis, the others' 89)
				var grid := _frame_direction(camera, pixel, FRAME)
				if SkyProjection.map == SkyProjection.Map.LENS:
					grid = _lens_direction(camera, pixel, FRAME)
				# the frames of the world-measured maps do not cover the frame's
				# corners in general: a point with no sky under it is not a point of
				# that map, so it is not measured
				var landed := SkyProjection.screen_point(camera, grid, FRAME)
				if landed.x < 0.0 or landed.x > FRAME.x or landed.y < 0.0 \
						or landed.y > FRAME.y:
					continue
				var there := _singular(func(world: Vector3) -> Vector2:
						return SkyProjection.screen_point(camera, world, FRAME), grid)
				worst_shape = maxf(worst_shape, there.x / maxf(there.y, 1.0e-6))
		lines.append("%-9s bow %5.0f px   zenith-to-horizon %.0f..%.0f px (spread %3.0f%%)   worst stretch %.2fx   %.1f px/deg"
				% [name, centre.y - side.y, low, high,
				(high - low) / ((high + low) * 0.5) * 100.0, worst_shape,
				(centre.y - zenith.y) / 90.0])
	SkyProjection.map = SkyProjection.Map.PAN
	check("the maps draw the same sky, the right way round", chirality,
			"a bearing west of the view lands on its right under all four")
	for line in lines:
		print("       %s" % line)


# --------------------------------------------------------------- the Sun's day

## 用户 2026-10-12 第二轮："太阳应当东升西落,你这样看起来太阳是横着过的,没有升"。这是
## 拿太阳自己的一天量的：春分那天（北京，日出正东、正午到 50 度、日落正西），每 5 分钟
## 取一次太阳的位置，走完 24 小时，看它在画上**竖直爬了多少、横着扫了多少**——比
## 0.2 以下就是"横着过去、没有升"。
##
## 根因不在画法，在**相机取景**：默认视角朝正南、仰角 45°，而太阳的周日轨迹（春分＝赤道）
## 那个平面跟视轴几乎平行（夹角 95°），所以只要竖直坐标是"相机自己的仰角"，整条弧就被
## 压平成一条横线——**而那一支正是现在的默认（`lens`）**：春分那天太阳走的就是赤道，
## 赤道是**大圆**，大圆过球心必被投影成直线，所以"横着过"在这天是几何事实，不是画错。
## 竖直坐标改成**世界地平高度**（`cylinder`）才把它变成"爬"。
##
## 这条量的因此是两件事：四个网格各量一遍（横/竖），并且钉住这个事实——**"太阳爬升"要
## 看的是太阳的高度，不是"固定机位下它在画上往哪走"**。跟着太阳转机位时，视线中心就是
## 太阳，画上的 y 差＝高度差：`.tmp/tests/sample.tscn` 出图量到春分 118 px、夏至 438 px。那条
## 是真机位下的"东升西落"，这里的比值是固定机位下的"轨迹形状"，两者都记着。
func _the_suns_day() -> void:
	var names := {
		"pan": SkyProjection.Map.PAN,
		"lens": SkyProjection.Map.LENS,
		"cylinder": SkyProjection.Map.CYLINDER,
		"sphere": SkyProjection.Map.SPHERE,
	}
	var lines: Array[String] = []
	var ratios: Dictionary = {}
	for name in names:
		SkyProjection.map = names[name]
		var camera := _camera(CameraRig.OPENING_ALTITUDE)
		var low := INF
		var high := -INF
		var left := INF
		var right := -INF
		for step in 288:
			var ut := Astro.julian_day(2026, 3, 20, 0, 0, 0.0) + float(step) / 288.0
			var position := Astro.sun_position(Astro.tt_from_ut(ut))
			var catalogue := Astro.local_from_date(Astro.tt_from_ut(ut), position.x,
					position.y)
			# daytime only, and only where the map itself has the Sun on the frame: the
			# question is what the eye watches during a day, not what the night does
			if asin(clampf((Astro.sky_basis(ut, LATITUDE, LONGITUDE) * catalogue).y,
					-1.0, 1.0)) <= 0.0:
				continue
			var at := SkyProjection.screen_point(camera,
					Astro.sky_basis(ut, LATITUDE, LONGITUDE) * catalogue * RADIUS, FRAME)
			if not is_finite(at.x) or at.x < 0.0 or at.x > FRAME.x:
				continue
			low = minf(low, at.y)
			high = maxf(high, at.y)
			left = minf(left, at.x)
			right = maxf(right, at.x)
		ratios[name] = (high - low) / maxf(right - left, 1.0)
		lines.append("%-9s climbs %4.0f px, sweeps %4.0f px (climb/sweep %.2f)"
				% [name, high - low, right - left, ratios[name]])
	SkyProjection.map = SkyProjection.Map.PAN
	for line in lines:
		print("       %s" % line)
	check("the Sun's day: the camera-like maps draw the equinox track for what it is (a great circle - a line), the ball curves it, the altitude grid makes it climb",
			ratios["pan"] < 0.1 and ratios["lens"] < 0.1
			and ratios["sphere"] > 0.05 and ratios["sphere"] < 0.25
			and ratios["cylinder"] > 0.25,
			"climb/sweep with the camera held still: pan %.2f, lens %.2f, sphere %.2f, cylinder %.2f (春分: the Sun's daily circle *is* the equator that day, and a great circle through the eye projects to a straight line - under the camera's own lens as much as under the pan-and-tilt grid, which is why the ball is the first of the radial maps to show any climb at all: a great circle is a curve, not a line, on a grid that is not projective. The climb is the Sun's *altitude*, which the cylinder puts straight onto the frame's y; a camera shows it when the view is turned to follow the Sun, measured on a scratch scene at 118 px over the equinox day and 438 px over the solstice)"
			% [ratios["pan"], ratios["lens"], ratios["sphere"], ratios["cylinder"]])

## The Moon's orbit is drawn while the Moon is on the frame - and on this map the frame
## is wider than the lens' (89 deg across the half-frame against the lens' 65), so a
## Moon at the side of the wallpaper is inside the picture and outside the camera's
## frustum at once. The frustum cannot be the test any more (计划 §6.5「一处要跟着走的
## 东西」): this is the view the wallpaper was checked on, where the two disagree, and
## the Moon's own ephemeris is what puts it there.
func _the_moon_at_the_side() -> void:
	var ut := Astro.julian_day(2026, 10, 22, 14, 0, 0.0)
	var jd := Astro.tt_from_ut(ut)
	var state := Astro.moon_state(jd)
	var world: Vector3 = Astro.sky_basis(ut, LATITUDE, LONGITUDE) \
			* Astro.local_from_date(jd, state.ra, state.dec) * RADIUS
	var camera := _camera(CameraRig.OPENING_ALTITUDE, 90.0)
	var disc := RADIUS * tan(deg_to_rad(state.radius_deg)) * SkyMoon.MAGNIFY
	var reach := disc * SkyProjection.pixels_per_unit(camera, FRAME, RADIUS)
	var screen := SkyProjection.screen_point(camera, world, FRAME)
	check("a Moon at the side of the frame is on the wallpaper",
			screen.x > 0.0 and screen.x < FRAME.x and screen.y > 0.0
			and screen.y < FRAME.y
			and SkyProjection.in_frame(camera, world, FRAME, reach)
			and not camera.is_position_in_frustum(world),
			"screen (%.1f, %.1f) of (%.0f, %.0f), disc %.1f px: the map has it, the lens' frustum does not"
			% [screen.x, screen.y, FRAME.x, FRAME.y, reach])


# ------------------------------------------------------------------- the tools

func _camera(altitude: float, azimuth := 180.0,
		fov := CameraRig.OPENING_FOV) -> Camera3D:
	# the camera has to carry the *frame's* own shape, not whatever viewport it happens
	# to be found in: the lens' projection matrix is where `SkyProjection._lens_point`
	# reads the frame from (its [1][1] is 1/tan(fov/2) and its [0][0] that over the
	# aspect), and under --headless the root viewport is square - so the lens was being
	# measured as a square picture stretched into a 16:9 frame, its horizontal scale out
	# by the frame's whole aspect (measured: a direction one-and-a-bit axes off the
	# middle landed at x 384 instead of 776). One viewport per camera, the wallpaper's own
	# 2560x1440.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(FRAME)
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.fov = fov
	camera.basis = Basis.looking_at(Astro.horizon_direction(azimuth, altitude),
			Astro.horizon_up(azimuth, altitude))
	viewport.add_child(camera)
	return camera


## The direction the map puts at (turn, rise) in the camera's own frame - the map read
## backwards, written out here rather than called, so that the round trips below are
## not the same code twice.
func _local(camera: Camera3D, turn_deg: float, rise_deg: float) -> Vector3:
	var turn := deg_to_rad(turn_deg)
	var rise := deg_to_rad(rise_deg)
	return camera.global_transform.basis * Vector3(sin(turn) * cos(rise), sin(rise),
			-cos(turn) * cos(rise))


## The sky direction the map has drawn at a pixel: the map read backwards, which is
## what lets a grid be laid over the frame instead of over the world.
func _frame_direction(camera: Camera3D, pixel: Vector2, size: Vector2) -> Vector3:
	var half := CameraRig.OPENING_FOV * 0.5
	return _local(camera, (pixel.x - size.x * 0.5) / (size.y * 0.5) * half,
			-(pixel.y - size.y * 0.5) / (size.y * 0.5) * half)


## The sky direction the lens itself has drawn at a pixel - the frame's own corner is
## 68 degrees off its axis where the map's is 89, and both have to be measured where
## they draw. Out of the perspective divide: a pixel's tangent plane is
## (ndc.x * tan(half) * aspect, ndc.y * tan(half), -1).
func _lens_direction(camera: Camera3D, pixel: Vector2, size: Vector2) -> Vector3:
	var half := deg_to_rad(CameraRig.OPENING_FOV * 0.5)
	var ndc := Vector2(pixel.x / size.x * 2.0 - 1.0, 1.0 - pixel.y / size.y * 2.0)
	var tangent := Vector3(ndc.x * tan(half) * (size.x / size.y), ndc.y * tan(half),
			-1.0)
	return (camera.global_transform.basis * tangent).normalized()


func _world(azimuth: float, altitude: float) -> Vector3:
	return Astro.horizon_direction(azimuth, altitude) * RADIUS


## Where the camera's own lens would put a world point: the perspective projection the
## map replaces, out of the camera's own matrix. The control of every line above.
func _lens_point(camera: Camera3D, world: Vector3, size: Vector2) -> Vector2:
	var view := camera.global_transform.affine_inverse() * world
	if view.z > -1.0e-6:
		return Vector2(INF, INF)
	var clip := camera.get_camera_projection() * Vector4(view.x, view.y, view.z, 1.0)
	var ndc := Vector2(clip.x / clip.w, clip.y / clip.w)
	return Vector2((ndc.x + 1.0) * size.x * 0.5, (1.0 - ndc.y) * size.y * 0.5)


## The strongest of the two scales the map draws a degree of sky with at a direction,
## in pixels: the larger singular value of the 2x2 Jacobian of the map at that point,
## which is what "the local scale in the strongest direction" means. The steps are
## along the parallel and along the vertical circle: a hundredth of a degree of
## azimuth is cos(altitude) hundredths of a degree of sky, and that division is the
## sky's own shape rather than the map's.
func _strongest(screen_point: Callable, direction: Vector3) -> float:
	return _singular(screen_point, direction).x


## Both of them: x is the strongest direction, y the weakest. Equal means the map draws
## the sky round there; 1.57 is what the dome's own grid does at the horizon (its
## tangential scale) and what the pan-and-tilt grid does at the top and bottom of the
## frame; 6.9 is the lens at the corners of its own frame.
func _singular(screen_point: Callable, direction: Vector3) -> Vector2:
	const STEP := 0.01
	var azimuth := Astro.azimuth_of(direction)
	var altitude := Astro.altitude_of(direction)
	var here: Vector2 = screen_point.call(_world(azimuth, altitude))
	var east: Vector2 = screen_point.call(_world(azimuth + STEP, altitude))
	var up: Vector2 = screen_point.call(_world(azimuth, altitude + STEP))
	var along := (east - here) / (STEP * cos(deg_to_rad(altitude)))
	var rise := (up - here) / STEP
	var a := along.x
	var b := rise.x
	var c := along.y
	var d := rise.y
	var trace := a * a + b * b + c * c + d * d
	var determinant := (a * d - b * c) * (a * d - b * c)
	var spread := sqrt(maxf(trace * trace - 4.0 * determinant, 0.0))
	return Vector2(sqrt(0.5 * (trace + spread)), sqrt(0.5 * (trace - spread)))


## The row the horizon crosses a given column at. The horizon is not a function of the
## frame's x on this map - it is a curve - so it is walked in bearing until the map's
## own x reaches the column: bearings west of the view's own raise x, east lower it.
func _horizon_row(camera: Camera3D, x: float) -> float:
	var east := -89.0
	var west := 89.0
	for _pass in 40:
		var middle := (east + west) * 0.5
		var at := SkyProjection.screen_point(camera,
				Astro.horizon_direction(180.0 + middle, 0.0) * RADIUS, FRAME)
		if at.x < x:
			east = middle
		else:
			west = middle
	return SkyProjection.screen_point(camera,
			Astro.horizon_direction(180.0 + (east + west) * 0.5, 0.0) * RADIUS,
			FRAME).y


func _angle_deg(offset: Vector2) -> float:
	return rad_to_deg(atan2(offset.y, offset.x))


## The turn from one bearing to another, signed, the short way round.
func _gap_deg(from_deg: float, to_deg: float) -> float:
	return fposmod(to_deg - from_deg + 180.0, 360.0) - 180.0


func check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s %s — %s" % ["pass" if ok else "FAIL", label, detail])
