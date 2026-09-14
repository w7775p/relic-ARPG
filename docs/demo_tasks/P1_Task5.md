# P1_Task 5：单词条位置重铸

仓库：[w7775p/relic-ARPG](https://github.com/w7775p/relic-ARPG)。工程入口：`game/project.godot`。技术栈：Godot 4.7.2 标准版、GDScript、3D 俯视即时动作、Windows 键鼠。

阶段：D1。状态：待验收。任务 ID：`P1_Task5`。工作分支：`feat/p1-task5-reforge`。

前置任务：[P1_Task 4](P1_Task4.md)。本次从最新 `main` `77948dcd4558c87188c995bf41e086525fe795f1` 开始；P1_Task4 已通过人工验收并由 PR #11 合入，Resource 存档与词条导出修复均已在 main。

## 开始前先阅读以下文档

| 文档（仓库根目录相对路径） | 阅读目的 |
| --- | --- |
| [AGENTS.md](../../AGENTS.md) | 项目约束与「完成任务前必须检查」 |
| [README.md](../../README.md) | 当前入口、操作和已实现功能 |
| [docs/engineering.md](../../docs/engineering.md) | 当前模块、数据与存档规则 |
| [docs/save_system.md](../../docs/save_system.md) | 五模块、Hub 保存、版本升级与整体回退边界 |
| [docs/tasks.md](../../docs/tasks.md) | 任务状态与前置合入情况 |
| [known_trap.md](../../known_trap.md) | 实际问题，避免重复踩坑 |
| [docs/plan.md](../../docs/plan.md) | 第 10、11 节阶段额度与验收目标 |
| [docs/demo_tasks/README.md](../../docs/demo_tasks/README.md) | 基线、执行顺序、内容归属与交接约定 |
| [docs/validation.md](../../docs/validation.md) | 现有验证入口与历史结果 |

有前置任务时同时阅读对应任务卡的验收与实际交接记录；上表文档均应存在。运行代码的最新状态优先用于判断已实现内容。

## 已经实现的功能

历史 M2 已完成战斗、随机装备、背包仓库和整备循环。当前存档基线为独立 Hub 与五模块 Resource 检查点；仅 Hub 保存，旧 JSON 和旧探险恢复已退休。P1_Task3 完成 D1 装备额度，P1_Task4 完成据点拆解与材料来源。

物品实例保存实际词条值，词条定义提供等级、部位、权重和互斥组。P1_Task5 在该结构上增加固定重铸位置与独立重铸随机序列，不新增存档模块。

## 本次实现

① 据点对未锁定的魔法/稀有背包装备开放重铸。第一次成功重铸选择一个已有随机词条位置，并把该位置写入装备实例；后续只能继续重铸该位置，其他词条、实例 ID、底材、品质和等级保持。

② `ItemGenerator.affix_candidates()` 与 `roll_affix()` 成为掉落和重铸共用规则：按物品等级/部位筛选，排除其他位置占据的词条与互斥组，并沿用权重和数值区间。当前允许重新抽到相同词条或相同数值，界面明确提示；独特装备不开放重铸。

③ `ReforgeRules` 集中配置费用：魔法基础 2 材料、稀有基础 4 材料，物品等级从 1 级起每跨 4 级额外 +1。UI 显示所选位置、当前词条、合法候选及数值范围、费用、当前材料与执行结果。

④ `ReforgeService` 使用独立 RNG；`InventoryState.reforge()` 一次提交词条、固定位置、材料和 RNG 状态。相同 `request_id` 返回首次结果，不重复扣费或推进随机序列。材料不足、零候选、锁定、仓库/穿戴、探险地点、独特装备和失效实例均拒绝提交并保持原值。

## 修改范围与 Godot 实现

| 主要路径 | 实现落点 |
| --- | --- |
| `game/systems/town/reforge_rules.gd、reforge_service.gd` | 费用、地点/品质/锁定校验、候选预览、独立 RNG 与重复请求保护。 |
| `game/systems/items/item_generator.gd` | 抽出掉落/重铸共用的合法候选与加权抽取规则。 |
| `game/systems/items/item_instance_resource.gd` | 新增 `reforge_index`，默认 `-1`；校验固定位置合法性。 |
| `game/systems/inventory/items_resource.gd、inventory_state.gd` | items v2、独立 `reforge_rng_seed/state`、v1→v2 升级及原子重铸事务。 |
| `game/world/hub/hub.gd` | Hub 背包接入位置选择、候选/费用说明和重铸按钮；首次成功后锁定位置选择器。 |
| `game/tests/p1_reforge.*、game/app/validation/pickup_smoke.gd` | 专项规则/事务/迁移测试和实际发布包 Hub 重铸/保存读回。 |

新增类、函数、回调与功能均写简明中文注释；`tools/verify.py` 已接入 `P1_REFORGE_RESULT`。

## 存档与兼容

items 模块由 v1 升到 **v2**。装备实例新增 `reforge_index`；ItemsResource 新增独立 `reforge_rng_seed/state`。v1→v2 升级把旧装备初始化为 `reforge_index=-1`，并从原掉落 `rng_seed` 稳定派生重铸 RNG，迁移不消耗、不改写原掉落 `rng_seed/state`。同一 v1 文件重复加载得到相同的重铸初始序列；加载升级只作用于候选，原旧档文件保持不变，后续正常保存才写出 v2。

首次重铸位置、新词条结果、材料余额和两套 RNG 均进入完整检查点。恢复后不会重新抽值；下一次重铸结果可复现，下一件掉落仍与未执行重铸的同掉落 RNG 快照一致。当前固定场地变体使用探险独立 `_run_rng`，重铸不会改变地图变体选择。

## 验收标准与实际结果

① 重铸一次后，实例 ID、底材、品质、等级、未选词条保持；第二次只能原位置。**自动回归通过。**

② 小候选池覆盖等级、部位、互斥、零候选与重复词条/数值；费用不足及相同请求不会多扣材料。**自动回归通过。**

③ 同底材两件装备与静态定义保持独立；重铸后重新穿戴，构筑伤害立即采用新词条。**自动回归通过。**

④ 保存重开后位置、材料、新词条及下一次重铸 RNG 一致；掉落 RNG 不受重铸推进；发布包真实 Hub 执行重铸后保存读回也通过。**自动回归通过。**

最终代码 head `6753e61811cbb041892408e86b30bddd13f030ea` 的 Windows [run 34826805034](https://github.com/w7775p/relic-ARPG/actions/runs/34826805034) 使用 `windows-latest`、PowerShell/Python 与官方 Godot 4.7.2：全量源码场景、存储故障、隔离 PCK、Windows `.exe` 导出和实际成品包 Hub 重铸/检查点读回全部通过。构建：[artifact 10340134660](https://github.com/w7775p/relic-ARPG/actions/runs/34826805034/artifacts/10340134660)，SHA256 `84fbaa2d5b228482bd094e3ea32a244987c01880a761bb6089c625f193417f8d`；启动日志：[artifact 10340623448](https://github.com/w7775p/relic-ARPG/actions/runs/34826805034/artifacts/10340623448)。

显示、中文排版、位置选择是否顺手及重铸反馈感受仍需 Windows 人工试玩，因此当前状态为“待验收”。

## 要求

1. 先检查当前项目状态：分支、工作区、最新 main、前置合入、实际代码与验证入口；保护现有未提交修改。
2. 不实现与本任务无关的系统。只参考本仓库与所需官方资料，沿用本项目约定，无需使用 `global-work-rules`。
3. 优先最小可用实现，以本卡验收为完成边界；数值为原型参数，后续可在平衡阶段调整。
4. 完成后按 AGENTS.md「完成任务前必须检查」逐条执行，更新本卡状态、任务总表和工作日志；实际遇到新坑才更新 `known_trap.md`。每个独立子任务完成并验证后单独 commit，再同步任务分支和 PR；合并按用户当前授权执行。
5. 最后按下表汇报，并附分支/提交、测试命令与实际结果、PR 和可用构建链接。

| 汇报项 | 必须包含 |
| --- | --- |
| 改了哪些文件 | 主要文件及用途；文档、资源、存档版本变化。 |
| 当前能做什么 | 从哪个入口操作，得到什么结果，哪些验收已经实际通过。 |
| 还不能做什么 | 未完成项、失败项、未验证项及对应影响。 |
| 下一步建议做什么 | 已解锁的下一张任务卡、待合入依赖或具体阻塞。 |

## 执行记录

2026-09-14 从 main `77948dcd` 建立 `feat/p1-task5-reforge`。独立提交：`261e8a0d` 保存固定位置与独立 RNG、items v2 迁移；`3b50f2e0` 抽出共用候选/抽取规则；`b472ee23` 实现重铸费用与事务；`a92035cd` 接入 Hub UI；`527c7d46` 增加专项规则/事务/真实旧档迁移回归；`a921da3f` 扩展发布包 smoke；`6753e618` 修正 smoke 在推进下一件掉落后才比较旧 RNG 状态的测试顺序。

首次扩展成品 smoke 时 37 项中 36 项通过，唯一失败来自测试先调用下一件掉落生成、随后拿已推进状态与保存前状态比较；玩法重铸、材料扣除、固定位置和检查点读回均已通过。修正断言顺序后 final run 34826805034 全绿。该问题属于新增测试自身时序错误，没有新增项目级 `known_trap`。

当前自动验收已完成，PR 合入前等待用户 Windows 可见试玩。通过后 P1_Task5 可标记已完成并解锁 P1_Task6。
