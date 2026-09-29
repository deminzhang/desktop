## The floating HUD: an analog clock plus live system monitors, drawn in one
## pass so the layout stays pixel-exact inside a borderless window.
class_name Hud
extends Control

const PANEL := Vector2(420.0, 252.0)
const CLOCK_C := Vector2(80.0, 74.0)
const CLOCK_R := 50.0
const DIVIDER_X := 152.0
const ROW_X := 160.0
const ROW_RIGHT := 406.0
const ROW_TOP := 14.0
const ROW_PITCH := 27.0
const GRAPH := Rect2(160.0, 180.0, 246.0, 58.0)
const HIST_LEN := 150

const C_BORDER := Color(0.30, 0.72, 0.82, 0.32)
const C_TEXT := Color(0.88, 0.96, 0.99)
const C_DIM := Color(0.44, 0.63, 0.70)
const C_TRACK := Color(0.08, 0.18, 0.22, 0.80)
const C_CPU := Color(0.30, 0.85, 1.00)
const C_GPU := Color(1.00, 0.68, 0.28)
const C_NET := Color(0.42, 0.92, 0.58)
const C_HOT := Color(1.00, 0.44, 0.36)

var metrics: MetricsClient
var font: Font
var chinese := false
var fps := 0.0

var _bg: StyleBoxFlat
var _hist := {}
var _net_peak := 1.0
var _acc := 0.0


func _ready() -> void:
	size = PANEL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg = StyleBoxFlat.new()
	_bg.bg_color = Color(0.016, 0.043, 0.058, 0.68)
	_bg.set_corner_radius_all(16)
	_bg.set_border_width_all(1)
	_bg.border_color = C_BORDER
	_bg.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	_bg.shadow_size = 12
	_hist["cpu"] = PackedFloat32Array()
	_hist["gpu"] = PackedFloat32Array()
	_hist["net"] = PackedFloat32Array()
	_load_font()
	set_process(true)


func _load_font() -> void:
	font = Fonts.ui_font()
	chinese = Fonts.has_chinese()


func attach(client: MetricsClient) -> void:
	metrics = client
	client.frame_received.connect(_on_frame)


func _on_frame(data: Dictionary) -> void:
	_push("cpu", metrics.cpu())
	_push("gpu", maxf(float(metrics.gpu()), 0.0))
	var net := metrics.net_rx() + metrics.net_tx()
	_net_peak = maxf(_net_peak * 0.985, maxf(net, 1024.0))
	_push("net", net)
	queue_redraw()


func _push(key: String, value: float) -> void:
	var a: PackedFloat32Array = _hist[key]
	a.append(value)
	if a.size() > HIST_LEN:
		a.remove_at(0)
	_hist[key] = a


func _process(delta: float) -> void:
	fps = Engine.get_frames_per_second()
	_acc += delta
	if _acc >= 0.2:
		_acc = 0.0
		queue_redraw()


# ------------------------------------------------------------------- drawing

func _draw() -> void:
	draw_style_box(_bg, Rect2(Vector2.ZERO, PANEL))
	draw_line(Vector2(DIVIDER_X, 14.0), Vector2(DIVIDER_X, PANEL.y - 16.0),
			Color(0.30, 0.72, 0.82, 0.18), 1.0)
	_draw_clock()
	_draw_clock_text()
	_draw_rows()
	_draw_graph()


func _label(cn: String, en: String) -> String:
	return cn if chinese else en


func _local_seconds() -> float:
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return Time.get_unix_time_from_system() + float(bias) * 60.0


func _draw_clock() -> void:
	var t := _local_seconds()
	var sec := fmod(t, 60.0)
	var minute := fmod(t / 60.0, 60.0)
	var hour := fmod(t / 3600.0, 24.0)

	draw_circle(CLOCK_C, CLOCK_R + 3.0, Color(0.02, 0.07, 0.10, 0.55))
	draw_arc(CLOCK_C, CLOCK_R, 0.0, TAU, 72, Color(0.30, 0.72, 0.82, 0.55), 1.4, true)

	for i in 60:
		var a := float(i) / 60.0 * TAU - PI * 0.5
		var major := i % 5 == 0
		var inner := CLOCK_R - (9.0 if major else 4.0)
		var col := Color(0.70, 0.88, 0.94, 0.85) if major else Color(0.45, 0.65, 0.72, 0.45)
		draw_line(CLOCK_C + Vector2(cos(a), sin(a)) * inner,
				CLOCK_C + Vector2(cos(a), sin(a)) * (CLOCK_R - 1.0),
				col, 1.6 if major else 1.0, true)

	var ha := (hour / 12.0) * TAU - PI * 0.5
	var ma := (minute / 60.0) * TAU - PI * 0.5
	var sa := (sec / 60.0) * TAU - PI * 0.5
	draw_line(CLOCK_C, CLOCK_C + Vector2(cos(ha), sin(ha)) * (CLOCK_R * 0.50), C_TEXT, 4.0, true)
	draw_line(CLOCK_C, CLOCK_C + Vector2(cos(ma), sin(ma)) * (CLOCK_R * 0.74), C_TEXT, 2.6, true)
	draw_line(CLOCK_C - Vector2(cos(sa), sin(sa)) * 8.0,
			CLOCK_C + Vector2(cos(sa), sin(sa)) * (CLOCK_R * 0.86), C_CPU, 1.3, true)
	draw_circle(CLOCK_C, 3.0, C_TEXT)
	draw_circle(CLOCK_C, 1.4, Color(0.02, 0.07, 0.10))


func _draw_clock_text() -> void:
	var d := Time.get_datetime_dict_from_system()
	var hh := int(d["hour"])
	var mm := int(d["minute"])
	var ss := int(d["second"])
	var time_text := "%02d:%02d:%02d" % [hh, mm, ss]
	draw_string(font, Vector2(14.0, 150.0), time_text, HORIZONTAL_ALIGNMENT_CENTER,
			132.0, 26, C_TEXT)

	var date_text := ""
	if chinese:
		var wd: Array = ["日", "一", "二", "三", "四", "五", "六"]
		date_text = "%d年%02d月%02d日 周%s" % [int(d["year"]), int(d["month"]), int(d["day"]), wd[int(d["weekday"])]]
	else:
		var wd: Array = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
		date_text = "%04d-%02d-%02d %s" % [int(d["year"]), int(d["month"]), int(d["day"]), wd[int(d["weekday"])]]
	draw_string(font, Vector2(14.0, 170.0), date_text, HORIZONTAL_ALIGNMENT_CENTER,
			132.0, 11, C_DIM)

	var up := metrics.uptime() if metrics != null else 0
	draw_string(font, Vector2(14.0, 188.0),
			"%s %02d:%02d:%02d" % [_label("运行", "up"), up / 3600, (up / 60) % 60, up % 60],
			HORIZONTAL_ALIGNMENT_CENTER, 132.0, 11, C_DIM)

	var wall := metrics.wall_state if metrics != null else "off"
	var live := metrics != null and metrics.online
	var dot := C_NET if live else C_HOT
	var status := ""
	match wall:
		"ok": status = _label("壁纸已挂载", "wallpaper live")
		"waiting", "no-worker": status = _label("等待桌面", "waiting desktop")
		"failed": status = _label("挂载失败", "wallpaper failed")
		_: status = _label("普通窗口", "windowed")
	if not live:
		status = _label("监控离线", "host offline")
	draw_circle(Vector2(22.0, 204.0), 3.0, dot)
	draw_string(font, Vector2(32.0, 208.0), status, HORIZONTAL_ALIGNMENT_LEFT, 116.0, 11, C_DIM)


func _draw_rows() -> void:
	var mem_u := metrics.mem_used() / 1073741824.0
	var mem_t := metrics.mem_total() / 1073741824.0
	var vram_u := metrics.vram_used() / 1024.0
	var vram_t := metrics.vram_total() / 1024.0
	var gpu := metrics.gpu()
	var temp := metrics.gpu_temp()
	var rx := metrics.net_rx()
	var tx := metrics.net_tx()

	var rows := [
		{
			"label": _label("处理器", "CPU"),
			"frac": clampf(metrics.cpu() / 100.0, 0.0, 1.0),
			"value": "%d%%" % int(round(metrics.cpu())),
			"color": C_CPU,
		},
		{
			"label": _label("内存", "MEM"),
			"frac": clampf(mem_u / maxf(mem_t, 0.001), 0.0, 1.0),
			"value": "%.1f/%.0fG" % [mem_u, mem_t],
			"color": C_CPU,
		},
		{
			"label": _label("显卡", "GPU"),
			"frac": clampf(float(gpu) / 100.0, 0.0, 1.0),
			"value": "--" if gpu < 0 else "%d%%" % gpu,
			"color": C_GPU,
		},
		{
			"label": _label("显存", "VRAM"),
			"frac": clampf(vram_u / maxf(vram_t, 0.001), 0.0, 1.0),
			"value": "--" if vram_t <= 0.0 else "%.1f/%.1fG" % [vram_u, vram_t],
			"color": C_GPU,
		},
		{
			"label": _label("温度", "TEMP"),
			"frac": clampf(float(temp) / 100.0, 0.0, 1.0),
			"value": "--" if temp < 0 else "%d°C" % temp,
			"color": C_HOT if temp >= 75 else C_GPU,
		},
		{
			"label": _label("网络", "NET"),
			"frac": clampf(rx / maxf(_net_peak, 1.0), 0.0, 1.0),
			"value": "↓%s ↑%s" % [_rate(rx), _rate(tx)],
			"color": C_NET,
		},
	]

	var y := ROW_TOP
	for row in rows:
		draw_string(font, Vector2(ROW_X, y + 13.0), row["label"],
				HORIZONTAL_ALIGNMENT_LEFT, 60.0, 11, C_DIM)
		var track := Rect2(ROW_X + 46.0, y + 4.0, 96.0, 8.0)
		draw_rect(track, C_TRACK, true)
		var frac: float = row["frac"]
		if frac > 0.001:
			draw_rect(Rect2(track.position, Vector2(track.size.x * frac, track.size.y)),
					row["color"], true)
		draw_string(font, Vector2(ROW_RIGHT - 108.0, y + 14.0), row["value"],
				HORIZONTAL_ALIGNMENT_RIGHT, 108.0, 13, C_TEXT)
		y += ROW_PITCH

	draw_string(font, Vector2(ROW_X, y + 13.0), _label("帧率", "FPS"),
			HORIZONTAL_ALIGNMENT_LEFT, 60.0, 11, C_DIM)
	draw_string(font, Vector2(ROW_RIGHT - 108.0, y + 14.0), "%d" % int(round(fps)),
			HORIZONTAL_ALIGNMENT_RIGHT, 108.0, 13, C_TEXT)


func _rate(bytes: float) -> String:
	if bytes >= 1048576.0:
		return "%.1fM" % (bytes / 1048576.0)
	if bytes >= 1024.0:
		return "%.0fK" % (bytes / 1024.0)
	return "%.0fB" % bytes


func _draw_graph() -> void:
	draw_rect(GRAPH, Color(0.02, 0.06, 0.08, 0.55), true)
	for i in 4:
		var y := GRAPH.position.y + GRAPH.size.y * float(i) / 3.0
		draw_line(Vector2(GRAPH.position.x, y), Vector2(GRAPH.end.x, y),
				Color(0.30, 0.72, 0.82, 0.10), 1.0)

	var legend := [
		[_label("处理器", "CPU"), C_CPU],
		[_label("显卡", "GPU"), C_GPU],
		[_label("网络", "NET"), C_NET],
	]
	var lx := GRAPH.position.x + 6.0
	for item in legend:
		draw_circle(Vector2(lx + 3.0, GRAPH.position.y + 9.0), 2.5, item[1])
		draw_string(font, Vector2(lx + 9.0, GRAPH.position.y + 12.0), item[0],
				HORIZONTAL_ALIGNMENT_LEFT, 40.0, 9, C_DIM)
		lx += 48.0

	var top := GRAPH.position.y + 18.0
	var bottom := GRAPH.end.y - 4.0
	_plot("cpu", 100.0, top, bottom, C_CPU, 1.6)
	_plot("gpu", 100.0, top, bottom, C_GPU, 1.6)
	_plot("net", maxf(_net_peak, 1.0), top, bottom, C_NET, 1.2)


func _plot(key: String, peak: float, top: float, bottom: float, color: Color,
		width: float) -> void:
	var a: PackedFloat32Array = _hist[key]
	if a.size() < 2:
		return
	var step := GRAPH.size.x / float(HIST_LEN - 1)
	var pts := PackedVector2Array()
	pts.resize(a.size())
	for i in a.size():
		var v := clampf(a[i] / peak, 0.0, 1.0)
		pts[i] = Vector2(GRAPH.position.x + float(i) * step, bottom - (bottom - top) * v)
	draw_polyline(pts, color, width, true)
