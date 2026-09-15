class_name ReforgeRules
extends Resource
## 据点重铸费用配置；仅魔法与稀有可重铸，品质决定基础材料并按物品等级递增。
@export var quality_base_materials: PackedInt32Array = PackedInt32Array([0, 2, 4, 0])
@export_range(1, 100, 1) var levels_per_bonus: int = 4
@export_range(0, 100, 1) var level_bonus_materials: int = 1

## 依据装备品质与物品等级计算单次重铸材料费用。
func materials_for(item: ItemInstanceResource) -> int:
	if item == null or item.quality < 0 or item.quality >= quality_base_materials.size():
		return 0
	var base_cost: int = quality_base_materials[item.quality]
	if base_cost <= 0:
		return 0
	var level_steps: int = int((maxi(item.level, 1) - 1) / levels_per_bonus)
	return base_cost + level_steps * level_bonus_materials
