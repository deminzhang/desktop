## Turns the process's main window into the desktop wallpaper: borderless, no
## resize, the title bin/host.exe matches on, covering the whole primary monitor.
class_name WallpaperWindow
extends RefCounted


static func apply(win: Window, fps: int) -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	# the Window node re-applies its own title, so set the property, not just the server
	win.title = MetricsClient.WALLPAPER_TITLE
	DisplayServer.window_set_title(MetricsClient.WALLPAPER_TITLE)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = fps

	# the wallpaper covers the whole primary monitor, not just the work area
	var screen := DisplayServer.get_primary_screen()
	var full := DisplayServer.screen_get_size(screen)
	var origin := DisplayServer.screen_get_position(screen)
	win.size = full
	win.position = origin
	DisplayServer.window_set_size(full)
	DisplayServer.window_set_position(origin)
