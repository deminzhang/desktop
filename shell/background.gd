## One switchable desktop background.
##
## A background owns everything that makes its scene: the 3D world it builds
## into the wallpaper window, the HUD content it shows inside the floating
## window, its own colour grade and its render policy. The shell
## (shell/main.gd) knows nothing about any concrete background, so adding one is
## a new directory under backgrounds/ plus a line in backgrounds.gd.
class_name Background
extends Node3D

## How often the wallpaper viewport has to redraw.
enum Policy {
	CONTINUOUS,  ## something moves every frame - the aquarium's fish
	ON_DEMAND,   ## static scene, redraw only when time or the observer changes
}

## The shell's metric stream (shell/metrics.gd), assigned before build() runs.
## A background that shows monitors in its HUD reads them from here.
var metrics: MetricsClient

## The shell's command line (shell/args.gd), also assigned before build() runs.
## The shared switches are the shell's; a background's own dev switches are its
## own business (the sky reads --sky-time and friends in sky.gd).
var opts: Args


# Registry id, e.g. "aquarium".
func id() -> String:
	return ""


# Name shown in the HUD's background picker.
func display_name() -> String:
	return ""


## Builds the whole world as children of this node. May await. `host` is the
## shell itself, for anything build() cannot get from its own properties.
func build(_host: Node) -> void:
	pass


## Releases everything build() created. The shell awaits `tree_exited` right
## after calling it, so the node must leave the tree - the default drops the
## whole subtree, which releases every mesh, material and shader with it.
func teardown() -> void:
	queue_free()


## Fresh HUD content for this background, rebuilt on every switch so no state
## leaks from the previous one. Must not be null.
func build_hud() -> Control:
	return Control.new()


## Size of that HUD content. The shell adds its own toolbar below it.
func hud_size() -> Vector2i:
	return Vector2i(320, 200)


## The switches this background offers in the HUD's 菜单 panel, one row each and
## in this order: {"id": String, "label": String, "on": bool}. The menu is the
## shell's chrome, so a background that has a switch of its own hands it over
## here instead of drawing a control in its own HUD - the shell rebuilds the rows
## on every switch, and the empty default is a menu with nothing but its own
## rows. Only the sky has one so far (the constellation figures and names).
func menu_switches() -> Array:
	return []


## One of menu_switches() has been clicked: `on` is the state it was switched to.
## The menu draws the label; the state is the background's, so it does not
## survive a rebuild (the same rule as the HUD content itself).
func set_menu_switch(_id: String, _on: bool) -> void:
	pass


func render_policy() -> int:
	return Policy.CONTINUOUS


## Asks the shell for one more frame. This is the other half of Policy.ON_DEMAND:
## a background that idles the viewport calls it whenever something actually
## changes, so the wallpaper never freezes on a stale frame.
func request_redraw() -> void:
	RenderingServer.viewport_set_update_mode(get_viewport().get_viewport_rid(),
			RenderingServer.VIEWPORT_UPDATE_ONCE)


## Full-screen colour grade drawn over the wallpaper, or null for none: the
## palette is part of a background's look, so each one ships its own.
func vignette_shader() -> Shader:
	return null
