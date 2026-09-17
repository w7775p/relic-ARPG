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
	preload("res://content/items/serrated_blade.tres"),
	preload("res://content/items/bastion_helm.tres"),
	preload("res://content/items/warded_boots.tres"),
	preload("res://content/items/focus_ring.tres"),
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
	preload("res://content/items/affix_bleeding.tres"),
	preload("res://content/items/affix_bulwark.tres"),
	preload("res://content/items/affix_fortitude.tres"),
	preload("res://content/items/affix_focus.tres"),
	preload("res://content/items/affix_surge.tres"),
	preload("res://content/items/affix_execution.tres"),
]
const UNIQUES: Array[UniqueDefinition] = [
	preload("res://content/items/unique_thunder_ring.tres"),
	preload("res://content/items/unique_ember_mail.tres"),
	preload("res://content/items/unique_energy_grips.tres"),
	preload("res://content/items/unique_blood_echo.tres"),
]
const STAT_NAMES: Dictionary = {"damage":"攻击", "armor":"护甲", "max_health":"最大生命", "critical_chance":"暴击率", "whirlwind_radius_m":"旋风范围", "move_speed_mps":"移速", "idle_energy_regen":"闲置回能", "hit_energy":"直接命中回能", "kill_energy":"击杀回能", "haste":"攻击间隔缩短", "lightning_damage":"闪电伤害", "bleed_damage_multiplier":"流血伤害"}

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

## 按稳定 ID 查找独特定义，目录排序不改变存档含义。
static func unique(id: String) -> UniqueDefinition:
	for entry: UniqueDefinition in UNIQUES:
		if entry.id == id:
			return entry
	return null

## 四件核心独特装备提供雷霆连锁、爆炸、续航与有限流血传播。
static func unique_stats(id: String) -> Dictionary:
	var definition: UniqueDefinition = unique(id)
	return definition.stats if definition != null else {}

## 按属性语义统一格式化单位；说明层和实际结算共用同一静态定义与实例数值。
static func stat_text(stat: String, value: float) -> String:
	match stat:
		"critical_chance":
			return "暴击率 +%.1f%%" % (value * 100.0)
		"bleed_damage_multiplier":
			return "流血伤害 +%.0f%%" % (value * 100.0)
		"whirlwind_radius_m":
			return "旋风范围 +%.1f 米" % value
		"move_speed_mps":
			return "移速 +%.2f 米/秒" % value
		"idle_energy_regen":
			return "闲置回能 +%.1f/秒" % value
		"haste":
			return "攻击间隔 -%.2f 秒" % value
		"hit_energy":
			return "直接命中回能 +%.1f" % value
		"kill_energy":
			return "击杀回能 +%.1f" % value
		"damage", "armor", "max_health", "lightning_damage":
			return "%s +%.1f" % [STAT_NAMES.get(stat, stat), value]
	return "%s +%.2f" % [STAT_NAMES.get(stat, stat), value]
