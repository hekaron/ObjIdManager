@tool
extends AcceptDialog

@onready var margin_container: MarginContainer = $MarginContainer
@onready var root_vb: VBoxContainer = $MarginContainer/VBoxContainer
@onready var label_guide: Label = $MarginContainer/VBoxContainer/Label
@onready var sc: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer
@onready var var_name_field: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/VarNameField
@onready var panel_bg: PanelContainer = $MarginContainer/VBoxContainer/ScrollContainer/PanelContainer
@onready var node_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/PanelContainer/NodeContainer
@onready var btn_check_all: Button = $MarginContainer/VBoxContainer/HBoxContainer/BtnCheckAll
@onready var btn_uncheck_all: Button = $MarginContainer/VBoxContainer/HBoxContainer/BtnUncheckAll
@onready var btn_convert: Button = $MarginContainer/VBoxContainer/HBoxContainer/BtnConvert
@onready var btn_copy: Button = $MarginContainer/VBoxContainer/HBoxContainer/BtnCopy
@onready var label_notice: Label = $MarginContainer/VBoxContainer/NoticeLabel
@onready var code_display: TextEdit = $MarginContainer/VBoxContainer/CodeDisplay
@onready var action_row: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer

const MIN_DIALOG_SIZE := Vector2i(680, 560)
const INITIAL_SIZE_FALLBACK_RATIO := 0.9

var _has_been_shown := false

var current_language: String = "en"

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

func set_language(locale: String) -> void:
	current_language = "ja" if locale.to_lower().begins_with("ja") else "en"
	if is_node_ready():
		_apply_localized_texts()

func trl(key: String) -> String:
	var lang_table: Dictionary = L10N.get(current_language, L10N["en"])
	if lang_table.has(key):
		return str(lang_table[key])

	var english_table: Dictionary = L10N["en"]
	if english_table.has(key):
		return str(english_table[key])

	push_warning("Missing localization key: %s" % key)
	return key

var CATEGORY_FUNC_MAP := {
	"AI_Spawner": "mod.GetSpawner",
	"AI_WaypointPath": "mod.GetWaypointPath",
	"AreaTrigger": "mod.GetAreaTrigger",
	"CombatArea": "",
	"DeployCam": "",
	"FixedCamera": "mod.GetFixedCamera",
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
	"LootSpawner": "mod.GetLootSpawner",
	"RingOfFire": "mod.GetRingOfFire",
	"VL7Cloud": "mod.GetVL7Cloud",
	"Bomb": "mod.GetBomb",
	"Spatial Object": "mod.GetSpatialObject"
}

var EXCLUDE_CLASSES := [
	"CombatArea",
	"DeployCam",
	"SurroundingCombatArea",
]

var checked_order: Array = []

func _ready() -> void:
	# This dialog is an editor utility window, so its UI must initialize even
	# during moments when edited_scene_root is temporarily null.
	exclusive = false

	_initialize_layout()

	btn_check_all.pressed.connect(_on_check_all)
	btn_uncheck_all.pressed.connect(_on_uncheck_all_pressed)
	btn_convert.pressed.connect(_on_convert_pressed)
	btn_copy.pressed.connect(_on_copy_pressed)
	_apply_localized_texts()
	label_notice.modulate = Color(1, 0.8, 0.4)
	
	panel_bg.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	var sb = panel_bg.get_theme_stylebox("panel")
	sb.bg_color = Color(0.08, 0.08, 0.08, 0.5)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	
	visibility_changed.connect(_on_visiblity_changed)
	close_requested.connect(_on_visiblity_changed)

func _apply_localized_texts() -> void:
	title = trl("Title")
	get_ok_button().text = trl("ButtonCloseDialog")
	btn_check_all.text = trl("ButtonCheckAll")
	btn_uncheck_all.text = trl("ButtonUncheckAll")
	btn_convert.text = trl("ButtonConvert")
	btn_copy.text = trl("ButtonCopy")
	label_guide.text = trl("LabelGuide")
	label_notice.text = trl("LabelNotice")
	var_name_field.placeholder_text = trl("PlaceholderVarNameField")

func _initialize_layout() -> void:
	# Keep this utility window associated with the currently focused Godot
	# editor window. It stays above its editor parent without becoming a
	# globally always-on-top or exclusive modal window.
	transient = true
	transient_to_focused = true
	exclusive = false
	always_on_top = false

	# AcceptDialog lays out its direct Control child inside the content area,
	# above the built-in Close button row. Keep the direct MarginContainer
	# unanchored so AcceptDialog can assign that rectangle correctly.
	unresizable = false
	maximize_disabled = false
	wrap_controls = true
	min_size = MIN_DIALOG_SIZE
	max_size = Vector2i.ZERO

	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Only the list and generated-code areas consume surplus height when the
	# user enlarges the window.
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(600, 200)

	code_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_display.custom_minimum_size = Vector2(600, 180)
	code_display.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY

	panel_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node_container.custom_minimum_size = Vector2(0, 10)

	action_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label_guide.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label_notice.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label_guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_guide.custom_minimum_size = Vector2(600, 0)
	label_notice.custom_minimum_size = Vector2(600, 0)

	hide()

func bring_to_front() -> void:
	if not visible:
		return

	# A minimized native editor window is still visible from Godot's point of
	# view, so restore it before requesting focus.
	if mode == Window.MODE_MINIMIZED:
		mode = Window.MODE_WINDOWED

	# Defer focus until the window manager has processed the mode change.
	call_deferred("grab_focus")


func popup_fitted() -> void:
	# The first opening is fitted to the controls' combined minimum size.
	# Later openings keep the size chosen by the user.
	child_controls_changed()
	await get_tree().process_frame

	if not _has_been_shown:
		var content_min := get_contents_minimum_size()
		size = Vector2i(
			maxi(MIN_DIALOG_SIZE.x, int(ceil(content_min.x))),
			maxi(MIN_DIALOG_SIZE.y, int(ceil(content_min.y)))
		)
		_has_been_shown = true

	popup_centered_clamped(size, INITIAL_SIZE_FALLBACK_RATIO)

func populate_list(rows: Array) -> void:
	# A newly instantiated Window can be asked to populate immediately after it
	# is added to the editor dock. Wait until @onready references are valid.
	if not is_node_ready():
		await ready

	_apply_localized_texts()
	checked_order.clear()

	if not is_instance_valid(node_container):
		push_error("TypeScript export dialog: NodeContainer is not ready.")
		return

	for child in node_container.get_children():
		node_container.remove_child(child)
		child.queue_free()

	await get_tree().process_frame
	
	for row in rows:
		if not row is Dictionary or not row.has("node"):
			continue
		var node := row["node"] as Node3D
		if not is_instance_valid(node):
			continue

		var cb = CheckBox.new()
		var script_name := ""
		var node_script := node.get_script()
		if node_script is Script and not node_script.resource_path.is_empty():
			script_name = node_script.resource_path.get_file().get_basename()
		cb.text = "%s (ObjId=%d)" % [node.name, node.ObjId]
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

	node_container.queue_sort()
	root_vb.queue_sort()
	child_controls_changed()
	await get_tree().process_frame
	child_controls_changed()
		
func _on_visiblity_changed():
	if visible:
		_reset_dialog_state()

func _reset_dialog_state() -> void:
	code_display.clear()
	checked_order.clear()

	for child in node_container.get_children():
		if child is CheckBox:
			child.button_pressed = false

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
