class_name SaveGameResource
extends Resource
## 一个完整检查点的封装；各业务模块独立演进，文件整体回退。
const FORMAT_VERSION: int = 1
const CONTENT_VERSION: int = 1
@export var format_version: int = FORMAT_VERSION
@export var content_version: int = CONTENT_VERSION
@export var group_id: String = ""
@export var checkpoint_id: String = ""
@export var saved_at: int = 0
@export var sequence: int = 0
@export var reason: String = ""
@export var modules: Array[SaveModule] = []

## 创建不依赖系统时间唯一性的文件与角色标识。
static func make_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

## 校验用作目录名的内部标识，阻止路径穿越。
static func valid_id(id: String) -> bool:
	if id.length() != 32:
		return false
	for character: String in id:
		if not "0123456789abcdef".contains(character):
			return false
	return true
