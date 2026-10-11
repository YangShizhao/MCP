# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个 **MCP (Model Context Protocol) 工具库**，集成了多种适用于不同 AI 工具（Claude Code、Cline、Codex、Continue、DeepSeek Harness 等）的 MCP 服务器。项目采用 **包装引用** 方式集成开源 MCP 工具，通过配置模板和文档帮助使用者快速在不同 AI 工具中启用这些 MCP 服务。

## 项目架构

```
MCP/
├── README.md                       # 项目总览与快速开始
├── docs/tools-overview.md          # 工具分类总览与兼容性矩阵
├── pdf/                            # PDF 文档处理工具 (npm)
│   ├── README.md                   # PDF 工具总览与配合使用说明
│   ├── pdf-reader-mcp/             # 读取/搜索/表格提取（sylphlab）
│   │   ├── README.md               # 详细使用文档
│   │   └── config/                 # 各 AI 工具的 MCP 配置模板
│   └── pdf-toolkit-mcp/            # 创建/编辑/操作 37 个工具（beepboop2025）
│       ├── README.md               # 详细使用文档
│       └── config/                 # 各 AI 工具的 MCP 配置模板
├── office/                         # Office 文档处理工具 (Python)
│   ├── README.md                   # Office 套件总览
│   ├── wordmcp/                    # Word 处理 — 51 个工具
│   ├── pptmcp/                     # PowerPoint 处理 — 48 个工具
│   └── excelmcp/                   # Excel 处理 — 65 个工具
├── scripts/                        # 打包与安装脚本
│   ├── pack.sh                      # 离线打包脚本（WSL/Linux/Mac）
│   ├── pack.ps1                     # 离线打包脚本（Windows PowerShell）
│   ├── pack.cmd                     # Windows CMD 启动器（调用 pack.ps1）
│   ├── install.ps1                  # Windows 安装脚本
│   └── install.sh                   # Linux/Mac 安装脚本
├── build/                           # 构建产物（.gitignore）
└── ...                             # 未来更多工具分类（图片、搜索、数据库等）
```

### 设计原则

- **分类目录** — 按功能领域（pdf、image、search 等）组织工具子目录
- **包装引用** — 不复制源码，通过文档 + 配置模板的方式引用上游开源项目
- **多工具兼容** — 每个工具目录下的 `config/` 为不同 AI 工具（Claude Code、Claude Desktop、Cline、Codex、Continue、DeepSeek Harness）提供配置模板
- **文档齐全** — 每个工具必须包含 README.md 说明用途、安装方式、工具列表和使用示例

## 离线打包

### 打包流程

```bash
# ---- Windows (CMD / PowerShell) ----
# 默认打包全部工具 + Node.js + Python。用 --skip-* 排除不需要的。
scripts\pack.cmd                                       # 全部（默认）
scripts\pack.cmd --skip-office --skip-python           # 仅 PDF
scripts\pack.cmd --skip-pdf --skip-nodejs              # 仅 Office
scripts\pack.cmd --skip-nodejs --skip-python           # 不含运行时

# 或直接使用 PowerShell:
powershell -File scripts/pack.ps1
powershell -File scripts/pack.ps1 -SkipOffice -SkipPython
powershell -File scripts/pack.ps1 -SkipNodejs

# ---- WSL / Linux / Mac ----
bash scripts/pack.sh                                   # 全部（默认）
bash scripts/pack.sh --skip-office --skip-python       # 仅 PDF
bash scripts/pack.sh --skip-pdf --skip-nodejs          # 仅 Office
bash scripts/pack.sh --skip-nodejs --skip-python       # 不含运行时
```

输出文件位于 `build/mcp-offline-{platform}-{date}.zip`。

### 安装流程

**Windows**：将 zip 复制到目标机器 → 解压 → 以管理员身份运行 `install.ps1`

**Linux/Mac**：将 zip 复制到目标机器 → 解压 → `sudo bash install.sh`

### 打包注意事项

**PDF 工具 (npm):**
- `pdf-toolkit-mcp` 未发布到 npm，需通过 git clone + npm build 方式获取
- `@sylphx/pdf-reader-mcp` 要求 Node.js >= 22.13.0
- 两个工具均为纯 JS 实现，`node_modules` 跨平台可移植

**Office 工具 (Python):**
- `mcp-office` 未发布到 PyPI，需通过 git clone + pip install -e 获取
- 要求 Python >= 3.11, 依赖 fastmcp/python-docx/python-pptx/openpyxl/Pillow
- `pptmcp` 额外依赖本地 `shared` 包（mcpshared），需先安装
- Python 离线打包使用 `pip download` 获取 wheel → `pip install --no-index` 安装
- COM 功能（样式/PDF导出/修订跟踪）仅 Windows + MS Office 支持
- 文件模式（python-docx/pptx/openpyxl）无需 Office，跨平台可用

**运行时:**
- 默认打包 Node.js 和 Python 运行时 → 用 `--skip-nodejs` / `--skip-python` 排除
- 安装时自动检测系统运行时版本，满足要求则优先使用系统版本
- 系统版本不满足时自动使用打包的运行时
- 启动器脚本通过相对路径引用依赖，解压到任意目录均可使用

## 项目维护操作

### 添加新 MCP 工具

1. 在对应分类目录下创建 `新工具名/` 子目录
2. 在子目录中创建 README.md，包含：
   - 工具来源（GitHub 链接、npm/pip 包名）
   - 核心特性
   - 安装命令
   - 提供的 MCP 工具列表
   - 使用示例
3. 在子目录下创建 `config/` 文件夹，为每种 AI 工具提供 MCP 配置模板
4. 更新 `docs/tools-overview.md` 的兼容性矩阵
5. 更新对应分类的 `README.md`
6. 更新根目录 `README.md` 的工具表格

### 配置模板命名规范

配置目录 `config/` 中的文件按 AI 工具命名：
- `claude-code.json` — Claude Code CLI
- `claude-desktop.json` — Claude Desktop
- `cline.json` — Cline (VSCode 扩展)
- `codex.json` — OpenAI Codex CLI
- `dsh.yml` — DeepSeek Harness（YAML，唯一的非 JSON 模板）

### DeepSeek Harness (dsh) 配置说明

dsh 不使用 `mcpServers` 映射，而是在 `$DSH_HOME/cordis.patch.yml`
（默认 `~/.dsh/cordis.patch.yml`，Windows 为 `%USERPROFILE%\.dsh\cordis.patch.yml`）
中写 YAML 加载器补丁记录。该用户补丁层会应用到**所有** dsh profile
（web / headless / sdk / acp / 自定义），每个 MCP 服务器是一条引用
`@deepseek-ai/dsh-mcp-client` 插件的 `insert` 记录：

```yaml
- insert:
    - id: mcp-<name>                 # 补丁行 id，普通安装按 mcp-<serverName> 命名
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: <name>           # 工具命名空间：mcp__<serverName>__<tool>
        transport: stdio             # 或 streamable-http（需 url/headers）
        command: <可执行文件>
        args: [...]
        env: { ... }                 # 可选
```

要点：
- 模板块插入前必须先删除文件里可能存在的空根占位符 `[]`，否则 YAML 会出现两个根节点
- 已存在的 `- id: mcp-<name>` 行不得覆盖（用户自定义优先）
- Windows 下 stdio 启动器为 `.cmd`，需写成 `command: cmd` + `args: [/d, /s, /c, '<路径>']`
- 安装脚本 `scripts/install.sh` / `scripts/install.ps1` 会自动合并该配置
- **白名单规则**（安装时自动探测）：Windows 见 `install.ps1` 的 `Get-AllowlistRoots`——取「C 盘当前
  用户空间（`$env:USERPROFILE`，唯一需要隔离的盘符）+ 其余所有就绪的固定 / 可移动盘整盘」，
  用 `-AllowlistRoots "C:\Users\me,D:\"` 可覆盖；Unix 见 `install.sh` 的 `detect_allowlist_roots`——取
  「`$HOME` + `/mnt`、`/media`、`/run/media`、`/Volumes` 下的挂载点」，用 `--allowlist-roots` 可覆盖
  （不在这些惯用位置的挂载点需手工加）。本机 Windows 探测结果：`C:\Users\yshzh,D:\`。
- 手工复制的模板（`office/*/config/*`）里写的是 `<用户名>`、`D:\`、`/mnt/data` 这类**占位符**：
  环境变量的值不会被 shell 展开，必须替换成真实路径（否则会报 `Path not in allowlist`）；
  用安装脚本则自动写入按目标机器探测出的值。
- 多个根用**逗号**分隔，路径 `resolve()` 后按前缀判定。该白名单同时约束**读取**：不在其中的
  文件一律报 `Path not in allowlist`，所以处理任何文档前先确认它落在白名单内。
  Excel 另有 `EXCEL_EXPORT_ROOTS`（**逗号**）与 `EXCEL_CSV_EXPORT_ROOTS`（**分号**）约束导出
  输出路径，两者语义不同、最容易漏；安装脚本会把这三个变量写成同一份根列表。

### Office COM 功能（调用前必须提醒用户关闭 Office）

`WORD_ENABLE_COM` / `PPT_ENABLE_COM` / `EXCEL_ENABLE_COM` 是 mcp-office 的**显式开关**，
安装脚本从不写它们（默认关闭）。本机已在 `%USERPROFILE%\.dsh\cordis.patch.yml` 的
word / ppt / excel 三个条目中设为 `"true"`，并设 `toolCallTimeoutMs: 180000`
（COM 首次冷启动通常超过默认的 60 秒，届时客户端会先报 `Request timed out`，
但服务端往往仍在继续并最终成功）。

**提醒义务（重要）**：这些 COM 工具通过 `Dispatch()` 接管**用户正在运行的** Office 实例，
收尾时 `finally: app.Quit()` 把它一并退出，且 `DisplayAlerts=0`——未保存内容不会有保存提示。
因此**调用任何 COM 功能前，先提醒用户保存并关闭 Word / PowerPoint / Excel**；
若对应应用正在运行且可能有未保存内容，先停下来询问用户，不要直接调用。
检查方式：`Get-Process WINWORD,EXCEL,POWERPNT -ErrorAction SilentlyContinue`。

受管制的典型功能：

| 服务器 | COM 功能 |
|--------|----------|
| word | 导出 PDF/HTML（`export`、`export_document`）、修订跟踪（`manage_tracked_changes`）、真实 Word 读取 |
| ppt | 导出 PNG/PDF（`export`、`export_slide`、`export_deck`）、图表重算（`recalculate_charts`）、放映（`run_slide_show`） |
| excel | 导出 PDF（`export_as_pdf`）、数据透视表（`pivot_table`）、重算（`recalculate_workbook`）、VBA（`run_macro`）、模板套用（`hydrate_template`） |

### 文档撰写约定

- 所有文档使用中文撰写（专有名词除外）
- 配置模板使用 JSON 格式（DeepSeek Harness 例外，使用 YAML `dsh.yml`）
- MCP 工具名称使用英文原名（如 `pdf_read`、`merge_pdfs`）
