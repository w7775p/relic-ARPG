class_name SaveResult
extends RefCounted
## 保存和恢复的结构化结果；界面显示消息，日志保留具体阶段与字段。
var ok: bool = true
var code: int = OK
var stage: String = ""
var module_id: String = ""
var field_path: String = ""
var message: String = ""
var warning: String = ""
var value: Variant

## 创建成功结果，可携带候选资源、会话或目录。
static func success(data: Variant = null, text: String = "") -> SaveResult:
	var result: SaveResult = SaveResult.new()
	result.value = data
	result.message = text
	return result

## 创建失败结果；错误码沿用 Godot Error。
static func failure(at: String, error: int, text: String, module: String = "", field: String = "") -> SaveResult:
	var result: SaveResult = SaveResult.new()
	result.ok = false
	result.code = error
	result.stage = at
	result.message = text
	result.module_id = module
	result.field_path = field
	return result

## 输出可定位问题的完整诊断。
func diagnostic() -> String:
	return "stage=%s module=%s field=%s code=%d %s %s" % [stage, module_id, field_path, code, message, warning]
