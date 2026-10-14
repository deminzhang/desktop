## Entry point: the desktop shell.
##
## Owns the two OS windows - the wallpaper (this scene's root viewport, later
## reparented into the desktop's WorkerW layer by bin/host.exe) and the floating
## HUD - plus the metric stream and the background registry that fills them.
## Everything specific to a background lives behind shell/background.gd.
##
## It also owns the two switches that are about the desktop layer and the panel rather
## than about what is drawn in either: show/hide the 3D desktop (`_toggle_desktop`),
## which the tray's 桌面 row and the host's Ctrl+Alt+H both ask for, and show/hide the
## panel (`_toggle_panel`) - the HUD window, which is the 罗盘 and the status readings
## in the screen's top-right corner, and which the tray's 面板 row asks for.
##
## The 菜单 is the host's notification-area icon since 2026-10-13 (native/host.c's
## tray block): Windows draws that popup, so this side's part is the *model* - which
## background is live, which monitors there are, whether 穿透 is locked - pushed as
## `menu ...` lines whenever one of those changes (_push_tray_model), and the rows
## come back as host events ("menu background sky", "menu screen 1").
##
## Dev switches: see shell/args.gd.
extends Node

const FADE_SEC := 0.12  ## per half of a background switch

var opts: Args
var hud_window: HudWindow
var metrics: MetricsClient

var _background: Background
var _current := ""
## Whether the panel - the HUD window, the 罗盘 and the status readings with it - is on
## screen. bin/host.exe owns that window and holds the same flag, so this only ever
## changes through _toggle_panel(); unlike _desktop_shown it has no hotkey - the tray's
## 面板 row is its one seat (用户 2026-10-15).
var _panel_shown := true
var _wallpaper := true
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
## own list (0 = the primary), which the tray shows as 主屏/副屏 N. Like
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
		# 穿透 is this window's flag and the tray is the shell's: keep the row's tick
		# in step with whatever turned it over - the tray itself, or Ctrl+Alt+T
		hud_window.passthrough_changed.connect(_on_passthrough_changed)
		hud_window.attach(metrics)
	metrics.host_event.connect(_on_host_event)
	metrics.online_changed.connect(_on_host_online)
	metrics.frame_received.connect(_on_frame)

	# the dev switch (README「命令行参数（`--` 之后为用户参数）」: --desktop-screen=<n>): the same request
	# the tray's 显示器 row sends, so a run can be put on the second monitor without a click
	_desktop_screen = int(opts.num("desktop_screen", 0.0))
	_wallpaper = opts.flag("wallpaper", not _shot)
	metrics.start({
		"wallpaper": _wallpaper,
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
		# the tray's 退出 row, Ctrl+Alt+Q, or --exit-after.
		print("XuanDesk: ignoring close request (use Ctrl+Alt+Q or the tray's 退出 row)")
	elif what == NOTIFICATION_PREDELETE:
		if metrics != null:
			metrics.stop()


# ------------------------------------------------------------ background host

func _on_background_selected(id: String) -> void:
	_switch(id)


## The tray's 显示器 row (2026-10-10): the host moves the wallpaper window to the
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


## The shell's own 穿透 bookkeeping: the HUD window has turned itself over, and the
## tray's row has to say the same thing. The window style that actually passes the
## mouse through is the host's (it owns the HUD's window styles), so the flag goes
## over the same socket the other switches use.
func _on_passthrough_changed(locked: bool) -> void:
	metrics.send_command("lock %d" % (1 if locked else 0))
	_push_tray_model()


## Every metric frame carries the host's monitor list; the tray is the only thing that
## shows it, and the model goes out only when the list changed. The index it marks is
## the host's own - the host is where the window is, so if it clamped a request (a
## monitor went away between the click and the frame) the tray says so rather than
## repeating what was asked for.
func _on_frame(_data: Dictionary) -> void:
	var list := metrics.screens()
	var key := "%s|%d" % [JSON.stringify(list), metrics.screen()]
	if key == _screens_seen:
		return
	_screens_seen = key
	_push_tray_model()


# ------------------------------------------------------------------- the tray

## The tray's model, pushed whole whenever anything in it changes (2026-10-13). The
## tray is drawn natively by bin/host.exe, so what crosses the wire is text: the rows
## it should offer, their labels and which ones are ticked.
##
## Everything goes each time - `menu reset` and then every row - so there is no diff
## to get wrong; it is a few hundred bytes on loopback, and the host keeps the last
## model it was handed.
##
## The shape is the same one the old 菜单 panel had: the 换桌面 rows are the registry's
## order with the live one ticked, 显示器 is drawn only when there is a choice of
## monitor, 桌面 and 面板 are the two switches over the process's own two windows
## (2026-10-15), and 桌面 goes with the desktop layer itself - `--wallpaper=0` makes it a
## no-op, so the row goes too. 面板 exists only for a run that has a HUD window to show
## or hide at all (`--hud=0` has none).
func _push_tray_model() -> void:
	metrics.send_command("menu reset")
	var ids := Backgrounds.ids()
	for index in ids.size():
		var id := String(ids[index])
		metrics.send_command("menu bg %d %d %s %s" % [index,
				1 if id == _current else 0, id, Backgrounds.display_name(id)])
	var screens := metrics.screens()
	for index in screens.size():
		metrics.send_command("menu screen %d %d %s" % [index,
				1 if index == metrics.screen() else 0,
				_screen_label(index, screens[index])])
	metrics.send_command("menu desk %d" % (1 if _wallpaper else 0))
	metrics.send_command("menu panel %d" % (1 if hud_window != null else 0))
	metrics.send_command("menu locked %d" % (1 if _locked_now() else 0))


## 主屏 / 副屏 N and the resolution: enough to tell two identical monitors apart is
## the geometry the host reported, which is what "at 2560,0" says. Moved here with
## the tray (it was HudMenu._screen_label).
static func _screen_label(index: int, entry: Dictionary) -> String:
	var place := "主屏" if bool(entry.get("primary", false)) else "副屏 %d" % index
	return "%s %d×%d" % [place, int(entry.get("w", 0)), int(entry.get("h", 0))]


## 穿透 is the HUD window's flag - the flag the tray's row has to show. A run without
## a HUD (--hud=0) has no window to pass anything through, so it reads as off.
func _locked_now() -> bool:
	return hud_window != null and hud_window.is_locked()


# ------------------------------------------------------------- the 3D desktop

## Shows or hides the 3D desktop itself. The hide used to be the HUD's, which
## left the desktop layer with no switch of its own: the layer is the thing that
## goes missing when the shell repaints its own wallpaper, and hiding and showing
## it is also what puts a fresh frame back on screen (a mounted wallpaper window
## is only redrawn when something asks for it - README「性能与静默」).
func _toggle_desktop() -> void:
	_desktop_shown = not _desktop_shown
	metrics.send_command("wall %d" % (1 if _desktop_shown else 0))
	if _desktop_shown and _background != null:
		_background.request_redraw()
	print("XuanDesk: 3D desktop %s" % ("shown" if _desktop_shown else "hidden"))


## Shows or hides the panel: the HUD window itself, which is the 罗盘 and the status
## readings in the screen's top-right corner. Whether that window is *on the screen* is
## bin/host.exe's to set - it owns the window it stamps the topmost/tool/穿透 bits on
## (apply_one_overlay), and the window it looks for may not exist yet when the command
## arrives - so this flips the client's flag and sends the command, exactly as
## _toggle_desktop does. The tray's 面板 row is the switch's one seat (用户 2026-10-15);
## the row's tick is the host's own flag, which this command sets, so the model needs no
## re-push here.
func _toggle_panel() -> void:
	_panel_shown = not _panel_shown
	metrics.send_command("hud %d" % (1 if _panel_shown else 0))
	print("XuanDesk: panel %s" % ("shown" if _panel_shown else "hidden"))


## The host's own events. The HUD answers the two that are its own
## (HudWindow._on_host_event); the desktop one is the shell's, and the tray's rows are
## the shell's too - they are the same requests its 菜单 rows used to send, arriving
## from a window that is not ours.
func _on_host_event(name: String) -> void:
	if name == "toggle_desktop":
		_toggle_desktop()
	elif name == "toggle_panel":
		_toggle_panel()
	elif name.begins_with("menu background "):
		_on_background_selected(name.substr("menu background ".length()))
	elif name.begins_with("menu screen "):
		_on_screen_selected(int(name.substr("menu screen ".length())))


## A respawned host starts out believing the desktop is shown (its flag is a
## fresh process'), so the switch is re-sent whenever the link comes up - the only
## state the two sides share that the client, not the host, owns. The panel is the
## same kind of flag (a fresh host shows the HUD), and the tray's model goes with them:
## the hours between two hosts are hours in which the model changed without anyone to
## send it to.
func _on_host_online(is_online: bool) -> void:
	if is_online:
		metrics.send_command("wall %d" % (1 if _desktop_shown else 0))
		# and which monitor, for the same reason: a fresh host starts on the primary
		metrics.send_command("screen %d" % _desktop_screen)
		# and 穿透: a fresh host has no such flag either, and this one is the HUD's
		metrics.send_command("lock %d" % (1 if _locked_now() else 0))
		# and the panel: a fresh host has the HUD window on the screen
		metrics.send_command("hud %d" % (1 if _panel_shown else 0))
		# a fresh host re-fits the window, so an on-demand background needs the frame
		# that shows it (the fit is a resize, exactly like the 显示器 row's move)
		if _desktop_shown and _background != null:
			_background.request_redraw()
		_push_tray_model()


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
		hud_window.set_content(next.build_hud(), next.hud_size())
	# the tray's 换桌面 rows mark whichever background is live, so the model goes out on
	# every switch (it used to ride along with the card's own 桌面 chip, gone 2026-10-15)
	_push_tray_model()

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
