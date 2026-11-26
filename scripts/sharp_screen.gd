class_name SharpScreen
extends RefCounted
## Version 384 (visual review of v383, fix 2: smooth on every screen). A phone set to its
## sharpest screen mode (the Galaxy S23 Ultra's WQHD+, 1440 x 3088) ran the game at 25 frames a
## second against 59 in FHD+ (1080 x 2316). The 3D world was already drawn at the same size in
## both, so the cost was everything drawn at the screen's full size: the buttons and text,
## the see-through full-screen layers and the last colour pass.
## On a screen wider than MAX_WIDTH the whole game (the Game node and everything under it)
## moves into a SubViewport that draws at MAX_WIDTH wide with the same 540-wide layout, and
## the picture is scaled up to the screen in one cheap step. Touches pass through the
## container, turned into the same layout units as before. Screens up to MAX_WIDTH wide are
## left exactly as they were.

const MAX_WIDTH := 1080
## A little room over MAX_WIDTH so a 1096-wide screen isn't scaled for nothing.
const SLACK := 40

## The viewport the game draws into, or null when it draws straight to the screen.
static var view: SubViewport
static var _box: SubViewportContainer


static func needed(win: Vector2i) -> bool:
	return win.x > MAX_WIDTH + SLACK and not "nosharpwrap" in OS.get_cmdline_user_args()


## Moves `node` (the Game autoload) into a viewport MAX_WIDTH wide. Called deferred, once the
## root has finished adding its children.
static func wrap(node: Node) -> void:
	var root := node.get_tree().root
	_box = SubViewportContainer.new()
	_box.name = "SharpScreen"
	_box.stretch = false
	_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_box.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	view = SubViewport.new()
	view.name = "View"
	view.size_2d_override_stretch = true
	view.gui_embed_subwindows = true   # the feedback box's long-press menu stays inside
	view.audio_listener_enable_2d = true
	view.audio_listener_enable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.positional_shadow_atlas_size = root.positional_shadow_atlas_size
	view.use_debanding = root.use_debanding
	view.screen_space_aa = root.screen_space_aa
	view.canvas_item_default_texture_filter = root.canvas_item_default_texture_filter
	_box.add_child(view)
	root.add_child(_box)
	root.audio_listener_enable_3d = false
	_fit(root)
	root.size_changed.connect(_fit.bind(root))
	node.reparent(view, false)


## Sizes the viewport to the screen's shape at no more than MAX_WIDTH wide, with the
## layout size (540 wide) of the screen itself.
static func _fit(root: Window) -> void:
	if view == null:
		return
	var win := root.size
	var vis := root.get_visible_rect().size
	if win.x <= 0 or win.y <= 0 or vis.x <= 0.0 or vis.y <= 0.0:
		return
	var k := minf(1.0, float(MAX_WIDTH) / float(win.x))
	var px := Vector2i(maxi(1, roundi(win.x * k)), maxi(1, roundi(win.y * k)))
	view.size = px
	view.size_2d_override = Vector2i(roundi(vis.x), roundi(vis.y))
	_box.position = Vector2.ZERO
	_box.size = Vector2(px)
	_box.scale = Vector2(vis.x / float(px.x), vis.y / float(px.y))


## The size in pixels the game draws at: the viewport's when wrapped, else the screen's.
static func draw_size(n: Node) -> Vector2i:
	if view != null:
		return view.size
	return n.get_window().size
