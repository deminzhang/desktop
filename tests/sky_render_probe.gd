## Acceptance probe for the sky as it is actually drawn (计划 §6.5 S4, §8 A4/A5):
## reads the PNG a --shot run left behind and checks what is in it against what
## astro.gd says should be, through the same camera the run was given.
##
## A shot first, then the probe:
##
##   tools/godot_console.exe --path . --background=sky --wallpaper=0 --hud=0 \
##       --sky-time=2026-09-29T04:00:00 --sky-rate=0 --sky-fov=20 \
##       --sky-view=180,48 --shot=shots/s4_day.png --shot-frames=30
##   tools/godot_console.exe --headless --path . \
##       --script res://tests/sky_render_probe.gd -- --image=shots/s4_day.png \
##       --sky-time=2026-09-29T04:00:00 --sky-fov=20 --sky-view=180,48 \
##       --body=sun --expect=day
##
## --predict prints where the Sun and the Moon are for an instant and a view and
## reads no image at all: that is how a view for a shot is chosen in the first
## place.
##
## Headless is fine here: it only reads a PNG (计划 §2.3 G17 is about reading
## meshes back from the dummy renderer). The tolerances are wide on purpose - a
## drawn edge, a threshold and a half-saturated disc are all worth a pixel or two.
extends SceneTree

const LATITUDE := 39.9042
const LONGITUDE := 116.4074
## The Sun's glow is read this far from the Sun when the sky's own colour is
## measured: the halo would otherwise answer for the sky.
const GLOW_EXCLUSION := 15.0
## How far the drawn bright limb, and the terminator, may sit from where the
## ephemeris puts them, as a fraction of the disc's radius.
const LIMB_TOLERANCE := 0.30
const TERMINATOR_TOLERANCE := 0.35

var _failures := 0
var _done := false

var _pixels: PackedByteArray
var _size := Vector2.ZERO
var _forward := Vector3.FORWARD
var _up := Vector3.UP
var _right := Vector3.RIGHT
var _focal := 0.0


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var opts := Args.parse(OS.get_cmdline_user_args())
	if opts.flag("predict", false):
		_predict(opts)
		quit(0)
		return true
	_run(opts)
	print("XuanDesk: sky render probe %s (%d failure%s)"
			% ["OK" if _failures == 0 else "FAILED", _failures,
					"" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)
	return true


## Where the Sun and the Moon are, for choosing the view of a shot.
func _predict(opts: Args) -> void:
	var jd_ut := Astro.julian_day_from_unix(
			Time.get_unix_time_from_datetime_string(opts.text("sky_time", "")))
	var jd := Astro.tt_from_ut(jd_ut)
	var lst := Astro.lst_deg(jd_ut, LONGITUDE)
	var sun := Astro.sun_position(jd)
	var moon := Astro.moon_state(jd)
	var sun_place := Astro.altaz(sun.x, sun.y, lst, LATITUDE)
	var moon_place := Astro.altaz(moon.ra, moon.dec, lst, LATITUDE)
	print("XuanDesk: %s: Sun alt %.3f az %.3f | Moon alt %.3f az %.3f, radius %.4f deg, %s, %.1f%% lit"
			% [opts.text("sky_time", ""), sun_place.x, sun_place.y, moon_place.x,
					moon_place.y, moon.radius_deg,
					Astro.moon_phase_name(moon.elongation_deg), moon.illuminated * 100.0])


func _run(opts: Args) -> void:
	# the projection: the same camera_rig basis, and a pinhole in front of it
	var bearing := opts.text("sky_view", "180,6").split(",", false)
	var azimuth := float(bearing[0]) if bearing.size() == 2 else 180.0
	var altitude := float(bearing[1]) if bearing.size() == 2 else 6.0
	var fov := opts.num("sky_fov", 60.0)
	_forward = Astro.horizon_direction(azimuth, altitude)
	_up = Astro.horizon_up(azimuth, altitude)
	_right = _up.cross(-_forward)

	var image := Image.load_from_file(opts.text("image", ""))
	if image == null:
		_check(false, "the shot", "cannot read %s" % opts.text("image", ""))
		return
	image.convert(Image.FORMAT_RGBA8)
	_pixels = image.get_data()
	_size = Vector2(image.get_width(), image.get_height())
	_focal = _size.y * 0.5 / tan(deg_to_rad(fov) * 0.5)

	var jd_ut := Astro.julian_day_from_unix(
			Time.get_unix_time_from_datetime_string(opts.text("sky_time", "")))
	var jd := Astro.tt_from_ut(jd_ut)
	var lst := Astro.lst_deg(jd_ut, LONGITUDE)
	var sun_position := Astro.sun_position(jd)
	var moon := Astro.moon_state(jd)
	var sun_place := Astro.altaz(sun_position.x, sun_position.y, lst, LATITUDE)
	var moon_place := Astro.altaz(moon.ra, moon.dec, lst, LATITUDE)
	var sun_world := Astro.horizon_direction(sun_place.y, sun_place.x)
	var moon_world := Astro.horizon_direction(moon_place.y, moon_place.x)

	print("XuanDesk: %s %dx%d, view az %.1f alt %.1f fov %.1f, focal %.1f px, Sun alt %.1f, Moon alt %.1f"
			% [opts.text("image", ""), int(_size.x), int(_size.y), azimuth, altitude,
					fov, _focal, sun_place.x, moon_place.x])

	var seen := _sky_and_ground(sun_world)
	if int(seen["sky_pixels"]) == 0:
		print("XuanDesk: the frame is inside the Sun's glare, so no sky was read")
	else:
		var stars := _count_stars(seen["sky"], sun_world)
		print("XuanDesk: sky luminance %.3f (%.3f below the horizon), %d star points"
				% [seen["sky"], seen["ground"], stars])
		match opts.text("expect", ""):
			"day":
				_check(seen["sky"] > 0.30, "the sky is lit by day",
						"luminance %.3f" % seen["sky"])
				_check(stars < 10, "no stars left in daylight", "%d points" % stars)
			"night":
				_check(seen["sky"] < 0.12, "the sky is dark by night",
						"luminance %.3f" % seen["sky"])
				_check(stars > 50, "stars in the night sky", "%d points" % stars)

	match opts.text("body", ""):
		"sun":
			_check_sun(opts.text("image", ""), sun_world, jd)
		"moon":
			_check_moon(moon_world, sun_world, moon)


## The Sun: drawn where the ephemeris puts it, at the size of its own disc, with
## the glow around it and the disc clipped by the horizon when it is down.
func _check_sun(label: String, world: Vector3, jd: float) -> void:
	var centre := _project(world)
	if centre.x < 0.0:
		_check(false, "the Sun is in the frame", "not in view")
		return
	var radius := _focal * tan(asin(SkySun.SUN_RADIUS_KM
			/ (Astro.sun_radius_au(jd) * SkySun.AU_KM)))
	var peak := _peak(centre, 3.0 * radius)
	# the disc's core is the only part of this that saturates - the glow around it
	# is a gradient over the sky - so what is left at the top of the range is the
	# disc. The bloom smears that edge by some pixels, which is why the tolerance
	# below is a fraction of the radius and why a shot to measure this uses a
	# narrow field: the same smear is a smaller share of a bigger disc.
	var blob := _blob(centre, radius * 6.0, 0.99)
	var measured := sqrt(float(blob.count) / PI)
	_check(peak > 0.95, "the Sun's disc is bright enough to bloom", "peak %.3f" % peak)
	_check(blob.count > 0 and absf(measured - radius) < 0.5 * radius,
			"the Sun's disc is the size the ephemeris gives it",
			"%.1f px drawn for %.1f computed (%.4f deg)" % [measured, radius,
					rad_to_deg(atan(radius / _focal))])
	_check(blob.centre.distance_to(centre) < 6.0,
			"the Sun is drawn where the ephemeris puts it",
			"centre %.2f px off" % blob.centre.distance_to(centre))
	# the glow, over and above the sky it is painted on, read at ring distances
	# that scale with the disc so a narrow field reads the same shape
	var background := _ring_mean(centre, 12.0 * radius, 13.0 * radius)
	var halos: Array[float] = [_ring_mean(centre, 2.0 * radius, 2.2 * radius),
			_ring_mean(centre, 4.0 * radius, 4.2 * radius),
			_ring_mean(centre, 7.0 * radius, 7.2 * radius),
			_ring_mean(centre, 11.0 * radius, 11.2 * radius)]
	var glow: Array[float] = []
	for value in halos:
		glow.append(maxf(value - background, 0.0))
	var falling: bool = glow[0] > glow[1] and glow[1] > glow[2] \
			and glow[2] > glow[3]
	_check(falling and glow[0] > 0.05 and glow[3] < 0.25 * glow[0],
			"%s: the glow falls away from the disc" % label,
			"%.3f, %.3f, %.3f, %.3f over the sky's %.3f at 65/135/225/295 px"
					% [glow[0], glow[1], glow[2], glow[3], background])


## The Moon: the lit limb at the ephemeris radius on the Sun's side, the limb away
## from the Sun dark, and the terminator where the phase angle puts it. All three
## are read in the frame of the predicted centre, along the direction to the Sun.
func _check_moon(world: Vector3, sun_world: Vector3, moon: Astro.MoonState) -> void:
	var centre := _project(world)
	if centre.x < 0.0:
		_check(false, "the Moon is in the frame", "not in view")
		return
	# the Sun's own direction in the image: the Moon's direction nudged towards it
	# and projected, so an off-frame Sun is no obstacle
	var toward := (world + (sun_world - world.dot(sun_world) * world) * 0.02).normalized()
	var sun_pixel := _project(toward)
	if sun_pixel.x < 0.0:
		_check(false, "a direction towards the Sun", "behind the camera")
		return
	var axis := (sun_pixel - centre).normalized()
	var across := Vector2(-axis.y, axis.x)
	var radius := _focal * tan(deg_to_rad(moon.radius_deg))
	var background := _ring_mean(centre, 2.2 * radius, 3.0 * radius)
	var threshold := background + 0.06

	# the lit pixels in the Moon's neighbourhood, and then only the largest group
	# of them that touch: a star in the field is a dot, the Moon's lit part is a
	# shape, and a dot must not answer for the crescent's tip
	var pixels := {}
	for y in range(int(centre.y - 2.0 * radius), int(centre.y + 2.0 * radius) + 1):
		for x in range(int(centre.x - 2.0 * radius), int(centre.x + 2.0 * radius) + 1):
			if _luminance(x, y) > threshold:
				pixels[Vector2i(x, y)] = true
	var lit := _largest_cluster(pixels)
	var along_min := 1.0e9
	var along_max := -1.0e9
	var across_min := 1.0e9
	var across_max := -1.0e9
	for pixel in lit:
		var offset := Vector2(pixel) - centre
		var a := offset.dot(axis)
		var b := offset.dot(across)
		along_min = minf(along_min, a)
		along_max = maxf(along_max, a)
		across_min = minf(across_min, b)
		across_max = maxf(across_max, b)

	var lit_fraction := float(lit.size()) / (PI * radius * radius)
	_check(lit.size() > 0, "the Moon is drawn, and lit",
			"%d lit pixels of %.1f px radius" % [lit.size(), radius])
	if lit.is_empty():
		return
	_check(absf(along_max - radius) < LIMB_TOLERANCE * radius,
			"the bright limb is at the ephemeris radius, on the Sun's side",
			"%.1f px out of %.1f" % [along_max, radius])
	# the terminator: at each height across the Sun's line, the lit part starts at
	# cos(elongation) * sqrt(r^2 - y^2) from the centre - the ellipse a sphere's
	# shadow edge projects to. That one law is the whole phase: full moon puts it
	# on the far limb, new moon on the near one, and half way through between the
	# quarters it crosses the middle. Reading it at one height only would be wrong
	# at the horns, which run out along the limb whatever the phase.
	var cos_elongation := cos(deg_to_rad(moon.elongation_deg))
	var worst_terminator := 0.0
	var heights := 0
	for fraction in [0.0, 0.5, -0.5]:
		var height: float = float(fraction) * radius
		var edge := 1.0e9
		for pixel in lit:
			var offset := Vector2(pixel) - centre
			if absf(offset.dot(across) - height) > 2.0:
				continue
			edge = minf(edge, offset.dot(axis))
		if edge > 1.0e8:
			continue
		var wanted := cos_elongation * sqrt(maxf(radius * radius - height * height, 0.0))
		worst_terminator = maxf(worst_terminator, absf(edge - wanted))
		heights += 1
	_check(heights > 0 and worst_terminator < TERMINATOR_TOLERANCE * radius,
			"the terminator is the ellipse the phase projects to",
			"worst %.1f px of %.1f at %d heights across the disc (elongation %.1f deg)"
					% [worst_terminator, radius, heights, moon.elongation_deg])
	_check(absf(across_min + across_max) < 0.4 * radius,
			"the lit part is centred across the Sun's line",
			"%.1f and %.1f px" % [across_min, across_max])
	# the side away from the Sun: read in the middle of it. On a gibbous Moon that
	# lune is a sliver too thin to sample - the phase's geometry above is what
	# carries those - so this is the crescent's own check.
	var dark := along_min + radius
	if dark > 0.25 * radius:
		var middle := centre + axis * (along_min - radius) * 0.5
		var value := _luminance(int(middle.x), int(middle.y))
		_check(value < threshold, "the side away from the Sun is dark",
				"%.3f against the sky's %.3f, %.1f px of dark side"
						% [value, background, dark])
	else:
		print("XuanDesk: the dark side is %.1f px wide, too thin to read" % dark)
	print("XuanDesk: Moon lit fraction drawn %.3f, ephemeris %.3f"
			% [lit_fraction, moon.illuminated])


# ------------------------------------------------------------------ readings

## The mean luminance above and below the horizon, away from the Sun's glow, and
## how many sky pixels were seen at all - a narrow field aimed at the Sun has
## none of them.
func _sky_and_ground(sun_world: Vector3) -> Dictionary:
	var sky := 0.0
	var sky_count := 0
	var ground := 0.0
	var ground_count := 0
	for y in range(2, int(_size.y), 4):
		for x in range(2, int(_size.x), 4):
			var direction := _ray(Vector2(x, y))
			if direction.angle_to(sun_world) < deg_to_rad(GLOW_EXCLUSION):
				continue
			var value := _luminance(x, y)
			if direction.y > 0.0:
				sky += value
				sky_count += 1
			else:
				ground += value
				ground_count += 1
	return {"sky": sky / maxf(sky_count, 1.0), "sky_pixels": sky_count,
			"ground": ground / maxf(ground_count, 1.0)}


## Points in the sky that stand above their own neighbourhood: the stars.
func _count_stars(sky: float, sun_world: Vector3) -> int:
	var found := 0
	for y in range(3, int(_size.y) - 3, 2):
		for x in range(3, int(_size.x) - 3, 2):
			var direction := _ray(Vector2(x, y))
			if direction.y <= 0.0 or direction.angle_to(sun_world) < deg_to_rad(GLOW_EXCLUSION):
				continue
			var value := _luminance(x, y)
			if value < sky + 0.12:
				continue
			if value > _luminance(x - 3, y) and value > _luminance(x + 3, y) \
					and value > _luminance(x, y - 3) and value > _luminance(x, y + 3):
				found += 1
	return found


## The largest group of lit pixels that touch each other. A star is a handful of
## pixels; the Moon's lit part is a shape, and only a shape is worth measuring.
func _largest_cluster(pixels: Dictionary) -> Array:
	var seen := {}
	var best: Array = []
	var queue: Array = []
	for start in pixels:
		if seen.has(start):
			continue
		seen[start] = true
		queue.clear()
		queue.append(start)
		var cluster: Array = []
		while not queue.is_empty():
			var at: Vector2i = queue.pop_back()
			cluster.append(at)
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
					Vector2i(0, -1)]:
				var next: Vector2i = at + step
				if pixels.has(next) and not seen.has(next):
					seen[next] = true
					queue.append(next)
		if cluster.size() > best.size():
			best = cluster
	return best


func _peak(centre: Vector2, radius: float) -> float:
	var peak := 0.0
	for y in range(int(centre.y - radius), int(centre.y + radius) + 1):
		for x in range(int(centre.x - radius), int(centre.x + radius) + 1):
			peak = maxf(peak, _luminance(x, y))
	return peak


## The centroid and the count of the pixels above `threshold`, over a box of
## `radius` around `centre`, and never more than `reach` from it.
func _blob(centre: Vector2, radius: float, threshold: float, reach := 0.0) -> Dictionary:
	var sum := Vector2.ZERO
	var count := 0
	for y in range(int(centre.y - radius), int(centre.y + radius) + 1):
		for x in range(int(centre.x - radius), int(centre.x + radius) + 1):
			var at := Vector2(x, y)
			if reach > 0.0 and at.distance_to(centre) > reach:
				continue
			if _luminance(x, y) <= threshold:
				continue
			sum += at
			count += 1
	return {"centre": sum / maxf(float(count), 1.0), "count": count}


func _ring_mean(centre: Vector2, inner: float, outer: float) -> float:
	var sum := 0.0
	var count := 0
	for i in 128:
		var angle := TAU * float(i) / 128.0
		var radius := (inner + outer) * 0.5
		var at := centre + Vector2(cos(angle), sin(angle)) * radius
		if at.x < 0.0 or at.y < 0.0 or at.x >= _size.x or at.y >= _size.y:
			continue
		sum += _luminance(int(at.x), int(at.y))
		count += 1
	return sum / maxf(float(count), 1.0)


func _luminance(x: int, y: int) -> float:
	var at := (y * int(_size.x) + x) * 4
	return (0.299 * _pixels[at] + 0.587 * _pixels[at + 1] + 0.114 * _pixels[at + 2]) \
			/ 255.0


## Where a sky direction lands in the frame, or (-1, -1) behind the camera.
func _project(world: Vector3) -> Vector2:
	var depth := world.dot(_forward)
	if depth <= 0.0:
		return Vector2(-1.0, -1.0)
	return Vector2(_size.x * 0.5 + _focal * world.dot(_right) / depth,
			_size.y * 0.5 - _focal * world.dot(_up) / depth)


## The inverse: the sky direction a pixel looks along.
func _ray(at: Vector2) -> Vector3:
	return (_forward + _right * ((at.x - _size.x * 0.5) / _focal)
			+ _up * ((_size.y * 0.5 - at.y) / _focal)).normalized()


func _check(ok: bool, label: String, detail: String) -> void:
	if not ok:
		_failures += 1
	print("%s %-52s %s" % ["pass" if ok else "FAIL", label, detail])
