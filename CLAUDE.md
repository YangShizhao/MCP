# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个 **MCP (Model Context Protocol) 工具库**，集成了多种适用于不同 AI 工具（Claude Code、Cline、Codex、Continue 等）的 MCP 服务器。项目采用 **包装引用** 方式集成开源 MCP 工具，通过配置模板和文档帮助使用者快速在不同 AI 工具中启用这些 MCP 服务。

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
- **多工具兼容** — 每个工具目录下的 `config/` 为不同 AI 工具（Claude Code、Cline、Codex、Claude Desktop）提供配置模板
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

### 文档撰写约定

- 所有文档使用中文撰写（专有名词除外）
- 配置模板使用 JSON 格式
- MCP 工具名称使用英文原名（如 `pdf_read`、`merge_pdfs`）
