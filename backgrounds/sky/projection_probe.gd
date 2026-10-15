## The sky's map to the frame, measured at the wallpaper's own scale (README「星点、记号与取舍」,
## 天球 → 屏的投影).
##
## The map has two sides that must agree - shaders/sky_projection.gdshaderinc draws the
## sphere with it, SkyProjection places the 2D layers with it - and this probe is the CPU
## side checked against the arithmetic it claims to be, and against the camera's own lens:
## most of the lines here are also something the lens gets wrong, which is why the map
## exists at all. The lens is measured beside the map, as the control.
##
##   "$G" --headless --path . --script res://backgrounds/sky/projection_probe.gd
##
## The exit code is the verdict; every line prints pass or FAIL. The wall is the
## wallpaper's own 2560x1440 (the instrument README「性能与静默」 measured) under the opening view
## (CameraRig.OPENING_ALTITUDE/FOV), with the same panel stood on its end for the
## portrait case.
##
## What is drawn since 2026-10-14 is the fisheye (SkyProjection.Map.FISHEYE, --sky-map):
## the dome master's azimuthal equidistant, its pole on the view axis - and the opening
## view is up (CameraRig.OPENING_ALTITUDE, 90), so that pole *is* the observer's zenith.
## 用户's two sentences are the acceptance test, and both are measured here as *motions*
## rather than as pictures, because that is how they were given (2026-10-12: "同一时间我
## 转方向,则星空绕天顶转,同一方向时间走动,则星空绕北极星转"; 2026-10-14: "目标效果1：时间
## 固定，旋转视角，看东，北，西天，星间距不变，看到以天顶为中心旋转，2：视角固定，时间变动，
## 应看到天空以北极星为中心旋转，星间距不变"):
##   * a turn of the view leaves every star's distance from the zenith's own point
##     standing - the picture rotates rigidly, so no separation can change (exact at the
##     opening, and measured again at a tilted view, where any camera-relative map has to
##     give some of it back);
##   * a day of the clock wheels the sky about the pole with the map's own scale field
##     standing still - what is left of that on a plane is measured as a drift.
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
	# the sky's own default (sky.gd): the fisheye, its pole on the view axis - and the
	# opening view is up, so that pole is the zenith itself
	SkyProjection.map = SkyProjection.Map.FISHEYE
	var opening := _camera(CameraRig.OPENING_ALTITUDE)
	var map := func(world: Vector3) -> Vector2:
		return SkyProjection.screen_point(opening, world, FRAME)
	var lens := func(world: Vector3) -> Vector2:
		return _lens_point(opening, world, FRAME)

	_the_framing(map, lens)
	_the_scale(opening)
	_the_width_is_the_frame(opening)
	_the_horizon(opening, map)
	_turning_swings_about_the_zenith(opening, map)
	_time_wheels_about_the_pole()
	_the_frame_is_wider_than_the_frustum()
	_the_ticks(opening)
	_the_four_maps()
	_the_turn()
	_the_suns_day()

	print("XuanDesk: sky_projection_probe: %d line(s) failed" % _failures)


# ----------------------------------------------------------------- the framing

## What the opening view puts where, and the map's own scale measured on it.
##
## The opening view is 用户's directed one (CameraRig.OPENING_ALTITUDE/FOV: due south, 42.5
## deg up, 96 deg of field), and its two numbers are tied together - altitude + half the
## field = 90.5 - so the frame's own top edge stands half a degree *past* the observer's
## zenith and the zenith's own point lands 7.5 px inside it. Half a degree inside and not
## on the edge, because a one-pixel line exactly on row 0 is lost by the rasteriser
## (measured on the 92 deg the framing started as: the cross's own bar came out a row
## above the frame and only its lower arm was ever drawn). What shows at the top is
## therefore 用户 2026-10-14's "能不能压一下让他在屏顶露个头,并标个淡白色虚十字" as pixels:
## the hollow cross's bar, its whole lower arm, and the first dash of its upper arm with
## the rest of that arm cut by the frame. The mark is drawn *at all* now, which it is not
## while the point sits off the picture: the 35/80 framing this replaced put it 270 px
## (0.19 of a frame) above the top edge and the cross never appeared.
##
## The frame's *bottom* is the desktop's end of the same question, and it is measured in
## `_the_horizon`: the horizon lands 0.943 of a frame down, which leaves 34.5 px of ground
## over the taskbar at the middle of the frame - the 地支 mark's own box with a third to
## spare (用户 2026-10-14: "桌面任务栏以上,地平线以下要露一个字的高度").
##
## The map's own scale is `half the frame's height over half the field` (15.00 px per
## degree at the opening), and this section measures it *radially* in several directions -
## a degree of sky is a degree of pixel from the axis outwards, which is 用户 2026-10-12's
## "从天顶到地平线从任意方向看起来都是等距的" - and the one direction where it is not:
## across the ring at a distance `rho` from the pole the map stretches a shape by
## `rho/sin(rho)` (1.00 at the middle, 1.571 at the horizon's own distance). That stretch
## is the whole price of a flat chart and it is pinned here rather than asserted away.
func _the_framing(map: Callable, lens: Callable) -> void:
	var unit := _px_per_deg()
	var at: Vector2 = map.call(Vector3.UP * RADIUS)
	var expected := Vector2(FRAME.x * 0.5,
			FRAME.y * 0.5 - (90.0 - CameraRig.OPENING_ALTITUDE) * unit)
	# the cross SkyLabels draws on the point, in the screen-space pixels it draws it in: a
	# hollow centre, three dashes of three pixels an arm, one pixel wide. `reach` is its far
	# end and `arm` the near end of the first dash of an arm.
	var reach := SkyLabels.ZENITH_GAP + float(SkyLabels.ZENITH_DASHES) \
			* (SkyLabels.ZENITH_DASH + SkyLabels.ZENITH_SPACE)
	var arm := SkyLabels.ZENITH_GAP + SkyLabels.ZENITH_DASH
	check("the zenith's cross pokes in at the frame's own top edge",
			at.distance_to(expected) < 0.5 and at.y >= 1.0 and at.y - arm >= 0.0 \
					and at.y - reach < 0.0 and at.y + reach < FRAME.y
					and at.x - reach > 0.0 and at.x + reach < FRAME.x,
			"%.0f deg above the view axis: (%.2f, %.2f) on the frame, (%.2f, %.2f) predicted - the point is %.2f px *inside* the top edge, so the cross's own bar has a row of its own (%.0f) and its lower arm (%.0f px) is wholly on the frame, while the upper arm is cut: its first dash starts %.2f px below the edge and the rest of the arm is off the frame, which is what \"露个头\" asks for"
			% [90.0 - CameraRig.OPENING_ALTITUDE, at.x, at.y, expected.x, expected.y,
			at.y, SkyLabels.ZENITH_GAP, reach, at.y - arm])

	var closed := 0.0
	for step in 16:
		var bearing := float(step) * 360.0 / 16.0
		var near: Vector2 = map.call(Astro.horizon_direction(bearing, 89.9) * RADIUS)
		closed = maxf(closed, near.distance_to(at))
	check("every azimuth above closes onto the zenith", closed < 4.0,
			"the ring at altitude 89.9 is %.2f px across" % (closed * 2.0))

	# the scale, radially and across, at three distances from the pole
	var camera := _camera(CameraRig.OPENING_ALTITUDE)
	var pole := -camera.global_transform.basis.z
	var across_pole := pole.cross(Vector3.UP).normalized()
	var lines: Array[String] = []
	var radial_error := 0.0
	var across_error := 0.0
	for rho in [20.0, 45.0, 70.0]:
		var there := _singular(map, pole.rotated(across_pole, deg_to_rad(rho)))
		var exact := deg_to_rad(rho) / sin(deg_to_rad(rho))
		var per_degree := there.y * PI / 180.0
		radial_error = maxf(radial_error, absf(per_degree - unit))
		across_error = maxf(across_error, absf(there.x / maxf(there.y, 1.0e-6) - exact))
		lines.append("%.0f deg off the axis: %.3f px per degree radially (%.3f exact), the shape stretched %.3f (%.3f exact)"
				% [rho, per_degree, unit, there.x / maxf(there.y, 1.0e-6), exact])
	check("a degree is a degree, radially, at every distance from the axis",
			radial_error < 0.05,
			"%s - which is 用户 2026-10-12's \"从天顶到地平线从任意方向看起来都是等距的\""
			% " / ".join(lines))
	check("and across the axis the map stretches a shape by rho/sin(rho)",
			across_error < 0.02,
			"%s: 1.00 at the axis, 1.571 at the horizon's own distance - the one price of any flat chart, and what the ring at the frame's edge pays"
			% " / ".join(lines))

	# and the same three degrees of sky through the camera's own lens, which spreads the
	# field over the frame by *magnifying* what is off its axis (sec^2) instead: the
	# control of every line above
	var lens_worst := 0.0
	for rho in [20.0, 45.0, 70.0]:
		var there := _singular(func(world: Vector3) -> Vector2:
				return _lens_point(camera, world, FRAME),
				pole.rotated(across_pole, deg_to_rad(rho)))
		lens_worst = maxf(lens_worst, there.x)
	check("the lens pays for the same field by magnifying",
			lens_worst * PI / 180.0 > unit * 1.5,
			"70 deg off its axis the lens draws a degree of sky at %.2f px against the map's %.2f (%.2fx - its sec^2)"
			% [lens_worst * PI / 180.0, unit, lens_worst * PI / 180.0 / unit])


# ------------------------------------------------------------------- the scale

## The local scale over the frame, relative to the frame's middle, in the stronger of the
## two directions it has there: the measure the map was chosen on (README「星点、记号与取舍」, the table in
## sky_projection.gdshaderinc). The lens swells by sec^2 away from its axis - 6.2x at the
## corners of this frame, which is the whole of the 2026-10-10 and the 2026-10-14 complaint
## ("当前中心正常，周围被拉伸放大") - against the fisheye's 1.571x, which is sin's own
## number: rho/sin(rho) at the horizon, the same price the ring above pays.
##
## The frame's own corners reach *past* the horizon's ring at this field - 97.9 deg off the
## axis, where rho/sin(rho) is 1.724, and still 15.4 deg above the horizon: the sky is wider
## than the 90.5 deg of axis height the frame's own top edge stands on - so the map's number
## there is larger than the ring's, and the two bounds below are stated apart.
func _the_scale(camera: Camera3D) -> void:
	var here := func(world: Vector3) -> Vector2:
		return SkyProjection.screen_point(camera, world, FRAME)
	var middle := _strongest(here, _fisheye_direction(camera, FRAME * 0.5, FRAME))
	var worst := 0.0
	var sky_worst := 0.0
	var total := 0.0
	var count := 0
	for column in 21:
		for row in 13:
			var pixel := Vector2(FRAME.x * float(column) / 20.0,
					FRAME.y * float(row) / 12.0)
			var direction := _fisheye_direction(camera, pixel, FRAME)
			var at := _strongest(here, direction) / middle
			worst = maxf(worst, at)
			if Astro.altitude_of(direction) > 0.0:
				sky_worst = maxf(sky_worst, at)
			total += at * at
			count += 1
	var rms := sqrt(total / count)

	var lens_middle := _strongest(func(world: Vector3) -> Vector2:
			return _lens_point(camera, world, FRAME),
			_lens_direction(camera, FRAME * 0.5, FRAME))
	var lens_worst := 0.0
	var lens_total := 0.0
	for column in 21:
		for row in 13:
			var pixel := Vector2(FRAME.x * float(column) / 20.0,
					FRAME.y * float(row) / 12.0)
			var at := _strongest(func(world: Vector3) -> Vector2:
					return _lens_point(camera, world, FRAME),
					_lens_direction(camera, pixel, FRAME)) / lens_middle
			lens_worst = maxf(lens_worst, at)
			lens_total += at * at
	var lens_rms := sqrt(lens_total / count)

	check("nothing in the sky is drawn larger than the middle of the frame",
			sky_worst < 1.75,
			"the worst the sky's own scale reaches above the horizon is %.3fx the middle's - the frame's own corner, 97.9 deg off the axis where rho/sin(rho) is 1.724; the horizon's own ring, inside it, is 1.571"
			% sky_worst)
	check("one scale across the frame", worst < 2.2 and rms < 1.6,
			"worst %.2fx, rms %.2fx over the whole frame (its corners are 97.9 deg off the axis, the sky's own at 1.72 and the rest ground); the camera's own lens reaches %.2fx / %.2fx over the very same frame"
			% [worst, rms, lens_worst, lens_rms])
	check("the lens is the thing being replaced", lens_worst > 3.0,
			"the lens reaches %.2fx of its middle at its own corners (its swell is sec^2, so the field decides the number: 3.95 at 80 deg of field, 6.15 at the opening 96, 9.5 at 110)" % lens_worst)


## The frame's width is the viewing width: the fisheye puts `half * aspect` degrees either
## side of the view axis on the frame's own left and right edges, so what a panel shows
## follows its shape - 170.7 degrees across a 16:9 panel, 54.0 across the same panel stood
## on its end ("横屏>90, 竖屏<90") - and at the opening field that is past the horizon
## itself, which is why the horizon's whole ring is on the frame.
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

## The horizon under the directed opening view: 42.5 deg below the view axis, so its row
## under the axis is `0.5 + 42.5/96` of the frame (y 1357.50, i.e 0.943 of the height), with
## the ground under it (16.95 per cent of the frame) and the 地支 ring along it.
##
## It is the one line the fisheye *bends* (a line of the sky that does not pass through
## the view axis is a curve on any map of a sphere): away from the middle it climbs, and
## how far is the field's business - 414 px at the opening, 272 at the 35/80 framing this
## replaced, 430 at 110 deg ("地平线是平的" and "从整体中截取一部分" pull against each other
## here, and 用户's answer was the narrower window). The zenith's own head on the top edge
## costs the arc another 142 px, and that is the trade this round made: the two are one
## knob short of independent, because the top edge is at the zenith whenever altitude + half
## the field = 90, and a narrower field than 96 with the same edge takes the horizon off
## the bottom instead.
##
## What the *bottom* has to hold is the desktop's, not the sky's: the wallpaper window is
## the whole screen and the taskbar lies over its last CameraRig.TASKBAR px, so the row the
## horizon lands on decides whether the 地支 mark under it is seen at all - which is what
## the last line here asserts, in the mark's own units (用户 2026-10-14: "桌面任务栏以上,
## 地平线以下要露一个字的高度"). The mark's box is asked of the font rather than assumed,
## because 15 px of type draws in a 20 px line box.
func _the_horizon(camera: Camera3D, map: Callable) -> void:
	var centre: Vector2 = map.call(Astro.horizon_direction(180.0, 0.0) * RADIUS)
	var expected_y := (0.5 + CameraRig.OPENING_ALTITUDE / CameraRig.OPENING_FOV) * FRAME.y
	check("the horizon under the view axis", absf(centre.y - expected_y) < 0.5,
			"y %.2f, %.2f predicted (%.3f of the frame), x %.2f"
			% [centre.y, expected_y, centre.y / FRAME.y, centre.x])

	var edge := _horizon_row(camera, FRAME.x * 0.05)
	var bow := expected_y - edge
	var ground := 0
	var total := 0
	for column in 256:
		for row in 144:
			var pixel := Vector2((float(column) + 0.5) / 256.0 * FRAME.x,
					(float(row) + 0.5) / 144.0 * FRAME.y)
			total += 1
			if Astro.altitude_of(_fisheye_direction(camera, pixel, FRAME)) < 0.0:
				ground += 1
	var share := float(ground) / float(total)
	check("the bow is the known cost of the field",
			bow > FRAME.y * 0.20 and bow < FRAME.y * 0.35,
			"the horizon climbs %.0f px from the middle to 5 per cent off the frame's left edge (y %.0f there, %.0f in the middle, %.1f per cent of the frame) - a straight horizon and a line through the observer's own axis cannot be had together: at 110 deg the same arc is 430 px, and what buys it down is the field"
			% [bow, edge, centre.y, bow / FRAME.y * 100.0])
	check("the ground is a band under it, not the frame",
			share > 0.05 and share < 0.25,
			"%.2f%% of the frame is below the horizon, the 地支 ring and the ground the sky is drawn with sitting on it"
			% (share * 100.0))

	# 用户 2026-10-14: "桌面任务栏以上,地平线以下要露一个字的高度" - the ground under the
	# horizon has to keep one 字 of the 地支 ring clear of the desktop's taskbar, which is
	# drawn over the frame's own last CameraRig.TASKBAR px (the wallpaper window is the whole
	# screen, so the frame's own numbers are the screen's). The mark at this bearing stands
	# SkyBranches.GAP below the horizon and draws in a line box asked of the font, not of the
	# size it is set in. This is the *thinnest* stretch of the ground on the frame - the
	# horizon's arc only rises away from the middle - and the 午 mark is on it, so one line
	# covers the whole ring.
	var letter := Fonts.ui_font().get_string_size("子", HORIZONTAL_ALIGNMENT_LEFT, -1,
			SkyBranches.FONT_SIZE)
	var clear := FRAME.y - CameraRig.TASKBAR - centre.y
	check("one 字 of the 地支 ring stays above the taskbar",
			clear >= SkyBranches.GAP + letter.y,
			"the horizon crosses the middle of the frame at y %.2f, so the ground above the taskbar's own edge (%.0f of the frame's %.0f) is %.1f px; the mark that hangs there is a %.1f px line box plus its %.1f px gap, i.e. %.2f of a 字 with the whole of it on the screen"
			% [centre.y, FRAME.y - CameraRig.TASKBAR, FRAME.y, clear, letter.y,
			SkyBranches.GAP, (clear - SkyBranches.GAP) / letter.y])


# ----------------------------------------------------------------- the turning

## "同一时间我转方向，则星空绕天顶转" (2026-10-12) and "旋转视角...看到以天顶为中心旋转"
## (2026-10-14): a turn is a rotation of the *picture* about the zenith's own point - and
## at the opening view that is exact, to the last pixel, because the map's pole is the
## zenith's own direction and a turn about that axis is a relabelling of the map's roll
## alone. Every star keeps its distance from the point, so no separation between any two
## of them can change: that is "星间距不变" read off the frame rather than argued about.
##
## The residual is measured again at a *tilted* view, where no camera-relative map can
## hold it - a turn is then a rotation about the world's vertical, not about the view
## axis, and what is left over is the map's own stretch. The camera's own lens is the
## control on both lines.
func _turning_swings_about_the_zenith(camera: Camera3D, map: Callable) -> void:
	var zenith: Vector2 = map.call(Vector3.UP * RADIUS)
	var drift := 0.0
	for step in 24:
		var rig := _camera(CameraRig.OPENING_ALTITUDE, float(step) * 15.0)
		var here := SkyProjection.screen_point(rig, Vector3.UP * RADIUS, FRAME)
		drift = maxf(drift, here.distance_to(zenith))
	check("the zenith holds still through the turn", drift < 0.5,
			"worst drift %.2f px over 24 bearings" % drift)

	var opening_fisheye := _turn_residual(SkyProjection.Map.FISHEYE,
			CameraRig.OPENING_ALTITUDE)
	var opening_lens := _turn_residual(SkyProjection.Map.LENS, CameraRig.OPENING_ALTITUDE)
	var zenith_fisheye := _turn_residual(SkyProjection.Map.FISHEYE, 90.0)
	var zenith_lens := _turn_residual(SkyProjection.Map.LENS, 90.0)
	check("the turn at the opening holds every separation to a few per cent",
			opening_fisheye < 8.0 and opening_lens > opening_fisheye * 3.0,
			"10 deg of view turn leaves a star's distance from the zenith within %.2f%% of what it was (the camera's own lens, pointed the same way, %.2f%%): the fisheye's whole field turns with the sky and only its rho/sin(rho) varies, the lens' sec^2 does not turn at all"
			% [opening_fisheye, opening_lens])
	check("and looking up it is exact",
			zenith_fisheye < 0.5 and zenith_lens < 0.5,
			"the same turn with the view axis on the zenith: the fisheye leaves %.2f%%, the lens %.2f%% - a yaw of a camera about its own axis is a roll of the picture whichever map draws it, so this is the one framing where both are rigid, and it is the fisheye's pole that makes it the picture's own rotation"
			% [zenith_fisheye, zenith_lens])
	SkyProjection.map = SkyProjection.Map.FISHEYE

	var overhead := Astro.horizon_direction(180.0, 85.0) * RADIUS
	var low := Astro.horizon_direction(180.0, 5.0) * RADIUS
	var turned := _camera(CameraRig.OPENING_ALTITUDE, 190.0)
	var near := SkyProjection.screen_point(turned, overhead, FRAME).distance_to(
			SkyProjection.screen_point(camera, overhead, FRAME))
	var far := SkyProjection.screen_point(turned, low, FRAME).distance_to(
			SkyProjection.screen_point(camera, low, FRAME))
	check("the sky moves least over the zenith", near < far * 0.2,
			"10 deg turn: %.1f px overhead, %.1f px at the horizon, ratio %.2f"
			% [near, far, near / maxf(far, 1.0e-6)])


# -------------------------------------------------------------------- the time

## "同一方向时间走动，则星空绕北极星转" (2026-10-12) and "视角固定，时间变动，应看到天空以北极
## 星为中心旋转，星间距不变" (2026-10-14): a star ten degrees off the pole keeps its ten
## degrees, goes round the pole 90 degrees per six hours, and goes round it anticlockwise -
## the way the sky turns when you stand facing north.
##
## The view is held on the pole for that measurement (north, the observer's own latitude),
## which is where the fisheye's own pole is too, so the day is as rigid there as the turn
## is at the opening. The wallpaper's real view is the zenith, so "星间距不变" is measured
## a second time from *there*: a pair of stars ten degrees off the pole, two degrees apart
## along it, followed for three quarters of a day. A plane cannot hold a sphere's whole day
## rigid about every axis at once, so the line is the size of what is left - and the
## camera's own lens, whose scale runs with sec^2, is the control.
func _time_wheels_about_the_pole() -> void:
	SkyProjection.map = SkyProjection.Map.FISHEYE
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
			"a ten degree star stands %.1f px from it at this map's scale (%.1f predicted)"
			% [reach, predicted])

	var drift := _wheel_drift(SkyProjection.Map.FISHEYE, CameraRig.OPENING_ALTITUDE)
	var lens_drift := _wheel_drift(SkyProjection.Map.LENS, CameraRig.OPENING_ALTITUDE)
	check("a pair of stars keeps its separation through the watched day",
			drift >= 0.0 and drift < 45.0 and lens_drift > drift * 2.0,
			"two stars two degrees apart across the view axis, followed from the opening over three quarters of a day while they are on the frame: their separation moves by %.2f%% (the camera's own lens: %.2f%%) - the map's own scale, rho/sin(rho), varies as the pair wheels through it, and that is all of it: the sky itself is rigid, and a degree of sky *radially* is exactly a degree of pixel all day. The bound is the window's own size, which is why it is wider than the 25 this line carried at the 35/80 framing (24.64 per cent then)"
			% [drift, lens_drift])
	SkyProjection.map = SkyProjection.Map.FISHEYE


## How much a pair of stars' separation moves over three quarters of a day, as a
## percentage of the separation it started with, seen from the opening view - and
## measured only while both stars are *on the frame*, because that is the only stretch of
## the day 用户's eye is following them for (the sky wheels 15 deg an hour, so a
## constellation crosses a 171 x 96 deg window in about five hours). The pair starts on the
## view axis, two degrees apart across it; the sky itself is rigid, so what this
## measures is the map - the local scale a pair sits on changes as the pair wheels
## through the map's own radius.
##
## The window's own size is part of the number, so it is not comparable across framings:
## the wider the frame, the longer the pair is watched and the further out it gets before it
## leaves - 7 of the 24 samples keep it on the frame at the 35/80 framing, 8 at the
## opening, where it reaches 78 deg off the axis instead of 65, and rho/sin(rho) keeps
## growing out there (1.39 against 1.25). Hence 39.06 per cent now against 24.64 then, both
## of them the flat map's own price: the pole measurement above holds the same kind of
## separation to a tenth of a pixel.
func _wheel_drift(map: SkyProjection.Map, altitude: float) -> float:
	var before := SkyProjection.map
	SkyProjection.map = map
	var camera := _camera(altitude)
	var jd := Astro.julian_day(2026, 10, 22, 0, 0, 0.0)
	# the celestial directions the view axis and its perpendicular are, at that instant:
	# the pair is the axis and a direction two degrees across from it
	var basis := Astro.sky_basis(jd, LATITUDE, LONGITUDE)
	var here := basis.inverse() * -camera.global_transform.basis.z
	var worst := 0.0
	# the pair is two degrees apart across the view axis and two degrees along it: the
	# map's own scale differs along the two, so the worse of the two is the answer
	for side in [camera.global_transform.basis.x, camera.global_transform.basis.y]:
		var across: Vector3 = basis.inverse() * (side * RADIUS)
		across = (across - here * here.dot(across)).normalized()
		worst = maxf(worst, _pair_drift(camera, here, here.rotated(across, deg_to_rad(2.0)), jd))
	SkyProjection.map = before
	return worst


## How far one pair's separation moves over the watched day: `first` and `second` are the
## two celestial directions, two degrees apart, and only the samples where both are on the
## frame are read.
func _pair_drift(camera: Camera3D, first: Vector3, second: Vector3, jd: float) -> float:
	var separation := func(jd_ut: float) -> Vector2:
		var turn := Astro.sky_basis(jd_ut, LATITUDE, LONGITUDE)
		var one := SkyProjection.screen_point(camera, turn * first * RADIUS, FRAME)
		var two := SkyProjection.screen_point(camera, turn * second * RADIUS, FRAME)
		if not Rect2(Vector2.ZERO, FRAME).has_point(one) \
				or not Rect2(Vector2.ZERO, FRAME).has_point(two):
			return Vector2(-1.0, 0.0)
		return Vector2(one.distance_to(two), 1.0)
	var start := -1.0
	var low := INF
	var high := -INF
	var kept := 0
	for step in 24:
		var here_at: Vector2 = separation.call(jd + float(step) * 0.03125)
		if here_at.x < 0.0:
			continue
		if start < 0.0:
			start = here_at.x
		low = minf(low, here_at.x)
		high = maxf(high, here_at.x)
		kept += 1
	if kept < 4 or start <= 0.0:
		return 0.0
	return (high - low) / start * 100.0


## How far a ten degree turn of the view is from a rigid rotation of the picture about the
## zenith's own point, as a percentage of the star's own distance from that point, over a
## grid of the sky: zero means every separation on the frame is untouched by the turn.
## The zenith's point is measured on each of the two frames rather than assumed to hold
## still, so the world-measured grids (the cylinder's zenith is a whole row) are measured
## by the same line.
func _turn_residual(map: SkyProjection.Map, altitude: float, turn_deg := 10.0) -> float:
	var before := SkyProjection.map
	SkyProjection.map = map
	var one := _camera(altitude, 180.0)
	var two := _camera(altitude, 180.0 + turn_deg)
	var here := SkyProjection.screen_point(one, Vector3.UP * RADIUS, FRAME)
	var there := SkyProjection.screen_point(two, Vector3.UP * RADIUS, FRAME)
	var worst := 0.0
	for azimuth_step in 24:
		for altitude_step in 9:
			var direction := Astro.horizon_direction(float(azimuth_step) * 15.0,
					10.0 + float(altitude_step) * 9.0) * RADIUS
			var before_at := SkyProjection.screen_point(one, direction, FRAME)
			var after_at := SkyProjection.screen_point(two, direction, FRAME)
			if not is_finite(before_at.x) or not is_finite(after_at.x):
				continue
			var reach := before_at.distance_to(here)
			# a star the map draws on top of the zenith's own point has no radius to
			# measure a change of, and one the lens has thrown to the edge of the frame
			# (hundreds of pixels per degree) is not a star the eye is following
			if reach < 50.0 or after_at.distance_to(there) > FRAME.length():
				continue
			worst = maxf(worst, absf(after_at.distance_to(there) - reach) / reach)
	SkyProjection.map = before
	return worst * 100.0


# ------------------------------------------------------------------ the frustum

## The picture is *wider* than the camera's own frustum, which is why a body hung off the
## sphere's centre carries SkyProjection.keep_visible() rather than trusting the frustum
## (README「星点、记号与取舍」): the fisheye lays the *angle* off the axis on
## the frame, 85.3 deg across at the opening against the lens' gnomonic 63.1, so a body at
## 63..98 deg off the axis is inside the picture and outside the frustum at once - the
## light version of what the world-measured grids (pan, cylinder) do at 89 deg. The day's
## Moon and the seven planets are the meshes that depend on it.
##
## The control is measured a pixel *inside* the frame: at this framing the zenith's own
## point sits within a row of the frame's top edge, i.e. of the frustum's own edge, and
## `is_position_in_frustum` rounds it out while the map's own `in_frame` rounds it in - a
## boundary case, not a disagreement (measured on the 92-deg framing, where the point was
## exactly on the edge: all 35 hits the tight test found in the loose one were the zenith,
## at ndc.y 1.0000).
func _the_frame_is_wider_than_the_frustum() -> void:
	var camera := _camera(CameraRig.OPENING_ALTITUDE)
	var outside := 0
	var on_frame := 0
	var widest := 0.0
	for azimuth_step in 72:
		for altitude_step in 37:
			var world := Astro.horizon_direction(float(azimuth_step) * 5.0,
					-90.0 + float(altitude_step) * 5.0) * RADIUS
			if not SkyProjection.in_frame(camera, world, FRAME):
				continue
			on_frame += 1
			if not camera.is_position_in_frustum(world):
				outside += 1
				widest = maxf(widest,
						rad_to_deg((-camera.global_transform.basis.z).angle_to(
						world.normalized())))
	SkyProjection.map = SkyProjection.Map.LENS
	var lens_outside := 0
	for azimuth_step in 72:
		for altitude_step in 37:
			var world := Astro.horizon_direction(float(azimuth_step) * 5.0,
					-90.0 + float(altitude_step) * 5.0) * RADIUS
			if SkyProjection.in_frame(camera, world, FRAME, -1.0) \
					and not camera.is_position_in_frustum(world):
				lens_outside += 1
	SkyProjection.map = SkyProjection.Map.FISHEYE
	check("the sky's own frame is wider than the camera's, so the frustum cannot be the test",
			outside > 100 and lens_outside == 0,
			"%d of %d of the sky's own directions are on the picture and outside the frustum (up to %.1f deg off the axis, where the frame's own edge is 85.3 and its corners 97.9); under the camera's own lens the same count is %d, measured a pixel inside the frame so that the zenith - which sits within a row of the frame's top edge at this framing, and of the frustum's own edge with it - is not counted as on one side of a boundary both tests round differently. Away from that edge the two agree by construction, which is why the bodies that hang off the sphere's centre call keep_visible()"
			% [outside, on_frame, widest, lens_outside])


# ------------------------------------------------------------------- the ticks

## The two scales' ticks as the sky draws them: the 宿's divisions either side of the
## equator, and the twenty-four solar terms standing off the ecliptic.
##
## 用户 2026-10-14 asked for the terms' ticks to read as marks *on* their circle rather than
## bands across it - "黄道的节气分野线只画线上部分,下部分不画" - so the line below pins the
## side they are drawn on: `Ecliptic.build` runs each one from `point(jd, lambda, 0.0)` to
## `point(jd, lambda, +reach)`, and +reach has to come out *above* the circle at every term
## the opening frame shows, or the comb hangs the wrong way off the line. Both calls here
## are the builder's own, so this line fails if either the sign in the builder or the
## frame's own up-ness changes.
##
## The 分野 ticks on the equator are symmetric and only their *length* moved
## ("天赤道的星宿分野线短一点", the same round), and that length is deliberately not restated
## anywhere: `SkyBackground.MANSION_TICK` *is* `Ecliptic.TICK_LONG`. It read 1.4 - four times
## the reach the comment beside it claimed - until this round, which is the drift one number
## with two homes gets; on screen the tick went 45.7 -> 24.5 px at the opening.
func _the_ticks(camera: Camera3D) -> void:
	var jd := Astro.julian_day(2026, 10, 14, 14, 0, 0.0)
	var basis := Astro.sky_basis(jd, LATITUDE, LONGITUDE)
	var shown := 0
	var flipped := 0
	var shortest := INF
	var longest := 0.0
	for i in Ecliptic.TERMS.size():
		var lambda := Ecliptic.term_longitude(i)
		var reach := Ecliptic.TICK_LONG if i % 2 == 0 else Ecliptic.TICK_SHORT
		var on := SkyProjection.screen_point(camera,
				basis * Ecliptic.point(jd, lambda, 0.0) * RADIUS, FRAME)
		var tip := SkyProjection.screen_point(camera,
				basis * Ecliptic.point(jd, lambda, reach) * RADIUS, FRAME)
		if not Rect2(Vector2.ZERO, FRAME).has_point(on) or not is_finite(tip.x) \
				or not is_finite(tip.y):
			continue
		shown += 1
		if tip.y > on.y:
			flipped += 1
		shortest = minf(shortest, on.distance_to(tip))
		longest = maxf(longest, on.distance_to(tip))
	check("the term ticks stand north of the ecliptic, which is up on the screen",
			shown > 8 and flipped == 0 and shortest > 3.0,
			"%d of the 24 terms are on the opening frame and every one of their ticks runs *above* the circle (%d the other way): %.0f..%.0f px long off the line, north of the ecliptic and nothing below it, the 中气's being the 0.75 deg reach and the 节令's the 0.45"
			% [shown, flipped, shortest, longest])


# ------------------------------------------------------------------- the maps

## The four maps, measured against the two motions 用户 reads the sky by and against the
## scale (--sky-map; the fisheye is what sky.gd draws with). Every map is measured on the
## frame's own grid, the lens through its own projection and the others through the map's
## own inverse, so each is measured where it actually draws.
##
##   map        px/deg  worst   the turn's residual   the day's    what it buys, and what
##                      stretch at the opening / 45   separation   it charges
##
##   fisheye    the fisheye: one scale in every direction radially, a rigid turn about the
##              zenith at the opening, and the shape of the sky kept through the day - the
##              price is a horizon that is a ring about the zenith rather than a line
##   lens       the camera's own lens: no map at all, and both motions come out right at the
##              opening because a camera looking up is the same rotation - the price is sec^2
##              (6.15x at its own corners at the opening) and a shape that breathes through
##              the day
##   pan        the flattest of the four and the least rigid: the frame's own two axes, one
##              constant scale each
##   cylinder   the world's altitude down the frame and its azimuth across: the horizon is
##              exactly a line, the zenith a whole row, and a turn is a slide
##
## The chirality line is the one that caught a real bug: the world-measured maps mirror the
## whole sky if the turn is subtracted the other way round, and a mirrored map flips the
## winding of the sphere seen from inside, so a cull_front layer's gradient vanishes. And
## the Moon's disc agreeing with SkyProjection to a couple of pixels is what says the shader
## half of *this* map is the same map the CPU half places the names with
## (.tmp/tests/ shots, taken with --shot and read back).
func _the_four_maps() -> void:
	var names := {
		"fisheye": SkyProjection.Map.FISHEYE,
		"lens": SkyProjection.Map.LENS,
		"pan": SkyProjection.Map.PAN,
		"cylinder": SkyProjection.Map.CYLINDER,
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
		# the walk from the zenith down to the horizon, in pixels, along nine of the sky's
		# own meridians: the distance the eye travels looking up in that direction, which
		# is the thing "从天顶到地平线从任意方向看起来都是等距的" is about. A chord across
		# the frame would measure something else.
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
		# and the shape: the worst a degree of sky is stretched against the other direction
		# at the same point. The grid is the *sky's* own (every azimuth at nine altitudes),
		# and each point is measured only where that map actually draws it: the frames of
		# the four cover different parts of the sky, so a grid laid over the frame would be
		# comparing four different pictures rather than four maps of one.
		var worst_shape := 0.0
		var worst_scale := 0.0
		var unit := SkyProjection.pixels_per_radian(camera, FRAME)
		for column in 36:
			for row in 9:
				var grid := Astro.horizon_direction(float(column) * 10.0,
						5.0 + float(row) * 10.0) * RADIUS
				var landed := SkyProjection.screen_point(camera, grid, FRAME)
				if not is_finite(landed.x) or landed.x < 0.0 or landed.x > FRAME.x \
						or landed.y < 0.0 or landed.y > FRAME.y:
					continue
				var there := _singular(func(world: Vector3) -> Vector2:
						return SkyProjection.screen_point(camera, world, FRAME), grid)
				worst_shape = maxf(worst_shape, there.x / maxf(there.y, 1.0e-6))
				worst_scale = maxf(worst_scale, there.x / unit)
		lines.append("%-9s %5.2f px/deg   scale %5.2fx   shape %5.2fx   turn %5.2f%% / %5.2f%%   day %6.2f%%   zenith-to-horizon %.0f..%.0f px (spread %3.0f%%)"
				% [name,
				SkyProjection.pixels_per_radian(camera, FRAME) * PI / 180.0,
				worst_scale,
				worst_shape,
				_turn_residual(names[name], CameraRig.OPENING_ALTITUDE),
				_turn_residual(names[name], 90.0),
				_wheel_drift(names[name], CameraRig.OPENING_ALTITUDE),
				low, high, (high - low) / ((high + low) * 0.5) * 100.0])
	SkyProjection.map = SkyProjection.Map.FISHEYE
	check("the maps draw the same sky, the right way round", chirality,
			"a bearing west of the view lands on its right under all four")
	for line in lines:
		print("       %s" % line)


# ------------------------------------------------------------------- the turn

## "同一时间我转方向，则星空绕天顶转": a turn of the view swings the sky about the zenith's
## point, so a star's screen motion falls off with its altitude and the zenith is the one
## place the sky does not drag. Measured per map, 10 degrees of view turn at the opening
## (CameraRig.OPENING_*), as pixels moved at 85/45/10 deg of altitude and by the zenith's
## own point:
##
##   map        the zenith   10 deg of turn moves (85 / 45 / 10 deg up)
##   fisheye    0.0 px       11.4 / 102.8 / 182.8   - the default: a rotation of the
##                                                    picture about the zenith's own point,
##                                                    so the motion is the arc at the map's
##                                                    own scale, 5 / 45 / 80 deg of radius
##   lens       0.0 px       ...
##   pan        0.0 px       ...
##   cylinder   4582 px      130.9 / 130.9 / 130.9   - a slide, the same at every
##                                                    height: its zenith is a row, not
##                                                    a point
func _the_turn() -> void:
	# the sky's own default (sky.gd): the fisheye
	SkyProjection.map = SkyProjection.Map.FISHEYE
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
	SkyProjection.map = SkyProjection.Map.FISHEYE


## What the same turn does under the cylinder, for the comparison in the line above.
func _cylinder_turn_move(camera: Camera3D) -> float:
	var before := SkyProjection.map
	SkyProjection.map = SkyProjection.Map.CYLINDER
	var moved := _turn_move(camera, 85.0)
	SkyProjection.map = before
	return moved


## The same turn under the camera's own lens, for the comparison in the turning section.
func _lens_turn_move(camera: Camera3D, altitude: float) -> float:
	var before := SkyProjection.map
	SkyProjection.map = SkyProjection.Map.LENS
	var moved := _turn_move(camera, altitude)
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


# --------------------------------------------------------------- the Sun's day

## 用户 2026-10-12 第二轮："太阳应当东升西落,你这样看起来太阳是横着过的,没有升"。这是
## 拿太阳自己的一天量的：春分那天（北京，日出正东、正午到 50 度、日落正西），每 5 分钟
## 取一次太阳的位置，走完 24 小时，看它在画上**竖直爬了多少、横着扫了多少**——比
## 0.2 以下就是"横着过去、没有升"。
##
## 根因不在画法，在**相机取景**：太阳的周日轨迹（春分＝赤道）那个平面跟视轴的关系决定画上
## 的形状。开场把视轴抬到天顶之后，赤道面与视轴成 50 度，整条轨迹在本图里就是**半径 50 度
## 的那个圆**（`50 * px per degree` = 655 px），所以它自己就走成一个圈——"爬"这件事在图上
## 是**太阳的高度**，跟着太阳转机位时画上的 y 差就是高度差（`.tmp/tests/sample.tscn` 出图
## 量到春分 118 px、夏至 438 px）。
func _the_suns_day() -> void:
	var names := {
		"fisheye": SkyProjection.Map.FISHEYE,
		"lens": SkyProjection.Map.LENS,
		"pan": SkyProjection.Map.PAN,
		"cylinder": SkyProjection.Map.CYLINDER,
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
	SkyProjection.map = SkyProjection.Map.FISHEYE
	for line in lines:
		print("       %s" % line)
	check("the Sun's day: a line through the camera's own lens, a climb on the map that puts the altitude on the frame",
			ratios["lens"] < 0.05 and ratios["cylinder"] > 0.15,
			"climb/sweep with the camera held at the opening: fisheye %.2f, lens %.2f, pan %.2f, cylinder %.2f (春分 the Sun's daily circle *is* the equator - a great circle through the eye, so the camera's own lens draws it as a line; the fisheye's shape depends on where its axis points relative to that circle, which is why the two ends of the family are asserted here and the fisheye's own number is printed)"
			% [ratios["fisheye"], ratios["lens"], ratios["pan"], ratios["cylinder"]])


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


## The sky direction the pan grid has drawn at a pixel: the map read backwards, which is
## what lets a grid be laid over the frame instead of over the world.
func _frame_direction(camera: Camera3D, pixel: Vector2, size: Vector2) -> Vector3:
	var half := CameraRig.OPENING_FOV * 0.5
	return _local(camera, (pixel.x - size.x * 0.5) / (size.y * 0.5) * half,
			-(pixel.y - size.y * 0.5) / (size.y * 0.5) * half)


## The sky direction the fisheye has drawn at a pixel - its own inverse, written out here
## rather than called, so the round trips are not the same code twice: the pixel's
## distance from the middle is the angle off the axis at the map's own scale, and its
## direction from the middle is the roll about the axis.
func _fisheye_direction(camera: Camera3D, pixel: Vector2, size: Vector2) -> Vector3:
	var offset := pixel - size * 0.5
	var off_axis := offset.length() / (size.y * 0.5) * SkyProjection.half_angle(camera)
	var roll := atan2(offset.x, -offset.y)
	return camera.global_transform.basis * Vector3(sin(off_axis) * sin(roll),
			sin(off_axis) * cos(roll), -cos(off_axis))


## The sky direction the lens itself has drawn at a pixel - the frame's own corner is
## 71 degrees off its axis where the fisheye's is 112, and both have to be measured where
## they draw. Out of the perspective divide: a pixel's tangent plane is
## (ndc.x * tan(half) * aspect, ndc.y * tan(half), -1).
func _lens_direction(camera: Camera3D, pixel: Vector2, size: Vector2) -> Vector3:
	var half := SkyProjection.half_angle(camera)
	var ndc := Vector2(pixel.x / size.x * 2.0 - 1.0, 1.0 - pixel.y / size.y * 2.0)
	var tangent := Vector3(ndc.x * tan(half) * (size.x / size.y), ndc.y * tan(half),
			-1.0)
	return (camera.global_transform.basis * tangent).normalized()


func _world(azimuth: float, altitude: float) -> Vector3:
	return Astro.horizon_direction(azimuth, altitude) * RADIUS


## Pixels one degree of sky covers at the middle of the frame: the map's own scale, and
## the number every figure above is stated in.
func _px_per_deg() -> float:
	return FRAME.y * 0.5 / (CameraRig.OPENING_FOV * 0.5)


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
## the sky round there; 1.571 is what the fisheye does at the horizon and what the
## pan-and-tilt grid does at the top and bottom of the frame; 9.5 is the lens at the
## corners of the frame it is pointed at.
##
## The two steps are an orthonormal pair of tangents at the direction - any pair, since
## only the magnitudes of the two scales are read off them - built from the direction
## itself rather than from its azimuth and altitude: at the pole (the view axis, at this
## opening) the azimuth has no direction of its own, and a basis built out of it collapses
## there. The steps are a quarter of a degree rather than a hundredth: at the pole the map
## turns the *arccosine* of the direction's z into a radius, and a hair-thin step off the
## pole is arithmetically zero in float32 (cos of it rounds to 1.0, the radius to 0.0, and
## the whole Jacobian to nothing - measured: the frame's middle pixel came out as a
## singular 0, and every number downstream of it as infinite).
func _singular(screen_point: Callable, direction: Vector3) -> Vector2:
	const STEP := deg_to_rad(0.25)
	var here := direction.normalized()
	var across := Vector3.UP.cross(here)
	if across.length() < 1.0e-4:
		across = Vector3.FORWARD.cross(here)
	across = across.normalized()
	var rise := here.cross(across).normalized()
	var at: Vector2 = screen_point.call(here * RADIUS)
	var stepped: Vector2 = screen_point.call((here + across * STEP).normalized() * RADIUS)
	var rised: Vector2 = screen_point.call((here + rise * STEP).normalized() * RADIUS)
	var along := (stepped - at) / STEP
	var up := (rised - at) / STEP
	var a := along.x
	var b := up.x
	var c := along.y
	var d := up.y
	var trace := a * a + b * b + c * c + d * d
	var determinant := (a * d - b * c) * (a * d - b * c)
	var spread := sqrt(maxf(trace * trace - 4.0 * determinant, 0.0))
	return Vector2(sqrt(0.5 * (trace + spread)), sqrt(0.5 * (trace - spread)))


## The row the horizon crosses a given column at. The horizon is not a function of the
## frame's x on any of the maps - it is a curve - so it is walked in bearing until the
## map's own x reaches the column: bearings west of the view's own raise x, east lower it.
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
