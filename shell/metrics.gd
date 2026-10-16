## Owns the native side and consumes its metric stream.
##
## The native side is a GDExtension loaded into *this* process
## (native/gdext/xuandesk_native.c, res://xuandesk_native.gdextension): it owns the
## notification-area icon, the window styles that make the HUD 穿透, the mount of the
## wallpaper window into the shell's WorkerW layer, the hotkeys and the readings.
##
## Until 2026-10-16 that work lived in bin/host.exe - a second process this client
## launched and then talked to over a loopback socket, the client being the TCP
## *server*. The link is now a call. What did not change is the *shape* of it: the same
## one-line JSON frames, the same one-line command grammar and the same events, so
## everything below and everything in shell/main.gd reads as it did before.
class_name MetricsClient
extends Node

signal frame_received(data: Dictionary)
signal online_changed(is_online: bool)
signal native_event(name: String)

const WALLPAPER_TITLE := "XuanDesk.Aquarium"
const HUD_TITLE := "XuanDesk.HUD"

var online := false
var wall_state := "off"
var data: Dictionary = {}

var _started := false


## `opts` carries the same switches the host process used to be launched with -
## wallpaper, no_activate, interval - plus the two window ids it needs to stamp its
## styles on: `main_window_id` (the wallpaper window) and `hud_window_id` (the HUD).
##
## Passing the handles in is the one thing the merge makes genuinely better: host.exe
## had to match windows by title prefix and handshake over its own pid, because it was
## a different process. This side already knows which windows it owns.
func start(opts: Dictionary) -> void:
	if _started:
		return
	# start() hands back the native side's first status line, and that is where its
	# outcome is reported - it is the one call that can fail for a reason worth
	# reading (no window to stamp, no tray window, already started).
	var status := String(XuanDeskNative.start(
			_handle(int(opts.get("main_window_id", 0))),
			_handle(int(opts.get("hud_window_id", -1))),
			1 if opts.get("wallpaper", true) else 0,
			int(opts.get("interval", 1000)),
			1 if opts.get("no_activate", true) else 0))
	var parsed: Variant = JSON.parse_string(status)
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("started", 0)) != 1:
		push_error("XuanDesk: native side did not start: " + status)
		return
	_started = true
	# There is no longer a window in which the link is down - the native side is this
	# process. Everything that used to wait for a spawned host to connect (main.gd's
	# _on_native_online re-sends the flags this side owns) hangs off this signal, so it
	# still has to fire exactly once, here.
	_set_online(true)


## The OS window handle for a Godot window id, or 0 when there is no such window - the
## native side then falls back to finding its own window by title.
func _handle(window_id: int) -> int:
	if window_id < 0:
		return 0
	return int(DisplayServer.window_get_native_handle(
			DisplayServer.WINDOW_HANDLE, window_id))


## Nothing to kill any more: the native side is this process and goes down with it.
func stop() -> void:
	if not _started:
		return
	_started = false
	_set_online(false)


## One line to the native side, in the grammar native/gdext/xuandesk_native.c
## handle_command reads: "quit", "wall 0|1", "screen n", "hud 0|1", "lock 0|1" and the
## "menu ..." model lines.
##
## A line takes effect the moment it is sent. The socket version could lose one written
## before the host was up, which is why the tray model was re-sent on every reconnect;
## that whole class of race is gone, and _on_native_online is now only about a state the
## two sides each hold a copy of.
func send_command(line: String) -> bool:
	if not _started:
		return false
	XuanDeskNative.command(line)
	return true


## Which monitor the 3D desktop is on. The native side holds the window and the
## geometry, so this is only a request: what it actually did comes back in the next
## frame's `screen` field.
func set_screen(index: int) -> bool:
	return send_command("screen %d" % index)


## One turn of the native side, once per rendered frame: its messages (the tray's
## popup, the hotkeys), the readings, and the five-second housekeeping pass that keeps
## the wallpaper fitted and the HUD's styles stamped. Returns "" when there is nothing
## new to report, which is most frames.
func _process(_delta: float) -> void:
	if not _started:
		return
	var frame := XuanDeskNative.poll()
	if not frame.is_empty():
		_handle_line(frame)


func _set_online(value: bool) -> void:
	if online == value:
		return
	online = value
	online_changed.emit(value)


func _handle_line(line: String) -> void:
	var parsed: Variant = JSON.parse_string(line)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	data = parsed
	wall_state = String(data.get("wall", "off"))
	for e in data.get("ev", []):
		native_event.emit(String(e))
	frame_received.emit(data)


# ------------------------------------------------------------ typed accessors

func cpu() -> float:
	return float(data.get("cpu", 0.0))


func mem_used() -> float:
	return float(data.get("mem_used", 0.0))


func mem_total() -> float:
	return float(data.get("mem_total", 0.0))


func gpu() -> int:
	return int(data.get("gpu", -1))


func vram_used() -> float:
	return float(data.get("vram_used", 0.0))


func vram_total() -> float:
	return float(data.get("vram_total", 0.0))


func gpu_temp() -> int:
	return int(data.get("gpu_temp", -1))


func net_rx() -> float:
	return float(data.get("net_rx", 0.0))


func net_tx() -> float:
	return float(data.get("net_tx", 0.0))


func uptime() -> int:
	return int(data.get("up", 0))


## The monitors the native side found, in its own order (index 0 is the primary):
## [{w, h, x, y, primary}], empty until the first frame arrives.
func screens() -> Array:
	var list: Variant = data.get("screens", [])
	return list if list is Array else []


## Which of them the 3D desktop is on, as the native side last reported it.
func screen() -> int:
	return int(data.get("screen", 0))
