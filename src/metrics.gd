## Owns the native host process and consumes its metric stream.
##
## The client is the TCP *server* on loopback: it binds an ephemeral port before
## spawning the host, so there is no port file, no firewall prompt and no race.
## The host exits on its own the moment this socket drops.
class_name MetricsClient
extends Node

signal frame_received(data: Dictionary)
signal online_changed(is_online: bool)
signal host_event(name: String)

const WALLPAPER_TITLE := "XuanDesk.Aquarium"
const HUD_TITLE := "XuanDesk.HUD"
const MAX_RESPAWNS := 3

var online := false
var wall_state := "off"
var data: Dictionary = {}
var host_pid := -1

var _server: TCPServer
var _peer: StreamPeerTCP
var _buf := ""
var _opts: Dictionary = {}
var _respawns := 0
var _retry_at := 0
var _started_at := 0
var _stopping := false


func start(opts: Dictionary) -> void:
	_opts = opts
	_started_at = Time.get_ticks_msec()
	_server = TCPServer.new()
	var err := _server.listen(0, "127.0.0.1")
	if err != OK:
		push_error("XuanDesk: cannot bind loopback listener (%d)" % err)
		return
	_spawn()


func stop() -> void:
	_stopping = true
	if _peer != null:
		_peer.put_data("quit\n".to_utf8_buffer())
		_peer.poll()
		_peer = null
	if host_pid > 0 and OS.is_process_running(host_pid):
		OS.kill(host_pid)
	host_pid = -1
	if _server != null:
		_server.stop()
		_server = null


func _spawn() -> void:
	var args := PackedStringArray([
		"--connect", "127.0.0.1:%d" % _server.get_local_port(),
		"--pid", str(OS.get_process_id()),
		"--title", WALLPAPER_TITLE,
		"--overlay-title", HUD_TITLE,
		"--wallpaper", "1" if _opts.get("wallpaper", true) else "0",
		"--no-activate", "1" if _opts.get("no_activate", true) else "0",
		"--interval", str(int(_opts.get("interval", 1000))),
	])
	host_pid = OS.create_process(_host_path(), args, false)
	if host_pid <= 0:
		push_error("XuanDesk: could not launch bin/host.exe")


func _host_path() -> String:
	var beside_project := ProjectSettings.globalize_path("res://bin/host.exe")
	if FileAccess.file_exists(beside_project):
		return beside_project
	return OS.get_executable_path().get_base_dir().path_join("host.exe")


func _process(_delta: float) -> void:
	if _server == null or _stopping:
		return

	if _peer == null:
		if _server.is_connection_available():
			_peer = _server.take_connection()
			_peer.set_no_delay(true)
			_buf = ""
			_respawns = 0
			_set_online(true)
		elif Time.get_ticks_msec() >= _retry_at and not _host_alive():
			_retry()
		return

	_peer.poll()
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_peer = null
		_set_online(false)
		_retry_at = Time.get_ticks_msec() + 2500
		return

	var available := _peer.get_available_bytes()
	if available > 0:
		_buf += _peer.get_utf8_string(available)
		var guard := 0
		while guard < 512:
			var nl := _buf.find("\n")
			if nl < 0:
				break
			guard += 1
			var line := _buf.substr(0, nl)
			_buf = _buf.substr(nl + 1)
			if not line.is_empty():
				_handle_line(line)


func _host_alive() -> bool:
	return host_pid > 0 and OS.is_process_running(host_pid)


func _retry() -> void:
	if _respawns >= MAX_RESPAWNS:
		return
	# give a freshly spawned host time to come up before assuming it died
	if Time.get_ticks_msec() - _started_at < 5000:
		return
	if _host_alive():
		return
	_respawns += 1
	_retry_at = Time.get_ticks_msec() + 2500
	_spawn()


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
		host_event.emit(String(e))
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
