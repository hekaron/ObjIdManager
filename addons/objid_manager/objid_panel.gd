@tool
extends Control

@export var plugin_ref: EditorPlugin

var all_nodes_tree_title: Label
var conflicts_count_label: Label
var show_conflicts_only: CheckBox
@onready var checked_tree = $VBoxContainer/CheckedTree
@onready var tree = $VBoxContainer/ObjTree
var btn_collapse_expand: Button
@onready var btn_refresh = $VBoxContainer/HBoxContainer/BtnRefresh
@onready var btn_assign = $VBoxContainer/HBoxContainer/BtnAssign
@onready var btn_ts_export = $VBoxContainer/HBoxContainer/BtnTSExport
@onready var start_num = $VBoxContainer/HBoxContainer2/StartNumber
@onready var same_number = $VBoxContainer/HBoxContainer2/UseSameNumber
@onready var btn_sync_selection = $VBoxContainer/CheckBtnSyncSceneSelection
@onready var ts_dialog = preload("res://addons/objid_manager/typescript_export_dialog.tscn").instantiate()

var current_language: String = "en"

var node_rows = [] # [{node: Node3D, item: TreeItem}]
var checked_order: Array[TreeItem] = []
var _checked_cat_roots: Dictionary = {}
var _checked_item_by_id: Dictionary = {}
var _category_items: Dictionary = {}
var _last_toggled_tree_item: TreeItem = null

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
		"CollapseExpandAll": "カテゴリを全て折りたたむ/展開",
		"ConflictsLabel": "競合",
		"ShowConflictsOnly": "競合のみ表示",
		"Column_NodeName": "ノード名",
		"Column_ObjId": "ObjId",
		"Action_ChangeObjId": "ObjIdを変更"
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
		"CollapseExpandAll": "Collapse/Expand All Categories",
		"ConflictsLabel": "Conflicts",
		"ShowConflictsOnly": "Show Conflicts Only",
		"Column_NodeName": "Node Name",
		"Column_ObjId": "ObjId",
		"Action_ChangeObjId": "Change ObjId"
	}
}

func set_language(locale: String) -> void:
	current_language = "ja" if locale.to_lower().begins_with("ja") else "en"

	if is_instance_valid(ts_dialog) and ts_dialog.has_method("set_language"):
		ts_dialog.call("set_language", current_language)

	if is_node_ready():
		update_texts()

func t(key: String) -> String:
	var lang_table: Dictionary = L10N.get(current_language, L10N["en"])
	if lang_table.has(key):
		return str(lang_table[key])

	var english_table: Dictionary = L10N["en"]
	if english_table.has(key):
		return str(english_table[key])

	push_warning("Missing localization key: %s" % key)
	return key

func _ready():
	if is_instance_valid(ts_dialog) and ts_dialog.has_method("set_language"):
		ts_dialog.call("set_language", current_language)

	_setup_header_controls()
	_setup_tree()
	update_texts()
	_hide_checked_tree_panel()

	btn_refresh.pressed.connect(refresh_list)
	if is_instance_valid(btn_collapse_expand):
		btn_collapse_expand.pressed.connect(_toggle_all_category_collapsed_state)
	btn_assign.pressed.connect(assign_ids)
	tree.item_edited.connect(_on_item_edited)
	tree.item_selected.connect(_on_item_selected)
	tree.gui_input.connect(_on_tree_gui_input)
	btn_ts_export.pressed.connect(_on_ts_button_pressed)
	btn_sync_selection.pressed.connect(_switch_tree_select_mode)
	if is_instance_valid(show_conflicts_only):
		show_conflicts_only.toggled.connect(_on_show_conflicts_only_toggled)
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
		
func _setup_header_controls() -> void:
	var container: VBoxContainer = get_node_or_null("VBoxContainer")
	if not container:
		return

	if not is_instance_valid(all_nodes_tree_title):
		all_nodes_tree_title = container.get_node_or_null("Label") as Label
	if not is_instance_valid(all_nodes_tree_title):
		all_nodes_tree_title = Label.new()
		all_nodes_tree_title.name = "Label"
		all_nodes_tree_title.text = t("AllNodesTitle")
		container.add_child(all_nodes_tree_title)

	if not is_instance_valid(conflicts_count_label):
		conflicts_count_label = container.get_node_or_null("ConflictsLabel") as Label
	if not is_instance_valid(conflicts_count_label):
		conflicts_count_label = Label.new()
		conflicts_count_label.name = "ConflictsLabel"
		conflicts_count_label.text = "Conflicts: 0"
		container.add_child(conflicts_count_label)
		container.move_child(conflicts_count_label, container.get_children().size() - 1)

	if not is_instance_valid(show_conflicts_only):
		show_conflicts_only = container.get_node_or_null("ShowConflictsOnly") as CheckBox
	if not is_instance_valid(show_conflicts_only):
		show_conflicts_only = CheckBox.new()
		show_conflicts_only.name = "ShowConflictsOnly"
		show_conflicts_only.text = t("ShowConflictsOnly")
		container.add_child(show_conflicts_only)
		container.move_child(show_conflicts_only, container.get_children().size() - 1)

	if not is_instance_valid(btn_collapse_expand):
		btn_collapse_expand = container.get_node_or_null("HBoxContainer3/BtnCollapseExpand") as Button
	if not is_instance_valid(btn_collapse_expand):
		var button_container: HBoxContainer = container.get_node_or_null("HBoxContainer3") as HBoxContainer
		if not is_instance_valid(button_container):
			button_container = HBoxContainer.new()
			button_container.name = "HBoxContainer3"
			container.add_child(button_container)
		btn_collapse_expand = Button.new()
		btn_collapse_expand.name = "BtnCollapseExpand"
		btn_collapse_expand.text = t("CollapseExpandAll")
		button_container.add_child(btn_collapse_expand)

# === 言語再描画 ===
func update_texts():
	if is_instance_valid(ts_dialog) and ts_dialog.has_method("set_language"):
		ts_dialog.call("set_language", current_language)

	btn_refresh.text = t("Refresh")
	btn_refresh.tooltip_text = t("Tooltip_Refresh")
	if is_instance_valid(btn_collapse_expand):
		btn_collapse_expand.text = t("CollapseExpandAll")

	btn_assign.text = t("BatchAssign")
	btn_assign.tooltip_text = t("Tooltip_BatchAssign")

	same_number.text = t("UseSameNumber")
	same_number.tooltip_text = t("Tooltip_UseSameNumber")
	
	btn_ts_export.text = t("OpenTSExportDialog")
	
	btn_sync_selection.text = t("CheckSceneSelection")

	if is_instance_valid(all_nodes_tree_title):
		all_nodes_tree_title.text = t("AllNodesTitle")
	if is_instance_valid(show_conflicts_only):
		show_conflicts_only.text = t("ShowConflictsOnly")
	_update_title_label()
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
	_hide_checked_tree_panel()

func _hide_checked_tree_panel() -> void:
	if is_instance_valid(checked_tree):
		checked_tree.visible = false

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
	checked_tree.visible = false


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
	var checked_ids: Array = []
	for row in node_rows:
		if row and row.item and row.item.is_checked(0):
			checked_ids.append(row.node.get_instance_id())

	tree.clear()
	node_rows.clear()
	checked_order.clear()
	_category_items.clear()
	_last_toggled_tree_item = null

	var scene: Node = get_tree().edited_scene_root
	if not scene:
		push_warning("No scene open or not saved.")
		return

	var root: TreeItem = tree.create_item()
	var category_items: Dictionary = {}
	var all_nodes: Array[Node3D] = []
	
	var warned_nodes: Array[StringName] = []

	for node_obj: Object in _walk(scene):
		if node_obj == null or not node_obj is Node3D:
			continue
		if not ("ObjId" in node_obj):
			continue

		all_nodes.append(node_obj)

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
			cat_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			cat_item.set_editable(0, true)
			cat_item.set_editable(1, false)
			cat_item.set_checked(0, false)
			cat_item.set_text(0, category_name)
			cat_item.set_text(1, "")
			cat_item.set_selectable(0, true)
			cat_item.set_selectable(1, false)
			cat_item.collapsed = false
			cat_item.set_meta("category_name", category_name)
			category_items[category_name] = cat_item
			_category_items[category_name] = cat_item

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

	var visible_nodes: Array[Node3D] = []
	if is_instance_valid(show_conflicts_only) and show_conflicts_only.button_pressed:
		var duplicates: Dictionary = {}
		for node_obj in all_nodes:
			var id_text := str(node_obj.ObjId)
			if id_text in ["", "-1", "0"]:
				continue
			if id_text not in duplicates:
				duplicates[id_text] = []
			duplicates[id_text].append(node_obj)
		for id_text in duplicates.keys():
			if len(duplicates[id_text]) > 1:
				for conflict_node in duplicates[id_text]:
					visible_nodes.append(conflict_node)
	else:
		visible_nodes = all_nodes

	tree.clear()
	node_rows.clear()
	_category_items.clear()
	checked_order.clear()
	_last_toggled_tree_item = null

	var filtered_root: TreeItem = tree.create_item()
	var filtered_category_items: Dictionary = {}
	var warned_nodes_again: Array[StringName] = []

	for node_obj in visible_nodes:
		if node_obj == null or not node_obj is Node3D:
			continue
		if not ("ObjId" in node_obj):
			continue

		var category_name := _get_category_name(node_obj)
		if not filtered_category_items.has(category_name):
			var cat_item: TreeItem = tree.create_item(filtered_root)
			cat_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			cat_item.set_editable(0, true)
			cat_item.set_editable(1, false)
			cat_item.set_checked(0, false)
			cat_item.set_text(0, category_name)
			cat_item.set_text(1, "")
			cat_item.set_selectable(0, true)
			cat_item.set_selectable(1, false)
			cat_item.collapsed = false
			cat_item.set_meta("category_name", category_name)
			cat_item.set_meta("is_category", true)
			filtered_category_items[category_name] = cat_item
			_category_items[category_name] = cat_item

		var parent_item: TreeItem = filtered_category_items[category_name]
		var item: TreeItem = tree.create_item(parent_item)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		_ti_set_checkable(item, 0, true)
		_ti_set_text(item, 0, node_obj.name)
		item.set_checked(0, false)
		_ti_set_text(item, 1, str(node_obj.ObjId))
		_ti_set_editable(item, 1, true)
		item.set_meta("category_name", category_name)
		item.set_meta("is_category", false)
		node_rows.append({"node": node_obj, "item": item})

	for row in node_rows:
		if checked_ids.has(row.node.get_instance_id()):
			row.item.set_checked(0, true)

	_refresh_category_checkboxes()
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
				_refresh_checkbox_state_ui()
			break
	
func _sync_checked_order_from_tree() -> void:
	var ordered_checked: Array[TreeItem] = []
	for item in checked_order:
		if not item:
			continue
		for row in node_rows:
			if row and row.item == item and row.item.is_checked(0):
				ordered_checked.append(item)
				break
	
	for row in node_rows:
		if not row or not is_instance_valid(row.node) or not row.item:
			continue
		if row.item.is_checked(0) and not ordered_checked.has(row.item):
			ordered_checked.append(row.item)

	checked_order = ordered_checked

	for idx in range(checked_order.size()):
		var item: TreeItem = checked_order[idx]
		if item and is_instance_valid(item):
			var base_text := _strip_order_prefix(item.get_text(0))
			item.set_text(0, "[%d] %s" % [idx + 1, base_text])

	for row in node_rows:
		if not row or not is_instance_valid(row.node) or not row.item:
			continue
		if not row.item.is_checked(0):
			var base_text := _strip_order_prefix(row.item.get_text(0))
			row.item.set_text(0, base_text)

func _refresh_checkbox_state_ui() -> void:
	_sync_checked_order_from_tree()
	_refresh_category_checkboxes()
	_update_checked_tree_display()
	_update_duplicates()

func _refresh_category_checkboxes() -> void:
	for category_name in _category_items:
		var cat_item: TreeItem = _category_items[category_name]
		if not is_instance_valid(cat_item):
			continue
		var has_checked := false
		var all_checked := true
		for row in node_rows:
			if not row or not is_instance_valid(row.node) or not row.item:
				continue
			if _get_category_name(row.node) != category_name:
				continue
			if row.item.is_checked(0):
				has_checked = true
			else:
				all_checked = false
		if has_checked and all_checked:
			cat_item.set_checked(0, true)
		else:
			cat_item.set_checked(0, false)

func _get_item_category_name(item: TreeItem) -> String:
	if not is_instance_valid(item):
		return ""
	var meta := item.get_meta("category_name")
	if meta != null and str(meta) != "":
		return str(meta)
	for row in node_rows:
		if row and row.item == item:
			return _get_category_name(row.node)
	return ""

func _is_category_item(item: TreeItem) -> bool:
	if not is_instance_valid(item):
		return false
	var is_category = item.get_meta("is_category")
	if is_category == null:
		return false
	return bool(is_category)

func _toggle_rows_in_range(start_item: TreeItem, end_item: TreeItem, checked: bool) -> void:
	var start_index := -1
	var end_index := -1
	for idx in range(node_rows.size()):
		var row = node_rows[idx]
		if row.item == start_item:
			start_index = idx
		if row.item == end_item:
			end_index = idx
	if start_index < 0 or end_index < 0:
		return

	var start_category := _get_item_category_name(start_item)
	if start_category == "":
		return

	var affected_items: Array[TreeItem] = []
	var step := 1 if start_index <= end_index else -1
	var idx := start_index
	while true:
		var row = node_rows[idx]
		if row and row.item:
			var row_category := _get_item_category_name(row.item)
			if row_category == start_category:
				row.item.set_checked(0, checked)
				affected_items.append(row.item)
		if idx == end_index:
			break
		idx += step

	if checked:
		for item in affected_items:
			if checked_order.has(item):
				checked_order.erase(item)
			if item.is_checked(0):
				checked_order.append(item)
	else:
		for item in affected_items:
			if checked_order.has(item):
				checked_order.erase(item)

	_refresh_checkbox_state_ui()

func _toggle_category_rows(category_name: String, checked: bool) -> void:
	for row in node_rows:
		if not row or not is_instance_valid(row.node) or not row.item:
			continue
		if _get_category_name(row.node) != category_name:
			continue
		row.item.set_checked(0, checked)
	_refresh_checkbox_state_ui()

func _on_tree_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var item: TreeItem = tree.get_item_at_position(mouse_event.position)
	if not item:
		return

	var column: int = tree.get_column_at_position(mouse_event.position)
	if not _is_category_item(item):
		return

	var category_name: String = item.get_meta("category_name")
	if category_name == "":
		return

	var cell_rect: Rect2 = tree.get_item_area_rect(item, column)
	var click_x: float = mouse_event.position.x - cell_rect.position.x
	var arrow_width: float = 18.0
	var left_indent_width: float = 16.0
	var checkbox_zone_width: float = 24.0

	if column != 0:
		return

	if click_x <= arrow_width + left_indent_width:
		_tree_set_item_collapsed(item, not item.collapsed)
		tree.accept_event()
		return

	if click_x > arrow_width + left_indent_width + checkbox_zone_width:
		if click_x > arrow_width + left_indent_width + 220.0:
			return

	var checked: bool = not item.is_checked(0)
	item.set_checked(0, checked)
	_toggle_category_rows(category_name, checked)
	tree.accept_event()

func _tree_set_item_collapsed(item: TreeItem, collapsed: bool) -> void:
	if is_instance_valid(item):
		item.collapsed = collapsed

func _toggle_all_category_collapsed_state() -> void:
	var should_collapse := false
	for category_name in _category_items:
		var category_item: TreeItem = _category_items[category_name]
		if is_instance_valid(category_item) and not category_item.collapsed:
			should_collapse = true
			break

	for category_name in _category_items:
		var category_item: TreeItem = _category_items[category_name]
		if is_instance_valid(category_item):
			category_item.collapsed = should_collapse

func _clear_all_selections() -> void:
	for row in node_rows:
		if row and row.item:
			row.item.set_checked(0, false)
	checked_order.clear()
	_last_toggled_tree_item = null
	_refresh_checkbox_state_ui()
	if is_instance_valid(tree):
		tree.deselect_all()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_clear_all_selections()

# === ObjIdセル編集時 ===
func _on_item_edited() -> void:
	var item: TreeItem = tree.get_edited()
	if not is_instance_valid(item):
		return

	var edit_col: int = tree.get_edited_column()

	if edit_col == 0:
		# カテゴリ行は、配下のノードをまとめて切り替える。
		if _is_category_item(item):
			var category_name := _get_item_category_name(item)
			if category_name != "":
				_toggle_category_rows(category_name, item.is_checked(0))
			return

		# 通常のノード行のチェック状態を反映する。
		var checked := item.is_checked(0)
		if (
			Input.is_key_pressed(KEY_SHIFT)
			and is_instance_valid(_last_toggled_tree_item)
			and _last_toggled_tree_item != item
		):
			_toggle_rows_in_range(_last_toggled_tree_item, item, checked)
		else:
			item.set_checked(0, checked)
			_refresh_checkbox_state_ui()

		_last_toggled_tree_item = item
		return

	if edit_col != 1:
		return

	# カテゴリ行のObjId列は編集対象外。
	if _is_category_item(item):
		return

	var target_node: Node3D = null
	for row in node_rows:
		if row and row.item == item and is_instance_valid(row.node):
			target_node = row.node
			break

	if not is_instance_valid(target_node):
		return

	var text_val := item.get_text(1).strip_edges()
	if not text_val.is_valid_int():
		# 不正な入力を0へ変換せず、実際の値へ戻す。
		item.set_text(1, str(target_node.ObjId))
		return

	var new_val := text_val.to_int()
	var old_val: int = int(target_node.ObjId)
	if old_val == new_val:
		item.set_text(1, str(old_val))
		return

	var ur: EditorUndoRedoManager = plugin_ref.get_undo_redo()
	ur.create_action(t("Action_ChangeObjId"))
	ur.add_do_property(target_node, "ObjId", new_val)
	ur.add_undo_property(target_node, "ObjId", old_val)
	ur.add_do_method(self, "_after_objid_changed", target_node, new_val)
	ur.add_undo_method(self, "_after_objid_changed", target_node, old_val)
	ur.commit_action()

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
func _count_duplicate_conflicts() -> int:
	var count_map: Dictionary = {}
	for row in node_rows:
		var id_text = row.item.get_text(1)
		if id_text in ["", "-1", "0"]:
			continue
		if id_text not in count_map:
			count_map[id_text] = 0
		count_map[id_text] += 1

	var conflict_count := 0
	for count in count_map.values():
		if count > 1:
			conflict_count += 1
	return conflict_count

func _update_title_label() -> void:
	var base_text := t("AllNodesTitle")
	var conflict_count := _count_duplicate_conflicts()
	if is_instance_valid(all_nodes_tree_title):
		all_nodes_tree_title.text = base_text
	if is_instance_valid(conflicts_count_label):
		conflicts_count_label.text = "%s: %d" % [t("ConflictsLabel"), conflict_count]

func _on_show_conflicts_only_toggled(_pressed: bool) -> void:
	refresh_list()

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

	_update_title_label()
		
func _collect_export_rows() -> Array:
	var rows: Array = []
	var scene: Node = get_tree().edited_scene_root
	if not is_instance_valid(scene):
		return rows

	# Export is deliberately collected from the scene itself rather than
	# node_rows. node_rows is a filtered view while "Show Conflicts Only" is
	# enabled, and must not control whether the export dialog can open.
	for node_obj: Object in _walk(scene):
		if node_obj == null or not node_obj is Node3D:
			continue
		if not ("ObjId" in node_obj):
			continue
		if node_obj.ObjId == -1:
			continue
		rows.append({"node": node_obj})

	return rows

func _on_ts_button_pressed() -> void:
	# When the export window is already open, the Export button acts as a
	# "recall window" action. Preserve its check state, generated code, size,
	# and position instead of rebuilding it.
	if is_instance_valid(ts_dialog) and ts_dialog.visible:
		if ts_dialog.has_method("bring_to_front"):
			ts_dialog.call("bring_to_front")
		else:
			if ts_dialog.mode == Window.MODE_MINIMIZED:
				ts_dialog.mode = Window.MODE_WINDOWED
			ts_dialog.call_deferred("grab_focus")
		return

	var list_items := _collect_export_rows()
	if list_items.is_empty():
		push_warning("No valid ObjId nodes available for TypeScript export.")
		return

	if not is_instance_valid(ts_dialog):
		ts_dialog = preload("res://addons/objid_manager/typescript_export_dialog.tscn").instantiate()

	if ts_dialog.get_parent() != self:
		add_child(ts_dialog)

	# Do not access @onready controls or call populate_list until the newly
	# instantiated dialog has completed _ready().
	if not ts_dialog.is_node_ready():
		await ts_dialog.ready

	if ts_dialog.has_method("set_language"):
		ts_dialog.call("set_language", current_language)

	await ts_dialog.populate_list(list_items)
	if ts_dialog.has_method("popup_fitted"):
		await ts_dialog.popup_fitted()
	else:
		ts_dialog.popup_centered()


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
	elif script_name == "CapturePoint":
		return "Capture Point"
	elif script_name == "AI_WaypointPath":
		return "AI Path"
	elif script_name == "AreaTrigger":
		return "Trigger"
	elif script_name == "CombatArea":
		return "Combat Area"
	elif script_name == "DeployCam":
		return "Deploy Camera"
	elif script_name == "FixedCamera":
		return "Fixed Camera"
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
	elif script_name == "LootSpawner":
		return "Loot Spawner"
	elif script_name == "SpawnPoint":
		return "Spawn Point" 
	elif script_name == "WorldIcon":
		return "World Icon"
	elif script_name == "RingOfFire":
		return "Ring Of Fire"
	elif script_name == "HeatZone":
		return "Heat Zone"
	elif script_name == "VL7Cloud":
		return "VL7 Cloud"
	elif script_name == "MCOM":
		return "MCOM"
	elif script_name == "Bomb":
		return "Bomb"
	else:
		return "Spatial Object"

func _strip_order_prefix(s: String) -> String:
	var r := RegEx.new()
	r.compile("^\\[\\d+\\]\\s*")
	return r.sub(s, "", true)
