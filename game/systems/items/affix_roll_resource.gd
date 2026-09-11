class_name AffixRollResource
extends Resource
## 一条词条的历史抽取值；更新掉落区间不改变已有装备。
@export var id: String = ""
@export var value: float = 0.0

## 创建具体抽取结果。
static func create(content_id: String, rolled_value: float) -> AffixRollResource:
	var roll: AffixRollResource = AffixRollResource.new()
	roll.id = content_id
	roll.value = rolled_value
	return roll
