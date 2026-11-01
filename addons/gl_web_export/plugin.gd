@tool
extends EditorPlugin
## UPDATE 09 section 2c (DECISIONS T-139): registers the web texture cap (web_texture_cap.gd) with the exporter.

var _cap: EditorExportPlugin


func _enter_tree() -> void:
	_cap = (load("res://addons/gl_web_export/web_texture_cap.gd") as GDScript).new() as EditorExportPlugin
	add_export_plugin(_cap)


func _exit_tree() -> void:
	if _cap != null:
		remove_export_plugin(_cap)
		_cap = null
