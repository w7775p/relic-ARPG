# P1_Task 2：流血横扫、战吼与恢复药剂

仓库：[w7775p/relic-ARPG](https://github.com/w7775p/relic-ARPG)。工程入口：`game/project.godot`。技术栈：Godot 4.7.2 标准版、GDScript、3D 俯视即时动作、Windows 键鼠。

阶段：D1。状态：待验收。任务 ID：`P1_Task2`。执行分支：`feat/p1-task2-bleed-skills`。前置任务：[P1_Task1](P1_Task1.md)。

## 开始前阅读

`AGENTS.md`、`README.md`、`docs/engineering.md`、`docs/tasks.md`、`known_trap.md`、`docs/plan.md`、`docs/demo_tasks/README.md`、`docs/validation.md`，以及前置任务卡。运行代码的最新状态用于判断实际已实现内容。

## 本次任务

① 新增流血横扫：前方范围直接攻击并附加流血；据点可以把右键旋风替换为横扫。伤害、范围、能耗、攻击间隔和流血参数均使用资源配置。

② 流血使用有界持续伤害：保存来源、攻击时属性、剩余时间和下一跳时间。最多三层；满层再次施加时替换剩余时间最短的一层。流血跳伤来源独立，跳伤无暴击闪电和直接命中回能；流血击杀沿统一死亡事件结算一次击杀收益。

③ 新增战吼并接入 F 辅助槽：短时提高护甲并立即回复能量，带持续时间和冷却；重复施放刷新持续时间，临时护甲保持单层。

④ 新增 Q 恢复药剂：按最大生命比例治疗并进入冷却；满血、死亡、暂停和冷却期间的请求均保持状态原值。据点整备重置药剂冷却。药剂独立于装备背包和技能槽。

⑤ 提供横扫方向、流血、战吼持续期和药剂冷却的基础反馈，并提供独立流血测试预设。

## 主要实现位置

| 路径 | 职责 |
| --- | --- |
| `game/systems/skills/` | 横扫、战吼、药剂配置与施放逻辑 |
| `game/systems/combat/`、`game/systems/effects/` | 直接伤害、流血跳伤、统一死亡收益与有限事件队列 |
| `game/actors/components/combat_actor.gd` | 流血层、生命恢复、持续状态计时 |
| `game/content/skills/` | `sweep.tres`、`warcry.tres`、`potion.tres` |
| `game/world/maps/expedition.gd` | 装配入口、战斗状态快照、恢复与据点重置 |
| `game/systems/persistence/` | v4 快照、校验与 v2/v3 迁移 |
| `game/ui/inventory/`、`game/project.godot` | 技能整备说明、F/Q 语义动作与冷却提示 |
| `game/tests/`、`tools/verify.py` | 实际场景回归与统一验证入口 |

## 存档与兼容

完整探险存档版本升级为 v4，增加敌人流血层、横扫计时、战吼持续/冷却/生效状态与药剂冷却。v2 依次迁移到 v3/v4，v3 直接补齐 v4 状态。战斗中保存后，流血从保存的下一跳继续，战吼和药剂按剩余时间继续。

## 验收标准

① 横扫前后方、范围边缘和地形遮挡符合配置；流血最多三层，刷新规则稳定，暂停期间计时冻结。

② 雷霆与流血混合时，持续伤害保持独立来源；流血击杀的击杀回能、金币、经验和掉落各结算一次。

③ 药剂受伤后可治疗；冷却重复输入、满血、死亡、暂停与读档行为一致。

④ 流血下一跳前、战吼结束前保存重启，剩余伤害、持续时间、护甲恢复和冷却继续正确推进。

⑤ `python tools/verify.py --godot <引擎路径>` 全量回归通过；Windows 导出包可以独立启动。画面、声音和操作手感由可见人工试玩完成最终验收。

## 完成检查

按 `AGENTS.md` 的完成任务检查执行：核对差异范围、中文注释、资源与 UID、存档版本、回归入口、文档同步和实际工作流结果。仅记录实际遇到的问题到 `known_trap.md`。

## 执行记录

执行日期：2026-09-11。开工时最新 `main` 为 `313ac7f`。前置 [PR #5](https://github.com/w7775p/relic-ARPG/pull/5) 仍处于 open，因此从其 head `1ff89c7` 建立堆叠分支 `feat/p1-task2-bleed-skills`。任务卡已随前置分支存在。

实现结果：右键主要槽新增流血横扫；F 辅助槽新增战吼；Q 新增独立恢复药剂；HUD 与基础反馈同步。完整探险存档升级为 v4，并保留 v2/v3 迁移链。实际开发中发现战吼临时护甲会被经验或装备属性重算覆盖，现已统一按基础护甲重建并补回有效战吼层，记录为 `P1-02`。

功能验证提交：`0dc446a8fdcce1d014aba6ef8c82457afa3b60c3`。Windows GitHub Actions 使用官方 Godot `4.7.2.stable.official.ed1daf0bf` 与同版导出模板。全量回归共 159 项：M0 20、M1 26、M2 46、P1_Task1 31、P1_Task2 36，结果为 0 失败。Windows `.exe` 导出成功，导出包独立 headless 启动进入 `M2_EXPEDITION_BOOT_READY`，日志无脚本错误。

工作流：[run 34552955127](https://github.com/w7775p/relic-ARPG/actions/runs/34552955127)。Windows 构建：[artifact 10181489752](https://github.com/w7775p/relic-ARPG/actions/runs/34552955127/artifacts/10181489752)。交付：[PR #6](https://github.com/w7775p/relic-ARPG/pull/6)，base 为 `feat/p1-task1-loadout`，head 为 `feat/p1-task2-bleed-skills`。前置合入后可将 PR #6 的 base 调整到 `main`。

机器验收已经通过。当前剩余人工项：横扫方向反馈、流血视觉辨识度、战吼与药剂反馈、中文排版、声音听感和实际操作手感，因此任务状态保持“待验收”。
