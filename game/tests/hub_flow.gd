extends Node
## Hub 场景流回归：验证独立据点状态可以进入正式探险运行场景且角色长期状态保持同一会话对象。

const HUB: PackedScene = preload("res://world/hub/hub.tscn")
const EXPEDITION_RUNTIME: PackedScene = preload("res://world/maps/expedition_runtime.tscn")
var failures: int = 0
var checks: int = 0


## 记录断言并保留全部失败。
func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)


## 等待 UI 与场景 ready 完成。
func frames(count: int = 2) -> void:
	for index: int in range(count):
		await get_tree().process_frame


## 验证 Hub 与正式探险之间的会话状态交接。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var hub: Control = HUB.instantiate()
	add_child(hub)
	await frames()
	check(hub.is_hub() and hub.panel.visible, "新 Hub 是独立据点场景并默认打开整备")
	check(hub.inventory.equipment.has("weapon"), "首次 Hub 创建锈剑起装")
	check(hub.loadout_action("skill", "sweep", "main").contains("更新"), "Hub 可以调整主要技能")
	check(hub.loadout_action("skill", "warcry", "auxiliary").contains("更新"), "Hub 可以调整辅助技能")
	var extra: Dictionary = hub.generator.generate(1)
	check(hub.inventory.pickup(extra), "Hub 长期背包可接收额外装备")
	hub.minimum_quality = 2
	var inventory_ref: InventoryState = hub.inventory
	var generator_ref: ItemGenerator = hub.generator
	SceneRouter.stage_character_state(inventory_ref, generator_ref, hub.minimum_quality)
	hub.queue_free()
	await frames()
	var expedition: Node3D = EXPEDITION_RUNTIME.instantiate()
	add_child(expedition)
	await frames(3)
	check(expedition.inventory == inventory_ref and expedition.generator == generator_ref, "探险领取 Hub 的同一角色与掉落生成器对象")
	check(not expedition.is_hub() and not expedition.in_town, "正式探险场景不提供据点服务")
	check(expedition.minimum_quality == 2, "掉落过滤设置跨场景保持")
	check(expedition.inventory.loadout.slots.main == "sweep" and expedition.inventory.loadout.slots.auxiliary == "warcry", "技能装配跨场景保持")
	check(expedition.inventory.bag.size() == 1 and expedition.combat.enemies.size() == 48, "背包状态保持且新探险生成完整怪群")
	check(not expedition.panel.visible and not get_tree().paused, "进入探险后整备面板关闭且世界运行")
	var bag_before: int = expedition.inventory.bag.size()
	var rejected: String = expedition.inventory_action("sell", 0, 0)
	check(rejected.begins_with("操作失败") and expedition.inventory.bag.size() == bag_before, "探险期间据点出售服务被拒绝")
	expedition.queue_free()
	await frames()
	get_tree().paused = false
	print("HUB_FLOW_RESULT: ", failures, " failures; ", checks, " checks")
	get_tree().quit(0 if failures == 0 else 1)
