# MCP Tools Library / MCP 工具库

A collection of MCP (Model Context Protocol) servers for AI tools — Claude Code, Cline, Codex, Continue, and more.
适用于多种 AI 工具的 MCP 服务器集合。

## Project Structure / 目录结构

```
MCP/
├── README.md
├── docs/                           # Documentation / 文档
│   └── tools-overview.md           # Tools overview / 工具总览
├── scripts/                        # Pack & install scripts / 打包与安装脚本
│   ├── pack.cmd / pack.ps1         # Windows pack scripts
│   ├── pack.sh                     # WSL/Linux/Mac pack script
│   ├── install.cmd / install.ps1   # Windows install scripts
│   └── install.sh                  # Linux/Mac install script
├── upstream/                       # Git submodules / 上游源码（子模块）
├── pdf/                            # PDF tools docs & configs / PDF 工具文档与配置
│   ├── pdf-reader-mcp/
│   └── pdf-toolkit-mcp/
├── office/                         # Office tools docs & configs / Office 工具文档与配置
│   ├── wordmcp/
│   ├── pptmcp/
│   └── excelmcp/
└── .cache/                         # Download cache (git-ignored) / 下载缓存（已排除版本控制）
    ├── git/                        # Git repos (submodules) / Git 仓库（子模块）
    ├── npm/                        # npm dependencies / npm 依赖
    ├── pip/                        # Python wheels / Python 包
    └── runtimes/                   # Node.js & Python portable / Node.js 与 Python 便携版
```

## Included Tools / 已集成的工具

### PDF Document Processing / PDF 文档处理

| Tool | Tools | Description / 用途 | Source / 来源 |
|------|-------|-------------------|---------------|
| [pdf-reader-mcp](pdf/pdf-reader-mcp/) | 8 | Read, search, table extraction, page rendering / 读取、搜索、表格提取、页面渲染 | [SylphxAI/pdf-reader-mcp](https://github.com/SylphxAI/pdf-reader-mcp) |
| [pdf-toolkit-mcp](pdf/pdf-toolkit-mcp/) | 37 | Create, merge, split, watermark, forms, encrypt / 创建、合并、拆分、水印、表单、加密 | [beepboop2025/pdf-toolkit-mcp](https://github.com/beepboop2025/pdf-toolkit-mcp) |

### Office Document Processing / Office 文档处理

Based on / 基于 [dosev-ai/mcp-office](https://github.com/dosev-ai/mcp-office) suite:

| Tool | Tools | Description / 用途 |
|------|-------|-------------------|
| [wordmcp](office/wordmcp/) | 51 | Word docs: create, template assembly, track changes, QA / Word 文档创建、模板组装、修订跟踪、结构 QA |
| [pptmcp](office/pptmcp/) | 48 | PowerPoint: slide editing, Output Contract framework / 幻灯片编辑、Output Contract 框架 |
| [excelmcp](office/excelmcp/) | 65 | Excel: formulas, charts, pivot tables, validation / 公式、图表、数据透视表、数据验证 |

> **Note / 注意:** mcp-office requires Python >= 3.11. File mode works without MS Office; COM features (styling, PDF export, track changes) require Windows + Microsoft Office.
> mcp-office 为 Python 项目，需 Python >= 3.11。文件模式无需 Office；COM 功能需 Windows + Microsoft Office。

## Offline Pack & Install / 离线打包与安装

Bundle all tools and dependencies into a self-contained zip for offline deployment.

将所有工具及依赖打包为自包含的离线安装包，适用于无网络环境。

### Pack (on a machine with internet) / 打包（在有网络的机器上执行）

**Windows:**
```cmd
REM Double-click scripts\pack.cmd, or run:
scripts\pack.cmd                                     # Everything (default)
scripts\pack.cmd --skip-office --skip-python         # PDF tools only
scripts\pack.cmd --skip-pdf --skip-nodejs            # Office tools only
scripts\pack.cmd --no-cache                          # Force re-download
```

**WSL / Linux / Mac:**
```bash
bash scripts/pack.sh                                 # Everything (default)
bash scripts/pack.sh --skip-office --skip-python     # PDF tools only
bash scripts/pack.sh --skip-nodejs --skip-python     # No bundled runtimes
```

Output: `build/mcp-offline-{platform}-{date}.zip`

Bundle contents / 打包产物包含:
- `deps/` — All Node.js & Python dependencies / 全部 npm/pip 依赖
- `deps/runtimes/` — Node.js & Python portable runtimes / Node.js 与 Python 便携版
- `tools/` — Tool source code / 工具源码
- `bin/` — Launcher scripts / 启动器脚本（`.cmd` / `.sh`）
- `config/` — MCP config templates / MCP 配置模板
- `install.cmd` / `install.ps1` / `install.sh` — Installers / 安装脚本

### Install (on an offline machine) / 安装（在无网络的目标机器上执行）

> No admin privileges required — installs to user-writable paths by default.
> 无需管理员权限，默认安装到用户可写目录。

**Windows** — Double-click `install.cmd`, or:
```powershell
.\install.ps1                       # Default: %LOCALAPPDATA%\MCP-Tools
.\install.ps1 -TargetPath "D:\Tools"
```

**Linux / Mac:**
```bash
bash install.sh                     # Default: ~/mcp-tools
bash install.sh --target ~/my-tools
```

The installer automatically / 安装脚本自动:
- Detects system Node.js/Python versions; uses bundled runtimes if system versions don't meet requirements / 检测系统运行时版本，不满足则使用打包版本
- Installs all deps from the unified `deps/` directory (no network) / 从统一 `deps/` 目录安装（无需网络）
- Configures Claude Code & Cline MCP settings (merge, never overwrite) / 配置 Claude Code 与 Cline 的 MCP 设置（合并，不覆盖）

## Quick Start (Online) / 快速开始（联网环境）

### PDF Tools / PDF 工具

```bash
npm install -g @sylphx/pdf-reader-mcp
# pdf-toolkit-mcp must be built from source:
git clone https://github.com/beepboop2025/pdf-toolkit-mcp.git
cd pdf-toolkit-mcp && npm install && npm run build
```

### Office Tools / Office 工具

```bash
git clone https://github.com/dosev-ai/mcp-office.git
cd mcp-office
pip install -e ./shared && pip install -e ./wordmcp && pip install -e ./pptmcp && pip install -e ./excelmcp
```

### Configure AI Tools / 配置 AI 工具

See `config/` templates under each tool directory. / 参考各工具目录下的 `config/` 配置模板。

- [Claude Code config](pdf/pdf-reader-mcp/config/claude-code.json)
- [Cline config](pdf/pdf-reader-mcp/config/cline.json)
- [Codex config](pdf/pdf-reader-mcp/config/codex.json)

## Runtime Requirements / 运行时要求

| Tool / 工具 | Runtime / 运行时 | Minimum Version / 最低版本 |
|-------------|-----------------|---------------------------|
| PDF tools | Node.js | >= 22.13.0 |
| Office tools | Python | >= 3.11 |

## Adding New Tools / 添加新工具

1. Create a subdirectory under the appropriate category / 在对应分类目录下创建子目录
2. Write a README.md with usage, install, and config instructions / 编写 README.md 说明用途、安装和配置方法
3. Add MCP config templates under `config/` for each AI tool / 在 `config/` 下为各 AI 工具提供配置模板
4. Update the tools table above / 更新上方工具表格

## License / 许可

This project provides documentation, configuration templates, and build scripts.
Each MCP tool follows the license of its original project.

本项目仅提供文档、配置模板和构建脚本。各 MCP 工具的许可遵循其原始项目的许可协议。
