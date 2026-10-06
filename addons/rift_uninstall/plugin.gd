@tool
extends EditorPlugin

var _export := AndroidExportPlugin.new()


func _enter_tree() -> void:
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)


class AndroidExportPlugin extends EditorExportPlugin:
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid


	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var which := "debug" if debug else "release"
		return PackedStringArray(["res://addons/rift_uninstall/bin/%s/riftuninstall-%s.aar" % [which, which]])


	func _get_name() -> String:
		return "RiftUninstall"
