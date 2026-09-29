## Development switches, everything after `--` on the command line:
##   --wallpaper=0|1         parent into the desktop's WorkerW layer (default 1)
##   --hud=0|1               create the floating HUD (default 1)
##   --background=<id>       background to open with (default: first registered)
##   --fps=<n>               frame cap (default 60)
##   --interval=<ms>         host metric sample period (default 1000)
##   --no-activate=0|1       HUD window without WS_EX_NOACTIVATE (default 1)
##   --shot=<png>            render N frames, save a viewport, quit
##   --shot-target=main|hud  which window to capture (default main)
##   --shot-frames=<n>       frames to settle before capturing (default 90)
##   --exit-after=<seconds>  quit after N seconds
##
## Keys are normalised to snake_case, so `--shot-frames` and `--shot_frames`
## both read back as `shot_frames`.
##
## A background may read further switches from the same line (shell/background.gd
## injects this object); the sky's are `--sky-time=<unix|ISO>`, `--sky-rate=<x>`
## and `--sky-view=<azimuth>,<altitude>`.
class_name Args
extends RefCounted

var opts: Dictionary = {}


static func parse(cmdline: PackedStringArray) -> Args:
	var args := Args.new()
	for raw in cmdline:
		var body := String(raw)
		if not body.begins_with("--"):
			continue
		body = body.substr(2)
		var eq := body.find("=")
		# only the key is normalised: a --shot=shots/a-b.png value keeps its dash
		var key := (body if eq < 0 else body.substr(0, eq)).replace("-", "_")
		args.opts[key] = true if eq < 0 else body.substr(eq + 1)
	return args


func has(key: String) -> bool:
	return opts.has(key)


func flag(key: String, fallback: bool) -> bool:
	if not opts.has(key):
		return fallback
	var value: Variant = opts[key]
	if value is bool:
		return value
	var text := String(value).to_lower()
	return text != "0" and text != "false" and text != "no"


func num(key: String, fallback: float) -> float:
	if not opts.has(key):
		return fallback
	return float(opts[key])


func text(key: String, fallback: String) -> String:
	if not opts.has(key):
		return fallback
	return String(opts[key])
