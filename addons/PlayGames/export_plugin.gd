@tool
extends EditorPlugin

# Adds the PlayGames Android plugin (android_plugins/PlayGames, built by CI into bin/) and
# Google's Play Games library to Android exports. CI only builds bin/ once
# android_plugins/PlayGames/app_id.txt holds the game's Play Games project ID: without one,
# Play Games would stop the app at launch, so nothing is added.
var export_plugin: PlayGamesExportPlugin


func _enter_tree():
	export_plugin = PlayGamesExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree():
	remove_export_plugin(export_plugin)
	export_plugin = null


class PlayGamesExportPlugin extends EditorExportPlugin:
	const NAME := "PlayGames"

	func _supports_platform(platform):
		return platform is EditorExportPlatformAndroid

	func _built(debug) -> bool:
		var kind := "debug" if debug else "release"
		return FileAccess.file_exists("res://addons/%s/bin/%s/%s-%s.aar" % [NAME, kind, NAME, kind])

	func _get_android_libraries(platform, debug):
		if not _built(debug):
			return PackedStringArray()
		var kind := "debug" if debug else "release"
		return PackedStringArray([NAME + "/bin/%s/%s-%s.aar" % [kind, NAME, kind]])

	func _get_android_dependencies(platform, debug):
		if not _built(debug):
			return PackedStringArray()
		return PackedStringArray(["com.google.android.gms:play-services-games-v2:20.1.2"])

	func _get_name():
		return NAME
