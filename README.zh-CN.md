# NimdaGame

语言：[English](README.md) | 简体中文 | [日本語](README.ja.md)

NimdaGame 是一个基于 Godot 的可复用游戏框架，面向轻量级 RPG 类项目：

- 回合制 RPG
- 简单实时 RPG 和幸存者类动作游戏
- 战棋游戏
- 塔防游戏
- 增量或放置类游戏

这个仓库不是围绕单个独立游戏组织的，而是围绕复用组织的。共享运行时代码、共享资源、数据工具和构建工具都放在稳定路径下。每个游戏类型拥有自己的独立包目录。

目录约定见 [docs/repository_layout.md](docs/repository_layout.md)。
分层边界见 [docs/architecture.md](docs/architecture.md)。
运行时插件规范见 [docs/plugin_system.md](docs/plugin_system.md)。

## 分层模型

- Godot 负责应用流程、场景、UI 展示、输入、动画、音频、调试面板和编辑器相关工作流。
- 纯 C++ core 负责确定性的玩法模拟，包括战斗规则、单位、技能、增益、网格、经济、随机数和存档。
- Python 工具负责校验源数据、生成运行时 JSON，以及运行离线模拟或平衡报告。
- 运行时插件可以用 GDScript、C++ GDExtension 类或外部脚本实现，并通过统一 hook 合约接入。

## 仓库结构

```text
game/app/            Godot 启动场景和全局应用流程
game/common/         多个游戏类型共享的 Godot 运行时代码
game/shared_assets/  共享美术、音频、字体、图标和其他可复用资源
game/genres/         各游戏类型的 Godot 包
game/plugins/        运行时插件 manifest 和实现
core/common/         共享 C++ 玩法基础设施
core/modules/        可复用玩法模块
core/genres/         各游戏类型的 C++ 玩法编排
bindings/            Godot GDExtension 桥接层和可选 CLI 适配器
data/common/         共享源数据
data/genres/         各游戏类型的源数据
data/schemas/        配置数据和 manifest 的 JSON Schema
tools/               Python 校验、生成、模拟和发布工具
docs/                架构和工作流文档
release/             发布目标配置、检查清单和发布说明模板
```

## 当前 Godot 入口

Godot 项目从这里启动：

```text
game/app/scenes/main.tscn
```

这个场景是一个轻量的框架 shell。玩法 demo 和 UI 生成实验已经移除，当前仓库优先沉淀可复用结构。

## 初始工作流

1. 在 `data/common/` 下编写共享数据，在 `data/genres/<genre>/` 下编写类型专属数据。
2. 使用 `tools/` 下的 Python 工具校验并生成运行时 JSON。
3. Godot 从 `game/data/generated/` 加载生成后的 JSON。
4. 通过 Godot 绑定层调用 C++ 玩法模拟。
5. 通过 `game/genres/<genre>/` 下的 Godot 场景展示结果。

## 发布流水线

```powershell
python tools/mygame_tools/release_pipeline.py plan
python tools/mygame_tools/release_pipeline.py check
python tools/mygame_tools/validate_plugins.py
python tools/mygame_tools/release_pipeline.py notes --version 0.1.0
```

真正导出需要本机 Godot export presets。详见 [docs/release_pipeline.md](docs/release_pipeline.md)。

## 当前状态

当前仓库包含可复用项目结构、插件注册器、数据工具桩、C++ core scaffold、Godot GDExtension scaffold 和发布工具。下一个实现里程碑应该在某个游戏类型包内添加一条完整垂直切片，而不是继续把玩法放到通用 demo 目录下。
