class_name InventoryState
extends RefCounted
## 物品事务入口；数据由五个业务 Resource 持有，属性汇总显式读取角色与装配。
signal changed
const BAG_CAPACITY: int = 40
const STASH_CAPACITY: int = 120
var data: ItemsResource
var character: CharacterResource
var economy: EconomyResource
var progression: ProgressionResource
var loadout: LoadoutState
var bag: Array[ItemInstanceResource]:
	get: return _resolve(data.bag_ids)
var stash: Array[ItemInstanceResource]:
	get: return _resolve(data.stash_ids)
var equipment: Dictionary[String, ItemInstanceResource]:
	get:
		var result: Dictionary[String, ItemInstanceResource] = {}
		for slot: String in data.equipment_ids:
			result[slot] = data.instances[data.equipment_ids[slot]]
		return result
var gold: int:
	get: return economy.gold
	set(value):
		if economy.gold != value:
			economy.gold = value
			economy.touch()
var materials: int:
	get: return economy.materials
	set(value):
		if economy.materials != value:
			economy.materials = value
			economy.touch()
var level: int:
	get: return character.level
	set(value):
		if character.level != value:
			character.level = value
			character.touch()
var experience: int:
	get: return character.experience
	set(value):
		if character.experience != value:
			character.experience = value
			character.touch()
var difficulty: int:
	get: return progression.difficulty
	set(value):
		if progression.difficulty != value:
			progression.difficulty = value
			progression.touch()
var completed: int:
	get: return progression.completed
	set(value):
		if progression.completed != value:
			progression.completed = value
			progression.touch()

## 绑定业务模块；独立测试可使用默认空角色。
func _init(items: ItemsResource = null, profile: CharacterResource = null, currency: EconomyResource = null, progress: ProgressionResource = null) -> void:
	data = items if items != null else ItemsResource.new()
	character = profile if profile != null else CharacterResource.new()
	economy = currency if currency != null else EconomyResource.new()
	progression = progress if progress != null else ProgressionResource.new()
	loadout = LoadoutState.new(character.loadout)
	character.loadout.changed.connect(character.touch)
	for module: SaveModule in [data, character, economy, progression]:
		module.changed.connect(_on_changed)

## 转发业务事务完成通知，驱动 UI 与战斗属性刷新。
func _on_changed() -> void:
	changed.emit()

## 提供容器的只读列表视图；修改必须通过事务入口。
func _resolve(ids: Array[String]) -> Array[ItemInstanceResource]:
	var result: Array[ItemInstanceResource] = []
	for id: String in ids:
		result.append(data.instances[id])
	return result

## 拾取时检查身份和容量，满包保持地面归属。
func pickup(item: ItemInstanceResource) -> bool:
	if item == null or data.bag_ids.size() >= data.bag_capacity or data.instances.has(item.id):
		return false
	if not item.validate().ok:
		return false
	data.instances[item.id] = item
	data.bag_ids.append(item.id)
	data.next_id = maxi(data.next_id, int(item.id) + 1)
	data.touch()
	return true

## 同部位交换，满包仍可换装，事务结束后统一通知。
func equip(index: int) -> bool:
	if index < 0 or index >= data.bag_ids.size():
		return false
	var id: String = data.bag_ids[index]
	var slot: String = ItemCatalog.base(data.instances[id].base).slot
	data.bag_ids.remove_at(index)
	if data.equipment_ids.has(slot):
		data.bag_ids.append(data.equipment_ids[slot])
	data.equipment_ids[slot] = id
	data.touch()
	return true

## 卸下时检查容量，失败保持原槽位。
func unequip(slot: String) -> bool:
	if not data.equipment_ids.has(slot) or data.bag_ids.size() >= data.bag_capacity:
		return false
	data.bag_ids.append(data.equipment_ids[slot])
	data.equipment_ids.erase(slot)
	data.touch()
	return true

## 在背包和本角色仓库之间原子移动 ID。
func transfer(index: int, to_stash: bool) -> bool:
	var source: Array[String] = data.bag_ids if to_stash else data.stash_ids
	var target: Array[String] = data.stash_ids if to_stash else data.bag_ids
	var capacity: int = data.stash_capacity if to_stash else data.bag_capacity
	if index < 0 or index >= source.size() or target.size() >= capacity:
		return false
	target.append(source[index])
	source.remove_at(index)
	data.touch()
	return true

## 锁定阻止误卖与丢弃，允许穿戴和转移。
func toggle_lock(index: int) -> void:
	if index >= 0 and index < data.bag_ids.size():
		var item: ItemInstanceResource = data.instances[data.bag_ids[index]]
		item.locked = not item.locked
		data.touch()

## 出售完成实例删除与余额入账后统一通知。
func sell(index: int) -> bool:
	if index < 0 or index >= data.bag_ids.size():
		return false
	var item: ItemInstanceResource = data.instances[data.bag_ids[index]]
	if item.locked:
		return false
	economy.gold += ItemGenerator.price(item)
	data.bag_ids.remove_at(index)
	data.instances.erase(item.id)
	data.touch()
	economy.touch()
	return true

## 丢弃时移出实例表，调用者接管地面实例。
func discard(index: int) -> ItemInstanceResource:
	if index < 0 or index >= data.bag_ids.size():
		return null
	var item: ItemInstanceResource = data.instances[data.bag_ids[index]]
	if item.locked:
		return null
	data.bag_ids.remove_at(index)
	data.instances.erase(item.id)
	data.touch()
	return item

## 完成一笔经验结算后通知，避免升级循环中的中间状态被观察。
func grant_experience(amount: int) -> void:
	character.experience += amount
	while character.experience >= character.level * 60:
		character.experience -= character.level * 60
		character.level += 1
	character.touch()

## 汇总装备成新的属性快照，卸下独特装备会移除相应机制。
func build() -> BuildDefinition:
	var result: BuildDefinition = BuildDefinition.new()
	result.display_name = "实装构筑 · 等级 %d" % level
	result.damage += (level - 1) * 2.0
	for item: ItemInstanceResource in equipment.values():
		var definition: ItemBase = ItemCatalog.base(item.base)
		_apply_stat(result, definition.stat, definition.value)
		for rolled: AffixRollResource in item.affixes:
			_apply_stat(result, ItemCatalog.affix(rolled.id).stat, rolled.value)
		for stat: String in ItemCatalog.unique_stats(item.unique_id):
			var value: Variant = ItemCatalog.unique_stats(item.unique_id)[stat]
			if stat == "death_explosion":
				result.death_explosion = true
			else:
				_apply_stat(result, stat, float(value))
	for id: String in loadout.passives:
		var node: PassiveDefinition = LoadoutState.passive(id)
		_apply_stat(result, node.stat, node.value)
	result.critical_chance = minf(result.critical_chance, 0.85)
	result.attack_interval_sec = maxf(result.attack_interval_sec, 0.12)
	result.whirlwind_interval_sec = maxf(result.whirlwind_interval_sec, 0.08)
	return result

## 生命与护甲独立于技能数值汇总。
func defense(stat: String) -> float:
	var total: float = 300.0 + (level - 1) * 15.0 if stat == "max_health" else 15.0
	for item: ItemInstanceResource in equipment.values():
		var definition: ItemBase = ItemCatalog.base(item.base)
		if definition.stat == stat:
			total += definition.value
		for rolled: AffixRollResource in item.affixes:
			if ItemCatalog.affix(rolled.id).stat == stat:
				total += float(rolled.value)
	for id: String in loadout.passives:
		var node: PassiveDefinition = LoadoutState.passive(id)
		if node.stat == stat:
			total += node.value
	return total

## 应用加法属性；攻速词条以减少两种攻击间隔实现。
func _apply_stat(result: BuildDefinition, stat: String, value: float) -> void:
	if stat == "armor" or stat == "max_health":
		return
	if stat == "haste":
		result.attack_interval_sec -= value
		result.whirlwind_interval_sec -= value
	elif stat == "chain_count":
		result.chain_count += int(value)
	else:
		result.set(stat, float(result.get(stat)) + value)
