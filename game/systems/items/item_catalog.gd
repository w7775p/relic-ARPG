class_name ItemCatalog
extends RefCounted
## 集中索引静态装备资源；描述与属性均读取同一份参数。
const SLOTS: Array[String] = ["weapon", "head", "body", "hands", "feet", "ring"]
const SLOT_NAMES: Dictionary = {"weapon":"武器", "head":"头部", "body":"胸甲", "hands":"手部", "feet":"足部", "ring":"戒指"}
const BASES: Array[ItemBase] = [
	preload("res://content/items/rust_sword.tres"),
	preload("res://content/items/stone_axe.tres"),
	preload("res://content/items/iron_helm.tres"),
	preload("res://content/items/leather_hood.tres"),
	preload("res://content/items/mail.tres"),
	preload("res://content/items/robe.tres"),
	preload("res://content/items/grips.tres"),
	preload("res://content/items/boots.tres"),
	preload("res://content/items/copper_ring.tres"),
	preload("res://content/items/bone_ring.tres"),
]
const AFFIXES: Array[AffixDefinition] = [
	preload("res://content/items/affix_power.tres"),
	preload("res://content/items/affix_cruel.tres"),
	preload("res://content/items/affix_precision.tres"),
	preload("res://content/items/affix_reach.tres"),
	preload("res://content/items/affix_speed.tres"),
	preload("res://content/items/affix_vitality.tres"),
	preload("res://content/items/affix_guard.tres"),
	preload("res://content/items/affix_recovery.tres"),
	preload("res://content/items/affix_leech.tres"),
	preload("res://content/items/affix_harvest.tres"),
	preload("res://content/items/affix_haste.tres"),
	preload("res://content/items/affix_storm.tres"),
]
const UNIQUES: Array[UniqueDefinition] = [
	preload("res://content/items/unique_thunder_ring.tres"),
	preload("res://content/items/unique_ember_mail.tres"),
	preload("res://content/items/unique_energy_grips.tres"),
]
const STAT_NAMES: Dictionary = {"damage":"攻击", "armor":"护甲", "max_health":"最大生命", "critical_chance":"暴击率", "whirlwind_radius_m":"旋风范围（米）", "move_speed_mps":"移速（米/秒）", "idle_energy_regen":"闲置回能/秒", "hit_energy":"直接命中回能", "kill_energy":"击杀回能", "haste":"攻击间隔缩短（秒）", "lightning_damage":"闪电伤害"}

## 按稳定编号查找底材，未知编号返回空。
static func base(id: String) -> ItemBase:
	for entry: ItemBase in BASES:
		if entry.id == id:
			return entry
	return null

## 按稳定编号查找词条。
static func affix(id: String) -> AffixDefinition:
	for entry: AffixDefinition in AFFIXES:
		if entry.id == id:
			return entry
	return null

## 三件核心独特装备分别提供连锁、爆炸和循环续航。
static func unique_stats(index: int) -> Dictionary:
	return UNIQUES[index].stats if index >= 0 and index < UNIQUES.size() else {}

## 按统一单位格式化词条。
static func stat_text(stat: String, value: float) -> String:
	if stat == "critical_chance":
		return "暴击率 +%.1f%%" % (value * 100.0)
	return "%s +%.2f" % [STAT_NAMES.get(stat, stat), value]
