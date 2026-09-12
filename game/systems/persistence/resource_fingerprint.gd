class_name ResourceFingerprint
extends RefCounted
## 比较存储字段的实际值，供读回完整性验证和整档回归使用。

## 生成包括嵌套 Resource 的确定性摘要，不写入存档格式。
static func digest(value: Variant) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	_append(context, value)
	return context.finish().hex_encode()

## 递归读取显式导出字段，排除引擎缓存路径和运行期信号。
static func _append(context: HashingContext, value: Variant) -> void:
	if value is Resource:
		context.update(var_to_bytes(value.get_script().resource_path))
		for property: Dictionary in value.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				context.update(var_to_bytes(property.name))
				_append(context, value.get(property.name))
	elif value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		context.update(var_to_bytes(keys.size()))
		for key: Variant in keys:
			_append(context, key)
			_append(context, value[key])
	elif value is Array:
		context.update(var_to_bytes(value.size()))
		for element: Variant in value:
			_append(context, element)
	else:
		context.update(var_to_bytes(value))
