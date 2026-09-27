## Entry point: the desktop shell.
##
## Owns the two OS windows - the wallpaper (this scene's root viewport, later
## reparented into the desktop's WorkerW layer by bin/host.exe) and the floating
## HUD - plus the metric stream and the background registry that fills them.
## Everything specific to a background lives behind shell/background.gd.
##
## It also owns the one switch that is about the desktop layer itself rather than
## about what is drawn in it: show/hide the 3D desktop (`_toggle_desktop`), which
## the HUD's 桌面 button and the host's Ctrl+Alt+H both ask for.
##
## Dev switches: see shell/args.gd.
extends Node

const FADE_SEC := 0.12  ## per half of a background switch

var opts: Args
var hud_window: HudWindow
var menu_window: HudMenu
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
## Whether the 3D desktop (the wallpaper window) is shown. bin/host.exe owns the
## window and holds the same flag, so this only ever changes through
## _toggle_desktop(); it starts shown, which is what the host assumes until it is
## told otherwise.
var _desktop_shown := true
## Which monitor the wallpaper window is on (2026-10-10): an index into the host's
## own list (0 = the primary), which the HUD menu shows as 主屏/副屏 N. Like
## _desktop_shown this is the client's state and the host is told about it - the
## list itself, and the geometry, are the host's.
var _desktop_screen := 0
var _screens_seen := ""


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
		hud_window.attach(metrics)

		# The menu is a window of the shell's own, not a child of the HUD window: a
		# Window nested inside another Window draws its first frame and then never
		# draws again - a panel opened under the pointer would never appear (计划 §2.3
		# G30). The HUD only glues it to its corner and reads 穿透 off it.
		menu_window = HudMenu.new()
		menu_window.name = "Menu"
		add_child(menu_window)
		menu_window.background_selected.connect(_on_background_selected)
		menu_window.desktop_toggle_requested.connect(_toggle_desktop)
		menu_window.quit_requested.connect(_quit)
		menu_window.passthrough_toggled.connect(hud_window.toggle_passthrough)
		menu_window.switch_toggled.connect(_on_menu_switch)
		menu_window.screen_selected.connect(_on_screen_selected)
		hud_window.set_menu(menu_window)
	metrics.host_event.connect(_on_host_event)
	metrics.online_changed.connect(_on_host_online)
	metrics.frame_received.connect(_on_frame)

	# the dev switch (计划 §8: --desktop-screen=<n>): the same request the 菜单's
	# 显示器 row sends, so a run can be put on the second monitor without a click
	_desktop_screen = int(opts.num("desktop_screen", 0.0))

	metrics.start({
		"wallpaper": opts.flag("wallpaper", not _shot),
		"no_activate": opts.flag("no_activate", true),
		"interval": int(opts.num("interval", 1000.0)),
	})

	_switch(opts.text("background", Backgrounds.default_id()), false)

	# the menu is opened by a click in real use; this is for photographs of it
	if opts.flag("menu", false) and menu_window != null:
		menu_window.open_panel()

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


## One of the live background's own 菜单 switches (Background.menu_switches). The
## shell holds none of that state - the switch belongs to the background, and the
## menu is only where its row is.
func _on_menu_switch(id: String, on: bool) -> void:
	if _background != null:
		_background.set_menu_switch(id, on)


## The 菜单's 显示器 row (2026-10-10): the host moves the wallpaper window to the
## monitor with this index and resizes it to that monitor, so the 3D desktop fills
## that screen and the primary goes back to the system's own wallpaper.
##
## The move is a WM_SIZE on a window whose contents the host owns, and an on-demand
## background (the sky) draws one frame per change: without asking for that frame the
## window is resized and left holding the previous monitor's last frame - which on a
## resized swap chain is nothing at all, and the desktop looks like it lost the sky.
func _on_screen_selected(index: int) -> void:
	_desktop_screen = index
	metrics.set_screen(index)
	if _desktop_shown and _background != null:
		_background.request_redraw()
	print("XuanDesk: 3D desktop on screen %d" % index)


## Every metric frame carries the host's monitor list; the menu is the only thing
## that shows it, and it rebuilds its rows only when the list changed. The index it
## marks is the host's own - the host is where the window is, so if it clamped a
## request (a monitor went away between the click and the frame) the menu says so
## rather than repeating what was asked for.
func _on_frame(_data: Dictionary) -> void:
	if menu_window == null:
		return
	var list := metrics.screens()
	var key := "%s|%d" % [JSON.stringify(list), metrics.screen()]
	if key == _screens_seen:
		return
	_screens_seen = key
	menu_window.set_screens(list, metrics.screen())


# ------------------------------------------------------------- the 3D desktop

## Shows or hides the 3D desktop itself. The hide used to be the HUD's, which
## left the desktop layer with no switch of its own: the layer is the thing that
## goes missing when the shell repaints its own wallpaper, and hiding and showing
## it is also what puts a fresh frame back on screen (a mounted wallpaper window
## is only redrawn when something asks for it - 计划 §7).
func _toggle_desktop() -> void:
	_desktop_shown = not _desktop_shown
	metrics.send_command("wall %d" % (1 if _desktop_shown else 0))
	if _desktop_shown and _background != null:
		_background.request_redraw()
	print("XuanDesk: 3D desktop %s" % ("shown" if _desktop_shown else "hidden"))


## The host's own events. The HUD answers the two that are its own
## (HudWindow._on_host_event); the desktop one is the shell's, and it has to be
## answered with no HUD window around too.
func _on_host_event(name: String) -> void:
	if name == "toggle_desktop":
		_toggle_desktop()


## A respawned host starts out believing the desktop is shown (its flag is a
## fresh process'), so the switch is re-sent whenever the link comes up - the only
## state the two sides share that the client, not the host, owns.
func _on_host_online(is_online: bool) -> void:
	if is_online:
		metrics.send_command("wall %d" % (1 if _desktop_shown else 0))
		# and which monitor, for the same reason: a fresh host starts on the primary
		metrics.send_command("screen %d" % _desktop_screen)
		# a fresh host re-fits the window, so an on-demand background needs the frame
		# that shows it (the fit is a resize, exactly like the 显示器 row's move)
		if _desktop_shown and _background != null:
			_background.request_redraw()


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
	if menu_window != null:
		# after build(): the switch states are the background's own (计划 §6.4)
		menu_window.set_switches(next.menu_switches())

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
	elif target == "menu" and hud_window != null:
		viewport = hud_window.menu_window()
	await Shots.capture(viewport, opts.text("shot", "shot.png"),
			int(opts.num("shot_frames", 90.0)), target)
	_quit()
