# Hub 场景拆分与存档重构边界

日期：2026-09-11。分支：`refactor/hub-scene`。PR：#7。

## 当前完成状态

正式新角色流程已改为 `MainMenu → Hub → ExpeditionRuntime → Hub`。`Hub` 是独立场景，负责背包、装备、仓库、出售、技能与被动整备；`ExpeditionRuntime` 负责战斗世界、掉落、怪物、技能瞬态和撤离。角色长期状态通过 `SceneRouter` 的一次性过渡引用在两个场景之间交接，目标场景领取后立即清空，SceneRouter 不长期持有玩法状态。

`InventoryPanel` 通过 `session.is_hub()` 判断地点能力，不再要求 UI 直接读取 `session.in_town`。正常 Hub 出发不会调用旧 JSON 据点自动保存；撤离或死亡会结束当前探险场景并真实切换回 Hub，未拾取地面物品随场景销毁，已拾取装备、成长、金币材料、技能装配与掉落生成器状态继续保留。

## 旧 in_town 的处理

`game/world/maps/expedition.gd` 暂时保留原 `in_town` 字段、弹窗式整备和 v4 JSON 快照，只服务于旧存档兼容、现有 M2/P1 回归及下一轮迁移输入。正式新角色流程由 `game/world/maps/expedition_runtime.tscn` 承接，不再把据点当作探险场景内状态。

在 Resource 存档完成前禁止继续向旧 `in_town` 分支增加新的据点服务。P1_Task4 拆解、P1_Task5 重铸及后续据点能力应落在 `Hub`。

## 下一轮存档重构目标

下一步将 JSON 持久化改为 Godot Resource。目标数据边界：

① `PlayerProfileResource`：背包、仓库、装备、金币、材料、等级经验、难度解锁、技能装配、被动等长期状态。

② `RunStateResource`：地图/随机种子、玩家位置与战斗资源、敌人、地面掉落、弹体、技能冷却、持续状态、战斗 RNG 等本趟状态。

③ `SaveGameResource`：版本、角色档、本趟档及迁移元数据。

开发阶段优先保存为 `user://save.tres` 便于检查；稳定后可根据发行需求改为二进制 `.res`。旧 `session.json` 只提供一次性迁移入口，迁移成功后新保存路径只写 Resource。

当 Resource 保存与旧 JSON 迁移回归完成后，删除 `LEGACY_EXPEDITION`、运行期 `in_town`、旧据点快照分支以及仅为 JSON v4 服务的兼容代码。

## 验证

新增 `game/tests/hub_flow.tscn`，覆盖独立 Hub、起始装备、技能装配、角色对象与 ItemGenerator 跨场景保持、掉落过滤保持、48 怪探险启动及探险期间拒绝据点出售服务。

最终代码提交 `fba5f85e423c5273e950dbc3e8a4b622ad01b2b9` 对应 GitHub Actions run `34574865158`：全量场景回归通过、Windows 导出通过、导出包独立启动通过。Windows artifact `10189231734`，SHA256 `e6a0b9a7dfc16a61c8b6b0a20ee27e1757042f3b2a4de87298d6b23151d9ae87`。
