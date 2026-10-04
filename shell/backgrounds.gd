## The background registry: adding a background is one entry here plus its
## directory under backgrounds/. Entry order is the picker order.
##
## "name" labels the picker before anything is instantiated, so it must match
## the background's own Background.display_name().
class_name Backgrounds
extends RefCounted

const ENTRIES := {
	"aquarium": {
		"script": preload("res://backgrounds/aquarium/aquarium.gd"),
		"name": "水族箱",
	},
	"sky": {
		"script": preload("res://backgrounds/sky/sky.gd"),
		"name": "星空",
	},
}


## The background the app opens with when `--background` names none. Kept apart
## from the entry order above, which is the picker's: 换桌面 still lists 水族箱
## first, and the tray's 换桌面 submenu marks whichever is live by name (the model
## shell/main.gd pushes carries both the id and the display name),
## not by position.
const DEFAULT := "sky"


static func ids() -> Array:
	return ENTRIES.keys()


static func default_id() -> String:
	return DEFAULT


static func display_name(id: String) -> String:
	return String(ENTRIES[id]["name"]) if ENTRIES.has(id) else id


static func create(id: String) -> Background:
	if not ENTRIES.has(id):
		push_error("XuanDesk: unknown background '%s'" % id)
		return null
	return (ENTRIES[id]["script"] as GDScript).new() as Background
