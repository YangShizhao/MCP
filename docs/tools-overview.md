# MCP 工具总览

## 工具分类

### 📄 PDF 文档处理 (npm)
- **[pdf-reader-mcp](../pdf/pdf-reader-mcp/)** — 读取、搜索、内容提取、表格识别
- **[pdf-toolkit-mcp](../pdf/pdf-toolkit-mcp/)** — 创建、编辑、操作（37 个工具）

### 📝 Office 文档处理 (Python)
- **[wordmcp](../office/wordmcp/)** — Word 文档创建、模板组装、修订跟踪、结构 QA（51 个工具）
- **[pptmcp](../office/pptmcp/)** — PowerPoint 演示文稿编辑、Output Contract 框架（48 个工具）
- **[excelmcp](../office/excelmcp/)** — Excel 电子表格、公式、图表、数据透视表（65 个工具）

## 兼容性矩阵

| 工具 | Claude Code | Claude Desktop | Cline | Codex | Continue |
|------|:-----------:|:--------------:|:-----:|:-----:|:--------:|
| pdf-reader-mcp | ✅ | ✅ | ✅ | ✅ | ✅ |
| pdf-toolkit-mcp | ✅ | ✅ | ✅ | ✅ | ✅ |
| wordmcp | ✅ | ✅ | ✅ | ✅ | ✅ |
| pptmcp | ✅ | ✅ | ✅ | ✅ | ✅ |
| excelmcp | ✅ | ✅ | ✅ | ✅ | ✅ |

## 运行时要求

| 工具 | 运行时 | 最低版本 | 额外要求 |
|------|--------|----------|----------|
| PDF 工具 | Node.js | >= 22.13.0 | 无 |
| Office 工具 | Python | >= 3.11 | MS Office（COM 功能需要，文件模式不需要） |

## 通用 MCP 配置格式

每个工具目录下 `config/` 文件夹包含针对不同 AI 工具的配置模板。本质上 MCP 配置格式是统一的：

```json
{
  "mcpServers": {
    "<server-name>": {
      "command": "<runtime>",
      "args": ["<package>", "<subcommand>"],
      "env": { "<key>": "<value>" }
    }
  }
}
```

各 AI 工具的配置文件路径略有不同：

| AI 工具 | 配置文件路径 |
|---------|------------|
| Claude Code | `.claude/settings.json` 或 `.claude/mcp.json` |
| Claude Desktop | `claude_desktop_config.json` |
| Cline | VSCode 设置 `cline.mcpServers` |
| Codex | `~/.codex/config.toml` 中的 MCP 配置段 |

## 离线打包

默认打包全部工具 + Node.js + Python 运行时。用 `--skip-*` 排除。

```bash
bash scripts/pack.sh                              # 全部（默认）
bash scripts/pack.sh --skip-office --skip-python  # 仅 PDF
bash scripts/pack.sh --skip-pdf --skip-nodejs     # 仅 Office
bash scripts/pack.sh --skip-nodejs --skip-python  # 不含运行时
```

安装时自动检测系统运行时版本，满足要求则优先使用系统版本，否则自动安装打包的运行时。

## 未来计划

- [ ] 图片/图像处理 MCP 工具
- [ ] 网络搜索 MCP 工具
- [ ] 数据库 MCP 工具
- [ ] 文件系统增强 MCP 工具
