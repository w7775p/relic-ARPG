class_name InventoryState
extends RefCounted
## 管理装备的唯一归属、容量与锁定；持有实例只存在于一个容器。
signal changed
const BAG_CAPACITY: int = 40
const STASH_CAPACITY: int = 120
var bag: Array = []
var stash: Array = []
var equipment: Dictionary = {}
var gold: int = 0
var materials: int = 0
var level: int = 1
var experience: int = 0
var difficulty: int = 1
var completed: int = 0

## 拾取整件实例，满包保留地面物品。
func pickup(item: Dictionary) -> bool:
	if bag.size() >= BAG_CAPACITY:
		return false
	bag.append(item)
	changed.emit()
	return true

## 同部位原装备与选中物品交换，满包仍能换装。
func equip(index: int) -> bool:
	if index < 0 or index >= bag.size():
		return false
	var item: Dictionary = bag[index]
	var slot: String = ItemCatalog.base(item.base).slot
	bag.remove_at(index)
	if equipment.has(slot):
		bag.append(equipment[slot])
	equipment[slot] = item
	changed.emit()
	return true

## 卸下装备时检查背包剩余容量。
func unequip(slot: String) -> bool:
	if not equipment.has(slot) or bag.size() >= BAG_CAPACITY:
		return false
	bag.append(equipment[slot])
	equipment.erase(slot)
	changed.emit()
	return true

## 整备时在背包与仓库之间搬移，失败保持原容器。
func transfer(index: int, to_stash: bool) -> bool:
	var source: Array = bag if to_stash else stash
	var target: Array = stash if to_stash else bag
	var capacity: int = STASH_CAPACITY if to_stash else BAG_CAPACITY
	if index < 0 or index >= source.size() or target.size() >= capacity:
		return false
	target.append(source[index])
	source.remove_at(index)
	changed.emit()
	return true

## 锁定阻止出售和丢弃，允许正常穿戴。
func toggle_lock(index: int) -> void:
	if index >= 0 and index < bag.size():
		bag[index].locked = not bag[index].locked
		changed.emit()

## 原子出售单件未锁定物品。
func sell(index: int) -> bool:
	if index < 0 or index >= bag.size() or bag[index].locked:
		return false
	gold += ItemGenerator.price(bag[index])
	bag.remove_at(index)
	changed.emit()
	return true

## 丢弃返回实例，由世界创建地面物品。
func discard(index: int) -> Dictionary:
	if index < 0 or index >= bag.size() or bag[index].locked:
		return {}
	var item: Dictionary = bag.pop_at(index)
	changed.emit()
	return item

## 连续升级消耗递增经验；换装重算时加入等级属性。
func grant_experience(amount: int) -> void:
	experience += amount
	while experience >= level * 60:
		experience -= level * 60
		level += 1
	changed.emit()

## 汇总装备成新的属性快照，卸下独特装备会移除相应机制。
func build() -> BuildDefinition:
	var result: BuildDefinition = BuildDefinition.new()
	result.display_name = "实装构筑 · 等级 %d" % level
	result.damage += (level - 1) * 2.0
	for item: Dictionary in equipment.values():
		var definition: ItemBase = ItemCatalog.base(item.base)
		_apply_stat(result, definition.stat, definition.value)
		for rolled: Dictionary in item.affixes:
			_apply_stat(result, ItemCatalog.affix(rolled.id).stat, rolled.value)
		for stat: String in ItemCatalog.unique_stats(int(item.unique)):
			var value: Variant = ItemCatalog.unique_stats(int(item.unique))[stat]
			if stat == "death_explosion":
				result.death_explosion = true
			else:
				_apply_stat(result, stat, float(value))
	result.critical_chance = minf(result.critical_chance, 0.85)
	result.attack_interval_sec = maxf(result.attack_interval_sec, 0.12)
	result.whirlwind_interval_sec = maxf(result.whirlwind_interval_sec, 0.08)
	return result

## 生命与护甲独立于技能数值汇总。
func defense(stat: String) -> float:
	var total: float = 300.0 + (level - 1) * 15.0 if stat == "max_health" else 15.0
	for item: Dictionary in equipment.values():
		var definition: ItemBase = ItemCatalog.base(item.base)
		if definition.stat == stat:
			total += definition.value
		for rolled: Dictionary in item.affixes:
			if ItemCatalog.affix(rolled.id).stat == stat:
				total += float(rolled.value)
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

## 复制完整持有与成长数据用于 JSON。
func snapshot() -> Dictionary:
	return {"bag":bag.duplicate(true), "stash":stash.duplicate(true), "equipment":equipment.duplicate(true), "gold":gold, "materials":materials, "level":level, "experience":experience, "difficulty":difficulty, "completed":completed}

## 已校验快照恢复为独立容器。
func restore(data: Dictionary) -> void:
	for key: String in data:
		set(key, data[key].duplicate(true) if data[key] is Array or data[key] is Dictionary else int(data[key]))
	changed.emit()
