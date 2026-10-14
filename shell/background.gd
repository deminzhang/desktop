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
