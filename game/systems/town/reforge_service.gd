class_name ReforgeService
extends RefCounted
## 据点单词条重铸服务；校验地点与候选规则，使用独立 RNG，并把最终事务交给 InventoryState。
const RULES: ReforgeRules = preload("res://content/town/reforge_rules.tres")
var inventory: InventoryState
var at_hub: bool = false
var definitions: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var completed_requests: Dictionary = {}

## 绑定当前角色库存和地点能力；可传入小候选池用于规则回归。
func _init(state: InventoryState, hub_allowed: bool, candidate_definitions: Array = []) -> void:
	inventory = state
	at_hub = hub_allowed
	definitions = candidate_definitions
	rng.seed = inventory.data.reforge_rng_seed
	rng.state = inventory.data.reforge_rng_state

## 只读预览目标位置、当前词条、候选范围和材料费用。
func preview(item_id: String, affix_index: int) -> Dictionary:
	if not at_hub:
		return _failure("只能在据点重铸装备")
	if item_id.is_empty() or not inventory.data.instances.has(item_id):
		return _failure("物品已不存在")
	var item: ItemInstanceResource = inventory.data.instances[item_id]
	if item.quality != 1 and item.quality != 2:
		return _failure("只有魔法或稀有装备可以重铸", item_id, affix_index)
	if inventory.data.equipment_ids.values().has(item_id):
		return _failure("已穿戴装备需要先卸下", item_id, affix_index)
	if inventory.data.stash_ids.has(item_id):
		return _failure("仓库装备需要先移入背包", item_id, affix_index)
	if not inventory.data.bag_ids.has(item_id):
		return _failure("物品当前不在背包", item_id, affix_index)
	if item.locked:
		return _failure("锁定装备禁止重铸", item_id, affix_index)
	if affix_index < 0 or affix_index >= item.affixes.size():
		return _failure("重铸位置无效", item_id, affix_index)
	if item.reforge_index >= 0 and item.reforge_index != affix_index:
		return _failure("该装备已固定为位置 %d" % (item.reforge_index + 1), item_id, affix_index)
	var cost: int = RULES.materials_for(item)
	if cost <= 0:
		return _failure("重铸费用配置无效", item_id, affix_index)
	var pool: Array[AffixDefinition] = _pool(item, affix_index)
	var current_text: String = _roll_text(item.affixes[affix_index])
	var candidate_text: String = _candidate_text(pool)
	if pool.is_empty():
		return _failure("当前位置没有合法候选词条", item_id, affix_index, cost, current_text, candidate_text)
	if inventory.materials < cost:
		return _failure("材料不足：需要 %d，当前 %d" % [cost, inventory.materials], item_id, affix_index, cost, current_text, candidate_text)
	return {
		"ok": true,
		"message": "可重铸位置 %d；可能获得相同词条或相同数值" % (affix_index + 1),
		"item_id": item_id,
		"index": affix_index,
		"cost": cost,
		"current": current_text,
		"candidates": candidate_text,
		"fixed": item.reforge_index >= 0
	}

## 按稳定实例 ID 和位置执行一次重铸；相同 request_id 只返回首次结果，不重复扣费或推进 RNG。
func reforge(item_id: String, affix_index: int, request_id: String = "") -> Dictionary:
	if not request_id.is_empty() and completed_requests.has(request_id):
		var duplicate: Dictionary = completed_requests[request_id].duplicate(true)
		duplicate["duplicate"] = true
		return duplicate
	var result: Dictionary = preview(item_id, affix_index)
	if not bool(result.get("ok", false)):
		return result
	var item: ItemInstanceResource = inventory.data.instances.get(item_id)
	if item == null:
		return _failure("物品状态已变化，请重新选择", item_id, affix_index)
	var pool: Array[AffixDefinition] = _pool(item, affix_index)
	var before_seed: int = inventory.data.reforge_rng_seed
	var before_state: int = inventory.data.reforge_rng_state
	var rolled: AffixRollResource = ItemGenerator.roll_affix(rng, pool)
	if rolled == null:
		_reset_rng(before_seed, before_state)
		return _failure("重铸候选抽取失败，未扣除材料", item_id, affix_index)
	var previous: String = _roll_text(item.affixes[affix_index])
	if not inventory.reforge(item_id, affix_index, rolled, int(result.cost), rng.seed, rng.state):
		_reset_rng(before_seed, before_state)
		return _failure("物品状态已变化，重铸未提交", item_id, affix_index)
	var success: Dictionary = {
		"ok": true,
		"message": "重铸完成：位置 %d · %s → %s · -%d 材料" % [affix_index + 1, previous, _roll_text(rolled), int(result.cost)],
		"item_id": item_id,
		"index": affix_index,
		"cost": int(result.cost),
		"previous": previous,
		"result": _roll_text(rolled),
		"duplicate": false
	}
	if not request_id.is_empty():
		completed_requests[request_id] = success.duplicate(true)
	return success

## 复用掉落候选规则，并排除其他位置占据的词条与互斥组。
func _pool(item: ItemInstanceResource, affix_index: int) -> Array[AffixDefinition]:
	return ItemGenerator.affix_candidates(item, affix_index, definitions)

## 失败结果保留预览字段，让 UI 即使在材料不足时仍能解释当前位置与候选。
func _failure(message: String, item_id: String = "", affix_index: int = -1, cost: int = 0, current_text: String = "", candidate_text: String = "") -> Dictionary:
	return {"ok": false, "message": message, "item_id": item_id, "index": affix_index, "cost": cost, "current": current_text, "candidates": candidate_text, "fixed": false}

## 抽取未能提交时恢复到持久模块记录的独立重铸随机位置。
func _reset_rng(seed_value: int, state_value: int) -> void:
	rng.seed = seed_value
	rng.state = state_value

## 把实例词条显示为玩家当前真实数值。
func _roll_text(roll: AffixRollResource) -> String:
	if roll == null:
		return "无"
	var definition: AffixDefinition = ItemCatalog.affix(roll.id)
	if definition == null:
		definition = ItemGenerator._affix_in(definitions, roll.id)
	return "%s %.3f" % [definition.display_name, roll.value] if definition != null else "%s %.3f" % [roll.id, roll.value]

## 展示候选名称及各自可抽数值范围；空池明确显示无候选。
func _candidate_text(pool: Array[AffixDefinition]) -> String:
	if pool.is_empty():
		return "无合法候选"
	var parts: PackedStringArray = []
	for candidate: AffixDefinition in pool:
		parts.append("%s %.3f～%.3f" % [candidate.display_name, candidate.minimum, candidate.maximum])
	return "；".join(parts)
