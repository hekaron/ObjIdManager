@tool
extends EditorPlugin

var panel : Control
var translations : Array = []


func _enter_tree():
	var editor_settings := get_editor_interface().get_editor_settings()
	
	var editor_lang := ""
	for key in [
		"interface/editor/language",
		"interface/editor/locale",
		"interface/editor/editor_language",
		"interface/editor/localization/editor_locale"
	]:
		if editor_settings.has_setting(key):
			editor_lang = str(editor_settings.get_setting(key))
			break

	if editor_lang == "" or editor_lang == "true":
		editor_lang = "en"

	var short_lang := editor_lang.split("_")[0]  # "ja_JP" → "ja", "en_US" → "en"

	TranslationServer.set_locale(short_lang)

	panel = preload("res://addons/objid_manager/objid_panel.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, panel)
	panel.plugin_ref = self
	panel.on_plugin_ready()

	if "update_texts" in panel:
		panel.update_texts()
		
	if self.has_signal("scene_changed"):
		self.scene_changed.connect(_on_scene_changed)

func _exit_tree():
	if panel:
		remove_control_from_docks(panel)
		panel.free()
		
	translations.clear()

func _on_scene_changed(scene_root):
	if panel and panel.has_method("refresh_list"):
		panel.refresh_list()
