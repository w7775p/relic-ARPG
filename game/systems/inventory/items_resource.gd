class_name ItemsResource
extends SaveModule
## 装备只在实例表保存一次；背包、仓库和穿戴仅保存所属实例 ID。
@export var instances: Dictionary[String, ItemInstanceResource] = {}
@export var bag_ids: Array[String] = []
@export var stash_ids: Array[String] = []
@export var equipment_ids: Dictionary[String, String] = {}
@export var bag_capacity: int = 40
@export var stash_capacity: int = 120
@export var next_id: int = 1
@export var rng_seed: int = 0
@export var rng_state: int = 0

## 新模块初始化独立随机状态，加载时由 Resource 字段覆盖。
func _init() -> void:
	module_id = "items"
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.randomize()
	rng_seed = random.seed
	rng_state = random.state

## 校验容量、唯一归属、引用完整和下一个生成编号。
func validate() -> SaveResult:
	var result: SaveResult = super.validate()
	if not result.ok:
		return result
	if bag_capacity < 1 or stash_capacity < 1 or bag_ids.size() > bag_capacity or stash_ids.size() > stash_capacity:
		return invalid("containers", "背包或仓库容量不合法")
	var owners: Dictionary = {}
	for id: String in bag_ids + stash_ids:
		if owners.has(id) or not instances.has(id):
			return invalid("containers." + id, "物品归属重复或实例缺失")
		owners[id] = true
	for slot: String in equipment_ids:
		var id: String = equipment_ids[slot]
		if not ItemCatalog.SLOTS.has(slot) or owners.has(id) or not instances.has(id):
			return invalid("equipment." + slot, "装备槽、实例或归属不合法")
		owners[id] = true
		var item: ItemInstanceResource = instances[id]
		if item == null or ItemCatalog.base(item.base) == null or ItemCatalog.base(item.base).slot != slot:
			return invalid("equipment." + slot, "穿戴部位不匹配")
	if owners.size() != instances.size() or next_id < 1:
		return invalid("instances", "存在无归属装备或生成编号不合法")
	for id: String in instances:
		var item: ItemInstanceResource = instances[id]
		if item == null or item.id != id or int(id) >= next_id:
			return invalid("instances." + id, "装备实例与编号计数不一致")
		result = item.validate()
		if not result.ok:
			return result
	return SaveResult.success()
