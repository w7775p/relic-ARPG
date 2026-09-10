class_name AffixDefinition
extends Resource
## 词条抽取限制和数值范围；同组词条互斥。
@export var id: String = ""
@export var display_name: String = ""
@export var stat: String = ""
@export var group: String = ""
@export var slots: PackedStringArray = []
@export var min_level: int = 1
@export var weight: float = 1.0
@export var minimum: float = 0.0
@export var maximum: float = 0.0
