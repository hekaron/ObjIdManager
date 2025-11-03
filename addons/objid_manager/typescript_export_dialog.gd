@tool
extends AcceptDialog

@onready var root_ctrl: Control = $RootControl
@onready var root_vb: VBoxContainer = $RootControl/MarginContainer/VBoxContainer
@onready var label_guide: Label = $RootControl/MarginContainer/VBoxContainer/Label
@onready var sc: ScrollContainer = $RootControl/MarginContainer/VBoxContainer/ScrollContainer
@onready var var_name_field: LineEdit = $RootControl/MarginContainer/VBoxContainer/HBoxContainer/VarNameField
@onready var panel_bg: PanelContainer = $RootControl/MarginContainer/VBoxContainer/ScrollContainer/PanelContainer
@onready var node_container: VBoxContainer = $RootControl/MarginContainer/VBoxContainer/ScrollContainer/PanelContainer/NodeContainer
@onready var btn_check_all: Button = $RootControl/MarginContainer/VBoxContainer/HBoxContainer/BtnCheckAll
@onready var btn_uncheck_all: Button = $RootControl/MarginContainer/VBoxContainer/HBoxContainer/BtnUncheckAll
@onready var btn_convert: Button = $RootControl/MarginContainer/VBoxContainer/HBoxContainer/BtnConvert
@onready var btn_copy: Button = $RootControl/MarginContainer/VBoxContainer/HBoxContainer/BtnCopy
@onready var label_notice: Label = $RootControl/MarginContainer/VBoxContainer/NoticeLabel
@onready var code_display: TextEdit = $RootControl/MarginContainer/VBoxContainer/CodeDisplay

var L10N = {
	"ja": {
		"Title": "TypeScript変換",
		"ButtonCloseDialog": "閉じる",
		"ButtonCheckAll": "全てチェック",
		"ButtonUncheckAll": "全解除",
		"ButtonConvert": "変換",
		"ButtonCopy": "コピー",
		"LabelGuide": "下で入力した名前の変数にチェックを付けた順番で値が入った配列を定義するコードを出力します。",
		"LabelNotice": "※-1は使わない物とみなし非表示。CombatArea/DeployCam/Surrounding..は現在取得不能のため除外。",
		"PlaceholderVarNameField": "変数名を入力",
		"WarningEmptyVariableName": "変数名を入力してください。",
		"WarningNoneChecked": "1つ以上の項目を選択してください。",
		"WarningNoneCopyContent": "コピーする内容がありません。",
	},
	"en": {
		"Title": "Convert to TypeScript",
		"ButtonCloseDialog": "Close",
		"ButtonCheckAll": "Check All",
		"ButtonUncheckAll": "Uncheck All",
		"ButtonConvert": "Convert",
		"ButtonCopy": "Copy",
		"LabelGuide": "Generates code to define an array with the variables named in the input field below,\nin the order they were checked.",
		"LabelNotice": "-1 was treated as unused and hidden. CombatArea/DeployCam/SurroundingCombatArea were excluded\nbecause they cannot currently be declared as objects.",
		"PlaceholderVarNameField": "Enter the variable name.",
		"WarningEmptyVariableName": "Please enter a variable name.",
		"WarningNoneChecked": "Please check one or more items.",
		"WarningNoneCopyContent": "There is no content to copy.",
	}
}

func trl(key: String) -> String:
	var lang := TranslationServer.get_locale()
	if L10N.has(lang) and L10N[lang].has(key):
		return L10N[lang][key]
	return L10N["en"][key]

var CATEGORY_FUNC_MAP := {
	"AI_Spawner": "mod.GetSpawner",
	"AI_WaypointPath": "mod.GetWaypointPath",
	"AreaTrigger": "mod.GetAreaTrigger",
	"CombatArea": "",
	"DeployCam": "",
	"HQ_PlayerSpawner": "mod.GetHQ",
	"InteractPoint": "mod.GetInteractPoint",
	"PlayerSpawner": "mod.GetSpawner",
	"Sector": "mod.GetSector",
	"SpawnPoint": "mod.GetSpawnPoint",
	"StationaryEmplacementSpawner": "mod.GetEmplacementSpawner",
	"VehicleSpawner": "mod.GetVehicleSpawner",
	"WorldIcon": "mod.GetWorldIcon",
	"MCOM": "mod.GetMCOM",
	"SFX_": "mod.GetSFX",
	"SurroundingCombatArea": "",
	"FX_": "mod.GetVFX",
	"VFX_": "mod.GetVFX",
	"Spatial Object": "mod.GetSpatialObject"
}

var EXCLUDE_CLASSES := [
	"CombatArea",
	"DeployCam",
	"SurroundingCombatArea",
]

var checked_order: Array = []

func _ready():
	if get_tree().edited_scene_root == null:
		return
		
	exclusive = true

	_initialize_layout()

	btn_check_all.pressed.connect(_on_check_all)
	btn_uncheck_all.pressed.connect(_on_uncheck_all_pressed)
	btn_convert.pressed.connect(_on_convert_pressed)
	btn_copy.pressed.connect(_on_copy_pressed)
	title = trl("Title")
	get_ok_button().text = trl("ButtonCloseDialog")
	btn_check_all.text = trl("ButtonCheckAll")
	btn_uncheck_all.text = trl("ButtonUncheckAll")
	btn_convert.text = trl("ButtonConvert")
	btn_copy.text = trl("ButtonCopy")
	label_guide.text = trl("LabelGuide")
	label_notice.text = trl("LabelNotice")
	label_notice.modulate = Color(1, 0.8, 0.4)
	var_name_field.placeholder_text = trl("PlaceholderVarNameField")
	
	panel_bg.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	var sb = panel_bg.get_theme_stylebox("panel")
	sb.bg_color = Color(0.08, 0.08, 0.08, 0.5)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	
	visibility_changed.connect(_on_visiblity_changed)
	close_requested.connect(_on_visiblity_changed)

func _initialize_layout():
	unresizable = true
	var fixed_size = Vector2i(680, 730)
	min_size = fixed_size
	max_size = Vector2i(900, 900)
	
	for c in [root_ctrl, root_vb, sc, panel_bg, node_container, code_display]:
		if is_instance_valid(c):
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if node_container:
		node_container.custom_minimum_size = Vector2(0, 10)

	if code_display:
		code_display.custom_minimum_size = Vector2(600, 300)
		code_display.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		
	root_ctrl.anchor_right = 1.0
	root_ctrl.anchor_bottom = 1.0
	root_ctrl.offset_left = 0
	root_ctrl.offset_top = 0
	root_ctrl.offset_right = 0
	root_ctrl.offset_bottom = 0

	hide()

func populate_list(rows: Array):
	if not node_container:
		return
	
	for c in node_container.get_children():
		c.queue_free()
		
	await get_tree().process_frame
	
	for row in rows:
		var cb = CheckBox.new()
		var script_name = row.node.get_script().get_path().get_file().get_basename()
		cb.text = "%s (ObjId=%d)" % [row.node.name, row.node.ObjId]
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.tooltip_text = script_name
		cb.set_meta("row", row)
		
		if script_name in EXCLUDE_CLASSES:
			cb.disabled = true
			cb.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.5))
		else:
			cb.toggled.connect(func(pressed: bool):
				if pressed:
					checked_order.append(cb)
				else:
					checked_order.erase(cb)
					
				var index = 1
				for c in checked_order:
					if is_instance_valid(c) and c is CheckBox:
						var base_text = c.text
						var regex = RegEx.new()
						regex.compile("^\\[\\d+\\]\\s*")
						base_text = regex.sub(base_text, "", true)
						c.text = "[%d] %s" % [index, base_text]
						index += 1
				
				for c in node_container.get_children():
					if c is CheckBox and not c.button_pressed:
						var regex = RegEx.new()
						regex.compile("^\\[\\d+\\]\\s*")
						c.text = regex.sub(c.text, "", true)
			)
			cb.add_theme_color_override("font_color", Color(1, 1, 1))
		
		node_container.add_child(cb)
		
func _on_visiblity_changed():
	if visible:
		_reset_dialog_state()

func _reset_dialog_state():
	# 変換結果テキストクリア
	var result_label = $RootControl/MarginContainer/VBoxContainer/CodeDisplay
	result_label.text = ""
	
	# チェック順や内部フラグ初期化
	if "check_order" in self:
		checked_order.clear()
	
	# UIの再生成（node_containerなど）
	var nc = $RootControl/MarginContainer/VBoxContainer/ScrollContainer/PanelContainer/NodeContainer
	for c in nc.get_children():
		if c is CheckBox:
			c.button_pressed = false
				
func _on_uncheck_all_pressed():
	for child in node_container.get_children():
		if child is CheckBox:
			if child.button_pressed:
				child.button_pressed = false
				
func _on_check_all():
	for child in node_container.get_children():
		if child is CheckBox:
			if not child.disabled && not child.button_pressed:
				child.button_pressed = true
				
func _on_convert_pressed():
	if not var_name_field or not node_container:
		return
	
	var var_name = var_name_field.text.strip_edges()
	if var_name.is_empty():
		push_warning(trl("WarningEmptyVariableName"))
		return

	var selected: Array = []
	for cb in checked_order:
		if cb is CheckBox and cb.button_pressed:
			selected.append(cb.get_meta("row"))
	
	if selected.is_empty():
		push_warning(trl("WarningNoneChecked"))
		return

	code_display.text = _generate_ts_code(var_name, selected)


func _on_copy_pressed():
	if not code_display:
		return
		
	if code_display.text.strip_edges().is_empty():
		push_warning(trl("WarningNoneCopyContent"))
		return
		
	DisplayServer.clipboard_set(code_display.text)


func _generate_ts_code(var_name: String, rows: Array) -> String:
	if rows.is_empty():
		return ""

	var lines: Array = []
	for r in rows:
		var node: Node3D = r.node
		var cat_name: String = _get_category_name(node)
		var func_name: String = CATEGORY_FUNC_MAP.get(cat_name, "mod.GetSpatialObject")
		lines.append("\t%s(%s)" % [func_name, str(node.ObjId)])

	var var_base = var_name.strip_edges()
	if var_base.is_empty():
		var_base = "objects"
		
	if rows.size() == 1:
		return "const %s = %s;" % [var_base, lines[0].strip_edges()]
	else:
		return "const %s = [\n%s\n];" % [var_base, ",\n".join(lines)]


func _get_category_name(node: Node3D) -> String:
	var cname = node.get_script().resource_path.get_file().get_basename()
	if cname.begins_with("VEH_"):
		return "VEH_"
	elif cname.begins_with("SFX_"):
		return "SFX_"
	elif cname.begins_with("FX_") or cname.begins_with("fx_"):
		return "FX_"
	elif cname.begins_with("VFX_"):
		return "VFX_"
	elif CATEGORY_FUNC_MAP.has(cname):
		return cname
	else:
		return "Spatial Object"
