extends Control
## 独立据点场景：持有角色长期状态，提供整备服务，并在出发时把状态交给探险场景。

const PANEL: Script = preload("res://ui/inventory/inventory_panel.gd")

var inventory: InventoryState = InventoryState.new()
var generator: ItemGenerator = ItemGenerator.new()
var minimum_quality: int = 0
var panel: InventoryPanel


## 领取跨场景角色状态；首次进入据点时创建最小新角色装备并打开整备面板。
func _ready() -> void:
	var transition: Dictionary = SceneRouter.take_character_state()
	if not transition.is_empty():
		inventory = transition.inventory
		generator = transition.generator
		minimum_quality = int(transition.minimum_quality)
	else:
		_create_new_character()
	inventory.changed.connect(_on_inventory_changed)
	panel = PANEL.new()
	panel.session = self
	add_child(panel)
	panel.show()
	panel.refresh()
	if OS.get_cmdline_user_args().has("--smoke-combat"):
		_depart_for_smoke.call_deferred()


## 据点向共用背包面板声明当前位置能力。
func is_hub() -> bool:
	return true


## 首次角色沿用现有锈剑起装，等待后续 Resource 存档重构替换初始化来源。
func _create_new_character() -> void:
	var starter: Dictionary = generator.generate(1)
	starter.base = "rust_sword"
	starter.quality = 0
	starter.unique = -1
	starter.affixes = []
	inventory.bag.append(starter)
	inventory.equip(0)


## 导出包 smoke 沿正式 Hub→探险路径自动出发，避免维护第二套启动流程。
func _depart_for_smoke() -> void:
	SceneRouter.stage_character_state(inventory, generator, minimum_quality)
	SceneRouter.open_expedition()


## Hub 没有战斗世界；关闭整备只隐藏面板，再按 I 或 Esc 可重新打开。
func toggle_inventory() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		panel.refresh()


## 据点物品服务只处理长期角色状态；丢弃与撤离由探险场景负责。
func inventory_action(action: String, source: int, index: int) -> String:
	var success: bool = false
	match action:
		"equip": success = source == 0 and inventory.equip(index)
		"unequip":
			if source == 1 and index >= 0 and index < panel.entries().size():
				success = inventory.unequip(ItemCatalog.base(panel.entries()[index].base).slot)
		"lock":
			if source == 0 and index >= 0 and index < inventory.bag.size():
				inventory.toggle_lock(index)
				success = true
		"sell": success = source == 0 and inventory.sell(index)
		"store": success = source == 0 and inventory.transfer(index, true)
		"retrieve": success = source == 2 and inventory.transfer(index, false)
		"depart":
			SceneRouter.stage_character_state(inventory, generator, minimum_quality)
			SceneRouter.open_expedition()
			return "已出发"
		"filter":
			minimum_quality = (minimum_quality + 1) % 3
			success = true
	return "操作完成" if success else "操作失败：请检查选中物品、锁定状态和容量"


## 据点允许免费调整技能与被动；修改后刷新整备信息。
func loadout_action(action: String, id: String = "", slot: String = "") -> String:
	var error: String = ""
	match action:
		"passive": error = inventory.loadout.toggle(id)
		"reset": inventory.loadout.passives.clear()
		"skill":
			if not LoadoutState.fits(slot, id):
				return "技能与槽位不匹配"
			inventory.loadout.slots[slot] = id
		_: return "未知装配操作"
	if not error.is_empty():
		return error
	inventory.changed.emit()
	return "装配已更新"


## 长期状态变化只刷新据点 UI；战斗属性由进入探险后重新构建。
func _on_inventory_changed() -> void:
	if panel != null:
		panel.refresh()


## 据点场景只处理整备开关与返回主菜单。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_I:
			toggle_inventory()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pause"):
			if panel.visible:
				toggle_inventory()
			else:
				SceneRouter.open_main_menu()
			get_viewport().set_input_as_handled()
