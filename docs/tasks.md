# 阶段任务

状态以代码和验证记录为准；下表是仓库内任务入口。完整设计与后续 Demo 见 `plan.md`。

| 编号 | 阶段 | 具体工作 | 依赖 | 交付 | 验收 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| M0-01 | M0 | 工程与中文规范 | 空仓库 | project.godot、AGENTS、docs | 可导入 | 已实现 |
| M0-02 | M0 | 启动、菜单、设置、音频 | M0-01 | app、ui | 启动和设置生效 | 已实现 |
| M0-03 | M0 | 操控、镜头、碰撞、导航样板 | M0-01 | player、test_arena | 可移动、碰撞、路径绕障 | 已实现；手感待验收 |
| M0-04 | M0 | 位置存档与恢复 | M0-02/03 | SaveManager | 历史位置恢复 | 历史功能；已由 Resource 检查点替代 |
| M0-05 | M0 | Windows 导出与验证 | M0-01～04 | 导出预设、工作流 | 独立包启动，目标机试玩 | 自动化状态见 validation.md |
| M1-01 | M1 | 生命、伤害、死亡结算 | M0 | 战斗与角色组件 | 同一死亡仅处理一次 | 已实现；验证见 validation.md |
| M1-02 | M1 | 普攻、旋风与能量 | M1-01 | 技能运行器 | 移动施放，耗尽停止 | 已实现；验证见 validation.md |
| M1-03 | M1 | 三类敌人与精英 | M1-01 | 近战、远程、冲锋 | 追击、攻击与死亡 | 已实现；验证见 validation.md |
| M1-04 | M1 | 雷霆旋风触发链 | M1-02/03 | 暴击闪电、感电爆炸、回复 | 有限触发、范围覆盖和目标去重 | 已实现；验证见 validation.md |
| M1-05 | M1 | 成型预设与反馈 | M1-04 | 调试装备、音效、特效 | 换预设可感受清怪差异 | 已实现；验证见 validation.md |
| M1-06 | M1 | 100 敌人压力测试 | M1-05 | 固定负载场景 | 记录设备与帧时间 | 已实现；验证见 validation.md |
| M2-01 | M2 | 装备定义与实例 | M1 | 底材、词条、装备 ID | 实例独立、合法抽取 | 已实现；自动验证见 validation.md，待人工试玩 |
| M2-02 | M2 | 掉落、拾取与背包 | M2-01 | 战利品、背包、穿脱 | 换装立即影响战斗 | 导出词条部位丢失已修复；PCK/Windows exe 内 27 项通过，新包见 validation.md |
| M2-03 | M2 | 整备与成长 | M2-02 | 仓库、出售、升级、再次出发 | 完成多趟循环 | 已实现；自动验证见 validation.md，待人工试玩 |
| M2-04 | M2 | 完整探险存档 | M2-01～03 | 历史 JSON 快照 | 历史探险恢复 | 已退休；正式规则见 Resource 重构 |

任务备注格式：`编号｜阶段｜系统｜具体工作｜前置依赖｜交付文件或场景｜验收步骤与预期｜状态｜备注`。

MVP 在 M2 全部验收后成立。D1 加入流血横扫及重铸循环，D2 加入冲锋重击、房间组合与首领，D3 完成引导、配置、平衡、性能和发行准备。

## D1 执行状态

| 任务 | 内容 | 状态 | 验证 |
| --- | --- | --- | --- |
| [P1_Task1](demo_tasks/P1_Task1.md) | 技能装配、六被动、据点调整与 v3 迁移 | 已完成 | 自动回归通过；2026-09-11 用户可见试玩验收通过 |
| [P1_Task2](demo_tasks/P1_Task2.md) | 流血横扫、战吼、恢复药剂与 v4 持续状态存档 | 已完成 | 最终 166 项自动回归通过；Windows 导出与独立启动通过；2026-09-11 用户可见试玩验收通过 |
| [P1_Task3](demo_tasks/P1_Task3.md) | 14/18/4 装备池、流血传播、两种精英修饰、固定场地双变体 | 已完成 | 最终 Windows run 34808913642 全量源码/PCK、Windows exe 与成品包验证通过；2026-09-14 用户最终复测验收通过；PR #10 已合入 main `48479ed` |
| [P1_Task4](demo_tasks/P1_Task4.md) | 据点单件拆解、出售/拆解收益选择与材料循环 | 已完成 | Windows run 34813475464 全量源码/PCK、Windows exe 与成品包验证通过；2026-09-14 用户试玩验收通过；PR #11 已合入 main `4798f7b`；数值与交互优化后置 |
| [P1_Task5](demo_tasks/P1_Task5.md) | 魔法/稀有单词条位置重铸、独立 RNG、items v2 与 Hub UI 模块化 | 待验收 | 最终重构 head `8f8fbb56`；Windows run 34952323992 全量源码、12 项 Hub 模块化、专项重铸、7 类故障、PCK、Windows exe 与实际成品 Hub 重铸/保存读回全部通过；待人工试玩 |

后续顺序见 [任务总表](demo_tasks/README.md)。P1_Task5 人工验收并合入后进入 P1_Task6。

## 架构重构

| 任务 | 内容 | 状态 | 验证 |
| --- | --- | --- | --- |
| Hub 拆分 | MainMenu → 独立 Hub → ExpeditionRuntime → Hub | 已合入 main `30b85f0`，PR #7 | 历史证据见 hub_refactor.md |
| [Resource 存档](resource_save_task.md) | 五模块、多角色多槽、Hub 检查点、整体回退、旧 JSON/旧探险移除 | 已合入 main `3cdc612`，PR #8；可见画面与手感待验收 | 11 个常规场景＋7 个故障进程＋PCK 成品回归；Windows exe 的生成/拾取/存档通过，详见 validation.md |
| P1_Task5 Hub UI 模块化 | `HubHUD` 总控 + 背包/装备/仓库/装配/重铸独立页面；工具栏归属 HUD；探险继续使用独立 `InventoryPanel` | 已在 `feat/p1-task5-reforge` 实现，待随 Task5 人工验收 | `HUB_UI_MODULARITY_RESULT` 12 项通过；最终 Windows run 34952323992 全绿 |

P1_Task1/2 的 v3/v4 描述属于原阶段交付历史。后续任务以 Resource 存档和真实 Hub 为准，保留新 Resource 已发布版本的升级链；不再要求 JSON 迁移或战斗中恢复。

2026-09-14 P1_Task3 已完成并通过人工验收；[PR #10](https://github.com/w7775p/relic-ARPG/pull/10) 合入 main `48479ed9ec67c1943d9cf590b8e430976547ed79`。P1_Task4 已完成自动与人工验收；[PR #11](https://github.com/w7775p/relic-ARPG/pull/11) 合入 main `4798f7b83dcb01405e1e8b7ab175a4c2b6c63284`。P1_Task5 已完成自动验收及试玩反馈触发的 Hub UI 结构整改：items 模块保持 v2，重铸业务规则不变，重铸改为独立页面并完成公开接口迁移；最终 run 34952323992 全绿，当前等待用户试玩新构建后再合入并进入 P1_Task6。
