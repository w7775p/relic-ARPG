class_name SalvageRules
extends Resource
## 据点拆解收益配置；品质决定基础材料，等级按固定步长追加材料。
@export var quality_base_materials: PackedInt32Array = PackedInt32Array([1, 2, 4, 7])
@export_range(1, 100, 1) var levels_per_bonus: int = 3
@export_range(0, 100, 1) var level_bonus_materials: int = 1

## 依据装备当前品质和物品等级计算单件拆解材料。
func materials_for(item: ItemInstanceResource) -> int:
	if item == null or item.quality < 0 or item.quality >= quality_base_materials.size():
		return 0
	var level_steps: int = int((maxi(item.level, 1) - 1) / levels_per_bonus)
	return quality_base_materials[item.quality] + level_steps * level_bonus_materials
