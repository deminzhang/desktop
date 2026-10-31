## The background registry: adding a background is one entry here plus its
## directory under backgrounds/. Entry order is the picker order.
##
## "name" labels the picker before anything is instantiated, so it must match
## the background's own Background.display_name().
##
## An entry may also be a *placeholder*: 五行 asks for five desktops and the tank
## is only the 水 one (用户 2026-11-04), so the four that are missing are registered
## as `todo` rows. The picker offers them and the tray draws them greyed - the flag
## is the third field of the `menu bg` line (shell/main.gd) and MF_GRAYED in the
## native popup - and create() refuses them, so neither a click nor a stale
## `--background=wood` can put the desktop on nothing.
class_name Backgrounds
extends RefCounted

const ENTRIES := {
	# 星空 first: it is the DEFAULT below and the row the user asked to see at the
	# top of 换桌面.
	"sky": {
		"script": preload("res://backgrounds/sky/sky.gd"),
		"name": "星空",
	},
	# 五行, in the order the picker lists them: 水族箱 is the set's 水, and the four
	# after it are its 木/火/土/金 - names registered, backgrounds not built yet.
	"aquarium": {
		"script": preload("res://backgrounds/aquarium/aquarium.gd"),
		"name": "水族箱",
	},
	"wood": {"name": "木TODO", "todo": true},
	"fire": {"name": "火TODO", "todo": true},
	"earth": {"name": "土TODO", "todo": true},
	"metal": {"name": "金TODO", "todo": true},
}


## The background the app opens with when `--background` names none. Kept apart
## from the entry order above, which is the picker's: 换桌面 lists 星空 first and
## then the five 五行 rows, and the tray's 换桌面 submenu marks whichever is live by
## name (the model shell/main.gd pushes carries both the id and the display name),
## not by position.
const DEFAULT := "sky"


static func ids() -> Array:
	return ENTRIES.keys()


static func default_id() -> String:
	return DEFAULT


static func display_name(id: String) -> String:
	return String(ENTRIES[id]["name"]) if ENTRIES.has(id) else id


## Whether a registered row is a placeholder: offered by the picker, not buildable
## yet. Every id in here has a name but no script.
static func is_todo(id: String) -> bool:
	return ENTRIES.has(id) and bool(ENTRIES[id].get("todo", false))


static func create(id: String) -> Background:
	if not ENTRIES.has(id):
		push_error("XuanDesk: unknown background '%s'" % id)
		return null
	if is_todo(id):
		push_error("XuanDesk: background '%s' (%s) is not built yet" % [id, display_name(id)])
		return null
	return (ENTRIES[id]["script"] as GDScript).new() as Background
