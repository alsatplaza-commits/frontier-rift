class_name AndroidUninstall
extends RefCounted

const PLUGIN := "RiftUninstall"
const FALLBACK := "Kaldırmak için Android Ayarlar > Uygulamalar bölümünü açın."


static func open_own_settings() -> String:
	if not OS.has_feature("android"):
		return FALLBACK
	if not Engine.has_singleton(PLUGIN):
		return FALLBACK
	var plugin := Engine.get_singleton(PLUGIN)
	if plugin == null:
		return FALLBACK
	plugin.call("openOwnAppSettings")
	return ""
