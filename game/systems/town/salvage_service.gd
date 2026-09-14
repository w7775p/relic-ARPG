class_name SalvageService
extends RefCounted
## 据点单件拆解事务；始终按稳定实例 ID 重新查询归属并一次提交物品与材料变化。
const RULES: SalvageRules = preload("res://content/town/salvage_rules.tres")
var inventory: InventoryState
var at_hub: bool = false

## 绑定当前角色库存，并由场景明确声明是否具备据点能力。
func _init(state: InventoryState, hub_allowed: bool) -> void:
	inventory = state
	at_hub = hub_allowed

## 只读预览当前实例的拆解收益与失败原因，UI 与真实执行共用同一规则。
func preview(item_id: String) -> Dictionary:
	if not at_hub:
		return _failure("只能在据点拆解装备")
	if item_id.is_empty() or not inventory.data.instances.has(item_id):
		return _failure("物品已不存在")
	var item: ItemInstanceResource = inventory.data.instances[item_id]
	if inventory.data.equipment_ids.values().has(item_id):
		return _failure("已穿戴装备需要先卸下")
	if inventory.data.stash_ids.has(item_id):
		return _failure("仓库装备需要先移入背包")
	if not inventory.data.bag_ids.has(item_id):
		return _failure("物品当前不在背包")
	if item.locked:
		return _failure("锁定装备禁止拆解")
	var amount: int = RULES.materials_for(item)
	if amount <= 0:
		return _failure("拆解收益配置无效")
	return {"ok":true, "message":"可拆解为 %d 材料" % amount, "materials":amount, "item_id":item_id}

## 再次按 ID 校验后提交单次拆解；重复请求的第二次会因实例已删除而失败。
func salvage(item_id: String) -> Dictionary:
	var result: Dictionary = preview(item_id)
	if not bool(result.ok):
		return result
	var index: int = inventory.data.bag_ids.find(item_id)
	if index < 0 or not inventory.data.instances.has(item_id):
		return _failure("物品状态已变化，请重新选择")
	var amount: int = int(result.materials)
	inventory.data.bag_ids.remove_at(index)
	inventory.data.instances.erase(item_id)
	inventory.economy.materials += amount
	inventory.data.touch()
	inventory.economy.touch()
	return {"ok":true, "message":"拆解完成：+%d 材料" % amount, "materials":amount, "item_id":item_id}

## 统一失败结构，保证失败路径不修改物品与余额。
func _failure(message: String) -> Dictionary:
	return {"ok":false, "message":message, "materials":0, "item_id":""}
