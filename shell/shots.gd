## Development screenshot hook.
class_name Shots
extends RefCounted


## Renders `frames` frames, waits for the last one to land on the GPU, then
## writes `viewport` to `path` (relative paths resolve against the project root).
static func capture(viewport: Viewport, path: String, frames: int,
		label: String) -> void:
	# an on-demand background would idle here and frame_post_draw would never
	# arrive, so a shot always draws
	RenderingServer.viewport_set_update_mode(viewport.get_viewport_rid(),
			RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	for i in maxi(frames, 1):
		await viewport.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var out := path
	if not out.is_absolute_path():
		out = ProjectSettings.globalize_path("res://").path_join(out)
	var err := image.save_png(out)
	print("XuanDesk: shot %s -> %s (%dx%d, err=%d)" % [label, out,
			image.get_width(), image.get_height(), err])
