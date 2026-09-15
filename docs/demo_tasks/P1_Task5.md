# P1_Task 5：单词条位置重铸

仓库：[w7775p/relic-ARPG](https://github.com/w7775p/relic-ARPG)。工程入口：`game/project.godot`。技术栈：Godot 4.7.2 标准版、GDScript、3D 俯视即时动作、Windows 键鼠。

阶段：D1。状态：**已完成**。任务 ID：`P1_Task5`。工作分支：`feat/p1-task5-reforge`。

前置任务：[P1_Task 4](P1_Task4.md)。本任务从 main `77948dcd4558c87188c995bf41e086525fe795f1` 开始；P1_Task4 已通过人工验收并由 PR #11 合入。

## 开始前先阅读以下文档

| 文档 | 阅读目的 |
| --- | --- |
| [AGENTS.md](../../AGENTS.md) | 项目约束与完成前检查 |
| [README.md](../../README.md) | 当前入口、操作和已实现功能 |
| [docs/engineering.md](../../docs/engineering.md) | 模块、数据与解耦规则 |
| [docs/save_system.md](../../docs/save_system.md) | Resource 检查点与升级边界 |
| [docs/tasks.md](../../docs/tasks.md) | 任务状态与前置关系 |
| [known_trap.md](../../known_trap.md) | 已知项目坑 |
| [docs/plan.md](../../docs/plan.md) | D1 阶段额度与验收目标 |
| [docs/demo_tasks/README.md](README.md) | 执行顺序与交接约定 |
| [docs/validation.md](../../docs/validation.md) | 自动化验证入口 |

## 已经实现的基础

M2 已完成战斗、随机装备、背包仓库和整备循环。当前持久化基线为独立 Hub 与五模块 Resource 检查点，仅 Hub 保存长期状态。P1_Task3 已完成 D1 装备额度，P1_Task4 已完成据点拆解与材料来源。

物品实例保存实际词条值，词条定义提供等级、部位、权重和互斥组。本任务在该结构上增加固定重铸位置与独立重铸随机序列，不新增存档模块。

## 本次实现

① 据点对未锁定的魔法/稀有背包装备开放重铸。第一次成功重铸选择一个已有随机词条位置，并把位置写入装备实例；后续只能继续重铸该位置。实例 ID、底材、品质、等级及未选词条保持。

② `ItemGenerator.affix_candidates()` 与 `roll_affix()` 成为掉落和重铸共用规则：按物品等级/部位筛选，排除其他位置已占据的词条与互斥组，沿用权重和数值区间。允许重新抽到相同词条或相同数值；独特装备不开放重铸。

③ `ReforgeRules` 集中配置费用：魔法基础 2 材料、稀有基础 4 材料，物品等级从 1 级起每跨 4 级额外 +1。

④ `ReforgeService` 使用独立 RNG；`InventoryState.reforge()` 一次提交词条、固定位置、材料和 RNG 状态。相同 `request_id` 返回首次结果，不重复扣费或推进随机序列。材料不足、零候选、锁定、仓库/穿戴、探险地点、独特装备和失效实例均拒绝提交并保持原值。

⑤ 人工试玩暴露“重铸详情动态塞进背包后挤压原页面”的 UI 架构问题后，本任务追加 Hub UI 模块化重构。重铸业务规则与存档结构保持原样，只重构展示与协调层。

## Hub UI 模块化重构

当前结构为：

```text
HubController（world/hub/hub.gd）
└── HubHUD（ui/hub/hub_hud.tscn/.gd）
    ├── BackpackPage
    ├── EquipmentPage
    ├── StashPage
    ├── LoadoutPage
    └── ReforgePage
```

`HubController` 持有会话、服务、保存和场景切换；`HubHUD` 负责页面组合、导航、工具栏和跨页面协调。背包、装备、仓库、装配、重铸均拥有独立 `.tscn + .gd`。探险场景继续使用原 `InventoryPanel`，据点重构不改变战斗 I 键背包。

背包页只保留轻量“重铸”入口并传递稳定 item ID。`ReforgePage` 独立显示装备摘要、词条位置、合法候选、费用、材料及结果；返回后按稳定 item ID 恢复原选择。标题与保存/读取/退出工具栏也已纳入 `HubHUD`，`hub.gd` 只通过 signal 与公开方法协调，不依赖 HUD 内部 NodePath。

已删除 Hub 与 HubHUD 的临时 UI 兼容别名；HubFlow、发布包 smoke、保存故障回归均改走公开接口。业务事务仍由 `ReforgeService` / `InventoryState` 负责，没有把经济、随机和存档规则复制到 UI。

## 主要修改范围

| 路径 | 实现落点 |
| --- | --- |
| `game/systems/town/reforge_rules.gd`、`reforge_service.gd` | 费用、地点/品质/锁定校验、候选预览、独立 RNG 与重复请求保护 |
| `game/systems/items/item_generator.gd` | 掉落/重铸共用候选与加权抽取 |
| `game/systems/items/item_instance_resource.gd` | `reforge_index`，默认 `-1` |
| `game/systems/inventory/items_resource.gd`、`inventory_state.gd` | items v2、独立重铸 RNG、v1→v2 升级及原子事务 |
| `game/world/hub/hub.gd` | 据点业务控制器，只协调会话、服务、保存与 HUD |
| `game/ui/hub/hub_hud.*` | 据点 UI 母控件、页面切换、工具栏和跨模块协调 |
| `game/ui/hub/backpack/` | 独立背包页与处置入口 |
| `game/ui/hub/equipment/` | 独立装备页 |
| `game/ui/hub/stash/` | 独立仓库页 |
| `game/ui/hub/loadout/` | 独立技能与被动页 |
| `game/ui/hub/reforge/` | 独立重铸页 |
| `game/tests/p1_reforge.*` | 重铸规则、事务、迁移专项回归 |
| `game/tests/hub_ui_modularity.*` | 据点页面边界、尺寸稳定、独立重铸页和返回选择专项回归 |
| `game/tests/hub_flow.gd` | 真实 Hub、保存与场景流公开接口回归 |
| `game/app/validation/pickup_smoke.gd` | 实际发布包 Hub 重铸与保存读回 |
| `game/tests/save_faults.gd` | 保存失败/恢复/退出完整故障探针 |

## 存档与兼容

items 模块由 v1 升到 **v2**。装备实例新增 `reforge_index`；`ItemsResource` 新增独立 `reforge_rng_seed/state`。v1→v2 升级把旧装备初始化为 `reforge_index=-1`，并从原掉落 `rng_seed` 稳定派生重铸 RNG；迁移不消耗、不改写原掉落 `rng_seed/state`。

首次重铸位置、新词条结果、材料余额和两套 RNG 均进入完整检查点。恢复后不会重新抽值；下一次重铸结果可复现，下一件掉落仍与未执行重铸的同掉落 RNG 快照一致。

本次 UI 重构**没有再次修改存档版本、字段和重铸事务语义**。

## 自动验收结果

① 单词条固定位置、候选筛选、零候选、重复请求、材料不足、锁定/归属/地点限制、同底材实例独立和属性即时生效全部通过。

② Resource 保存重开保留固定位置、材料、新词条及下一次重铸 RNG；掉落 RNG 不受重铸推进；items v1→v2 确定性迁移通过。

③ `HUB_UI_MODULARITY_RESULT` 覆盖 12 项：Hub 默认页互斥、选中可重铸装备不改变背包尺寸、背包只提供重铸入口、ReforgePage 独占固定 PageHost、返回恢复原稳定实例选择，以及装备/仓库/装配页面独立切换。

④ 保存故障探针恢复完整覆盖：写入、替换、损坏内容、缺失内容、索引、中断写入、正常退出。重构后的失败重试状态通过 `HubHUD` 公开接口验证。

⑤ 最终 PR head `55aafee06a0e95e74b454251471444626c482868` 的 Windows [run 34953250933](https://github.com/w7775p/relic-ARPG/actions/runs/34953250933) 全绿：官方 Godot 4.7.2、全量源码场景、故障进程、隔离 PCK、Windows `.exe` 导出及实际成品包拾取/重铸/保存验证全部成功。

用户最终验收使用 Windows 构建：[artifact 10389614800](https://github.com/w7775p/relic-ARPG/actions/runs/34953250933/artifacts/10389614800)，SHA256 `8e57b583d62e5899be9dc94864367d8e62f3e91d507319105eec278bd332994a`。启动日志：[artifact 10390451398](https://github.com/w7775p/relic-ARPG/actions/runs/34953250933/artifacts/10390451398)，SHA256 `a8b9c4beb47fb5d9db88932c5278ee3d3f4bb0c3ef416928a4337c874985c287`。

## 人工验收与合入

2026-09-15 用户完成 Windows 人工试玩并确认验收通过，覆盖据点四个主页面切换、背包布局稳定、独立重铸页操作与返回选择恢复，以及保存/读取/退出工具栏排版。

[PR #12](https://github.com/w7775p/relic-ARPG/pull/12) 已合入 main，merge commit：`154f4529fad0bcfbdbc6df68cb7eb217dc75d49c`。P1_Task5 完成，P1_Task6 解锁。

## 要求

1. 先检查当前项目状态、分支、最新 main、前置合入和验证入口。
2. 不实现与本任务无关的系统；无需使用 `global-work-rules`。
3. 以本卡验收为完成边界，数值属于原型参数。
4. 完成后按 AGENTS.md「完成任务前必须检查」执行；每个独立子任务验证后单独 commit。
5. PR 在自动门禁通过后提交，合并等待用户人工验收授权。

## 执行记录

原重铸实现提交：`261e8a0d` 保存固定位置与独立 RNG、items v2 迁移；`3b50f2e0` 共用候选/抽取规则；`b472ee23` 重铸费用与事务；`a92035cd` 初版 Hub UI；`527c7d46` 专项规则/事务/旧档迁移回归；`a921da3f` 发布包 smoke；`6753e618` 修正 smoke 测试顺序。

2026-09-15 根据人工试玩暴露的布局问题进行 UI 架构重构。主要提交包括：`9d06a84e` 拆出 HubHUD 与 ReforgePage；`dd0a5240` 拆出背包/装备/仓库/装配页；`29b5456c` 迁移装配回归；`b8c52879` 接入 Hub 模块化专项回归；`39c68332` 将工具栏纳入 HUD；`5a468a19`、`4e091a33` 迁移并恢复完整保存故障探针；`6ad05833` 补齐 HUD 黑盒接口；`2cc93def` 迁移 HubFlow；`6984d0dc` 迁移发布包重铸 smoke；`fb659ace` 删除 HubHUD 临时别名；`8f8fbb56` 删除 Hub 控制器兼容 UI 入口。

重构过程中出现的失败均来自旧自动测试直接依赖旧 UI 私有结构，或测试重写时误删原 quit 探针；业务重铸和持久化事务始终通过。上述测试已迁到公开接口并恢复原覆盖，因此没有新增项目级 `known_trap`。
