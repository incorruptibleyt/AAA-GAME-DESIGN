class_name Share
## SHARE RESULT on the Daily Crypt end screen. On Android it opens the phone's share menu
## with the result as words and as a picture (saved under user://, which Godot's own file
## provider lets other apps read). The words are always copied too, for apps that keep only
## the picture; on other systems copying is all it does.

const PICTURE := "user://share/bone-chain-daily.png"
const SIZE := Vector2i(720, 720)


## Returns true when the phone's share menu was asked to open.
static func send(text: String, picture: Image) -> bool:
	DisplayServer.clipboard_set(text)
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return false
	var runtime = Engine.get_singleton("AndroidRuntime")
	var activity = runtime.getActivity()
	var intents = JavaClassWrapper.wrap("android.content.Intent")
	if activity == null or intents == null:
		return false
	var uri = _picture_uri(activity, picture)
	var intent = intents.Intent(intents.ACTION_SEND)
	if intent == null:
		return false
	intent.setType("image/png" if uri else "text/plain")
	intent.putExtra(intents.EXTRA_TEXT, text)
	if uri:
		intent.putExtra(intents.EXTRA_STREAM, uri)
		var clips = JavaClassWrapper.wrap("android.content.ClipData")
		if clips:
			intent.setClipData(clips.newRawUri("", uri))
		intent.addFlags(intents.FLAG_GRANT_READ_URI_PERMISSION)
	var chooser = intents.createChooser(intent, "Share your Daily Crypt")
	if chooser == null:
		return false
	activity.runOnUiThread(runtime.createRunnableFromGodotCallable(func(): activity.startActivity(chooser)))
	return true


## The picture saved as a file, as a content:// address other apps may read (or null).
static func _picture_uri(activity, picture: Image):
	if picture == null or picture.is_empty():
		return null
	DirAccess.make_dir_recursive_absolute(PICTURE.get_base_dir())
	if picture.save_png(PICTURE) != OK:
		return null
	var provider = JavaClassWrapper.wrap("androidx.core.content.FileProvider")
	var files = JavaClassWrapper.wrap("java.io.File")
	if provider == null or files == null:
		return null
	var file = files.File(ProjectSettings.globalize_path(PICTURE))
	if file == null:
		return null
	return provider.getUriForFile(activity, activity.getPackageName() + ".fileprovider", file)


## The result card drawn as a square picture: the game's name, then `lines` ([text, size,
## colour] each), the coloured squares and the streak. Null where nothing is drawn (headless).
static func picture(parent: Node, lines: Array, rows: Array, caption: String) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.06, 0.13)
	vp.add_child(Hud.full(bg))
	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.09, 0.18)
	sb.set_corner_radius_all(28)
	sb.set_border_width_all(6)
	sb.border_color = Hud.GOLD
	frame.add_theme_stylebox_override("panel", sb)
	vp.add_child(Hud.full(frame))
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	frame.add_child(Hud.full(col))
	col.add_child(Hud.label("BONE CHAIN", 70, Hud.GOLD))
	for line: Array in lines:
		col.add_child(Hud.label(line[0], line[1], line[2]))
	var card := ShareCard.new()
	card.zoom = 1.7
	col.add_child(card)
	card.show_rows(rows, caption)
	col.add_child(Hud.label("Bone Chain on Google Play", 24, Color(0.75, 0.72, 0.85)))
	# Two frames: one to lay the boxes out, one to draw them.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img
