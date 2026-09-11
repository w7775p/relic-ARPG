class_name ItemInstanceResource
extends Resource
## 动态装备实例，以内容 ID 引用底材和独特配置，保留实际词条值。
@export var id: String = ""
@export var base: String = ""
@export var level: int = 1
@export var quality: int = 0
@export var unique_id: String = ""
@export var affixes: Array[AffixRollResource] = []
@export var locked: bool = false

## 查找独特定义，身份不依赖目录数组顺序。
func unique_definition() -> UniqueDefinition:
	for definition: UniqueDefinition in ItemCatalog.UNIQUES:
		if definition.id == unique_id:
			return definition
	return null

## 校验身份、内容和结构；历史词条只要求有限数值，不套用新掉落区间。
func validate() -> SaveResult:
	var path: String = "instances." + id
	var definition: ItemBase = ItemCatalog.base(base)
	if not id.is_valid_int() or int(id) < 1 or str(int(id)) != id or definition == null:
		return SaveResult.failure("validate", ERR_INVALID_DATA, "装备身份或底材内容缺失", "items", path)
	if level < 1 or quality < 0 or quality > 3:
		return SaveResult.failure("validate", ERR_INVALID_DATA, "装备等级或品质不合法", "items", path)
	var unique: UniqueDefinition = unique_definition()
	if (quality == 3 and (unique == null or unique.base_id != base)) or (quality != 3 and not unique_id.is_empty()):
		return SaveResult.failure("validate", ERR_INVALID_DATA, "独特装备内容缺失或底材不匹配", "items", path + ".unique_id")
	if (quality == 0 and not affixes.is_empty()) or (quality == 1 and (affixes.size() < 1 or affixes.size() > 2)) or (quality == 2 and (affixes.size() < 3 or affixes.size() > 4)) or (quality == 3 and affixes.size() != 1):
		return SaveResult.failure("validate", ERR_INVALID_DATA, "装备词条数量不合法", "items", path + ".affixes")
	var seen: Dictionary = {}
	for roll: AffixRollResource in affixes:
		if roll == null:
			return SaveResult.failure("validate", ERR_INVALID_DATA, "装备词条缺失", "items", path + ".affixes")
		var affix: AffixDefinition = ItemCatalog.affix(roll.id)
		if affix == null or not is_finite(roll.value) or seen.has(roll.id):
			return SaveResult.failure("validate", ERR_INVALID_DATA, "装备词条内容缺失、重复或数值损坏", "items", path + ".affixes." + roll.id)
		seen[roll.id] = true
	return SaveResult.success()
