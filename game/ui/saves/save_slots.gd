extends PanelContainer
## 手动保存与整档回退共用面板，一个自动栏位展开最近成功历史。
signal closed
var location: Node
var session: GameSession
var saving: bool = false
var groups: Array[String] = []
var selected: SaveSlotResource

## 面板随所属场景销毁，默认隐藏。
func _ready() -> void:
	hide()

## 打开选择器，读取模式暂停据点自动保存直到关闭或完成加载。
func open(owner_scene: Node, active: GameSession, save_mode: bool) -> void:
	location = owner_scene
	session = active
	saving = save_mode
	$Rows/Title.text = "选择手动保存槽" if saving else "选择存档返回据点"
	$Rows/Actions/Accept.text = "保存到此槽" if saving else "载入此存档"
	$Rows/Message.text = "角色、物品、资源、据点与进度将作为一个检查点保存。" if saving else "载入后回到据点；可展开自动存档查看历史版本。"
	groups.clear()
	$Rows/Groups.clear()
	if session != null:
		groups.append(session.group_id)
	for entry: SaveSlotResource in SaveManager.store.catalog().slots:
		if not groups.has(entry.group_id) and not saving:
			groups.append(entry.group_id)
	for group: String in groups:
		$Rows/Groups.add_item("角色 " + group.left(8))
	$Rows/Groups.disabled = saving
	_rebuild()
	show()
	$Rows/Actions/Cancel.grab_focus()

## 为所选角色重建五个手动槽和自动历史树。
func _rebuild() -> void:
	selected = null
	$Rows/Actions/Accept.disabled = true
	var tree: Tree = $Rows/Slots
	tree.clear()
	var root: TreeItem = tree.create_item()
	if groups.is_empty():
		$Rows/Message.text = "还没有可读取的存档，请新建角色。"
		return
	var group: String = groups[$Rows/Groups.selected]
	var entries: Dictionary = {}
	var autos: Array[SaveSlotResource] = []
	var recoveries: Array[SaveSlotResource] = []
	for entry: SaveSlotResource in SaveManager.store.catalog().slots:
		if entry.group_id != group:
			continue
		entries[entry.slot_id] = entry
		if entry.slot_id.ends_with(".rollback"):
			recoveries.append(entry)
		elif entry.slot_id.begins_with("auto_"):
			autos.append(entry)
	for index: int in range(1, SaveManager.store.manual_count + 1):
		var id: String = "manual_%02d" % index
		var entry: SaveSlotResource = entries.get(id)
		if entry == null:
			entry = SaveSlotResource.new()
			entry.group_id = group
			entry.slot_id = id
			entry.problem = "空槽"
		_add_row(root, entry, "手动 %02d · 空槽" % index if entry.problem == "空槽" else entry.label())
	if not saving:
		var auto: TreeItem = tree.create_item(root)
		auto.set_text(0, "自动存档（展开查看 %d 个成功历史位置）" % autos.size())
		auto.set_selectable(0, false)
		for entry: SaveSlotResource in autos:
			_add_row(auto, entry, entry.label())
		auto.collapsed = true
		for entry: SaveSlotResource in recoveries:
			_add_row(root, entry, entry.label())

## 槽位元数据保留真实位置，坏槽可点击查看诊断及回退提示。
func _add_row(parent: TreeItem, entry: SaveSlotResource, text: String) -> void:
	var row: TreeItem = $Rows/Slots.create_item(parent)
	row.set_text(0, text)
	row.set_metadata(0, entry)

## 切换角色组后重建槽位，手动保存固定为当前角色。
func _on_group_selected(_index: int) -> void:
	_rebuild()

## 根据选中条目开放明确的保存或载入动作。
func _on_slot_selected() -> void:
	var row: TreeItem = $Rows/Slots.get_selected()
	selected = row.get_metadata(0) as SaveSlotResource if row != null else null
	$Rows/Actions/Accept.disabled = selected == null

## 已有手动槽通过原生确认框覆盖；载入失败留在选择界面。
func _on_accept_pressed() -> void:
	if selected == null:
		return
	if saving:
		if FileAccess.file_exists(SaveManager.store.slot_path(selected.group_id, selected.slot_id)):
			$Overwrite.dialog_text = "覆盖此手动槽？自动存档历史会继续保留。"
			$Overwrite.popup_centered()
		else:
			_on_overwrite_confirmed()
	else:
		var result: SaveResult = SceneRouter.load_game(selected.group_id, selected.slot_id)
		if not result.ok:
			$Rows/Message.text = result.message + "。请选择同一角色的自动历史或其他手动槽回退。"

## 实际保存完成后显示结果，失败可在同一槽重试。
func _on_overwrite_confirmed() -> void:
	var index: int = int(selected.slot_id.get_slice("_", 1))
	var result: SaveResult = SaveManager.save_game(session, location, index, "manual")
	$Rows/Message.text = result.message + ("；" + result.warning if not result.warning.is_empty() else "")
	_rebuild()

## 关闭面板并通知据点恢复保存调度。
func _on_cancel_pressed() -> void:
	hide()
	closed.emit()

## 全局 Esc 关闭面板，覆盖确认由原生弹窗优先处理。
func _input(event: InputEvent) -> void:
	if visible and not $Overwrite.visible and event.is_action_pressed("pause"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()
