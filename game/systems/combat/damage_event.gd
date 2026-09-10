class_name DamageEvent
extends RefCounted
## 一次命中的结果快照，触发队列可在尸体回收后继续使用位置与属性。

var target: CombatActor
var origin: Vector3
var skill_id: StringName
var root_attack_id: int
var amount: float
var is_critical: bool
var killed: bool
var was_shocked: bool
var build: BuildDefinition
