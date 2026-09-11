class_name CombatActor
extends CharacterBody3D
## 玩家与敌人的生命、护甲、感电、流血和硬直状态；伤害由 CombatSystem 提交。

signal health_changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0
@export var armor: float = 0.0

var health: float = 100.0
var is_dead: bool = false
var shock_remaining_sec: float = 0.0
var stagger_remaining_sec: float = 0.0
var knockback_velocity: Vector3 = Vector3.ZERO
var bleeds: Array = []


## 初始化独立生命，静态定义不保存运行状态。
func _ready() -> void:
	health = max_health


## 扣除已结算伤害；死亡在通知前标记，重复请求不再产生死亡。
func receive_damage(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	var actual: float = minf(health, amount)
	health = maxf(0.0, health - actual)
	is_dead = health <= 0.0
	health_changed.emit(health, max_health)
	if is_dead:
		died.emit()
	return actual


## 回复生命并限制在上限；死亡角色拒绝治疗。
func restore_health(amount: float) -> float:
	if is_dead or amount <= 0.0 or health >= max_health:
		return 0.0
	var actual: float = minf(max_health - health, amount)
	health += actual
	health_changed.emit(health, max_health)
	return actual


## 添加一层流血；达到上限时用新攻击快照替换剩余时间最短的一层。
func apply_bleed(entry: Dictionary, max_stacks: int) -> void:
	if is_dead or max_stacks <= 0:
		return
	var snapshot: Dictionary = entry.duplicate(true)
	if bleeds.size() < max_stacks:
		bleeds.append(snapshot)
		return
	var replace_index: int = 0
	var shortest: float = float(bleeds[0].remaining_sec)
	for index: int in range(1, bleeds.size()):
		if float(bleeds[index].remaining_sec) < shortest:
			shortest = float(bleeds[index].remaining_sec)
			replace_index = index
	bleeds[replace_index] = snapshot


## 推进每层流血计时并返回本帧到期的跳伤快照；大步长也不会漏掉合法跳数。
func advance_bleeds(delta: float) -> Array:
	var due: Array = []
	for index: int in range(bleeds.size() - 1, -1, -1):
		var entry: Dictionary = bleeds[index]
		var active_delta: float = minf(maxf(delta, 0.0), float(entry.remaining_sec))
		entry.remaining_sec = maxf(0.0, float(entry.remaining_sec) - active_delta)
		entry.next_tick_sec = float(entry.next_tick_sec) - active_delta
		var interval: float = maxf(0.01, float(entry.tick_interval_sec))
		while float(entry.next_tick_sec) <= 0.000001:
			due.append(entry.duplicate(true))
			entry.next_tick_sec = float(entry.next_tick_sec) + interval
		if float(entry.remaining_sec) <= 0.0:
			bleeds.remove_at(index)
		else:
			bleeds[index] = entry
	return due


## 推进状态计时，减弱击退速度。
func tick_status(delta: float) -> void:
	shock_remaining_sec = maxf(0.0, shock_remaining_sec - delta)
	stagger_remaining_sec = maxf(0.0, stagger_remaining_sec - delta)
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 20.0 * delta)


## 应用有限硬直与水平击退，精英可通过调用方削弱幅度。
func push_back(direction: Vector3, speed_mps: float) -> void:
	knockback_velocity = direction * speed_mps
	knockback_velocity.y = 0.0
	stagger_remaining_sec = 0.08


## 恢复生命和瞬态；仅用于新遭遇与死亡重开。
func reset_health() -> void:
	is_dead = false
	health = max_health
	shock_remaining_sec = 0.0
	stagger_remaining_sec = 0.0
	knockback_velocity = Vector3.ZERO
	bleeds.clear()
	health_changed.emit(health, max_health)
