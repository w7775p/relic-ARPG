class_name EconomyResource
extends SaveModule
## 独立管理金币与材料余额，后续材料种类可在模块内升级。
@export var gold: int = 0
@export var materials: int = 0

## 初始化稳定模块 ID。
func _init() -> void:
	module_id = "economy"

## 拒绝负余额。
func validate() -> SaveResult:
	var result: SaveResult = super.validate()
	if not result.ok:
		return result
	if gold < 0 or materials < 0:
		return invalid("balances", "金币或材料余额不合法")
	return SaveResult.success()
