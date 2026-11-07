@tool
extends EditorPlugin

# Adds the PlayUpdate Android plugin (android_plugins/PlayUpdate, built by CI into bin/)
# and Google's app-update library to Android exports.
var export_plugin: PlayUpdateExportPlugin


func _enter_tree():
	export_plugin = PlayUpdateExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree():
	remove_export_plugin(export_plugin)
	export_plugin = null


class PlayUpdateExportPlugin extends EditorExportPlugin:
	const NAME := "PlayUpdate"

	func _supports_platform(platform):
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(platform, debug):
		var kind := "debug" if debug else "release"
		return PackedStringArray([NAME + "/bin/%s/%s-%s.aar" % [kind, NAME, kind]])

	func _get_android_dependencies(platform, debug):
		return PackedStringArray(["com.google.android.play:app-update:2.1.0"])

	func _get_name():
		return NAME
