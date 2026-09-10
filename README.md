# Relic ARPG

单机 3D 俯视动作刷宝项目。第一套构筑计划为雷霆旋风，目标是成型后高速清理怪群。当前提交为 M0 工程基础，正式名称待定。

## 启动

使用 **Godot 4.7.2 标准版**打开 `game/project.godot`，按 F6 运行当前场景或 F5 运行项目。项目运行时 F5 用于保存位置。Windows 键鼠为首个验证平台；M0 使用兼容渲染器和原生几何体占位资产。

| 操作 | 按键 |
| --- | --- |
| 移动 | WASD / 方向键 |
| 朝向 | 鼠标瞄准地面 |
| 闪避 | 空格；沿移动方向，静止时沿朝向 |
| 暂停 | Esc |
| 保存位置 | F5；也可使用暂停菜单 |

目前可以从主菜单进入带障碍的试炼场、移动与闪避、暂停、修改总音量和全屏、保存后返回菜单、继续上次位置。离开窗口时打开暂停菜单，使用“保存并退出”结束。

**尚未实现：**伤害、敌人、旋风斩、连锁闪电、装备、掉落、背包和完整探险存档。这些按 M1/M2 实施；当前存档只承载测试位置。视觉、音效听感、Windows 目标机手感与性能仍需人工验证。

## 验证与导出

```bash
python tools/verify.py --godot /path/to/godot
```

该命令使用临时用户目录运行导入、启动及 M0 场景回归，避免改写正常存档。所有测试失败与引擎错误均返回失败状态。

安装同版导出模板，创建 `builds/windows/` 后执行：

```bash
godot --headless --path game --editor --import --quit
godot --headless --path game --export-release "Windows Desktop" ../builds/windows/relic_arpg.exe
```

Windows 成品为内嵌资源的 `relic_arpg.exe`。`.github/workflows/windows.yml` 提供自动验证、导出及 Windows 包启动检查，成功后在对应 Actions（自动化工作流）页面下载 `relic-arpg-m0-windows`。实际执行状态见工作流页面。

正常用户数据由 Godot 写入 `user://`，Windows 默认位于 `%APPDATA%/Godot/app_userdata/Relic ARPG/`。`settings.cfg` 保存设置，`session.json` 保存测试场地位置。

## 项目文档

| 文件 | 内容 |
| --- | --- |
| [docs/plan.md](docs/plan.md) | 全量工程规范、MVP 与 Demo 阶段规划 |
| [docs/tasks.md](docs/tasks.md) | M0/M1/M2 任务与验收 |
| [docs/engineering.md](docs/engineering.md) | 当前代码结构、实现选择和版本 |
| [docs/assets.md](docs/assets.md) | 资产命名、比例、交付要求 |
| [docs/asset_sources.md](docs/asset_sources.md) | 当前资产来源与依赖 |
| [docs/validation.md](docs/validation.md) | 实际测试记录及未验证项 |
| [docs/work_log.md](docs/work_log.md) | 工作进度 |
| [known_trap.md](known_trap.md) | 已发现问题及处理方式 |

代码从此仓库空提交开始编写。本轮没有读取其他业务仓库或引入跨项目代码。
