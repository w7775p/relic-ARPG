class_name SaveIndexResource
extends Resource
## 轻量目录缓存，可由槽位文件重新生成，删除或写失败不影响检查点。
@export var fingerprint: String = ""
@export var slots: Array[SaveSlotResource] = []
