class_name SaveModule
extends Resource
## 模块协议：业务数据、独立版本、校验、升级和恢复准备集中在所属模块。
@export var module_id: String = ""
@export var module_version: int = 1

## 当前模块格式版本；扩展时由模块覆盖。
func current_version() -> int:
	return 1

## 声明恢复前必须准备好的模块 ID。
func dependencies() -> Array[String]:
	return []

## 生成完整独立快照，嵌套容器和动态子资源一并复制。
func capture() -> SaveModule:
	return duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as SaveModule

## 校验公共模块标识与版本，子类继续校验自己的字段。
func validate() -> SaveResult:
	if module_id.is_empty() or module_version != current_version():
		return invalid("module_version", "模块版本不受支持")
	return SaveResult.success()

## 已发布模块需要逐版实现升级；未知旧版和未来版拒绝加载。
func upgrade() -> SaveResult:
	if module_version != current_version():
		return invalid("module_version", "缺少此模块版本的升级规则")
	return SaveResult.success()

## 在全部模块校验后准备依赖；默认仅检查声明的依赖存在。
func prepare_restore(modules: Dictionary) -> SaveResult:
	for id: String in dependencies():
		if not modules.has(id):
			return invalid("dependencies", "缺少依赖模块：" + id)
	return SaveResult.success()

## 由业务事务完成后通知会话，避免保存半次操作。
func touch() -> void:
	emit_changed()

## 为本模块生成带字段路径的失败结果。
func invalid(field: String, text: String) -> SaveResult:
	return SaveResult.failure("validate", ERR_INVALID_DATA, text, module_id, field)
