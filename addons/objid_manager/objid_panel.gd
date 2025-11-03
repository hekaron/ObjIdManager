@tool
extends Control

@export var plugin_ref: EditorPlugin

@onready var all_nodes_tree_title = $VBoxContainer/Label
@onready var checked_tree = $VBoxContainer/CheckedTree
@onready var tree = $VBoxContainer/ObjTree
@onready var btn_refresh = $VBoxContainer/HBoxContainer/BtnRefresh
@onready var btn_assign = $VBoxContainer/HBoxContainer/BtnAssign
@onready var btn_ts_export = $VBoxContainer/HBoxContainer/BtnTSExport
@onready var start_num = $VBoxContainer/HBoxContainer2/StartNumber
@onready var same_number = $VBoxContainer/HBoxContainer2/UseSameNumber
@onready var btn_sync_selection = $VBoxContainer/CheckBtnSyncSceneSelection
@onready var ts_dialog = preload("res://addons/objid_manager/typescript_export_dialog.tscn").instantiate()

var node_rows = [] # [{node: Node3D, item: TreeItem}]
var checked_order: Array[TreeItem] = []
var _checked_cat_roots: Dictionary = {}
var _checked_item_by_id: Dictionary = {}

var L10N = {
	"ja": {
		"Refresh": "更新",
		"Tooltip_Refresh": "シーン内のObjIdリストを再読み込みします",
		"BatchAssign": "一括設定",
		"Tooltip_BatchAssign": "チェックされたノードに連番または同一番号を一括設定します",
		"UseSameNumber": "同じ番号を使う",
		"Tooltip_UseSameNumber": "オンの場合、すべての選択ノードに同じObjIdを設定します",
		"CheckSceneSelection": "シーン上で選択したノードにチェックを付ける",
		"OpenTSExportDialog": "コード出力",
		"CheckedNodes": "チェック済みノード",
		"AllNodesTitle": "全ノード",
		"Column_NodeName": "ノード名",
		"Column_ObjId": "ObjId"
	},
	"en": {
		"Refresh": "Refresh",
		"Tooltip_Refresh": "Refresh the ObjId list from the current scene",
		"BatchAssign": "Batch Assign",
		"Tooltip_BatchAssign": "Assign sequential or identical ObjIds to selected nodes",
		"UseSameNumber": "Use Same Number",
		"Tooltip_UseSameNumber": "If ON, sets the same ObjId for all selected nodes",
		"CheckSceneSelection": "Check node when selected in scene",
		"OpenTSExportDialog": "Export",
		"CheckedNodes": "Checked nodes",
		"AllNodesTitle": "All nodes",
		"Column_NodeName": "Node Name",
		"Column_ObjId": "ObjId"
	}
}

func t(key: String) -> String:
	var lang := TranslationServer.get_locale()
	if L10N.has(lang) and L10N[lang].has(key):
		return L10N[lang][key]
	return L10N["en"][key]

func _ready():
	_setup_tree()
	update_texts()

	btn_refresh.pressed.connect(refresh_list)
	btn_assign.pressed.connect(assign_ids)
	tree.item_edited.connect(_on_item_edited)
	tree.item_selected.connect(_on_item_selected)
	btn_ts_export.pressed.connect(_on_ts_button_pressed)
	btn_sync_selection.pressed.connect(_switch_tree_select_mode)
	add_child(ts_dialog)
	ts_dialog.hide()

	refresh_list()
	_setup_checked_tree()
	
	start_num.max_value = 999999
	start_num.allow_greater = true
	start_num.allow_lesser = true
	start_num.step = 1
	start_num.rounded = true
	
func on_plugin_ready():
	var editor_sel = plugin_ref.get_editor_interface().get_selection()
	editor_sel.selection_changed.connect(_on_editor_selection_changed)
	
func _exit_tree():
	if is_instance_valid(ts_dialog):
		ts_dialog.queue_free()
		ts_dialog = null
		
# === 言語再描画 ===
func update_texts():
	btn_refresh.text = t("Refresh")
	btn_refresh.tooltip_text = t("Tooltip_Refresh")

	btn_assign.text = t("BatchAssign")
	btn_assign.tooltip_text = t("Tooltip_BatchAssign")

	same_number.text = t("UseSameNumber")
	same_number.tooltip_text = t("Tooltip_UseSameNumber")
	
	btn_ts_export.text = t("OpenTSExportDialog")
	
	btn_sync_selection.text = t("CheckSceneSelection")

	all_nodes_tree_title.text = t("AllNodesTitle")
	tree.columns = 2
	tree.set_column_titles_visible(true)

	var cols = tree.columns
	if cols > 0:
		tree.set_column_title(0, t("Column_NodeName"))
	if cols > 1:
		tree.set_column_title(1, t("Column_ObjId"))
		
	for row in node_rows:
		row.item.set_text(1, str(row.node.ObjId))


# === Tree初期設定 ===
func _setup_tree():
	_setup_columns_for(tree)
	
	tree.hide_root = false
	
func _setup_checked_tree():
	_setup_columns_for(checked_tree)
	checked_tree.hide_root = false
	checked_tree.visible = false
	checked_tree.column_titles_visible = false
	checked_tree.item_edited.connect(_on_checked_tree_item_edited)

func _setup_columns_for(t: Tree) -> void:
	t.columns = 2
	t.set_column_titles_visible(true)
	t.set_column_title(0, t("Column_NodeName"))
	t.set_column_title(1, t("Column_ObjId"))
	t.set_column_expand(0, true)
	t.set_column_expand(1, false)
	t.set_column_custom_minimum_width(1, 90)
	
func _on_checked_tree_item_edited() -> void:
	var item: TreeItem = checked_tree.get_edited()
	if not item:
		return
	var col = checked_tree.get_edited_column()

	var node: Node3D = item.get_meta("node")
	var main_item: TreeItem = item.get_meta("main_item")

	if col == 0:
		# チェックを外したらメイン側も外す
		if not item.is_checked(0):
			if main_item:
				# 既存のチェック解除ロジックと整合させる
				main_item.set_checked(0, false)
				# ラベルから [n] を外すなど既存処理と同じに
				var base := _strip_order_prefix(main_item.get_text(0))
				main_item.set_text(0, base)
				# checked_order からも除外（既存配列）
				if checked_order.has(main_item):
					checked_order.erase(main_item)
			_update_checked_tree_display()
			_update_duplicates()
		return

	if col == 1:
		# ObjId 編集（Undo/Redo）
		var new_val := int(item.get_text(1))
		var old_val = node.ObjId
		if new_val == old_val:
			return

		var ur: EditorUndoRedoManager = plugin_ref.get_undo_redo()  # EditorPlugin から注入している UndoRedo
		ur.create_action(t("Action_ChangeObjId"))
		ur.add_do_property(node, "ObjId", new_val)
		ur.add_undo_property(node, "ObjId", old_val)
		# UI更新は両側必要
		ur.add_do_method(self, "_after_objid_changed", node, new_val)
		ur.add_undo_method(self, "_after_objid_changed", node, old_val)
		ur.commit_action()
		
func _after_objid_changed(node: Node3D, value: int) -> void:
	# メインツリー側
	for row in node_rows:
		if row.node == node:
			row.item.set_text(1, str(value))
			break
	# チェック済み側
	var ci := _checked_item_by_id.get(node.get_instance_id(), null)
	if ci:
		ci.set_text(1, str(value))

	_update_duplicates()
	
func _update_checked_tree_display() -> void:
	checked_tree.clear()
	_checked_cat_roots.clear()
	_checked_item_by_id.clear()

	var any := false
	var root: TreeItem = checked_tree.create_item()
	root.set_text(0, t("CheckedNodes"))  # 必要なら翻訳キー

	# 既存の node_rows を走査し、「メインツリーでチェック済み」のみ抜き出し
	for row in node_rows:
		if not row or not is_instance_valid(row.node) or not row.item:
			continue
		if not row.item.is_checked(0):
			continue

		any = true

		var node: Node3D = row.node
		var cat := _get_category_name(node)  # 既存のカテゴリ判定関数をそのまま利用
		var cat_item: TreeItem = _checked_cat_roots.get(cat, null)
		if cat_item == null:
			cat_item = checked_tree.create_item(root)
			cat_item.set_text(0, cat)
			cat_item.set_selectable(0, false)
			cat_item.set_editable(0, false)
			_checked_cat_roots[cat] = cat_item

		var ci: TreeItem = checked_tree.create_item(cat_item)
		# 列0: チェック + 名前（番号[ n ]を付けない素の名前が良ければ正規表現で剥がす）
		ci.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		ci.set_checked(0, true)
		ci.set_editable(0, true)
		ci.set_text(0, _strip_order_prefix(row.item.get_text(0)))
		ci.set_meta("node", node)
		ci.set_meta("main_item", row.item)

		# 列1: ObjId（編集可）
		ci.set_text(1, str(node.ObjId))
		ci.set_editable(1, true)

		_checked_item_by_id[node.get_instance_id()] = ci

	checked_tree.visible = any


# 安全にセルへアクセスする小ユーティリティ
func _ti_set_text(item: TreeItem, col: int, text: String) -> void:
	if col < tree.columns:
		item.set_text(col, text)

func _ti_set_checkable(item: TreeItem, col: int, checkable: bool) -> void:
	if col < tree.columns:
		item.set_cell_mode(col, TreeItem.CELL_MODE_CHECK)
		item.set_editable(col, true)
		item.set_checked(col, checkable)

func _ti_set_editable(item: TreeItem, col: int, editable: bool) -> void:
	if col < tree.columns:
		item.set_editable(col, editable)

# === 一覧更新 ===
func refresh_list():
	tree.clear()
	node_rows.clear()
	checked_order.clear()

	var scene: Node = get_tree().edited_scene_root
	if not scene:
		push_warning("No scene open or not saved.")
		return

	var root: TreeItem = tree.create_item()
	var category_items: Dictionary = {}
	
	var warned_nodes: Array[StringName] = []

	for node_obj: Object in _walk(scene):
		if node_obj == null or not node_obj is Node3D:
			continue
		if not ("ObjId" in node_obj):
			continue

		# --- スケール警告 ---
		var scale_vec: Vector3 = node_obj.scale
		if node_obj.name not in warned_nodes:
			if scale_vec.is_equal_approx(Vector3.ZERO):
				push_warning("Node '%s' has zero scale. It may cause continuous Basis errors in the editor. Please set a small non-zero scale such as 0.001." % node_obj.name)
				warned_nodes.append(node_obj.name)
			elif abs(scale_vec.x) < 0.0001 or abs(scale_vec.y) < 0.0001 or abs(scale_vec.z) < 0.0001:
				push_warning("Node '%s' has very small scale (%.6f, %.6f, %.6f). Consider using at least 0.001 to avoid Basis errors." % [node_obj.name, scale_vec.x, scale_vec.y, scale_vec.z])
				warned_nodes.append(node_obj.name)

		# --- カテゴリ判定 ---
		var category_name := _get_category_name(node_obj)

		# --- 親カテゴリItemの取得 or 生成 ---
		if not category_items.has(category_name):
			var cat_item: TreeItem = tree.create_item(root)
			cat_item.set_text(0, category_name)
			cat_item.set_editable(0, false)
			cat_item.collapsed = false
			category_items[category_name] = cat_item

		var parent_item: TreeItem = category_items[category_name]

		# --- ノード行 ---
		var item: TreeItem = tree.create_item(parent_item)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)  # チェックボックス追加
		_ti_set_checkable(item, 0, true)
		_ti_set_text(item, 0, node_obj.name)
		item.set_checked(0, false)
		_ti_set_text(item, 1, str(node_obj.ObjId))
		_ti_set_editable(item, 1, true)

		node_rows.append({"node": node_obj, "item": item})

	_update_duplicates()

# === 再帰走査 ===
func _walk(node: Node) -> Array:
	var out: Array = []
	var stack: Array = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current != node:
			out.append(current)
		for c in current.get_children():
			stack.append(c)
	return out

# === 一括設定 ===
func assign_ids():
	start_num.release_focus()
	
	if checked_order.is_empty():
		push_warning("No checked nodes for batch assign.")
		return

	var ur: EditorUndoRedoManager = plugin_ref.get_undo_redo()
	ur.create_action("Batch Set ObjId")

	var start_val: int = int(start_num.value)
	var use_same: bool = same_number.button_pressed
	var current: int = start_val

	# チェック順に沿って適用
	for item in checked_order:
		var match_rows = node_rows.filter(func(r): return r.item == item)
		if match_rows.is_empty():
			continue
		var node: Node3D = match_rows[0].node
		ur.add_do_property(node, "ObjId", current)
		ur.add_undo_property(node, "ObjId", node.ObjId)
		if not use_same:
			current += 1

	ur.add_do_method(self, "refresh_list")
	ur.add_undo_method(self, "refresh_list")
	ur.commit_action()
	
func _highlight_tree_item_for_node(node):
	for row in node_rows:
		if row.node == node:
			var item: TreeItem = row.item
			item.select(0)
			tree.ensure_cursor_is_visible()
			return
			
func _switch_tree_select_mode():
	tree.allow_reselect = not btn_sync_selection.pressed

func _on_editor_selection_changed():
	if not btn_sync_selection.button_pressed:
		return
	
	var editor_if = plugin_ref.get_editor_interface()
	var editor_sel = editor_if.get_selection()
	var selected_nodes = editor_sel.get_selected_nodes()
	if selected_nodes.is_empty():
		return
	
	for node in selected_nodes:
		_check_tree_item_for_node(node)
		_highlight_tree_item_for_node(node)
		
func _check_tree_item_for_node(node: Node):
	for row in node_rows:
		if row.node == node:
			var item: TreeItem = row.item
			if not item.is_checked(0):
				item.set_checked(0, true)
				if not checked_order.has(item):
					checked_order.append(item)
					var base_text := _strip_order_prefix(item.get_text(0))
					item.set_text(0, "[%d] %s" % [checked_order.size(), base_text])
			break
	
# === ObjIdセル編集時 ===
func _on_item_edited():
	var item: TreeItem = tree.get_edited()
	if not item:
		return

	var edit_col = tree.get_edited_column()
	if edit_col == 0:
		if item.get_cell_mode(0) == TreeItem.CELL_MODE_CHECK:
			if item.is_checked(0):
				# チェック追加
				if not checked_order.has(item):
					checked_order.append(item)
					var base_text := item.get_text(0)
					var regex := RegEx.new()
					regex.compile("^\\[\\d+\\]\\s*")
					base_text = regex.sub(base_text, "", true)
					item.set_text(0, "[%d] %s" % [checked_order.size(), base_text])
			else:
				# チェック解除
				if checked_order.has(item):
					checked_order.erase(item)
					var base_text := item.get_text(0)
					var regex := RegEx.new()
					regex.compile("^\\[\\d+\\]\\s*")
					base_text = regex.sub(base_text, "", true)
					item.set_text(0, base_text)
					
			_update_duplicates()
		return
		
	if edit_col == 1:
		# ObjId 列の編集
		var text_val: String = item.get_text(1)
		var new_val := text_val.to_int()
		for row in node_rows:
			if row.item == item:
				var node: Node3D = row.node
				var old_val = node.ObjId
				if old_val == new_val:
					continue
				var ur: = plugin_ref.get_undo_redo()
				ur.create_action(t("Action_ChangeObjId"))
				ur.add_do_property(node, "ObjId", new_val)
				ur.add_undo_property(node, "ObjId", old_val)
				ur.add_do_method(self, "refresh_list")
				ur.add_undo_method(self, "refresh_list")
				ur.commit_action()
				break
		
		_update_checked_tree_display()
		_update_duplicates()

# === Treeで選択したらエディタ上でも選択 ===
func _on_item_selected():
	var selected_item: TreeItem = tree.get_selected()
	if not selected_item:
		return

	for row in node_rows:
		if row.item == selected_item:
			var node: Node3D = row.node
			if node and node.is_inside_tree():
				plugin_ref.get_editor_interface().get_selection().clear()
				plugin_ref.get_editor_interface().get_selection().add_node(node)
			break

# === ObjId重複検出＆ハイライト ===
func _update_duplicates():
	var count_map: Dictionary = {}
	for row in node_rows:
		var id_text = row.item.get_text(1)
		if id_text not in count_map:
			count_map[id_text] = []
		count_map[id_text].append(row.item)

	for id_text in count_map.keys():
		var items = count_map[id_text]
		var is_duplicate = (len(items) > 1 and id_text not in ["-1", "0"])
		for i in items:
			if is_duplicate:
				i.set_custom_color(1, Color(1, 0.4, 0.4))
			else:
				i.clear_custom_color(1)
				
func _on_ts_button_pressed():
	# リスト初期化・フィルタ
	var list_items: Array = []
	for row in node_rows:
		if row.node.ObjId == -1:
			continue
			
		list_items.append(row)
	
	if list_items.is_empty():
		push_warning("No valid ObjId nodes available for TypeScript export.")
		return
		
	if not has_node("TypeScriptExportDialog"):
		add_child(ts_dialog)
	ts_dialog.populate_list(list_items)
	ts_dialog.popup_centered()
	ts_dialog.show()


func _get_category_name(node_obj: Object) -> String:
	if not node_obj.get_script():
		return "Spatial Object"

	var script_name := ""
	if node_obj.get_script().has_source_code():
		script_name = node_obj.get_script().get_path().get_file().get_basename()
	else:
		script_name = node_obj.get_script().get_class()

	if script_name.begins_with("VEH_"):
		return "Vehicle"
	elif script_name.begins_with("SFX_"):
		return "Sound"
	elif script_name.begins_with("FX_") or script_name.begins_with("fx_") or script_name.begins_with("VFX_"):
		return "Visual FX"
	elif script_name == "AI_Spawner":
		return "AI Spawner"
	elif script_name == "AI_WaypointPath":
		return "AI Path"
	elif script_name == "AreaTrigger":
		return "Trigger"
	elif script_name == "CombatArea":
		return "Combat Area"
	elif script_name == "DeployCam":
		return "Deploy Camera"
	elif script_name == "HQ_PlayerSpawner":
		return "HQ Spawner"
	elif script_name == "InteractPoint":
		return "Interact Point"
	elif script_name == "PlayerSpawner":
		return "Player Spawner"
	elif script_name == "Sector":
		return "Sector"
	elif script_name == "StationaryEmplacementSpawner":
		return "Emplacement Spawner"
	elif script_name == "SurroundingCombatArea":
		return "Surrounding Area"
	elif script_name == "VehicleSpawner":
		return "Vehicle Spawner"
	elif script_name == "SpawnPoint":
		return "Spawn Point" 
	elif script_name == "WorldIcon":
		return "World Icon"
	elif script_name == "MCOM":
		return "MCOM"
	else:
		return "Spatial Object"

func _strip_order_prefix(s: String) -> String:
	var r := RegEx.new()
	r.compile("^\\[\\d+\\]\\s*")
	return r.sub(s, "", true)
