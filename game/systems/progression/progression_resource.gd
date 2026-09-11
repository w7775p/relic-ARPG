class_name ProgressionResource
extends SaveModule
## 跨探险难度及已结算通关次数，后续区域进度在此演进。
@export var difficulty: int = 1
@export var completed: int = 0

## 初始化稳定模块 ID。
func _init() -> void:
	module_id = "progression"

## 当前难度仍按通关递增，三档难度由后续任务升级本模块。
func validate() -> SaveResult:
	var result: SaveResult = super.validate()
	if not result.ok:
		return result
	if difficulty < 1 or completed < 0:
		return invalid("difficulty/completed", "难度或完成进度不合法")
	return SaveResult.success()
