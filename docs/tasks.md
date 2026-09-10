# 阶段任务

状态以代码和验证记录为准；下表是仓库内任务入口。完整设计与后续 Demo 见 `plan.md`。

| 编号 | 阶段 | 具体工作 | 依赖 | 交付 | 验收 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| M0-01 | M0 | 工程与中文规范 | 空仓库 | project.godot、AGENTS、docs | 可导入 | 已实现 |
| M0-02 | M0 | 启动、菜单、设置、音频 | M0-01 | app、ui | 启动和设置生效 | 已实现 |
| M0-03 | M0 | 操控、镜头、碰撞、导航样板 | M0-01 | player、test_arena | 可移动、碰撞、路径绕障 | 已实现；手感待验收 |
| M0-04 | M0 | 位置存档与恢复 | M0-02/03 | SaveManager | 新场景恢复位置 | 已实现 |
| M0-05 | M0 | Windows 导出与验证 | M0-01～04 | 导出预设、工作流 | 独立包启动，目标机试玩 | 自动化状态见 validation.md |
| M1-01 | M1 | 生命、伤害、死亡结算 | M0 | 战斗与角色组件 | 同一死亡仅处理一次 | 已实现；验证见 validation.md |
| M1-02 | M1 | 普攻、旋风与能量 | M1-01 | 技能运行器 | 移动施放，耗尽停止 | 已实现；验证见 validation.md |
| M1-03 | M1 | 三类敌人与精英 | M1-01 | 近战、远程、冲锋 | 追击、攻击与死亡 | 已实现；验证见 validation.md |
| M1-04 | M1 | 雷霆旋风触发链 | M1-02/03 | 暴击闪电、感电爆炸、回复 | 有限触发、范围覆盖和目标去重 | 已实现；验证见 validation.md |
| M1-05 | M1 | 成型预设与反馈 | M1-04 | 调试装备、音效、特效 | 换预设可感受清怪差异 | 已实现；验证见 validation.md |
| M1-06 | M1 | 100 敌人压力测试 | M1-05 | 固定负载场景 | 记录设备与帧时间 | 已实现；验证见 validation.md |
| M2-01 | M2 | 装备定义与实例 | M1 | 底材、词条、装备 ID | 实例独立、合法抽取 | 已实现；自动验证见 validation.md，待人工试玩 |
| M2-02 | M2 | 掉落、拾取与背包 | M2-01 | 战利品、背包、穿脱 | 换装立即影响战斗 | 已实现；自动验证见 validation.md，待人工试玩 |
| M2-03 | M2 | 整备与成长 | M2-02 | 仓库、出售、升级、再次出发 | 完成多趟循环 | 已实现；自动验证见 validation.md，待人工试玩 |
| M2-04 | M2 | 完整探险存档 | M2-01～03 | 状态序列化与恢复 | 装备与探险一致 | 已实现；自动验证见 validation.md，待人工试玩 |

任务备注格式：`编号｜阶段｜系统｜具体工作｜前置依赖｜交付文件或场景｜验收步骤与预期｜状态｜备注`。

MVP 在 M2 全部验收后成立。D1 加入流血横扫及重铸循环，D2 加入冲锋重击、房间组合与首领，D3 完成引导、配置、平衡、性能和发行准备。

## D1～D3 独立任务卡

2026-09-10：M0/M1/M2 已合并 main，核对基线 `313ac7f`。用户已试玩 M2，反馈效果可以；历史自动化结果保留在 `validation.md`。下列为新拆分的待执行任务，完整依赖与使用方法见 [D1～D3 任务总表](demo_tasks/README.md)。

| 任务 | 交付主题 | 硬依赖 | 状态 |
| --- | --- | --- | --- |
| [P1_Task 1](demo_tasks/P1_Task1.md) | 技能装配与被动选择 | main 的 M2 | 待执行 |
| [P1_Task 2](demo_tasks/P1_Task2.md) | 流血横扫、战吼与恢复药剂 | P1_Task 1 | 待执行 |
| [P1_Task 3](demo_tasks/P1_Task3.md) | D1 装备池、精英修饰与地图变体 | P1_Task 2 | 待执行 |
| [P1_Task 4](demo_tasks/P1_Task4.md) | 据点拆解与材料循环 | P1_Task 3 | 待执行 |
| [P1_Task 5](demo_tasks/P1_Task5.md) | 单词条位置重铸 | P1_Task 4 | 待执行 |
| [P1_Task 6](demo_tasks/P1_Task6.md) | D1 过滤、属性解释与阶段验收 | P1_Task 1、P1_Task 2、P1_Task 3、P1_Task 4、P1_Task 5 | 待执行 |
| [P2_Task 1](demo_tasks/P2_Task1.md) | 冲锋重击与被动扩展 | P1_Task 6 | 待执行 |
| [P2_Task 2](demo_tasks/P2_Task2.md) | 墓园敌人与精英组合 | P2_Task 1 | 待执行 |
| [P2_Task 3](demo_tasks/P2_Task3.md) | 墓园房间标准与十二个模板 | P2_Task 2 | 待执行 |
| [P2_Task 4](demo_tasks/P2_Task4.md) | 随机连接、导航与布局存档 | P2_Task 3 | 待执行 |
| [P2_Task 5](demo_tasks/P2_Task5.md) | 墓园首领战 | P2_Task 4 | 待执行 |
| [P2_Task 6](demo_tasks/P2_Task6.md) | 三档难度、宝箱与据点入口 | P2_Task 5 | 待执行 |
| [P2_Task 7](demo_tasks/P2_Task7.md) | 目标掉落与 Demo 装备总量 | P2_Task 6 | 待执行 |
| [P2_Task 8](demo_tasks/P2_Task8.md) | 主要美术、动作与音效替换 | P2_Task 7 | 待执行 |
| [P2_Task 9](demo_tasks/P2_Task9.md) | 随机区域整体验收与存档回归 | P2_Task 1、P2_Task 2、P2_Task 3、P2_Task 4、P2_Task 5、P2_Task 6、P2_Task 7、P2_Task 8 | 待执行 |
| [P3_Task 1](demo_tasks/P3_Task1.md) | 首次引导、保存与结算反馈 | P2_Task 9 | 待执行 |
| [P3_Task 2](demo_tasks/P3_Task2.md) | 键位、显示、声音与镜头设置 | P3_Task 1 | 待执行 |
| [P3_Task 3](demo_tasks/P3_Task3.md) | 物品说明、过滤预设与界面可读性 | P3_Task 2 | 待执行 |
| [P3_Task 4](demo_tasks/P3_Task4.md) | 成长、经济与构筑平衡 | P3_Task 3 | 待执行 |
| [P3_Task 5](demo_tasks/P3_Task5.md) | 怪群、标签与加载性能 | P3_Task 4 | 待执行 |
| [P3_Task 6](demo_tasks/P3_Task6.md) | Demo 发行构建与交付 | P3_Task 1、P3_Task 2、P3_Task 3、P3_Task 4、P3_Task 5 | 待执行 |
