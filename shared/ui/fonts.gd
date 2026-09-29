## System CJK font lookup, shared by the HUD shell and by every background's HUD.
##
## Windows ships no font the engine will pick for Chinese labels on its own, and
## a FontFile reports nothing about coverage, so the candidates are probed once
## and cached for the process.
class_name Fonts
extends RefCounted

const CANDIDATES := [
	"C:/Windows/Fonts/msyh.ttc",
	"C:/Windows/Fonts/msyhl.ttc",
	"C:/Windows/Fonts/simhei.ttf",
	"C:/Windows/Fonts/simsun.ttc",
]

static var _font: Font = null
static var _probed := false
static var _chinese := false


static func _probe() -> void:
	_probed = true
	for path in CANDIDATES:
		if not FileAccess.file_exists(path):
			continue
		var candidate := FontFile.new()
		if candidate.load_dynamic_font(path) == OK and candidate.has_char(0x5904):  # 处
			_font = candidate
			_chinese = true
			return
	_font = ThemeDB.fallback_font


## The system's CJK font, or the engine fallback when there is none.
static func ui_font() -> Font:
	if not _probed:
		_probe()
	return _font


## Whether ui_font() can actually draw Chinese labels.
static func has_chinese() -> bool:
	if not _probed:
		_probe()
	return _chinese
