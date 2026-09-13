class_name ResourceFingerprint
extends RefCounted
## 比较存储字段的实际值，供读回完整性验证和整档回归使用。

## 生成包括嵌套 Resource 的确定性摘要，不写入存档格式。
static func digest(value: Variant) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	_append(context, value)
	return context.finish().hex_encode()

## 定位读回与原快照的首个字段差异，用于存储诊断。
static func difference(a: Variant, b: Variant, path: String = "") -> String:
	if a is Resource and b is Resource:
		if a.get_script() != b.get_script():
			return path + ".script"
		for property: Dictionary in a.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				var field: String = difference(a.get(property.name), b.get(property.name), path + "." + property.name)
				if not field.is_empty():
					return field
	elif a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return path + ".size"
		for key: Variant in a:
			if not b.has(key):
				return path + "." + str(key)
			var field: String = difference(a[key], b[key], path + "." + str(key))
			if not field.is_empty():
				return field
	elif a is Array and b is Array:
		if a.size() != b.size():
			return path + ".size"
		for index: int in range(a.size()):
			var field: String = difference(a[index], b[index], path + "." + str(index))
			if not field.is_empty():
				return field
	elif a is float and b is float:
		if absf(a - b) > 1e-12 * maxf(1.0, maxf(absf(a), absf(b))):
			return path
	elif typeof(a) != typeof(b) or a != b:
		return path + " [%s -> %s]" % [String.num(a, 17) if a is float else str(a), String.num(b, 17) if b is float else str(b)]
	return ""

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
	elif value is float:
		# 当前词条精度为 0.001；摘要保留十二位小数，排除十进制往返的末位舍入。
		context.update(String.num(value, 12).to_utf8_buffer())
	else:
		context.update(var_to_bytes(value))
