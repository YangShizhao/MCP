# MCP 工具库

适用于多种 AI 工具（Claude Code、Codex、Cline 等）的 MCP (Model Context Protocol) 工具集合。

## 目录结构

```
MCP/
├── README.md                   # 项目总览（本文件）
├── docs/                       # 文档
│   └── tools-overview.md       # 工具总览
├── scripts/                    # 离线打包与安装脚本
│   ├── pack.cmd / pack.ps1    # Windows 打包脚本
│   ├── pack.sh                 # WSL/Linux/Mac 打包脚本
│   ├── install.ps1             # Windows 安装脚本
│   └── install.sh              # Linux/Mac 安装脚本
├── pdf/                        # PDF 文档处理工具
│   ├── pdf-reader-mcp/         # PDF 读取/搜索/内容提取
│   └── pdf-toolkit-mcp/        # PDF 创建/编辑/操作
├── office/                     # Office 文档处理工具
│   ├── wordmcp/                # Word 文档处理（51 个工具）
│   ├── pptmcp/                 # PowerPoint 演示文稿（48 个工具）
│   └── excelmcp/               # Excel 电子表格（65 个工具）
└── ...                         # 更多工具（待添加）
```

## 已集成的 MCP 工具

### PDF 文档处理

| 工具 | 用途 | 来源 |
|------|------|------|
| [pdf-reader-mcp](pdf/pdf-reader-mcp/) | PDF 读取、搜索、内容提取、表格识别 | [sylphlab/pdf-reader-mcp](https://github.com/SylphxAI/pdf-reader-mcp) |
| [pdf-toolkit-mcp](pdf/pdf-toolkit-mcp/) | PDF 创建、合并、拆分、水印、表单、加密等 37 个工具 | [beepboop2025/pdf-toolkit-mcp](https://github.com/beepboop2025/pdf-toolkit-mcp) |

### Office 文档处理（Word / PowerPoint / Excel）

基于 [dosev-ai/mcp-office](https://github.com/dosev-ai/mcp-office) 统一套件：

| 工具 | 工具数 | 用途 |
|------|--------|------|
| [wordmcp](office/wordmcp/) | 51 | Word 文档创建、模板组装、修订跟踪、结构 QA |
| [pptmcp](office/pptmcp/) | 48 | PowerPoint 幻灯片编辑、Output Contract 框架 |
| [excelmcp](office/excelmcp/) | 65 | Excel 电子表格、公式、图表、数据透视表 |

> **注意：** mcp-office 为 Python 项目，需要 Python >= 3.11。文件模式无需 Office 安装，COM 功能（样式/修订/PDF 导出）需要 Microsoft Office + Windows。

## 快速开始

### 1. 安装 Node.js 依赖（PDF 工具）

```bash
# pdf-reader-mcp
npm install -g @sylphx/pdf-reader-mcp

# pdf-toolkit-mcp
npm install -g @beepboop2025/pdf-toolkit-mcp
```

### 2. 配置 AI 工具

根据你使用的 AI 工具，参考各工具目录下的 `config/` 文件夹中的配置文件：

- [Claude Code 配置](pdf/pdf-reader-mcp/config/claude-code.json)
- [Cline 配置](pdf/pdf-reader-mcp/config/cline.json)
- [Codex 配置](pdf/pdf-reader-mcp/config/codex.json)

## 离线安装（无网络环境）

本项目的所有 MCP 工具可以打包为一个自包含的离线安装包，适用于无法访问互联网的目标机器。

### 打包（在有网络的开发机上执行）

**Windows (推荐)：**
```cmd
REM 双击 scripts\pack.cmd 或命令行运行
REM 默认打包全部工具 + 全部运行时（Node.js + Python）
scripts\pack.cmd

REM 仅打包 PDF 工具（不含运行时）
scripts\pack.cmd --skip-office --skip-python

REM 仅打包 Office 工具（不含 Node.js）
scripts\pack.cmd --skip-pdf --skip-nodejs
```

**WSL / Linux / Mac：**
```bash
# 默认打包全部（含运行时）
bash scripts/pack.sh

# 仅打包 PDF（不含 Python 运行时）
bash scripts/pack.sh --skip-office --skip-python

# 不打包运行时（目标机器已有对应环境）
bash scripts/pack.sh --skip-nodejs --skip-python
```

打包产物位于 `build/mcp-offline-{platform}-{date}.zip`，包含：
- 所有 MCP 工具及其全部 npm 依赖
- 启动器脚本（`.cmd` / `.sh`）
- AI 工具配置模板
- 安装脚本
- 可选：Node.js 便携版

### 安装（在无网络的目标机器上执行）

**Windows**：
1. 将 `mcp-offline-*.zip` 复制到目标机器并解压
2. 以管理员身份打开 PowerShell，进入解压目录
3. 运行 `.\install.ps1`

**Linux/Mac**：
1. 将 `mcp-offline-*.zip` 复制到目标机器并解压
2. 进入解压目录，运行 `sudo bash install.sh`

安装脚本会自动：
- **智能检测运行时**：优先使用系统已安装的 Node.js/Python，版本不满足则自动安装打包的运行时
- 安装工具到目标路径（默认 `C:\MCP-Tools` 或 `/opt/mcp-tools`）
- 验证所有工具能正常启动
- 自动配置 Claude Code / Cline 的 MCP 设置
- 可选配置系统 PATH

## 添加新工具

1. 在对应分类目录下创建新的工具子目录
2. 编写 README.md 说明工具的用途、安装和配置方法
3. 在 `config/` 目录下为不同 AI 工具提供 MCP 配置模板
4. 更新本文档的"已集成的 MCP 工具"表格

## 许可

本项目仅提供配置和文档指引工具。各 MCP 工具的许可遵循其原始项目的许可协议。
