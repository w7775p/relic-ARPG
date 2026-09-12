extends SaveModule
## 扩展协议验收用模块：真实文件升级可保留旧计数并补充新字段。
@export var counter: int = 0
@export var unlocked: bool = false

## 当前测试模块使用版本二。
func _init() -> void:
	module_id = "extension"

## 当前模块独立格式版本。
func current_version() -> int:
	return 2

## 依赖据点准备完成。
func dependencies() -> Array[String]:
	return ["hub"]

## 版本一明确补充新字段，升级保留原计数。
func upgrade() -> SaveResult:
	if module_version == 1:
		unlocked = counter >= 3
		module_version = 2
	return super.upgrade()

## 模块自主校验业务值。
func validate() -> SaveResult:
	var result: SaveResult = super.validate()
	if not result.ok:
		return result
	return invalid("counter", "测试计数不合法") if counter < 0 else SaveResult.success()
