## File: addons/objid_tool/make_release.gd
##
## 🔧 Godot Editor Script
## プラグイン一式を ZIP 化して配布用に出力します。
## 実行すると `res://addons/objid_tool_vX.X.zip` が生成されます。

@tool
extends EditorScript

func _run():
	var plugin_dir := "res://addons/objid_manager/"
	var output_zip := "res://objid_manager_v1.1.1.zip"

	var file_list := [
		"plugin.cfg",
		"objid_tool.gd",
		"objid_panel.gd",
		"objid_panel.tscn",
		"typescript_export_dialog.tscn",
		"typescript_export_dialog.gd",
		"icon.svg"
	]

	# ZIP作成
	var zip := ZIPPacker.new()
	var err := zip.open(output_zip)
	if err != OK:
		push_error("ZIP作成に失敗しました: %s" % output_zip)
		return

	for path in file_list:
		var full_path = plugin_dir + path
		if FileAccess.file_exists(full_path):
			var zip_path = "addons/objid_manager/" + path
			zip.start_file(zip_path)
			var data = FileAccess.get_file_as_bytes(full_path)
			
			# ★ UID削除フィルタ：.tscn / .tres のみ対象にする
			if path.ends_with(".tscn") or path.ends_with(".tres"):
				var text := data.get_string_from_utf8()

				# 1) [gd_scene ... uid="..."] の uid を削除
				var regex1 = RegEx.new()
				regex1.compile('\\[gd_scene([^\\]]*)\\suid="uid:\\/\\/[^\"]+"')
				text = regex1.sub(text, '[gd_scene$1', true)

				# 2) [ext_resource ... uid="..."] の uid を削除
				#    例: [ext_resource type="Script" uid="uid://xxxx" path="..." id="1_xxx"]
				var regex2 = RegEx.new()
				regex2.compile('\\[ext_resource([^\\]]*)\\suid="uid:\\/\\/[^\"]+"')
				text = regex2.sub(text, '[ext_resource$1', true)

				# 必要なら CRLF 正規化などもここで
				data = text.to_utf8_buffer()
			
			zip.write_file(data)
			zip.close_file()
			print("[ObjIdManager] Added:", zip_path)
		else:
			print("[ObjIdManager] Missing:", path)

	zip.close()
	print("[ObjIdManager] ✅ ZIP作成完了:", output_zip)
