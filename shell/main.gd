## Entry point: the desktop shell.
##
## Owns the two OS windows - the wallpaper (this scene's root viewport, later
## reparented into the desktop's WorkerW layer by bin/host.exe) and the floating
## HUD - plus the metric stream and the background registry that fills them.
## Everything specific to a background lives behind shell/background.gd.
##
## Dev switches: see shell/args.gd.
extends Node

const FADE_SEC := 0.12  ## per half of a background switch

var opts: Args
var hud_window: HudWindow
var metrics: MetricsClient

var _background: Background
var _current := ""
var _grade: ColorRect
var _vignette: ShaderMaterial
var _fade: ColorRect
var _switching := false
var _shot := false
var _fps := 60
var _policy := Background.Policy.CONTINUOUS


func _ready() -> void:
	opts = Args.parse(OS.get_cmdline_user_args())
	_shot = opts.has("shot")
	_fps = int(opts.num("fps", 60.0))
	WallpaperWindow.apply(get_window(), _fps)
	_build_overlay()

	metrics = MetricsClient.new()
	metrics.name = "Metrics"
	add_child(metrics)

	if opts.flag("hud", true):
		hud_window = HudWindow.new()
		hud_window.name = "HudWindow"
		add_child(hud_window)
		hud_window.quit_requested.connect(_quit)
		hud_window.background_selected.connect(_on_background_selected)
		hud_window.attach(metrics)

	metrics.start({
		"wallpaper": opts.flag("wallpaper", not _shot),
		"no_activate": opts.flag("no_activate", true),
		"interval": int(opts.num("interval", 1000.0)),
	})

	_switch(opts.text("background", Backgrounds.default_id()), false)

	if opts.has("exit_after"):
		_timed_quit(opts.num("exit_after", 0.0))
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


# ------------------------------------------------------------ background host

func _on_background_selected(id: String) -> void:
	_switch(id)


## Replaces the live background, fading through black so the viewport never
## shows the empty scene between teardown and build.
func _switch(id: String, animate := true) -> void:
	if _switching or id == _current:
		return
	_switching = true

	# The cross-fade needs frames, so the wallpaper keeps drawing for the whole
	# transition; the incoming policy is applied once it is over.
	RenderingServer.viewport_set_update_mode(get_viewport().get_viewport_rid(),
			RenderingServer.VIEWPORT_UPDATE_ALWAYS)

	if _background != null:
		if animate:
			await _fade_to(1.0)
		var previous := _background
		_background = null
		previous.teardown()
		await previous.tree_exited

	var next := Backgrounds.create(id)
	if next == null:
		_switching = false
		return
	var built_at := Time.get_ticks_msec()
	next.name = "Background"
	next.metrics = metrics
	next.opts = opts
	add_child(next)
	next.build(self)
	_background = next
	_current = id
	print("XuanDesk: background '%s' built in %d ms" % [id,
			Time.get_ticks_msec() - built_at])

	var grade := next.vignette_shader()
	_grade.visible = grade != null
	_vignette.shader = grade

	if hud_window != null:
		hud_window.set_current(id)
		hud_window.set_content(next.build_hud(), next.hud_size())

	if animate:
		await _fade_to(0.0)
	_apply_render_policy(next)
	_switching = false


## Applies a background's redraw policy to the wallpaper viewport.
##   CONTINUOUS keeps drawing at the frame cap - the aquarium's fish never stop.
##   ON_DEMAND draws one frame and then idles the GPU; the background asks for
##   the next one itself through Background.request_redraw() whenever its time or
##   observer changes.
## Only the wallpaper viewport is touched, so the HUD window keeps animating.
func _apply_render_policy(bg: Background) -> void:
	_policy = bg.render_policy()
	RenderingServer.viewport_set_update_mode(get_viewport().get_viewport_rid(),
			RenderingServer.VIEWPORT_UPDATE_ONCE if _policy == Background.Policy.ON_DEMAND
			else RenderingServer.VIEWPORT_UPDATE_ALWAYS)


## Full-screen cover used to hide the frames where no background is in the tree,
## plus the current background's colour grade underneath it.
func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Overlay"
	layer.layer = 10
	add_child(layer)

	_grade = ColorRect.new()
	_grade.name = "Grade"
	_grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade.visible = false
	_vignette = ShaderMaterial.new()
	_grade.material = _vignette
	layer.add_child(_grade)

	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	layer.add_child(_fade)


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_SEC)
	await tween.finished


# ------------------------------------------------------------------- shutdown

func _quit() -> void:
	print("XuanDesk: shutting down")
	if metrics != null:
		metrics.stop()
	get_tree().quit()


func _timed_quit(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.1)).timeout
	_quit()


func _capture() -> void:
	var target := opts.text("shot_target", "main")
	var viewport: Viewport = get_viewport()
	if target == "hud" and hud_window != null:
		viewport = hud_window.get_viewport()
	await Shots.capture(viewport, opts.text("shot", "shot.png"),
			int(opts.num("shot_frames", 90.0)), target)
	_quit()
