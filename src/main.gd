## Entry point.
##
## Owns the two OS windows — the wallpaper (this scene's root viewport, later
## reparented into the desktop WorkerW layer by the native host) and the
## floating HUD — plus the metrics client that feeds the HUD.
##
## Dev switches (everything after `--` on the command line):
##   --shot=<png>            render N frames, save the wallpaper viewport, quit
##   --shot-target=hud|main  which window to capture (default main)
##   --shot-frames=<n>       frames to settle before capturing (default 90)
##   --wallpaper=0|1         parent into WorkerW (default 1)
##   --hud=0|1               create the floating HUD (default 1)
##   --fps=<n>               frame cap (default 60)
##   --interval=<ms>         metric sample period (default 1000)
##   --exit-after=<seconds>  quit after N seconds
extends Node

var opts: Dictionary = {}
var aquarium: Aquarium
var hud_window: HudWindow
var metrics: MetricsClient

var _shot := false


func _ready() -> void:
	opts = _parse_args()
	_shot = opts.has("shot")
	_setup_wallpaper_window()

	var build_t0 := Time.get_ticks_msec()
	aquarium = Aquarium.new()
	aquarium.name = "Aquarium"
	add_child(aquarium)
	print("XuanDesk: aquarium built in %d ms" % (Time.get_ticks_msec() - build_t0))
	_add_vignette()

	if _flag("hud", true):
		hud_window = HudWindow.new()
		hud_window.name = "HudWindow"
		add_child(hud_window)
		hud_window.quit_requested.connect(_quit)

	metrics = MetricsClient.new()
	metrics.name = "Metrics"
	add_child(metrics)
	if hud_window != null:
		hud_window.attach(metrics)
	metrics.start({
		"wallpaper": _flag("wallpaper", not _shot),
		"no_activate": _flag("no_activate", true),
		"interval": int(_num("interval", 1000.0)),
	})

	if opts.has("exit_after"):
		_timed_quit(_num("exit_after", 0.0))
	if _shot:
		_capture()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# A wallpaper is not a document: stray WM_CLOSE (shell housekeeping, a
		# second host instance) must not take it down. Quit is explicit only -
		# the HUD quit button, Ctrl+Alt+Q, or --exit-after.
		print("XuanDesk: ignoring close request (use Ctrl+Alt+Q or the HUD quit button)")
	elif what == NOTIFICATION_PREDELETE:
		if metrics != null:
			metrics.stop()


func _quit() -> void:
	print("XuanDesk: shutting down")
	if metrics != null:
		metrics.stop()
	get_tree().quit()


func _parse_args() -> Dictionary:
	var out := {}
	for raw in OS.get_cmdline_user_args():
		var s := String(raw)
		if not s.begins_with("--"):
			continue
		s = s.substr(2)
		var eq := s.find("=")
		if eq < 0:
			out[s] = true
		else:
			out[s.substr(0, eq)] = s.substr(eq + 1)
	return out


func _flag(key: String, fallback: bool) -> bool:
	if not opts.has(key):
		return fallback
	var v: Variant = opts[key]
	if v is bool:
		return v
	var s := String(v).to_lower()
	return s != "0" and s != "false" and s != "no"


func _num(key: String, fallback: float) -> float:
	if not opts.has(key):
		return fallback
	return float(opts[key])


func _setup_wallpaper_window() -> void:
	var screen := DisplayServer.get_primary_screen()
	var rect := DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	# the Window node re-applies its own title, so set the property, not just the server
	get_window().title = MetricsClient.WALLPAPER_TITLE
	DisplayServer.window_set_title(MetricsClient.WALLPAPER_TITLE)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = int(_num("fps", 60.0))

	# the wallpaper covers the whole primary monitor, not just the work area
	var full := DisplayServer.screen_get_size(screen)
	var origin := DisplayServer.screen_get_position(screen)
	var win := get_window()
	win.size = full
	win.position = origin
	DisplayServer.window_set_size(full)
	DisplayServer.window_set_position(origin)
	if rect.size.x < full.x or rect.size.y < full.y:
		# keep the window inside the visible screen; the host resizes it later
		win.size = full


func _add_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Vignette"
	layer.layer = 10
	var rect := ColorRect.new()
	rect.name = "Overlay"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vignette.gdshader")
	rect.material = mat
	layer.add_child(rect)
	add_child(layer)


func _timed_quit(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.1)).timeout
	_quit()


func _capture() -> void:
	var frames := int(_num("shot_frames", 90.0))
	for i in maxi(frames, 1):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var target := String(opts.get("shot_target", "main"))
	var viewport: Viewport = get_viewport()
	if target == "hud" and hud_window != null:
		viewport = hud_window.get_viewport()
	var image := viewport.get_texture().get_image()
	var path := String(opts["shot"])
	if not path.is_absolute_path():
		path = ProjectSettings.globalize_path("res://").path_join(path)
	var err := image.save_png(path)
	print("XuanDesk: shot %s -> %s (%dx%d, err=%d)" % [target, path,
			image.get_width(), image.get_height(), err])
	_quit()
