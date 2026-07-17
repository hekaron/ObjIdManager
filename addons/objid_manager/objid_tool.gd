@tool
extends EditorPlugin

var panel: Control
var translations: Array = []
var current_language: String = "en"


func _enter_tree() -> void:
	# Use the language actually displayed by the Godot editor.
	# Do not change TranslationServer's global locale from an editor plugin.
	var editor_language := get_editor_interface().get_editor_language()
	current_language = "ja" if editor_language.to_lower().begins_with("ja") else "en"

	panel = preload("res://addons/objid_manager/objid_panel.tscn").instantiate()
	panel.set("plugin_ref", self)
	if panel.has_method("set_language"):
		panel.call("set_language", current_language)

	add_control_to_dock(DOCK_SLOT_RIGHT_UL, panel)

	if panel.has_method("on_plugin_ready"):
		panel.on_plugin_ready()

	if self.has_signal("scene_changed"):
		self.scene_changed.connect(_on_scene_changed)

func _exit_tree() -> void:
	if is_instance_valid(panel):
		remove_control_from_docks(panel)
		panel.queue_free()
		panel = null

	translations.clear()

func _on_scene_changed(_scene_root: Node) -> void:
	if is_instance_valid(panel) and panel.has_method("refresh_list"):
		panel.refresh_list()
